mod app;
mod runner;
mod scheduler;
mod state;
mod task;
mod ui;

use app::{App, Config, KeyOutcome};
use clap::Parser;
use crossterm::{
    event::{self, Event, KeyCode, KeyModifiers},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{backend::CrosstermBackend, Terminal};
use std::io;
use std::path::PathBuf;
use std::process::Command as StdCommand;
use std::time::Duration;
use tokio::sync::mpsc;

use crate::runner::Message;
use crate::state::State;

#[derive(Parser)]
#[command(name = "dottod", about = "Interactive bootstrap TUI for dottod")]
struct Cli {
    /// Comma-separated list of tasks to run (default: all)
    #[arg(long, value_name = "LIST")]
    only: Option<String>,

    /// Comma-separated list of tasks to skip
    #[arg(long, value_name = "LIST")]
    skip: Option<String>,

    /// Run tasks concurrently instead of sequentially
    #[arg(long)]
    parallel: bool,

    /// Skip GUI/desktop tasks (desktop, vscode, ghostty)
    #[arg(long)]
    no_ui_support: bool,

    /// Assume yes for prompts
    #[arg(long)]
    yes: bool,

    /// Path to the repository root (default: auto-detected)
    #[arg(long, value_name = "PATH")]
    repo: Option<PathBuf>,

    /// Container runtime: podman, docker, or auto (default: podman)
    #[arg(long, value_name = "RUNTIME")]
    runtime: Option<String>,
}

fn split_ids(s: &str) -> Vec<String> {
    s.split(',')
        .map(|x| x.trim().to_string())
        .filter(|x| !x.is_empty())
        .collect()
}

fn apply_filters(mut tasks: Vec<task::Task>, cli: &Cli) -> Vec<task::Task> {
    let only = cli.only.as_ref().map(|s| split_ids(s));
    let skip = cli.skip.as_ref().map(|s| split_ids(s)).unwrap_or_default();

    tasks.retain(|t| {
        if cli.no_ui_support && t.ui {
            return false;
        }
        if let Some(o) = &only {
            if !o.contains(&t.id) {
                return false;
            }
        }
        !skip.contains(&t.id)
    });

    tasks
}

fn is_root() -> bool {
    StdCommand::new("id")
        .arg("-u")
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim() == "0")
        .unwrap_or(false)
}

/// Ensure privilege escalation is available before entering raw mode.
///
/// When running as a non-root user without passwordless sudo/doas, this prompts
/// once on the terminal (sudo -v / doas true) so the underlying scripts can
/// reuse the cached credential without needing a TTY themselves.
fn preflight_privilege() -> anyhow::Result<()> {
    if is_root() {
        return Ok(());
    }

    let tool = if StdCommand::new("sudo").arg("--version").output().is_ok() {
        "sudo"
    } else {
        "doas"
    };

    let nopasswd = StdCommand::new(tool)
        .arg("-n")
        .arg("true")
        .status()
        .map(|s| s.success())
        .unwrap_or(false);
    if nopasswd {
        return Ok(());
    }

    let args: &[&str] = if tool == "sudo" { &["-v"] } else { &["true"] };
    let status = StdCommand::new(tool)
        .args(args)
        .status()
        .map_err(|e| anyhow::anyhow!("failed to run {tool}: {e}"))?;
    if !status.success() {
        anyhow::bail!("{tool} authentication failed");
    }
    Ok(())
}

fn git_config_value(key: &str) -> String {
    StdCommand::new("git")
        .args(["config", "--global", key])
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_default()
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();
    let repo_root = task::resolve_repo_root(cli.repo.clone());
    let tasks = apply_filters(task::registry(), &cli);
    let runtime = task::resolve_runtime(cli.runtime.as_deref())?;

    preflight_privilege()?;

    let state = State::load();
    let cfg = Config {
        tasks,
        parallel: cli.parallel,
        yes: cli.yes,
        git_name: git_config_value("user.name"),
        git_email: git_config_value("user.email"),
        repo_root,
        state,
        runtime: runtime.clone(),
        runtime_explicit: cli.runtime.is_some(),
    };
    let mut app = App::new(cfg);

    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;
    terminal.hide_cursor()?;

    let result = run_loop(&mut terminal, &mut app).await;

    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    app.sync_state();
    let _ = app.state.save();

    result
}

async fn run_loop(
    terminal: &mut Terminal<CrosstermBackend<io::Stdout>>,
    app: &mut App,
) -> anyhow::Result<()> {
    let (tx, mut rx) = mpsc::channel::<Message>(256);

    loop {
        terminal.draw(|f| ui::draw(f, app))?;

        if event::poll(Duration::ZERO)? {
            if let Event::Key(key) = event::read()? {
                if key.code == KeyCode::Char('c') && key.modifiers.contains(KeyModifiers::CONTROL) {
                    app.should_quit = true;
                } else {
                    let KeyOutcome { quit, run } = app.handle_key(key);
                    if quit {
                        app.should_quit = true;
                    }
                    if let Some(spec) = run {
                        let tx = tx.clone();
                        tokio::spawn(async move {
                            scheduler::run_tasks(
                                spec.tasks,
                                spec.repo_root,
                                spec.env,
                                spec.parallel,
                                tx,
                            )
                            .await;
                        });
                    }
                }
            }
        }

        while let Ok(msg) = rx.try_recv() {
            app.handle_message(msg);
        }

        if app.should_quit {
            break;
        }

        app.tick = app.tick.wrapping_add(1);
        tokio::time::sleep(Duration::from_millis(16)).await;
    }

    Ok(())
}
