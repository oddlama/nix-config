use anyhow::{Context, Result};
use rusqlite::{params, Connection};
use serde::Deserialize;
use std::collections::HashMap;
use std::fs::File;

#[derive(Debug, Deserialize)]
struct SecretMappings {
    oauth2_basic_secrets: HashMap<String, String>,
}

fn main() -> Result<()> {
    // Read command-line arguments
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 3 {
        eprintln!("Usage: kanidm-secret-manipulator <db.sqlite> <mappings.json>");
        std::process::exit(1);
    }

    // Open JSON mappings file
    let mappings_file = File::open(&args[2]).context("Failed to open mappings file")?;
    let mut secret_mappings: SecretMappings =
        serde_json::from_reader(mappings_file).context("Failed to parse mappings file")?;

    // Open SQLite database
    let db_path = &args[1];
    let conn = Connection::open(db_path)
        .with_context(|| format!("Failed to open database: {}", db_path))?;

    // Prepare statement to update rows
    let mut update_stmt = conn
        .prepare("UPDATE id2entry SET data = ? WHERE id = ?")
        .context("Failed to prepare update statement")?;

    // Iterate over rows and update secrets
    let mut stmt = conn
        .prepare("SELECT id, data FROM id2entry")
        .context("Failed to prepare SELECT statement")?;

    let rows = stmt
        .query_map([], |row| {
            let id: i64 = row.get(0)?;
            let data: Vec<u8> = row.get(1)?;

            Ok((id, data))
        })
        .context("Failed to execute SELECT statement")?;

    for row in rows {
        let (id, data) = row?;
        let mut json_data: serde_json::Value = serde_json::from_slice(&data)?;

        // Clone paths for updating
        let oauth2_rs_name_path = json_data
            .pointer("/ent/V2/attrs/oauth2_rs_name/N8/0")
            .and_then(|value| value.as_str())
            .map(|value| value.to_string()); // Clone the value
        let oauth2_rs_basic_secret_path = "/ent/V2/attrs/oauth2_rs_basic_secret/RU";

        if let Some(oauth2_rs_name) = oauth2_rs_name_path {
            if let Some(secret_path) = secret_mappings.oauth2_basic_secrets.remove(&oauth2_rs_name)
            {
                match std::fs::read_to_string(&secret_path) {
                    Ok(secret) => {
                        let secret = secret.trim();

                        // Update the cloned JSON data
                        if let Some(value) = json_data.pointer_mut(oauth2_rs_basic_secret_path) {
                            *value = serde_json::Value::String(secret.to_string());
                        }

                        // Update the row in the database
                        update_stmt
                            .execute(params![serde_json::to_vec(&json_data)?, id])
                            .context(
                                "Failed to update oauth2 service '{oauth2_rs_name}' in database",
                            )?;

                        println!("oauth2: Updated {oauth2_rs_name}");
                    }
                    Err(e) => eprintln!(
                        "oauth2: Could not update {oauth2_rs_name} with {secret_path}: {e}"
                    ),
                }
            }
        }
    }

    // Print missing items
    if !secret_mappings.oauth2_basic_secrets.is_empty() {
        eprintln!(
            "oauth2: Skipped update of missing services: {}",
            secret_mappings
                .oauth2_basic_secrets
                .keys()
                .cloned()
                .collect::<Vec<String>>()
                .join(", ")
        );
    }

    Ok(())
}
