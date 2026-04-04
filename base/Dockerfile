FROM docker/sandbox-templates:claude-code-minimal@sha256:88fd0f6650667e832b87fe0aea413076d32e9b1475ec0ba2ab0b7bf64269c79e

ARG GITSIGN_VERSION=0.14.0
ARG GITSIGN_SHA256_AMD64=23fcc3d71e0abcbc635b1b95dbe758ac08773e3642b407646c32c3cf4c6def74
ARG GITSIGN_SHA256_ARM64=adaa11fb9557618737fc127be1e2f236eee3c11d97c5499d2b4a7018b28252af
ARG GITSIGN_CC_SHA256_AMD64=5fef099124c92f4c5b3b7ade2f28db73b143a93ac526d6e171da13a5d9a0093e
ARG GITSIGN_CC_SHA256_ARM64=58b1f741b5a629edf452c3133b4c7cf2905128f8ca7cdebbbf8b6ff52db827f0
ARG DELTA_VERSION=0.19.2
ARG YQ_VERSION=4.52.5
ARG YQ_SHA256_AMD64=75d893a0d5940d1019cb7cdc60001d9e876623852c31cfc6267047bc31149fa9
ARG YQ_SHA256_ARM64=90fa510c50ee8ca75544dbfffed10c88ed59b36834df35916520cddc623d9aaa

USER root
RUN <<EOF
set -e

# Bun runtime (system-wide — used by all images for npm/npx and LSP servers)
curl -fsSL https://bun.sh/install | BUN_INSTALL=/usr/local bash
ln -sf /usr/local/bin/bun /usr/local/bin/npm
ln -sf /usr/local/bin/bunx /usr/local/bin/npx

# Add third-party apt repos before updating
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list

curl -fsSL https://downloads.1password.com/linux/keys/1password.asc \
    | gpg --dearmor -o /usr/share/keyrings/1password-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" \
    > /etc/apt/sources.list.d/1password.list

# Single apt-get update + install for all packages
apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    jq \
    tmux \
    ncurses-base \
    zsh \
    openssh-client \
    procps \
    ripgrep \
    fd-find \
    bat \
    eza \
    fzf \
    gnupg \
    gh \
    1password-cli

# Cleanup apt caches
apt-get clean && rm -rf /var/lib/apt/lists/*

# Gitsign (keyless commit signing via Sigstore)
ARCH=$(dpkg --print-architecture)
GITSIGN_SHA256=$([ "$ARCH" = "amd64" ] && echo "$GITSIGN_SHA256_AMD64" || echo "$GITSIGN_SHA256_ARM64")
GITSIGN_CC_SHA256=$([ "$ARCH" = "amd64" ] && echo "$GITSIGN_CC_SHA256_AMD64" || echo "$GITSIGN_CC_SHA256_ARM64")
curl -fsSL "https://github.com/sigstore/gitsign/releases/download/v${GITSIGN_VERSION}/gitsign_${GITSIGN_VERSION}_linux_${ARCH}" -o /usr/local/bin/gitsign
curl -fsSL "https://github.com/sigstore/gitsign/releases/download/v${GITSIGN_VERSION}/gitsign-credential-cache_${GITSIGN_VERSION}_linux_${ARCH}" -o /usr/local/bin/gitsign-credential-cache
echo "${GITSIGN_SHA256}  /usr/local/bin/gitsign" | sha256sum -c -
echo "${GITSIGN_CC_SHA256}  /usr/local/bin/gitsign-credential-cache" | sha256sum -c -
chmod +x /usr/local/bin/gitsign /usr/local/bin/gitsign-credential-cache

# yq (jq for YAML)
YQ_SHA256=$([ "$ARCH" = "amd64" ] && echo "$YQ_SHA256_AMD64" || echo "$YQ_SHA256_ARM64")
curl -fsSL "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${ARCH}" -o /usr/local/bin/yq
echo "${YQ_SHA256}  /usr/local/bin/yq" | sha256sum -c -
chmod +x /usr/local/bin/yq

# git-delta (syntax-highlighted diffs)
curl -fsSL "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_$(dpkg --print-architecture).deb" -o /tmp/git-delta.deb
dpkg -i /tmp/git-delta.deb
rm /tmp/git-delta.deb

# Socket Firewall (supply chain protection for package installs)
ARCH=$(uname -m) && [ "$ARCH" = "aarch64" ] && ARCH="arm64"
curl -fsSL "https://github.com/SocketDev/sfw-free/releases/latest/download/sfw-free-linux-${ARCH}" -o /usr/local/bin/sfw
chmod +x /usr/local/bin/sfw
EOF

USER agent
RUN <<EOF
set -e

# oh-my-zsh + shell config
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
sed -i 's/plugins=(git)/plugins=(git gh docker tmux fzf)/' ~/.zshrc
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
printf 'set -g mouse on\nset -g history-limit 50000\nset -g default-terminal "tmux-256color"\n' > ~/.tmux.conf

# Claude Code settings — merge into existing settings from base image
mkdir -p ~/.claude
if [ -f ~/.claude/settings.json ]; then
  jq '. + {"attribution": {"commits": false, "pullRequests": false}}' ~/.claude/settings.json > ~/.claude/settings.json.tmp
  mv ~/.claude/settings.json.tmp ~/.claude/settings.json
else
  echo '{"attribution":{"commits":false,"pullRequests":false}}' > ~/.claude/settings.json
fi

# SSH known hosts for GitHub
mkdir -p ~/.ssh
cat > ~/.ssh/known_hosts <<'KEYS'
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
KEYS

# Claude plugin marketplaces
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin marketplace add stuartparmenter/claude-plugin

# Claude plugins — common (non-language-specific)
claude plugin install agent-sdk-dev@claude-plugins-official
claude plugin install claude-code-setup@claude-plugins-official
claude plugin install claude-md-management@claude-plugins-official
claude plugin install code-review@claude-plugins-official
claude plugin install commit-commands@claude-plugins-official
claude plugin install explanatory-output-style@claude-plugins-official
claude plugin install feature-dev@claude-plugins-official
claude plugin install github@claude-plugins-official
claude plugin install mcp-server-dev@claude-plugins-official
claude plugin install plugin-dev@claude-plugins-official
claude plugin install pr-review-toolkit@claude-plugins-official
claude plugin install security-guidance@claude-plugins-official
claude plugin install serena@claude-plugins-official
claude plugin install skill-creator@claude-plugins-official

# Claude plugins — stuart-plugins
claude plugin install auto-format@stuart-plugins
claude plugin install efficient-commands@stuart-plugins

# Git config: delta pager + gitsign for commit signing
git config --global core.pager delta
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.side-by-side true
git config --global merge.conflictstyle zdiff3
git config --global gpg.format x509
git config --global gpg.x509.program gitsign
git config --global commit.gpgsign true
git config --global gitsign.connectorID "https://github.com/login/oauth"
git config --global url."https://github.com/".insteadOf "git@github.com:"
git config --global --unset gpg.ssh.program 2>/dev/null || true
git config --global --unset core.sshcommand 2>/dev/null || true
EOF

ENV SHELL=/usr/bin/zsh
