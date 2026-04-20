# ssh-agent-proxy-setup: configure git commit signing if the proxy is reachable.
# Sourced by /etc/sandbox-persistent.sh, which both bash (via BASH_ENV) and zsh
# (via ~/.zshenv) source, so it runs on every shell start. Probes the proxy
# once per container — the stamp file prevents repeat probes. On success it
# appends an `export SSH_AGENT_PROXY_URL=…` line to sandbox-persistent.sh so
# future shells set the env var that git's signing subprocess
# (ssh-agent-proxy-sign) reads to reach the right proxy host.
#
# https://github.com/pavlov-net/ssh-agent-proxy

if [ ! -f "$HOME/.cache/ssh-agent-proxy/.configured" ]; then
    _sap_proxy="${SSH_AGENT_PROXY_URL:-http://host.docker.internal:7221/sign}"
    _sap_base="${_sap_proxy%/sign}"
    _sap_pubkey=$(curl --silent --fail --max-time 2 "${_sap_base}/publickey" 2>/dev/null) || true

    if [ -n "$_sap_pubkey" ]; then
        mkdir -p "$HOME/.cache/ssh-agent-proxy"
        printf '%s\n' "$_sap_pubkey" > "$HOME/.cache/ssh-agent-proxy/signing.pub"

        # Persist the proxy URL globally so every future shell exports it
        # before invoking git. The :- expansion preserves any explicit
        # override the user sets before shell start.
        printf 'export SSH_AGENT_PROXY_URL="${SSH_AGENT_PROXY_URL:-%s}"\n' "$_sap_proxy" \
            | sudo tee -a /etc/sandbox-persistent.sh > /dev/null

        git config --global gpg.format ssh
        git config --global gpg.ssh.program /usr/local/bin/ssh-agent-proxy-sign
        git config --global user.signingkey "$HOME/.cache/ssh-agent-proxy/signing.pub"
        git config --global commit.gpgsign true
        git config --global tag.gpgsign true

        touch "$HOME/.cache/ssh-agent-proxy/.configured"
    fi

    unset _sap_proxy _sap_base _sap_pubkey
fi
