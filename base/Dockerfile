FROM docker/sandbox-templates:claude-code-minimal@sha256:31176d2cbb07ba18a709f015bea0e6e3c56f6b7b92744d16309d94e905c91482

# renovate: datasource=github-releases depName=dandavison/delta
ARG DELTA_VERSION=0.19.2
ARG DELTA_SHA256_AMD64=ea4f0222950ee750a3d38dd80d03bce4cee07a3f63928fc47548383bcaf23093
ARG DELTA_SHA256_ARM64=0edc36cf514f1bd84becac3e94ee8ae9f8818c6a1f99f7b2ee67b362afa253d3
# renovate: datasource=github-releases depName=mikefarah/yq
ARG YQ_VERSION=4.54.1
ARG YQ_SHA256_AMD64=8e34fc298390875de416e6a4afcb8cabeceb25d9aa8506c1a2f9353cf702ea5f
ARG YQ_SHA256_ARM64=189088da0c6429ec5178dfaab1a114805f6cab0b61b165ab236efedf1d57a71b
# renovate: datasource=npm depName=bun
ARG BUN_VERSION=1.4.2
ARG BUN_SHA256_AMD64=36368faef7527875d5ffa52e53cd48021741f2a83eb6208a8dd64068d422a913
ARG BUN_SHA256_ARM64=54328bbc2d9c8e0c9f892c544d66c57a83b84139e34909e5ee81758f1ac8fda7
# renovate: datasource=github-releases depName=SocketDev/sfw-free
ARG SFW_VERSION=1.15.3
ARG SFW_SHA256_AMD64=2aca7b45150bebd7343e977fb82f387ffe143f5bc03e557741daeb51f5ee27b4
ARG SFW_SHA256_ARM64=d10a203a91aea18d527e24f32f9164e9d322c96ca57749e2ab535fa3791b0455
# renovate: datasource=github-releases depName=rui314/mold
ARG MOLD_VERSION=2.42.1
ARG MOLD_SHA256_AMD64=6ff270c9bf07d2bec5c98aa324eb7c4daf6a1a4d815c05ff1708049616047855
ARG MOLD_SHA256_ARM64=16b025652d3d7456689e6025a77e1903bb2a15e7630877c26cc133f5df95b9c6
# renovate: datasource=github-releases depName=gastownhall/beads
ARG BEADS_VERSION=1.3.1
ARG BEADS_SHA256_AMD64=2f92b904ecf35b607e44dc5c39229173af69c54f1183e8d709f1773540cdcf3b
ARG BEADS_SHA256_ARM64=4ce9446a68edc13202b76c84a47d66fb3dad2787b6464c9522a108faf9c1c608
# renovate: datasource=github-releases depName=j178/prek
ARG PREK_VERSION=0.5.4
ARG PREK_SHA256_AMD64=6147dfe64051af590f4bfc2c073a0780fb5e2cc37d9eab8e47fe9fe26c7dfb80
ARG PREK_SHA256_ARM64=5478e436210b5226b8db3dccdd1a2e9094b1c63d81155d96bfa8b83f0398885c
# renovate: datasource=github-releases depName=openai/codex
ARG CODEX_VERSION=0.159.2
ARG CODEX_SHA256_AMD64=9e2d29a713b94478b240dec2f10e11324cd05fad76dc43e7c639bdf8a1337a6b
ARG CODEX_SHA256_ARM64=05a524a463cadf7e3e22c7f923539c0d0b74c3e78b1f5f1fab52e50e6fb3312f
# renovate: datasource=python-version depName=python
ARG PYTHON_VERSION=3.14.8

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

# Claude Code attribution off, via the managed-settings layer. sbx rewrites
# ~/.claude/settings.json (and ~/.claude.json) at sandbox creation, so
# anything baked into the user settings file is lost; the docs list those
# paths as sandbox-managed and point at a separate settings layer instead.
# /etc/claude-code/managed-settings.json is the Linux managed layer: highest
# precedence, read at startup, untouched by sbx.
mkdir -p /etc/claude-code
cat > /etc/claude-code/managed-settings.json <<'JSON'
{
  "attribution": {
    "commit": "",
    "pr": "",
    "sessionUrl": false
  }
}
JSON
chmod 644 /etc/claude-code/managed-settings.json
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

# OpenAI Codex CLI — upstream GitHub release "codex-package" tarball, the
# same payload the npm package vendors. Installed the way the official
# installer (chatgpt.com/codex/install.sh) does it: the package stays intact
# in its own directory and codex/codex-code-mode-host are symlinked onto
# PATH. Codex locates its pieces relative to its resolved executable:
# codex-package.json describes the layout, bin/codex-code-mode-host backs
# Code Mode, codex-path/rg is the ripgrep it shells out to, and
# codex-resources/ holds a Codex-specific bwrap build (with flags system
# bubblewrap lacks) plus its own zsh. Tags are rust-v<semver>.
case "$ARCH" in
  amd64) CODEX_ARCH=x86_64;  CODEX_SHA256="$CODEX_SHA256_AMD64" ;;
  arm64) CODEX_ARCH=aarch64; CODEX_SHA256="$CODEX_SHA256_ARM64" ;;
  *) echo "unsupported arch: $ARCH" >&2; exit 1 ;;
esac
curl -fsSL "https://github.com/openai/codex/releases/download/rust-v${CODEX_VERSION}/codex-package-${CODEX_ARCH}-unknown-linux-musl.tar.gz" -o /tmp/codex.tar.gz
echo "${CODEX_SHA256}  /tmp/codex.tar.gz" | sha256sum -c -
mkdir -p /opt/codex
tar -xzf /tmp/codex.tar.gz -C /opt/codex
chmod 0755 /opt/codex/bin/codex /opt/codex/bin/codex-code-mode-host /opt/codex/codex-path/rg /opt/codex/codex-resources/bwrap
ln -s /opt/codex/bin/codex /usr/local/bin/codex
ln -s /opt/codex/bin/codex-code-mode-host /usr/local/bin/codex-code-mode-host
rm /tmp/codex.tar.gz
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
