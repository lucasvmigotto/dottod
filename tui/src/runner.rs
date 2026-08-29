use crate::state::TaskStatus;
use crate::task::Task;
use std::collections::HashMap;
use std::path::Path;
use std::process::Stdio;
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::Command;
use tokio::sync::mpsc;

/// Messages emitted by the runner and consumed by the UI.
#[derive(Debug, Clone)]
pub enum Message {
    Log { task: String, line: String },
    Status { task: String, status: TaskStatus },
}

/// Spawn `bin/<task>.sh`, streaming its merged stdout/stderr line-by-line into
/// `tx`, and returning the resulting task status.
pub async fn run_task(
    task: &Task,
    repo_root: &Path,
    env: &HashMap<String, String>,
    tx: mpsc::Sender<Message>,
) -> TaskStatus {
    let script = task.script_path(repo_root);

    let mut cmd = Command::new(&script);
    cmd.stdout(Stdio::piped()).stderr(Stdio::piped());
    cmd.env("NO_COLOR", "1");
    cmd.env("DOT_REPO_ROOT", repo_root);
    for (k, v) in env {
        cmd.env(k, v);
    }

    let mut child = match cmd.spawn() {
        Ok(c) => c,
        Err(e) => {
            let _ = tx
                .send(Message::Log {
                    task: task.id.clone(),
                    line: format!("spawn error: {e}"),
                })
                .await;
            return TaskStatus::Failed;
        }
    };

    let stdout = child.stdout.take().expect("stdout is piped");
    let stderr = child.stderr.take().expect("stderr is piped");

    let t1 = tokio::spawn(pipe_lines(stdout, task.id.clone(), tx.clone()));
    let t2 = tokio::spawn(pipe_lines(stderr, task.id.clone(), tx.clone()));

    let status = child.wait().await;
    let _ = tokio::join!(t1, t2);

    match status {
        Ok(s) if s.success() => TaskStatus::Passed,
        _ => TaskStatus::Failed,
    }
}

async fn pipe_lines<R>(reader: R, task: String, tx: mpsc::Sender<Message>)
where
    R: tokio::io::AsyncRead + Unpin,
{
    let mut lines = BufReader::new(reader).lines();
    while let Ok(Some(line)) = lines.next_line().await {
        if tx
            .send(Message::Log {
                task: task.clone(),
                line,
            })
            .await
            .is_err()
        {
            break;
        }
    }
}
