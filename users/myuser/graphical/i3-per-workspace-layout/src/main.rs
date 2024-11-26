use anyhow::{anyhow, Context, Result};
use clap::Parser;
use log::{debug, info, warn};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use tokio::{sync::mpsc, task::JoinHandle};
use tokio_i3ipc::{
    event::{Event, Subscribe, WindowChange, WorkspaceChange},
    msg::Msg,
    reply::{Node, NodeLayout, NodeType},
    I3,
};
use tokio_stream::StreamExt;

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    /// Specifies the confiuguration file that maps workspace names to their desired layout.
    /// Should be a simple toml file containing a category [layouts] that contains the mapping.
    #[arg(short, long, value_name = "FILE")]
    config: PathBuf,
}

/// Example:
///
/// ```toml
/// [layouts]
/// "1" = "stacked"
/// "2" = "tabbed"
/// # ...
/// ```
#[derive(Debug, Serialize, Deserialize)]
struct Config {
    /// The workspace -> layout associations
    layouts: HashMap<String, NodeLayout>,
}

fn find_workspace_for_window(tree: &Node, window_id: usize) -> Option<&Node> {
    fn inner<'a>(node: &'a Node, window_id: usize, mut ret_workspace: Option<&'a Node>) -> Option<&'a Node> {
        if node.node_type == NodeType::Workspace {
            ret_workspace = Some(node);
        }

        if node.id == window_id {
            return ret_workspace;
        }

        for child in &node.nodes {
            if let Some(workspace) = inner(child, window_id, ret_workspace) {
                return Some(workspace);
            }
        }

        None
    }

    inner(tree, window_id, None)
}

#[tokio::main]
async fn main() -> Result<()> {
    flexi_logger::Logger::try_with_env()?.start()?;
    let cli = Cli::parse();

    // Load the layout configuration from the TOML file.
    let config_file = std::fs::read_to_string(cli.config)?;
    let config: Config = toml::from_str(&config_file)?;

    debug!("Connecting to i3 to send and receive events...");
    let (send, mut recv) = mpsc::channel::<String>(10);
    let s_handle: JoinHandle<Result<()>> = tokio::spawn(async move {
        let mut event_listener = {
            let mut i3 = I3::connect().await?;
            i3.subscribe([Subscribe::Workspace, Subscribe::Window]).await?;
            i3.listen()
        };

        // Second connection to allow querying workspaces when needed.
        let mut i3 = I3::connect().await?;

        info!("Waiting for workspace events...");
        while let Some(Ok(event)) = event_listener.next().await {
            match event {
                Event::Workspace(data) if data.change == WorkspaceChange::Focus => {
                    let workspace = data
                        .current
                        .ok_or_else(|| anyhow!("Missing current field on workspace event. Is your i3 up-to-date?"))?;

                    let Some(cmd) = cmd_toggle_layout(&config, &workspace) else { continue };
                    send.send(cmd).await.context("Failed to queue command for sending")?;
                }
                Event::Window(data) if matches!(data.change, WindowChange::New | WindowChange::Move) => {
                    let tree = i3.get_tree().await?;
                    if let Some(workspace) = find_workspace_for_window(&tree, data.container.id) {
                        let Some(cmd) = cmd_toggle_layout(&config, workspace) else { continue };
                        send.send(cmd).await.context("Failed to queue command for sending")?;
                    } else {
                        debug!("Ignoring window without workspace {:?}", data.container.id);
                    }
                }
                _ => {}
            }
        }
        Ok(())
    });

    let r_handle: JoinHandle<Result<()>> = tokio::spawn(async move {
        let mut i3 = I3::connect().await?;
        while let Some(cmd) = recv.recv().await {
            i3.send_msg_body(Msg::RunCommand, cmd).await?;
        }
        Ok(())
    });

    let (send, recv) = tokio::try_join!(s_handle, r_handle)?;
    send.and(recv)?;
    debug!("Shutting down...");
    Ok(())
}

fn cmd_toggle_layout(config: &Config, workspace: &Node) -> Option<String> {
    let mut con = workspace;
    let name = workspace.name.as_ref()?;
    let desired_layout = config.layouts.get(name)?;

    // If the workspace already has a single child node that is a container,
    // we want to change the layout of that one instead.
    if workspace.nodes.len() == 1 && workspace.nodes[0].node_type == NodeType::Con {
        con = &workspace.nodes[0];

        // This command works very strangely, as it always targets the parent
        // container of the specified container. So we now have to find the first child
        // and operate on that instead... Wow.
        // If the container is empty, we refuse to do anything.
        if con.nodes.is_empty() {
            return None;
        }

        // Don't do anything if the layout is already correct
        if &con.layout == desired_layout {
            return None;
        }

        con = &con.nodes[0];
    } else {
        // Strangely enough, setting a layout on the workspace container will create a new
        // container inside of it. So if we haven't found a single container to modify,
        // we can operate on the workspace.
    }

    let desired_layout = match desired_layout {
        NodeLayout::SplitH => "splith",
        NodeLayout::SplitV => "splitv",
        NodeLayout::Stacked => "stacked",
        NodeLayout::Tabbed => "tabbed",
        x => {
            warn!("Encountered invalid layout in configuration: {:?}", x);
            return None;
        }
    };

    debug!(
        "Changing layout of workspace {:?} to {} (modifying con_id={})",
        &name, desired_layout, con.id
    );

    Some(format!("[con_id={}] layout {}", con.id, desired_layout))
}
