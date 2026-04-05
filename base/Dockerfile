# --- Stage 1: Verify cosign binary via TUF root of trust ---
FROM golang:1.26@sha256:595c7847cff97c9a9e76f015083c481d26078f961c9c8dca3923132f51fe12f1 AS cosign-verify

# renovate: datasource=github-releases depName=sigstore/cosign
ARG COSIGN_VERSION=3.0.5

RUN apt-get update && apt-get install -y --no-install-recommends jq && rm -rf /var/lib/apt/lists/*
RUN <<EOF
set -e
mkdir -p /out

# Install TUF client (v2)
go install github.com/theupdateframework/go-tuf/v2/examples/cli/tuf-client@v2.4.1

# Bootstrap TUF from Sigstore's published root (10th iteration, per docs)
cd /tmp
curl -fsSL -o root.json \
  https://raw.githubusercontent.com/sigstore/root-signing/refs/heads/main/metadata/root_history/10.root.json
tuf-client init --url https://tuf-repo-cdn.sigstore.dev -f root.json

# Retrieve Sigstore's artifact verification key via TUF
tuf-client get --url https://tuf-repo-cdn.sigstore.dev --turl https://tuf-repo-cdn.sigstore.dev/targets artifact.pub

# artifact.pub is downloaded to tuf_download/ in cwd (/tmp)
ARCH=$(dpkg --print-architecture)
curl -fsSL -o /out/cosign \
  "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-${ARCH}"
curl -fsSL -o /tmp/cosign-kms.sigstore.json \
  "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-${ARCH}-kms.sigstore.json"

# Verify cosign binary with artifact key (per Sigstore docs for v3.x)
cat /tmp/cosign-kms.sigstore.json | jq -r .messageSignature.signature | base64 -d > /tmp/cosign-kms.sig
openssl dgst -sha256 -verify /tmp/tuf_download/artifact.pub -signature /tmp/cosign-kms.sig /out/cosign

chmod +x /out/cosign
EOF

# --- Stage 2: Build gascity (gc) from source ---
FROM golang:1.26@sha256:595c7847cff97c9a9e76f015083c481d26078f961c9c8dca3923132f51fe12f1 AS gascity-build

ARG GASCITY_VERSION=1af897c4001da28c55369a5a97d4a603fa60190e

RUN <<EOF
set -e
git clone --no-checkout https://github.com/gastownhall/gascity.git /src
cd /src
git fetch --depth 1 origin ${GASCITY_VERSION}
git checkout FETCH_HEAD
make install
EOF

# --- Stage 3: Main image ---
FROM docker/sandbox-templates:claude-code-minimal@sha256:88fd0f6650667e832b87fe0aea413076d32e9b1475ec0ba2ab0b7bf64269c79e

# renovate: datasource=github-releases depName=sigstore/gitsign
ARG GITSIGN_VERSION=0.14.0
# renovate: datasource=github-releases depName=dandavison/delta
ARG DELTA_VERSION=0.19.2
ARG DELTA_SHA256_AMD64=ea4f0222950ee750a3d38dd80d03bce4cee07a3f63928fc47548383bcaf23093
ARG DELTA_SHA256_ARM64=0edc36cf514f1bd84becac3e94ee8ae9f8818c6a1f99f7b2ee67b362afa253d3
# renovate: datasource=github-releases depName=mikefarah/yq
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
EOF

# Cosign (TUF-verified in stage 1)
COPY --from=cosign-verify /out/cosign /usr/local/bin/cosign

# gascity CLI (built from source in stage 2)
COPY --from=gascity-build /go/bin/gc /usr/local/bin/gc

RUN <<EOF
set -e

# Gitsign (keyless commit signing via Sigstore) — verified with cosign
ARCH=$(dpkg --print-architecture)
GITSIGN_BASE="https://github.com/sigstore/gitsign/releases/download/v${GITSIGN_VERSION}"
for bin in gitsign gitsign-credential-cache; do
  ARTIFACT="${bin}_${GITSIGN_VERSION}_linux_${ARCH}"
  curl -fsSL "${GITSIGN_BASE}/${ARTIFACT}" -o "/usr/local/bin/${bin}"
  curl -fsSL "${GITSIGN_BASE}/${ARTIFACT}.sig" -o "/tmp/${bin}.sig"
  curl -fsSL "${GITSIGN_BASE}/${ARTIFACT}.pem" -o "/tmp/${bin}.pem"
  cosign verify-blob "/usr/local/bin/${bin}" \
    --signature "/tmp/${bin}.sig" \
    --certificate "/tmp/${bin}.pem" \
    --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
    --certificate-identity-regexp "^https://github.com/sigstore/gitsign/"
  rm "/tmp/${bin}.sig" "/tmp/${bin}.pem"
  chmod +x "/usr/local/bin/${bin}"
done

# yq (jq for YAML)
YQ_SHA256=$([ "$ARCH" = "amd64" ] && echo "$YQ_SHA256_AMD64" || echo "$YQ_SHA256_ARM64")
curl -fsSL "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${ARCH}" -o /usr/local/bin/yq
echo "${YQ_SHA256}  /usr/local/bin/yq" | sha256sum -c -
chmod +x /usr/local/bin/yq

# git-delta (syntax-highlighted diffs)
DELTA_SHA256=$([ "$ARCH" = "amd64" ] && echo "$DELTA_SHA256_AMD64" || echo "$DELTA_SHA256_ARM64")
curl -fsSL "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_${ARCH}.deb" -o /tmp/git-delta.deb
echo "${DELTA_SHA256}  /tmp/git-delta.deb" | sha256sum -c -
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
