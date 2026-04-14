# ssh-agent-proxy-setup: configure git commit signing if the proxy is reachable.
# Sourced by .zshenv (all zsh) and BASH_ENV via sandbox-persistent.sh (all bash).
# Runs once per container — the stamp file prevents repeat probes.
#
# https://github.com/stuartparmenter/ssh-agent-proxy

if [ ! -f "$HOME/.cache/ssh-agent-proxy/.configured" ]; then
    _sap_proxy="${SSH_AGENT_PROXY_URL:-http://host.docker.internal:7221/sign}"
    _sap_base="${_sap_proxy%/sign}"
    _sap_pubkey=$(curl --silent --fail --max-time 2 "${_sap_base}/publickey" 2>/dev/null) || true

    if [ -n "$_sap_pubkey" ]; then
        mkdir -p "$HOME/.cache/ssh-agent-proxy"
        printf '%s\n' "$_sap_pubkey" > "$HOME/.cache/ssh-agent-proxy/signing.pub"

        git config --global gpg.format ssh
        git config --global gpg.ssh.program /usr/local/bin/ssh-agent-proxy-sign
        git config --global user.signingkey "$HOME/.cache/ssh-agent-proxy/signing.pub"
        git config --global commit.gpgsign true
        git config --global tag.gpgsign true

        touch "$HOME/.cache/ssh-agent-proxy/.configured"
    fi

    unset _sap_proxy _sap_base _sap_pubkey
fi
