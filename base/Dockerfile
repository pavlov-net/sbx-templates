# --- Stage 1: Build gascity (gc) from source ---
FROM golang:1.26@sha256:fcdb3e42c5544e9682a635771eac76a698b66de79b1b50ec5b9ce5c5f14ad775 AS gascity-build

ARG GASCITY_VERSION=1af897c4001da28c55369a5a97d4a603fa60190e

RUN <<EOF
set -e
git clone --no-checkout https://github.com/gastownhall/gascity.git /src
cd /src
git fetch --depth 1 origin ${GASCITY_VERSION}
git checkout FETCH_HEAD
make install
EOF

# --- Stage 2: Main image ---
FROM docker/sandbox-templates:claude-code-minimal@sha256:1d8a3f4d3f9afa9ddcc07bebd84d05c61754d7ac297119280df7d206e32ef842

# renovate: datasource=github-releases depName=dandavison/delta
ARG DELTA_VERSION=0.19.2
ARG DELTA_SHA256_AMD64=ea4f0222950ee750a3d38dd80d03bce4cee07a3f63928fc47548383bcaf23093
ARG DELTA_SHA256_ARM64=0edc36cf514f1bd84becac3e94ee8ae9f8818c6a1f99f7b2ee67b362afa253d3
# renovate: datasource=github-releases depName=mikefarah/yq
ARG YQ_VERSION=4.52.5
ARG YQ_SHA256_AMD64=75d893a0d5940d1019cb7cdc60001d9e876623852c31cfc6267047bc31149fa9
ARG YQ_SHA256_ARM64=90fa510c50ee8ca75544dbfffed10c88ed59b36834df35916520cddc623d9aaa
# renovate: datasource=npm depName=bun
ARG BUN_VERSION=1.3.12
ARG BUN_SHA256_AMD64=11dc3ee11bc1695e149737c6ca3d5619302cf4346e6b8a6ec7988967ef01ddc5
ARG BUN_SHA256_ARM64=c40bc0ebca11bde7d75af497a654a874d0c7fd8d6a8d6031c173c10c9064297b
# renovate: datasource=github-releases depName=SocketDev/sfw-free
ARG SFW_VERSION=1.6.1
ARG SFW_SHA256_AMD64=4a1e8b65e90fce7d5fd066cf0af6c93d512065fa4222a475c8d959a6bc14b9ff
ARG SFW_SHA256_ARM64=df2eedb2daf2572eee047adb8bfd81c9069edcb200fc7d3710fca98ec3ca81a1
# renovate: datasource=github-releases depName=rui314/mold
ARG MOLD_VERSION=2.41.0
ARG MOLD_SHA256_AMD64=a3696680d99e692970590a178bc3a33d78d60d1c6dc9db7a11b557b02b751f5d
ARG MOLD_SHA256_ARM64=946de2774b06a71346bd59b55fddba610b65b8d93c3a4a1559cc84e103472710

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

# uv (Python package manager) — installed in base so every template can use
# it for scripts, managed Python, or one-off tooling. Installed root-owned
# to /opt/uv/bin with sfw shims at /opt/socket/bin/{uv,uvx} so invocations
# route through Socket Firewall regardless of shell or caller. UV_INSTALL_DIR
# forces the destination, UV_NO_MODIFY_PATH keeps the installer from touching
# any rc files, and UV_UNMANAGED_INSTALL skips the self-update receipt we
# don't want inside a container image.
curl -LsSf https://astral.sh/uv/install.sh -o /tmp/install-uv.sh
UV_INSTALL_DIR=/opt/uv/bin UV_NO_MODIFY_PATH=1 UV_UNMANAGED_INSTALL=1 sh /tmp/install-uv.sh
rm /tmp/install-uv.sh

for cmd in uv uvx; do
  cat > "/opt/socket/bin/${cmd}" <<SHIM
#!/bin/bash
exec /opt/socket/bin/sfw "/opt/uv/bin/${cmd}" "\$@"
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

# gascity CLI (built from source in stage 1)
COPY --from=gascity-build /go/bin/gc /usr/local/bin/gc

RUN <<EOF
set -e
ARCH=$(dpkg --print-architecture)

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

# mold linker. Ships with bin/{mold,ld.mold}, lib/mold/mold-wrapper.so, and
# libexec/mold/ld — keep the tarball layout in /opt/mold so mold can locate
# its own wrapper/driver files, then symlink the two bins onto PATH.
case "$ARCH" in
  amd64) MOLD_ARCH=x86_64;  MOLD_SHA256="$MOLD_SHA256_AMD64" ;;
  arm64) MOLD_ARCH=aarch64; MOLD_SHA256="$MOLD_SHA256_ARM64" ;;
  *) echo "unsupported arch: $ARCH" >&2; exit 1 ;;
esac
curl -fsSL "https://github.com/rui314/mold/releases/download/v${MOLD_VERSION}/mold-${MOLD_VERSION}-${MOLD_ARCH}-linux.tar.gz" -o /tmp/mold.tar.gz
echo "${MOLD_SHA256}  /tmp/mold.tar.gz" | sha256sum -c -
tar -xzf /tmp/mold.tar.gz -C /opt
mv "/opt/mold-${MOLD_VERSION}-${MOLD_ARCH}-linux" /opt/mold
ln -s /opt/mold/bin/mold /usr/local/bin/mold
ln -s /opt/mold/bin/ld.mold /usr/local/bin/ld.mold
rm /tmp/mold.tar.gz
EOF

# PATH: shim dir first, then /opt/bun/bin and /opt/uv/bin (real bun/uv),
# then the inherited base PATH, then bun's per-user global install dir at
# the end (so bun install -g targets are discoverable without winning over
# the shims).
ENV PATH="/opt/socket/bin:/opt/bun/bin:/opt/uv/bin:${PATH}:/home/agent/.bun/bin"

# ssh-agent-proxy: container-side signing shim + auto-setup script.
# The shim forwards git's signing requests to ssh-agent-proxy on the host.
# The setup script probes the proxy on first shell start and configures git
# signing if reachable — zero impact when the proxy isn't running.
COPY scripts/ssh-agent-proxy-sign.sh /usr/local/bin/ssh-agent-proxy-sign
COPY scripts/ssh-agent-proxy-setup.sh /usr/local/lib/ssh-agent-proxy-setup.sh
RUN chmod +x /usr/local/bin/ssh-agent-proxy-sign \
 && echo '. /usr/local/lib/ssh-agent-proxy-setup.sh' >> /etc/sandbox-persistent.sh

USER agent
RUN <<EOF
set -e

# ssh-agent-proxy: .zshenv is sourced for ALL zsh invocations (interactive +
# non-interactive), so this covers both user shells and Claude subprocesses.
# BASH_ENV (set by base image to /etc/sandbox-persistent.sh) covers bash.
printf '. /usr/local/lib/ssh-agent-proxy-setup.sh\n' > ~/.zshenv

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

# Git config: delta pager + diff/merge preferences
git config --global core.pager delta
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.side-by-side true
git config --global merge.conflictstyle zdiff3
git config --global url."https://github.com/".insteadOf "git@github.com:"
EOF

ENV SHELL=/usr/bin/zsh
