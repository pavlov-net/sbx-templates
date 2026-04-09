ARG BASE_IMAGE=sbx-templates:base
FROM ${BASE_IMAGE}

# /opt/uv/bin holds the system uv binary. Appended so the sfw shim at
# /opt/socket/bin/uv (created below) takes precedence.
ENV PATH="${PATH}:/opt/uv/bin"

USER root
RUN <<EOF
set -e

# uv (Python package manager), installed root-owned to /opt/uv/bin.
# UV_INSTALL_DIR forces the destination, UV_NO_MODIFY_PATH keeps the
# installer from touching any rc files, and UV_UNMANAGED_INSTALL skips
# the self-update receipt we don't want inside a container image.
UV_INSTALL_DIR=/opt/uv/bin \
UV_NO_MODIFY_PATH=1 \
UV_UNMANAGED_INSTALL=1 \
curl -LsSf https://astral.sh/uv/install.sh | sh

# sfw shim for uv. Routes all uv invocations through /opt/socket/bin/sfw
# regardless of shell, replacing the previous ~/.zshrc alias.
cat > /opt/socket/bin/uv <<SHIM
#!/bin/bash
exec /opt/socket/bin/sfw /opt/uv/bin/uv "\$@"
SHIM
chmod +x /opt/socket/bin/uv

# sfw shims for pip / pip3. There is no standalone system pip in this
# container (uv manages Python), so the shims route through `uv pip`,
# which is a pip-compatible interface backed by uv's resolver. sfw is
# invoked with an absolute path to the real uv so it bypasses the
# /opt/socket/bin/uv shim (avoiding double-wrapping).
for cmd in pip pip3; do
  cat > "/opt/socket/bin/${cmd}" <<SHIM
#!/bin/bash
exec /opt/socket/bin/sfw /opt/uv/bin/uv pip "\$@"
SHIM
  chmod +x "/opt/socket/bin/${cmd}"
done
EOF

USER agent
RUN <<EOF
set -e

# Install a default Python via uv (routed through the sfw shim; uv's
# Python cache lives under the agent user's home, not /opt).
uv python install

# Pyright LSP. bun on PATH is the sfw shim from the base image.
bun install -g pyright

# oh-my-zsh plugins — zsh-only sugar
sed -i -E 's/^plugins=\(([^)]*)\)/plugins=(\1 python pip)/' ~/.zshrc

# Claude plugins — language-specific
claude plugin install pyright-lsp@claude-plugins-official
EOF
