#!/usr/bin/env bash

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

readonly DOT_TASKS=(shell fonts vim neovim container zed gitconfig ssh tools cargo bun)
readonly DOT_UI_TASKS=(zed)

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
  --extras <list>    Opt-in tools for the tools task (gh, lazygit, lazydocker,
                     k9s, resterm, httpie, chafa, or all); default none
  --ui               Include GUI tasks (zed); default skips them
  --no-ui            Skip GUI tasks (the default; explicit form of omitting --ui)
  --yes              Assume yes for any prompts
  --verbose, -v      Stream full task output (default: summarized)
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

function _main() {
    local only="" skip="" with_ui=0 parallel=0 verbose=0
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
