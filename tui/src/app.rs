use crate::runner::Message;
use crate::state::{State, TaskStatus};
use crate::task::Task;
use crossterm::event::{KeyCode, KeyEvent};
use std::collections::{BTreeMap, HashMap, VecDeque};
use std::path::PathBuf;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Mode {
    Selection,
    Identity,
    Running,
    Summary,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Pane {
    List,
    Log,
}

impl Pane {
    pub fn other(self) -> Self {
        match self {
            Pane::List => Pane::Log,
            Pane::Log => Pane::List,
        }
    }
}

#[derive(Debug, Clone)]
pub struct LogLine {
    pub task: String,
    pub line: String,
}

#[derive(Debug)]
pub struct RunSpec {
    pub tasks: Vec<Task>,
    pub repo_root: PathBuf,
    pub env: HashMap<String, String>,
    pub parallel: bool,
}

#[derive(Debug)]
pub struct KeyOutcome {
    pub quit: bool,
    pub run: Option<RunSpec>,
}

impl KeyOutcome {
    fn none() -> Self {
        Self {
            quit: false,
            run: None,
        }
    }
    fn quit() -> Self {
        Self {
            quit: true,
            run: None,
        }
    }
    fn run(spec: RunSpec) -> Self {
        Self {
            quit: false,
            run: Some(spec),
        }
    }
}

pub struct Config {
    pub tasks: Vec<Task>,
    pub parallel: bool,
    pub yes: bool,
    pub git_name: String,
    pub git_email: String,
    pub repo_root: PathBuf,
    pub state: State,
    pub runtime: String,
    pub runtime_explicit: bool,
}

pub struct IdentityField {
    pub name: String,
    pub email: String,
    /// `false` -> editing name, `true` -> editing email.
    pub current: bool,
}

pub struct App {
    pub tasks: Vec<Task>,
    pub selected: Vec<bool>,
    pub results: BTreeMap<String, TaskStatus>,
    pub cursor: usize,
    pub logs: VecDeque<LogLine>,
    pub focus: Pane,
    pub log_scroll: usize,
    pub mode: Mode,
    pub show_ui: bool,
    pub parallel: bool,
    pub yes: bool,
    pub repo_root: PathBuf,
    pub identity: IdentityField,
    pub active: usize,
    pub should_quit: bool,
    pub tick: u64,
    pub state: State,
    pub runtime: String,
    pub runtime_explicit: bool,
}

const MAX_LOG_LINES: usize = 500;

impl App {
    pub fn new(cfg: Config) -> Self {
        let tasks = cfg.tasks;
        let selected = if cfg.state.selected.is_empty() {
            vec![true; tasks.len()]
        } else {
            tasks
                .iter()
                .map(|t| cfg.state.selected.contains(&t.id))
                .collect()
        };

        let results = cfg.state.results.clone();

        Self {
            tasks,
            selected,
            results,
            cursor: 0,
            logs: VecDeque::new(),
            focus: Pane::List,
            log_scroll: 0,
            mode: Mode::Selection,
            show_ui: true,
            parallel: cfg.parallel,
            yes: cfg.yes,
            repo_root: cfg.repo_root,
            identity: IdentityField {
                name: cfg.git_name,
                email: cfg.git_email,
                current: false,
            },
            active: 0,
            should_quit: false,
            tick: 0,
            state: cfg.state,
            runtime: cfg.runtime,
            runtime_explicit: cfg.runtime_explicit,
        }
    }

    pub fn visible_tasks(&self) -> Vec<usize> {
        (0..self.tasks.len())
            .filter(|&i| self.show_ui || !self.tasks[i].ui)
            .collect()
    }

    pub fn focused_task_id(&self) -> Option<String> {
        self.visible_tasks()
            .get(self.cursor)
            .map(|&i| self.tasks[i].id.clone())
    }

    pub fn status_of(&self, id: &str) -> TaskStatus {
        self.results.get(id).copied().unwrap_or(TaskStatus::Pending)
    }

    pub fn logs_for_render(&self) -> Vec<String> {
        let show_all = matches!(self.mode, Mode::Running | Mode::Summary);
        let focused = self.focused_task_id();
        self.logs
            .iter()
            .filter(|l| show_all || Some(&l.task) == focused.as_ref())
            .map(|l| {
                if show_all {
                    format!("[{}] {}", l.task, l.line)
                } else {
                    l.line.clone()
                }
            })
            .collect()
    }

    pub fn handle_message(&mut self, msg: Message) {
        match msg {
            Message::Log { task, line } => {
                self.logs.push_back(LogLine { task, line });
                while self.logs.len() > MAX_LOG_LINES {
                    self.logs.pop_front();
                }
            }
            Message::Status { task, status } => match status {
                TaskStatus::Running => {
                    self.results.insert(task, TaskStatus::Running);
                }
                final_status => {
                    self.results.insert(task, final_status);
                    self.active = self.active.saturating_sub(1);
                    if self.mode == Mode::Running && self.active == 0 {
                        self.mode = Mode::Summary;
                    }
                }
            },
        }
    }

    pub fn handle_key(&mut self, key: KeyEvent) -> KeyOutcome {
        match self.mode {
            Mode::Selection => self.handle_selection(key),
            Mode::Identity => self.handle_identity(key),
            Mode::Running => self.handle_running(key),
            Mode::Summary => self.handle_summary(key),
        }
    }

    fn handle_selection(&mut self, key: KeyEvent) -> KeyOutcome {
        match key.code {
            KeyCode::Char('q') => return KeyOutcome::quit(),
            KeyCode::Char('j') | KeyCode::Down => self.move_cursor(1),
            KeyCode::Char('k') | KeyCode::Up => self.move_cursor(-1),
            KeyCode::Char(' ') => self.toggle_cursor(),
            KeyCode::Char('a') => self.select_visible(true),
            KeyCode::Char('n') => self.select_visible(false),
            KeyCode::Char('u') => self.toggle_ui(),
            KeyCode::Char('e') => self.cycle_runtime(),
            KeyCode::Tab => self.focus = self.focus.other(),
            KeyCode::Char('h') | KeyCode::Left => self.focus = Pane::List,
            KeyCode::Char('l') | KeyCode::Right => self.focus = Pane::Log,
            KeyCode::PageUp => self.log_scroll = self.log_scroll.saturating_sub(1),
            KeyCode::PageDown => self.log_scroll = self.log_scroll.saturating_add(1),
            KeyCode::Enter => {
                let selected = self.selected_tasks();
                if selected.is_empty() {
                    return KeyOutcome::none();
                }
                if !self.yes
                    && selected.iter().any(|t| t.id == "gitconfig")
                    && !self.identity_complete()
                {
                    self.mode = Mode::Identity;
                    return KeyOutcome::none();
                }
                return KeyOutcome::run(self.build_run_spec(selected));
            }
            _ => {}
        }
        KeyOutcome::none()
    }

    fn handle_identity(&mut self, key: KeyEvent) -> KeyOutcome {
        match key.code {
            KeyCode::Esc | KeyCode::Char('q') => {
                self.mode = Mode::Selection;
            }
            KeyCode::Tab => self.identity.current = !self.identity.current,
            KeyCode::Backspace => self.identity_backspace(),
            KeyCode::Char(c) => self.identity_push(c),
            KeyCode::Enter => {
                if !self.identity.current {
                    self.identity.current = true;
                } else if self.identity_complete() {
                    let selected = self.selected_tasks();
                    self.mode = Mode::Running;
                    return KeyOutcome::run(self.build_run_spec(selected));
                }
            }
            _ => {}
        }
        KeyOutcome::none()
    }

    fn handle_running(&mut self, key: KeyEvent) -> KeyOutcome {
        match key.code {
            KeyCode::Char('q') | KeyCode::Esc => KeyOutcome::quit(),
            KeyCode::PageUp => {
                self.log_scroll = self.log_scroll.saturating_sub(1);
                KeyOutcome::none()
            }
            KeyCode::PageDown => {
                self.log_scroll = self.log_scroll.saturating_add(1);
                KeyOutcome::none()
            }
            _ => KeyOutcome::none(),
        }
    }

    fn handle_summary(&mut self, key: KeyEvent) -> KeyOutcome {
        match key.code {
            KeyCode::Char('q') | KeyCode::Esc => KeyOutcome::quit(),
            KeyCode::Char('r') => {
                let failed: Vec<Task> = self
                    .tasks
                    .iter()
                    .filter(|t| self.status_of(&t.id) == TaskStatus::Failed)
                    .cloned()
                    .collect();
                let rerun = if failed.is_empty() {
                    self.selected_tasks()
                } else {
                    failed
                };
                if rerun.is_empty() {
                    return KeyOutcome::none();
                }
                self.selected = self
                    .tasks
                    .iter()
                    .map(|t| rerun.iter().any(|r| r.id == t.id))
                    .collect();
                KeyOutcome::run(self.build_run_spec(rerun))
            }
            KeyCode::Enter => {
                self.mode = Mode::Selection;
                KeyOutcome::none()
            }
            _ => KeyOutcome::none(),
        }
    }

    fn move_cursor(&mut self, delta: isize) {
        let visible = self.visible_tasks();
        if visible.is_empty() {
            return;
        }
        let len = visible.len() as isize;
        let next = (self.cursor as isize + delta).rem_euclid(len);
        self.cursor = next as usize;
    }

    fn toggle_cursor(&mut self) {
        let visible = self.visible_tasks();
        if let Some(&i) = visible.get(self.cursor) {
            self.selected[i] = !self.selected[i];
        }
    }

    fn select_visible(&mut self, value: bool) {
        for i in self.visible_tasks() {
            self.selected[i] = value;
        }
    }

    fn toggle_ui(&mut self) {
        self.show_ui = !self.show_ui;
        let len = self.visible_tasks().len();
        if len > 0 {
            self.cursor = self.cursor.min(len - 1);
        } else {
            self.cursor = 0;
        }
    }

    /// Cycle the container runtime podman -> docker -> auto. Interacting
    /// marks the choice explicit, so it is forwarded to task scripts.
    fn cycle_runtime(&mut self) {
        self.runtime = match self.runtime.as_str() {
            "podman" => "docker",
            "docker" => "auto",
            _ => "podman",
        }
        .to_string();
        self.runtime_explicit = true;
    }

    fn selected_tasks(&self) -> Vec<Task> {
        self.tasks
            .iter()
            .zip(&self.selected)
            .filter(|(_, s)| **s)
            .map(|(t, _)| t.clone())
            .collect()
    }

    fn identity_complete(&self) -> bool {
        !self.identity.name.trim().is_empty() && !self.identity.email.trim().is_empty()
    }

    fn identity_push(&mut self, c: char) {
        if self.identity.current {
            self.identity.email.push(c);
        } else {
            self.identity.name.push(c);
        }
    }

    fn identity_backspace(&mut self) {
        if self.identity.current {
            self.identity.email.pop();
        } else {
            self.identity.name.pop();
        }
    }

    fn build_run_spec(&mut self, selected: Vec<Task>) -> RunSpec {
        self.results.clear();
        self.active = selected.len();
        self.mode = Mode::Running;

        let mut env = HashMap::new();
        if !self.identity.name.trim().is_empty() {
            env.insert("GIT_NAME".to_string(), self.identity.name.clone());
        }
        if !self.identity.email.trim().is_empty() {
            env.insert("GIT_EMAIL".to_string(), self.identity.email.clone());
        }
        // Forward an explicit runtime choice; otherwise leave the ambient
        // environment (or each script's Podman default) untouched.
        if self.runtime_explicit {
            env.insert("_DOT_CONTAINER_RUNTIME".to_string(), self.runtime.clone());
        }

        RunSpec {
            tasks: selected,
            repo_root: self.repo_root.clone(),
            env,
            parallel: self.parallel,
        }
    }

    pub fn sync_state(&mut self) {
        self.state.selected = self
            .tasks
            .iter()
            .zip(&self.selected)
            .filter(|(_, s)| **s)
            .map(|(t, _)| t.id.clone())
            .collect();
        self.state.results = self.results.clone();
        self.state.last_run = Some(
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.as_secs().to_string())
                .unwrap_or_default(),
        );
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_app(runtime: &str, explicit: bool) -> App {
        App::new(Config {
            tasks: Vec::new(),
            parallel: false,
            yes: false,
            git_name: String::new(),
            git_email: String::new(),
            repo_root: PathBuf::from("/tmp"),
            state: State::default(),
            runtime: runtime.to_string(),
            runtime_explicit: explicit,
        })
    }

    #[test]
    fn runtime_cycles_podman_docker_auto() {
        let mut app = test_app("podman", false);
        app.cycle_runtime();
        assert_eq!(app.runtime, "docker");
        assert!(app.runtime_explicit);
        app.cycle_runtime();
        assert_eq!(app.runtime, "auto");
        app.cycle_runtime();
        assert_eq!(app.runtime, "podman");
    }

    #[test]
    fn runtime_cycle_recovers_unknown_value() {
        let mut app = test_app("bogus", false);
        app.cycle_runtime();
        assert_eq!(app.runtime, "podman");
        assert!(app.runtime_explicit);
    }

    #[test]
    fn run_spec_forwards_explicit_runtime_only() {
        let mut implicit = test_app("podman", false);
        let spec = implicit.build_run_spec(Vec::new());
        assert!(!spec.env.contains_key("_DOT_CONTAINER_RUNTIME"));

        let mut explicit = test_app("docker", true);
        let spec = explicit.build_run_spec(Vec::new());
        assert_eq!(
            spec.env.get("_DOT_CONTAINER_RUNTIME").map(String::as_str),
            Some("docker")
        );
    }
}
