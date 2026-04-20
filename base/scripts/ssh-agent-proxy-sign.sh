#!/usr/bin/env bash
#
# ssh-agent-proxy-sign: drop-in gpg.ssh.program that forwards signing requests
# to ssh-agent-proxy running on the host. Non-sign operations (verify, etc.)
# are passed through to the real ssh-keygen.
#
# https://github.com/pavlov-net/ssh-agent-proxy
#
# Git invokes gpg.ssh.program as:
#     <program> -Y sign -n git -f <signing-key> [file|-]
#
# Environment variables:
#   SSH_AGENT_PROXY_URL         Sign endpoint (default: http://host.docker.internal:7221/sign)
#   SSH_AGENT_PROXY_CURL        Override curl binary (default: curl)

set -euo pipefail

PROXY_URL="${SSH_AGENT_PROXY_URL:-http://host.docker.internal:7221/sign}"
CURL="${SSH_AGENT_PROXY_CURL:-curl}"

die() {
    printf 'ssh-agent-proxy-sign: %s\n' "$*" >&2
    exit 1
}

# First pass: figure out whether this is a "-Y sign" invocation. Everything
# else gets delegated to real ssh-keygen verbatim.
mode=""
for ((i = 1; i <= $#; i++)); do
    if [[ "${!i}" == "-Y" ]]; then
        next=$((i + 1))
        if (( next <= $# )); then
            mode="${!next}"
        fi
        break
    fi
done

if [[ "$mode" != "sign" ]]; then
    if ! command -v ssh-keygen >/dev/null 2>&1; then
        die "operation '-Y ${mode:-?}' requires ssh-keygen, which is not installed"
    fi
    exec ssh-keygen "$@"
fi

# Second pass: parse sign-specific arguments.
files=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -Y)    shift 2 ;;
        -n)    shift 2 ;;
        -f)    shift 2 ;;
        -O)    shift 2 ;;
        -q|-v|-U) shift ;;
        --)
            shift
            while [[ $# -gt 0 ]]; do files+=("$1"); shift; done
            ;;
        -*)    die "unsupported flag: $1" ;;
        *)     files+=("$1"); shift ;;
    esac
done

post_sign() {
    "$CURL" --silent --show-error --fail \
        --proto '=http,https' --proto-redir '=http,https' \
        --header 'Content-Type: application/octet-stream' \
        --data-binary @- \
        "$PROXY_URL"
}

if [[ ${#files[@]} -eq 0 || "${files[0]}" == "-" ]]; then
    # Sign stdin → stdout (git's default mode)
    post_sign
else
    # ssh-keygen writes to "<file>.sig" when given a file argument
    target="${files[0]}"
    [[ -r "$target" ]] || die "cannot read $target"
    post_sign <"$target" >"${target}.sig"
fi
