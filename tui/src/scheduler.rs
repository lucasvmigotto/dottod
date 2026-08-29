use crate::runner::{run_task, Message};
use crate::state::TaskStatus;
use crate::task::Task;
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::{mpsc, Semaphore};
use tokio::task::JoinSet;

/// Run the given tasks and return a map of task id -> final status.
///
/// When `parallel` is false, tasks run sequentially in the order given. When
/// `parallel` is true, tasks run concurrently but at most one `needs_apt` task
/// runs at a time (mirroring the dpkg lock), while non-apt tasks are capped at
/// the number of available CPUs.
pub async fn run_tasks(
    tasks: Vec<Task>,
    repo_root: PathBuf,
    env: HashMap<String, String>,
    parallel: bool,
    tx: mpsc::Sender<Message>,
) -> HashMap<String, TaskStatus> {
    let mut results = HashMap::new();

    if !parallel {
        for task in &tasks {
            let _ = tx
                .send(Message::Status {
                    task: task.id.clone(),
                    status: TaskStatus::Running,
                })
                .await;
            let status = run_task(task, &repo_root, &env, tx.clone()).await;
            let _ = tx
                .send(Message::Status {
                    task: task.id.clone(),
                    status,
                })
                .await;
            results.insert(task.id.clone(), status);
        }
        return results;
    }

    let apt_sem = Arc::new(Semaphore::new(1));
    let gen_sem = Arc::new(Semaphore::new(concurrency_limit()));
    let mut set = JoinSet::new();

    for task in tasks {
        let tx = tx.clone();
        let repo_root = repo_root.clone();
        let env = env.clone();
        let apt_sem = Arc::clone(&apt_sem);
        let gen_sem = Arc::clone(&gen_sem);

        set.spawn(async move {
            let permit = if task.needs_apt {
                apt_sem.acquire().await
            } else {
                gen_sem.acquire().await
            };

            // Hold the permit until the task finishes.
            let _permit = match permit {
                Ok(p) => p,
                Err(_) => {
                    return (task.id.clone(), TaskStatus::Failed);
                }
            };

            let _ = tx
                .send(Message::Status {
                    task: task.id.clone(),
                    status: TaskStatus::Running,
                })
                .await;

            let status = run_task(&task, &repo_root, &env, tx.clone()).await;

            let _ = tx
                .send(Message::Status {
                    task: task.id.clone(),
                    status,
                })
                .await;

            drop(_permit);

            (task.id.clone(), status)
        });
    }

    while let Some(res) = set.join_next().await {
        if let Ok((id, status)) = res {
            results.insert(id, status);
        }
    }

    results
}

fn concurrency_limit() -> usize {
    std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(4)
        .max(1)
}
