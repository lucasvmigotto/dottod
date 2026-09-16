use std::path::{Path, PathBuf};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Task {
    pub id: String,
    pub description: String,
    pub ui: bool,
    pub needs_apt: bool,
    pub dependencies: Vec<String>,
}

impl Task {
    pub fn script_path(&self, repo_root: &Path) -> PathBuf {
        repo_root.join("bin").join(format!("{}.sh", self.id))
    }
}

/// The task registry mirrors `DOT_TASKS` / `DOT_UI_TASKS` in `bin/bootstrap.sh`.
pub fn registry() -> Vec<Task> {
    let ui_ids = ["desktop", "vscode", "ghostty"];
    [
        ("shell", "zsh + oh-my-zsh + spaceship prompt + system info"),
        (
            "fonts",
            "Nerd Fonts (FiraCode, FiraMono, RobotoMono, NerdFontsSymbolsOnly, ZedMono)",
        ),
        ("vim", "vim + vim-plug + plugins"),
        (
            "container",
            "Container runtime (Podman default, Docker alternative)",
        ),
        ("desktop", "GNOME system monitor, dark theme and fonts"),
        ("vscode", "VSCode (Microsoft apt repo)"),
        ("ghostty", "Ghostty terminal + set as default"),
        ("gitconfig", "Git identity and config"),
        ("ssh", "SSH config (GitHub host, merged safely)"),
        (
            "tools",
            "lazygit, lazydocker, k9s, btop, httpie, bat, resterm, xclip, chafa",
        ),
    ]
    .into_iter()
    .map(|(id, description)| Task {
        id: id.to_string(),
        description: description.to_string(),
        ui: ui_ids.contains(&id),
        needs_apt: !matches!(id, "gitconfig" | "ssh"),
        dependencies: Vec::new(),
    })
    .collect()
}

/// Resolve the container runtime selection: explicit value or Podman default.
/// Mirrors `_ctr_configured` in scripts/.container.utils.sh; keep the two
/// value sets in sync.
pub fn resolve_runtime(raw: Option<&str>) -> anyhow::Result<String> {
    let Some(value) = raw else {
        return Ok("podman".to_string());
    };
    let normalized = value.to_lowercase();
    match normalized.as_str() {
        "podman" | "docker" | "auto" => Ok(normalized),
        _ => anyhow::bail!("invalid container runtime '{value}' (want podman|docker|auto)"),
    }
}

/// Resolve the repository root:
/// 1. explicit `--repo` path,
/// 2. `DOT_REPO_ROOT` environment variable,
/// 3. walking up from the current executable,
/// 4. current working directory.
pub fn resolve_repo_root(cli_repo: Option<PathBuf>) -> PathBuf {
    if let Some(p) = cli_repo {
        if p.join("bin").is_dir() {
            return p;
        }
    }

    if let Ok(p) = std::env::var("DOT_REPO_ROOT") {
        let p = PathBuf::from(p);
        if p.join("bin").is_dir() {
            return p;
        }
    }

    if let Ok(exe) = std::env::current_exe() {
        let mut dir = exe.parent().map(|p| p.to_path_buf());
        while let Some(d) = dir {
            if d.join("bin").join("bootstrap.sh").exists() {
                return d;
            }
            dir = d.parent().map(|p| p.to_path_buf());
        }
    }

    std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn repo_root() -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .expect("tui/ has a parent")
            .to_path_buf()
    }

    fn parse_list(line: &str) -> Vec<String> {
        let inner = line
            .split('(')
            .nth(1)
            .and_then(|s| s.split(')').next())
            .expect("expected list in parentheses");
        inner.split_whitespace().map(str::to_string).collect()
    }

    #[test]
    fn registry_matches_bootstrap() {
        let src = std::fs::read_to_string(repo_root().join("bin/bootstrap.sh"))
            .expect("bootstrap.sh is readable");

        let tasks_line = src
            .lines()
            .find(|l| l.contains("DOT_TASKS="))
            .expect("DOT_TASKS declared");
        let ui_line = src
            .lines()
            .find(|l| l.contains("DOT_UI_TASKS="))
            .expect("DOT_UI_TASKS declared");

        let expected_tasks = parse_list(tasks_line);
        let expected_ui = parse_list(ui_line);

        let reg = registry();
        let ids: Vec<String> = reg.iter().map(|t| t.id.clone()).collect();
        assert_eq!(ids, expected_tasks);

        for t in &reg {
            assert_eq!(
                t.ui,
                expected_ui.contains(&t.id),
                "ui flag mismatch for {}",
                t.id
            );
        }
    }

    #[test]
    fn runtime_defaults_to_podman() {
        assert_eq!(resolve_runtime(None).unwrap(), "podman");
    }

    #[test]
    fn runtime_accepts_each_value() {
        for v in ["podman", "docker", "auto", "Podman", "DOCKER", "Auto"] {
            assert!(resolve_runtime(Some(v)).is_ok(), "{v} should be accepted");
        }
        assert_eq!(resolve_runtime(Some("Docker")).unwrap(), "docker");
    }

    #[test]
    fn runtime_rejects_invalid() {
        for v in ["", "bogus", "podman ", " containerd", "docker-compose"] {
            assert!(
                resolve_runtime(Some(v)).is_err(),
                "{v:?} should be rejected"
            );
        }
    }
}
