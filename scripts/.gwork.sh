#!/usr/bin/env bash
# gwork — give chosen repositories the work git identity (spec 016).
#
#   gwork                          which identity this repo resolves, and from where
#   gwork clone <url> [dir] [opts] git clone, with the work identity in the clone's
#                                  local config; then cd into it
#   gwork set [dir]                mark an existing checkout as work (local config)
#   gwork unset [dir]              back to the default (the global identity)
#
# The work identity comes from GIT_WORK_NAME/GIT_WORK_EMAIL, else from
# ~/.gitconfig-work (written by the gitconfig task; plain data, included by
# nothing). Personal — the global identity — stays the default everywhere;
# git's own config is the only record of which repos are work.
#
# Any URL git accepts works unchanged (scp-style SSH, ssh://, https://) on
# any host: gwork never parses or rewrites it.
#
# Pure definitions: sourcing this file prints nothing and changes nothing.

# Prints "name<TAB>email" of the work identity, or fails with a hint.
__gwork_identity() {
    local name=${GIT_WORK_NAME:-} email=${GIT_WORK_EMAIL:-}
    local file="${HOME}/.gitconfig-work"
    [[ -z $name ]] && name=$(git config --file "$file" user.name 2>/dev/null)
    [[ -z $email ]] && email=$(git config --file "$file" user.email 2>/dev/null)
    if [[ -z $name || -z $email ]]; then
        echo 'gwork: no work identity: set GIT_WORK_NAME and GIT_WORK_EMAIL, or run' >&2
        echo '       GIT_WORK_NAME=… GIT_WORK_EMAIL=… ./bin/bootstrap.sh --only gitconfig' >&2
        return 1
    fi
    printf '%s\t%s\n' "$name" "$email"
}

# The directory `git clone <url>` creates when none is given: git's
# "humanish" part — trailing slashes and .git (or /.git) dropped, then the
# last component after '/' or ':'.
__gwork_humanish() {
    local u=$1
    while [[ $u == */ ]]; do u=${u%/}; done
    u=${u%/.git}
    u=${u%.git}
    while [[ $u == */ ]]; do u=${u%/}; done
    u=${u##*/}
    u=${u##*:}
    printf '%s\n' "$u"
}

# Repository top level for a dir (default: here), or fail with git's error.
__gwork_top() {
    git -C "${1:-.}" rev-parse --show-toplevel
}

__gwork_status() {
    local top name email work_email origin ctx
    top=$(__gwork_top "${1:-.}") || return
    name=$(git -C "$top" config user.name 2>/dev/null)
    email=$(git -C "$top" config user.email 2>/dev/null)
    if [[ -z $email ]]; then
        printf '%s: no identity (git would refuse to commit)\n' "$top"
        return 0
    fi
    origin=$(git -C "$top" config --show-scope user.email 2>/dev/null)
    origin=${origin%%$'\t'*}
    ctx=personal
    work_email=$(__gwork_identity 2>/dev/null) && work_email=${work_email#*$'\t'}
    [[ -n $work_email && ${email,,} == "${work_email,,}" ]] && ctx=work
    printf '%s: %s — %s <%s> (%s config)\n' "$top" "$ctx" "$name" "$email" "${origin:-?}"
}

__gwork_clone() {
    local id name email
    id=$(__gwork_identity) || return
    name=${id%%$'\t'*}
    email=${id#*$'\t'}

    # Find the URL and optional dir among git clone's arguments, skipping
    # options (and the value of those that take one) — only to know where
    # the clone lands; every argument still goes to git untouched.
    local -a pos=()
    local a skip=0 end=0
    for a in "$@"; do
        if ((skip)); then
            skip=0
            continue
        fi
        if ((!end)); then
            case $a in
                --) end=1 && continue ;;
                -b | -o | -c | -u | -j | --branch | --origin | --config | --depth | \
                    --reference | --reference-if-able | --separate-git-dir | \
                    --upload-pack | --template | --shallow-since | --shallow-exclude | \
                    --filter | --jobs | --server-option | --bundle-uri | --ref-format)
                    skip=1 && continue
                    ;;
                -*) continue ;;
            esac
        fi
        pos+=("$a")
    done
    if ((${#pos[@]} == 0)); then
        echo 'usage: gwork clone <url> [dir] [git clone options…]' >&2
        return 2
    fi
    local dir=${pos[1]:-$(__gwork_humanish "${pos[0]}")}

    # -c writes into the new repository's local config, and only once the
    # clone succeeds: a failed clone configures nothing.
    git clone -c "user.name=$name" -c "user.email=$email" "$@" || return

    if [[ -d $dir ]] && [[ $(git -C "$dir" config --local user.email 2>/dev/null) == "$email" ]]; then
        printf 'gwork: %s cloned with the work identity\n' "$dir"
        cd -- "$dir" || return
    else
        printf 'gwork: cloned, but %s has no local work identity; run gwork set <dir>\n' "$dir" >&2
        return 1
    fi
}

__gwork_set() {
    local id top
    id=$(__gwork_identity) || return
    top=$(__gwork_top "${1:-.}") || return
    git -C "$top" config --local user.name "${id%%$'\t'*}" &&
        git -C "$top" config --local user.email "${id#*$'\t'}" || return
    __gwork_status "$top"
}

__gwork_unset() {
    local top key rc
    top=$(__gwork_top "${1:-.}") || return
    for key in user.name user.email; do
        git -C "$top" config --local --unset-all "$key" 2>/dev/null
        rc=$?
        # 5: the key wasn't set — already the default.
        ((rc == 0 || rc == 5)) || return "$rc"
    done
    __gwork_status "$top"
}

gwork() {
    case ${1:-} in
        '' | status)
            __gwork_status "${2:-.}"
            ;;
        clone)
            shift
            __gwork_clone "$@"
            ;;
        set)
            __gwork_set "${2:-.}"
            ;;
        unset)
            __gwork_unset "${2:-.}"
            ;;
        -h | --help | help)
            sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            ;;
        *)
            echo "gwork: unknown command '$1' (want clone, set, unset, status)" >&2
            return 2
            ;;
    esac
}

_gwork() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    if ((COMP_CWORD == 1)); then
        mapfile -t COMPREPLY < <(compgen -W 'clone set unset status help' -- "$cur")
    else
        mapfile -t COMPREPLY < <(compgen -d -- "$cur")
    fi
}
complete -F _gwork gwork 2>/dev/null
