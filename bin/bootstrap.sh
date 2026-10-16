#!/usr/bin/env bash

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

readonly DOT_TASKS=(shell fonts vim neovim container zed gitconfig ssh tools cargo bun secrets)
readonly DOT_UI_TASKS=(zed)
# Opt-in tasks run only when --only names them (never in a default run).
readonly DOT_OPTIN_TASKS=(secrets)

function _in_list() {
    local needle=${1}
    shift
    local item
    for item in "$@"; do
        [[ "${item}" == "${needle}" ]] && return 0
    done
    return 1
}

function _usage() {
    cat <<'EOF'
Usage: bootstrap.sh [options]

Bootstraps the workstation by running the dottod task scripts.

Options:
  --only <list>      Comma-separated list of tasks to run (default: all)
  --skip <list>      Comma-separated list of tasks to skip
  --parallel         Run tasks concurrently instead of sequentially
  --extras <list>    Opt-in tools for the tools task (gh, httpie, chafa,
                     fastfetch, or all); default none
  --ui               Include GUI tasks (zed); default skips them
  --no-ui            Skip GUI tasks (the default; explicit form of omitting --ui)
  --yes              Assume yes for any prompts
  --verbose, -v      Stream full task output (default: summarized)
  --status           Print every selected task's status report (changes
                     nothing; honours --only, --skip and --ui)
  --list, -l         List available tasks and exit
  --help, -h         Show this help

Tasks:
  shell     bash as login shell + dottod bashrc (plain bash, no plugins)
  fonts     Nerd Fonts (FiraCode, FiraMono, RobotoMono, NerdFontsSymbolsOnly, ZedMono)
  vim       vim + vim-plug + plugins
  neovim    Neovim + lazy.nvim + Telescope (first-class; vim untouched)
  container Podman (rootless)
  zed       Zed editor (user-level install)
  gitconfig Git identity and config
  ssh       SSH config (GitHub host, merged safely) + ed25519 key
  tools     btop, bat, xclip, jq, fzf, shellcheck, bats, shfmt, just (+ --extras)
  cargo     Rust toolchain via rustup (stable, minimal profile)
  bun       Bun JS runtime (direct-zip install, verified) + devcontainer CLI
  secrets   pass + container registry logins through it (opt-in: --only secrets)
EOF
}

function _run_task() {
    local task=${1}
    local script="${DOT_REPO_ROOT}/bin/${task}.sh"

    if [[ ! -f "${script}" ]]; then
        log_error "Unknown task '${task}' (missing ${script})"
        return 1
    fi

    if [[ "${DOT_VERBOSE:-0}" == 1 ]]; then
        "${script}"
    else
        "${script}" >"${DOT_LOG_DIR}/${task}.log" 2>&1
    fi
}

function _run_sequential() {
    local task failures=0
    for task in "$@"; do
        log_step "Running task: ${task}"
        if _run_task "${task}"; then
            log_ok "${task}: PASS"
        else
            log_error "${task}: FAIL (see ${DOT_LOG_DIR}/${task}.log)"
            failures=$((failures + 1))
        fi
    done
    return "${failures}"
}

function _run_parallel() {
    local -a tasks=("$@")
    local -a pids=()
    local task

    for task in "${tasks[@]}"; do
        log_step "Starting task (parallel): ${task}"
        _run_task "${task}" &
        pids+=("$!")
    done

    local i pid failures=0
    for i in "${!tasks[@]}"; do
        pid="${pids[$i]}"
        task="${tasks[$i]}"
        if wait "${pid}"; then
            log_ok "${task}: PASS"
        else
            log_error "${task}: FAIL (see ${DOT_LOG_DIR}/${task}.log)"
            failures=$((failures + 1))
        fi
    done

    return "${failures}"
}

# Every task answers `status` with a read-only report; print them in task
# order. No sudo preflight and no package installs: status changes nothing.
function _status_reports() {
    local task script failures=0
    for task in "$@"; do
        script="${DOT_REPO_ROOT}/bin/${task}.sh"
        if [[ ! -f "${script}" ]]; then
            log_error "Unknown task '${task}' (missing ${script})"
            failures=$((failures + 1))
            continue
        fi
        if ! "${script}" status; then
            log_error "${task}: status report failed"
            failures=$((failures + 1))
        fi
        printf '\n'
    done
    return $((failures > 0))
}

function _main() {
    local only="" skip="" with_ui=0 parallel=0 verbose=0 status=0
    local failures=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --only)
                only="${2:?'--only requires a comma-separated task list'}"
                shift 2
                ;;
            --skip)
                skip="${2:?'--skip requires a comma-separated task list'}"
                shift 2
                ;;
            --extras)
                export DOT_TOOLS_EXTRA="${2:?'--extras requires a comma-separated tool list'}"
                shift 2
                ;;
            --parallel)
                parallel=1
                shift
                ;;
            --ui)
                with_ui=1
                shift
                ;;
            --no-ui)
                with_ui=0
                shift
                ;;
            --yes)
                export DOT_ASSUME_YES=1
                shift
                ;;
            --verbose | -v)
                verbose=1
                shift
                ;;
            --status)
                status=1
                shift
                ;;
            --list | -l)
                printf '%s\n' "${DOT_TASKS[@]}"
                return 0
                ;;
            --help | -h)
                _usage
                return 0
                ;;
            *)
                log_error "Unknown option: $1"
                _usage
                return 1
                ;;
        esac
    done

    export DOT_VERBOSE="${verbose}"
    # One id per bootstrap run: tasks share a single package-index refresh.
    # PID + start time, so a stale stamp from an earlier run never matches.
    export DOT_RUN_ID="${DOT_RUN_ID:-$$.$(date +%s)}"

    local -a tasks=()
    local task
    for task in "${DOT_TASKS[@]}"; do
        if [[ -n "${only}" ]] && [[ ",${only}," != *",${task},"* ]]; then
            continue
        fi
        if _in_list "${task}" "${DOT_OPTIN_TASKS[@]}" && [[ ",${only}," != *",${task},"* ]]; then
            log_info "Skipping opt-in task (select it with --only ${task}): ${task}"
            continue
        fi
        if [[ "${with_ui}" == 0 ]] && _in_list "${task}" "${DOT_UI_TASKS[@]}"; then
            log_info "Skipping UI task (pass --ui to include): ${task}"
            continue
        fi
        if [[ -n "${skip}" ]] && [[ ",${skip}," == *",${task},"* ]]; then
            log_info "Skipping task: ${task}"
            continue
        fi
        tasks+=("${task}")
    done

    if [[ ${#tasks[@]} -lt 1 ]]; then
        log_warn 'No tasks to run'
        return 0
    fi

    if [[ "${status}" == 1 ]]; then
        _status_reports "${tasks[@]}"
        return $?
    fi

    log_step "Bootstrap starting (${#tasks[@]} task(s))"

    _sudo_preflight

    if [[ "${parallel}" == 1 ]]; then
        _run_parallel "${tasks[@]}" || failures=$?
    else
        _run_sequential "${tasks[@]}" || failures=$?
    fi

    if [[ "${failures}" -gt 0 ]]; then
        log_error "Bootstrap finished with ${failures} failure(s)"
        return 1
    fi

    log_ok 'Bootstrap complete'
    return 0
}

_main "$@"
