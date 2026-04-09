# --- Stage 1: Verify cosign binary via TUF root of trust ---
FROM golang:1.26@sha256:ec4debba7b371fb2eaa6169a72fc61ad93b9be6a9ae9da2a010cb81a760d36e7 AS cosign-verify

# renovate: datasource=github-releases depName=sigstore/cosign
ARG COSIGN_VERSION=3.0.6

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
FROM golang:1.26@sha256:ec4debba7b371fb2eaa6169a72fc61ad93b9be6a9ae9da2a010cb81a760d36e7 AS gascity-build

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
FROM docker/sandbox-templates:claude-code-minimal@sha256:d17605375b77b3466732e39080014224626a9039538a2a8721b7ca3a7dea6bdd

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
# renovate: datasource=npm depName=bun
ARG BUN_VERSION=1.3.11
ARG BUN_SHA256_AMD64=8611ba935af886f05a6f38740a15160326c15e5d5d07adef966130b4493607ed
ARG BUN_SHA256_ARM64=d13944da12a53ecc74bf6a720bd1d04c4555c038dfe422365356a7be47691fdf
# renovate: datasource=github-releases depName=SocketDev/sfw-free
ARG SFW_VERSION=1.6.1
ARG SFW_SHA256_AMD64=4a1e8b65e90fce7d5fd066cf0af6c93d512065fa4222a475c8d959a6bc14b9ff
ARG SFW_SHA256_ARM64=df2eedb2daf2572eee047adb8bfd81c9069edcb200fc7d3710fca98ec3ca81a1

# Explicit locale + terminal settings so tools don't silently depend on
# upstream base image defaults.
ENV TERM=xterm-256color
ENV COLORTERM=truecolor
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

USER root
RUN <<EOF
set -e

ARCH=$(dpkg --print-architecture)

# Bun runtime — pinned GitHub release + SHA256 (instead of the unpinned
# curl https://bun.sh/install | bash path). Extracted to /opt/bun/bin
# so the sfw shims in /opt/socket/bin can wrap it unambiguously.
case "$ARCH" in
  amd64) BUN_ARCH=x64; BUN_SHA256="$BUN_SHA256_AMD64" ;;
  arm64) BUN_ARCH=aarch64; BUN_SHA256="$BUN_SHA256_ARM64" ;;
  *) echo "unsupported arch: $ARCH" >&2; exit 1 ;;
esac
curl -fsSL "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-${BUN_ARCH}.zip" -o /tmp/bun.zip
echo "${BUN_SHA256}  /tmp/bun.zip" | sha256sum -c -
mkdir -p /opt/bun/bin
unzip -q -j /tmp/bun.zip "bun-linux-${BUN_ARCH}/bun" -d /opt/bun/bin
chmod +x /opt/bun/bin/bun
rm /tmp/bun.zip

# Socket Firewall (sfw) — pinned release + SHA256, installed alongside
# PATH-level shims that wrap bun/bunx/npm/npx. Shims beat shell aliases
# because they work in every execution context (default CMD, docker exec,
# subprocesses spawned by Claude Code, bash as well as zsh).
case "$ARCH" in
  amd64) SFW_ARCH=x86_64; SFW_SHA256="$SFW_SHA256_AMD64" ;;
  arm64) SFW_ARCH=arm64;  SFW_SHA256="$SFW_SHA256_ARM64" ;;
  *) echo "unsupported arch: $ARCH" >&2; exit 1 ;;
esac
mkdir -p /opt/socket/bin
curl -fsSL "https://github.com/SocketDev/sfw-free/releases/download/v${SFW_VERSION}/sfw-free-linux-${SFW_ARCH}" -o /opt/socket/bin/sfw
echo "${SFW_SHA256}  /opt/socket/bin/sfw" | sha256sum -c -
chmod +x /opt/socket/bin/sfw

# Shim generator: each shim is a real executable on PATH that unconditionally
# wraps the target binary through sfw. bunx/npx route to "bun x".
for cmd in bun bunx npm npx; do
  case "$cmd" in
    bunx|npx) real="/opt/bun/bin/bun x" ;;
    *)        real="/opt/bun/bin/bun" ;;
  esac
  cat > "/opt/socket/bin/${cmd}" <<SHIM
#!/bin/bash
exec /opt/socket/bin/sfw ${real} "\$@"
SHIM
  chmod +x "/opt/socket/bin/${cmd}"
done

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
EOF

# PATH: shim dir first, then /opt/bun/bin (real bun), then the inherited
# base PATH, then bun's per-user global install dir at the end (so bun
# install -g targets are discoverable without winning over the shims).
ENV PATH="/opt/socket/bin:/opt/bun/bin:${PATH}:/home/agent/.bun/bin"

USER agent
RUN <<EOF
set -e

# oh-my-zsh + shell config
# NOTE: do NOT prepend ~/.local/bin to PATH here — it's already in the
# image's ENV PATH, and prepending it in .zshrc would push it ahead of
# /opt/socket/bin and bypass the sfw shims in interactive zsh.
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
sed -i 's/plugins=(git)/plugins=(git gh docker tmux fzf)/' ~/.zshrc
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
