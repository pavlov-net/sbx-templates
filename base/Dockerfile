FROM docker/sandbox-templates:claude-code-minimal@sha256:fdab8eccd25cf8bb03c8079524e7cfdb21b338cd1c5aae3418dda9904e522112

# renovate: datasource=github-releases depName=dandavison/delta
ARG DELTA_VERSION=0.19.2
ARG DELTA_SHA256_AMD64=ea4f0222950ee750a3d38dd80d03bce4cee07a3f63928fc47548383bcaf23093
ARG DELTA_SHA256_ARM64=0edc36cf514f1bd84becac3e94ee8ae9f8818c6a1f99f7b2ee67b362afa253d3
# renovate: datasource=github-releases depName=mikefarah/yq
ARG YQ_VERSION=4.53.2
ARG YQ_SHA256_AMD64=d56bf5c6819e8e696340c312bd70f849dc1678a7cda9c2ad63eebd906371d56b
ARG YQ_SHA256_ARM64=03061b2a50c7a498de2bbb92d7cb078ce433011f085a4994117c2726be4106ea
# renovate: datasource=npm depName=bun
ARG BUN_VERSION=1.3.13
ARG BUN_SHA256_AMD64=79c0771fa8b92c33aae41e15a0e0d307ea99d0e2f00317c71c6c53237a78e25a
ARG BUN_SHA256_ARM64=70bae41b3908b0a120e1e58c5c8af30e74afae3b8d11b0d3fdd8e787ddfb4b22
# renovate: datasource=github-releases depName=SocketDev/sfw-free
ARG SFW_VERSION=1.8.0
ARG SFW_SHA256_AMD64=55ce4f8fd0d39196280fb9e20d430c3f631fd65a4be94d2b19167be03165d648
ARG SFW_SHA256_ARM64=b1ebb0ec4ea72ddf989c5c22ada68aa02e8fe790441455655eadd91c85c88602
# renovate: datasource=github-releases depName=rui314/mold
ARG MOLD_VERSION=2.41.0
ARG MOLD_SHA256_AMD64=a3696680d99e692970590a178bc3a33d78d60d1c6dc9db7a11b557b02b751f5d
ARG MOLD_SHA256_ARM64=946de2774b06a71346bd59b55fddba610b65b8d93c3a4a1559cc84e103472710
# renovate: datasource=github-releases depName=gastownhall/beads
ARG BEADS_VERSION=1.0.3
ARG BEADS_SHA256_AMD64=1ef5dca818d7e81574df9e9f9fc2a16ab711da09b0fa7b822ae162d9a81c8912
ARG BEADS_SHA256_ARM64=243a9c75012e794888fcafb957e7624b8fefdfef033d14cd03ebc9831c3bc12f
# renovate: datasource=github-releases depName=j178/prek
ARG PREK_VERSION=0.3.11
ARG PREK_SHA256_AMD64=c467f219c2a8e2997608853ccedf349f3033d25086f3af1e7babf968ab9edd2d
ARG PREK_SHA256_ARM64=3640161080ccaaba5b42cc66603c31ec6bc5e356c676f1416c602bb20fa93ab7
# renovate: datasource=python-version depName=python
ARG PYTHON_VERSION=3.14.4

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

# Remove base image uv to save space — we install our own at /opt/uv/bin.
rm -f /usr/local/bin/uv

# Add third-party apt repos before updating
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list

curl -fsSL https://downloads.1password.com/linux/keys/1password.asc \
    | gpg --dearmor -o /usr/share/keyrings/1password-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" \
    > /etc/apt/sources.list.d/1password.list

# Single apt-get update + install for all packages. Not chained with && —
# set -e exempts the left side of &&, so an `update` failure would silently
# skip `install` and surface as a confusing missing-package error later.
apt-get update
apt-get install -y --no-install-recommends \
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
    git-lfs \
    gh \
    1password-cli

# Register git-lfs filters in /etc/gitconfig so both root and the agent user
# inherit the smudge/clean filters without needing per-user `git lfs install`.
git lfs install --system --skip-repo

# Cleanup apt caches
apt-get clean
rm -rf /var/lib/apt/lists/*
EOF

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

# beads (bd) — issue tracker for AI agents, single Go binary from upstream releases.
BEADS_SHA256=$([ "$ARCH" = "amd64" ] && echo "$BEADS_SHA256_AMD64" || echo "$BEADS_SHA256_ARM64")
curl -fsSL "https://github.com/gastownhall/beads/releases/download/v${BEADS_VERSION}/beads_${BEADS_VERSION}_linux_${ARCH}.tar.gz" -o /tmp/beads.tar.gz
echo "${BEADS_SHA256}  /tmp/beads.tar.gz" | sha256sum -c -
tar -xzf /tmp/beads.tar.gz -C /tmp bd
mv /tmp/bd /usr/local/bin/bd
chmod +x /usr/local/bin/bd
rm /tmp/beads.tar.gz

# prek — fast pre-commit reimplementation in Rust, single binary nested one
# level deep inside the release tarball (prek-<triple>/prek), so strip the
# leading directory on extract.
case "$ARCH" in
  amd64) PREK_ARCH=x86_64;  PREK_SHA256="$PREK_SHA256_AMD64" ;;
  arm64) PREK_ARCH=aarch64; PREK_SHA256="$PREK_SHA256_ARM64" ;;
  *) echo "unsupported arch: $ARCH" >&2; exit 1 ;;
esac
curl -fsSL "https://github.com/j178/prek/releases/download/v${PREK_VERSION}/prek-${PREK_ARCH}-unknown-linux-gnu.tar.gz" -o /tmp/prek.tar.gz
echo "${PREK_SHA256}  /tmp/prek.tar.gz" | sha256sum -c -
mkdir -p /tmp/prek-extract
tar -xzf /tmp/prek.tar.gz -C /tmp/prek-extract --strip-components=1
mv /tmp/prek-extract/prek /usr/local/bin/prek
chmod +x /usr/local/bin/prek
rm -rf /tmp/prek.tar.gz /tmp/prek-extract
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
# Source /etc/sandbox-persistent.sh (the same file BASH_ENV points at for bash)
# so both shells share one persistence chain — including any env-var exports
# that ssh-agent-proxy-setup.sh appends to it at probe time.
printf '. /etc/sandbox-persistent.sh\n' > ~/.zshenv

# oh-my-zsh + shell config
# NOTE: do NOT prepend ~/.local/bin to PATH here — it's already in the
# image's ENV PATH, and prepending it in .zshrc would push it ahead of
# /opt/socket/bin and bypass the sfw shims in interactive zsh.
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
sed -i 's/plugins=(git)/plugins=(git gh docker tmux fzf)/' ~/.zshrc
printf 'set -g mouse on\nset -g history-limit 50000\nset -g default-terminal "tmux-256color"\n' > ~/.tmux.conf

# Default Python via uv. --default installs the unversioned python/python3
# symlinks alongside python${PYTHON_VERSION%.*} into ~/.local/bin (already on
# PATH from the upstream image). Calls the real uv directly (not the sfw shim)
# because this downloads a Python runtime binary from GitHub, not a package —
# sfw's TLS interception rejects GitHub's cert here.
/opt/uv/bin/uv python install $PYTHON_VERSION --default

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
