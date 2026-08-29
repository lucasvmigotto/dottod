#!/usr/bin/env bash

set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

readonly DOT_TASKS=(shell fonts vim docker desktop vscode ghostty gitconfig ssh tools)
readonly DOT_UI_TASKS=(desktop vscode ghostty)

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
  --no-ui-support    Skip GUI/desktop tasks (desktop, vscode, ghostty)
  --yes              Assume yes for any prompts
  --verbose, -v      Stream full task output (default: summarized)
  --list, -l         List available tasks and exit
  --help, -h         Show this help

Tasks:
  shell     zsh + oh-my-zsh + spaceship prompt
  fonts     Nerd Fonts (FiraCode, FiraMono, RobotoMono, NerdFontsSymbolsOnly, ZedMono)
  vim       vim + vim-plug + plugins
  docker    Docker Engine (official apt repo)
  desktop   GNOME system monitor, dark theme and fonts
  vscode    VSCode (Microsoft apt repo)
  ghostty   Ghostty terminal + set as default
  gitconfig Git identity and config
  ssh       SSH config (links ~/.ssh/config)
  tools     lazygit, lazydocker, k9s, btop, httpie, bat, resterm, xclip, chafa
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
    local only="" skip="" no_ui=0 parallel=0 verbose=0
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
            --parallel)
                parallel=1
                shift
                ;;
            --no-ui-support)
                no_ui=1
                shift
                ;;
            --yes)
                export DOT_ASSUME_YES=1
                shift
                ;;
            --verbose|-v)
                verbose=1
                shift
                ;;
            --list|-l)
                printf '%s\n' "${DOT_TASKS[@]}"
                return 0
                ;;
            --help|-h)
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

    local -a tasks=()
    local task
    for task in "${DOT_TASKS[@]}"; do
        if [[ -n "${only}" ]] && [[ ",${only}," != *",${task},"* ]]; then
            continue
        fi
        if [[ "${no_ui}" == 1 ]] && _in_list "${task}" "${DOT_UI_TASKS[@]}"; then
            log_info "Skipping UI task: ${task}"
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
