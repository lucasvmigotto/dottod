use anyhow::Context;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::path::PathBuf;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum TaskStatus {
    Pending,
    Running,
    Passed,
    Failed,
    Skipped,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct State {
    pub selected: Vec<String>,
    pub results: BTreeMap<String, TaskStatus>,
    pub last_run: Option<String>,
}

impl State {
    pub fn path() -> PathBuf {
        let base = dirs::cache_dir().unwrap_or_else(|| PathBuf::from("/tmp"));
        base.join("dottod").join("state.json")
    }

    pub fn load() -> Self {
        match std::fs::read_to_string(Self::path()) {
            Ok(raw) => serde_json::from_str(&raw).unwrap_or_default(),
            Err(_) => Self::default(),
        }
    }

    pub fn save(&self) -> anyhow::Result<()> {
        let path = Self::path();
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).context("create state dir")?;
        }
        let raw = serde_json::to_string_pretty(self).context("serialize state")?;
        std::fs::write(path, raw).context("write state")?;
        Ok(())
    }
}
