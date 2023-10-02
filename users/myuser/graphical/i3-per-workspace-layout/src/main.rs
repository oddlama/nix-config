// Inspired by https://github.com/chmln/i3-auto-layout (MIT licensed)

use anyhow::{anyhow, Context, Result};
use clap::Parser;
use log::{debug, info};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use tokio::{sync::mpsc, task::JoinHandle};
use tokio_i3ipc::{
    event::{Event, Subscribe, WorkspaceChange},
    msg::Msg,
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
    /// Whether to force setting the layout even on filled workspaces
    #[serde(default)] // false
    force: bool,
    /// The workspace -> layout associations
    layouts: HashMap<String, String>,
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
            i3.subscribe([Subscribe::Workspace]).await?;
            i3.listen()
        };

        info!("Waiting for workspace events...");
        loop {
            let Some(Ok(Event::Workspace(workspace_event))) = event_listener.next().await else { continue };

            debug!(
                "Got workspace event: name={:?}, change={:?}",
                workspace_event.current.clone().and_then(|x| x.name),
                workspace_event.change
            );

            if WorkspaceChange::Focus == workspace_event.change {
                let workspace = workspace_event
                    .current
                    .ok_or_else(|| anyhow!("Missing current field on workspace event. Is your i3 up-to-date?"))?;

                // Only change the layout if the workspace is empty or force == true
                if !workspace.nodes.is_empty() && !config.force {
                    continue;
                }

                let Some(name) = workspace.name else { continue };
                let Some(desired_layout) = config.layouts.get(&name) else { continue };

                send.send(format!("[con_id={}] layout {}", workspace.id, desired_layout))
                    .await
                    .context("Failed to queue command for sending")?;

                debug!("Changed layout of workspace {:?} to {}", &name, desired_layout);
            }
        }
    });

    let r_handle: JoinHandle<Result<()>> = tokio::spawn(async move {
        let mut i3 = I3::connect().await?;
        loop {
            let Some(cmd) = recv.recv().await else { continue };
            i3.send_msg_body(Msg::RunCommand, cmd).await?;
        }
    });

    let (send, recv) = tokio::try_join!(s_handle, r_handle)?;
    send.and(recv)?;
    debug!("Shutting down...");
    Ok(())
}
