use anyhow::{anyhow, Context, Result};
use argon2::{Algorithm, Argon2};
use base64urlsafedata::Base64UrlSafeData;
use rand::Rng;
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs::File;

#[derive(Debug, Deserialize, Serialize)]
struct Argon2IDHash {
    m: u32,
    t: u32,
    p: u32,
    v: u32,
    s: Base64UrlSafeData,
    k: Base64UrlSafeData,
}

#[derive(Debug, Deserialize)]
struct SecretMappings {
    account_credentials: HashMap<String, String>,
    oauth2_basic_secrets: HashMap<String, String>,
}

const ACCOUNT_NAME_PATH: &str = "/ent/V2/attrs/name/N8/0";
const ACCOUNT_PRIMARY_CREDENTIAL_PATH: &str =
    "/ent/V2/attrs/primary_credential/CR/0/d/password/ARGON2ID";

const OAUTH2_BASIC_SECRET_PATH: &str = "/ent/V2/attrs/oauth2_rs_basic_secret/RU";
const OAUTH2_NAME_PATH: &str = "/ent/V2/attrs/oauth2_rs_name/N8/0";

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

        let mut any_changes = false;
        any_changes |=
            rewrite_account_credentials(&mut secret_mappings, &mut json_data).unwrap_or(false);
        any_changes |= rewrite_oauth2_secret(&mut secret_mappings, &mut json_data).unwrap_or(false);

        // Update the row in the database if necessary
        if any_changes {
            update_stmt
                .execute(params![serde_json::to_vec(&json_data)?, id])
                .context("Failed to update oauth2 service '{oauth2_rs_name}' in database")?;
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

fn hash_argon2_id(password: &str, salt: Option<Vec<u8>>) -> Result<Argon2IDHash> {
    let salt_len: usize = 16;
    let key_len: usize = 32;
    let version: argon2::Version = argon2::Version::V0x13;
    let m_cost: u32 = 8192;
    let t_cost: u32 = 2;
    let p_cost: u32 = 1;

    let params = argon2::Params::new(m_cost, t_cost, p_cost, None).unwrap_or_default();
    let argon = Argon2::new(Algorithm::Argon2id, version, params);

    let mut rng = rand::thread_rng();
    let salt: Vec<u8> = salt.unwrap_or_else(|| (0..salt_len).map(|_| rng.gen()).collect());
    let mut key: Vec<u8> = (0..key_len).map(|_| 0).collect();
    argon
        .hash_password_into(password.as_bytes(), salt.as_slice(), key.as_mut_slice())
        .map_err(|_| anyhow!("Failed to create argon2id hash of password"))?;

    Ok(Argon2IDHash {
        m: m_cost,
        t: t_cost,
        p: p_cost,
        v: version as u32,
        s: salt.into(),
        k: key.into(),
    })
}

fn rewrite_account_credentials(
    secret_mappings: &mut SecretMappings,
    json_data: &mut serde_json::Value,
) -> Result<bool> {
    if let Some(name) = json_data
        .pointer(ACCOUNT_NAME_PATH)
        .and_then(|value| value.as_str())
        .map(|value| value.to_string())
    {
        if let Some(secret_path) = secret_mappings.account_credentials.remove(&name) {
            let secret = std::fs::read_to_string(&secret_path).context(format!(
                "account: Could not update credential for {name} with {secret_path}",
            ))?;
            if let Some(value) = json_data.pointer_mut(ACCOUNT_PRIMARY_CREDENTIAL_PATH) {
                let secret = secret.trim().to_string();
                let current_hash: Argon2IDHash = serde_json::from_value(value.clone())
                    .map_err(|e| anyhow!("Failed to load current argon2id hash: {e}"))?;
                let test_hash = hash_argon2_id(&secret, Some(current_hash.s.into()))?;

                if current_hash.k != test_hash.k {
                    let new_hash = hash_argon2_id(&secret, None)?;
                    *value = serde_json::to_value(new_hash)?;
                    println!("account: Updated credential for {name}");
                    return Ok(true);
                }
            }
        }
    }
    Ok(false)
}

fn rewrite_oauth2_secret(
    secret_mappings: &mut SecretMappings,
    json_data: &mut serde_json::Value,
) -> Result<bool> {
    if let Some(name) = json_data
        .pointer(OAUTH2_NAME_PATH)
        .and_then(|value| value.as_str())
        .map(|value| value.to_string())
    {
        if let Some(secret_path) = secret_mappings.oauth2_basic_secrets.remove(&name) {
            let secret = std::fs::read_to_string(&secret_path).context(format!(
                "oauth2: Could not update basic secret for {name} with {secret_path}"
            ))?;
            if let Some(value) = json_data.pointer_mut(OAUTH2_BASIC_SECRET_PATH) {
                let secret = secret.trim().to_string();
                if *value != secret {
                    *value = serde_json::Value::String(secret);
                    println!("oauth2: Updated basic secret for {name}");
                    return Ok(true);
                }
            }
        }
    }
    Ok(false)
}
