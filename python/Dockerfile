ARG BASE_IMAGE=sbx-templates:base
FROM ${BASE_IMAGE}

# renovate: datasource=python-version depName=python
ARG PYTHON_VERSION=3.14.4

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
curl -LsSf https://astral.sh/uv/install.sh -o /tmp/install-uv.sh
UV_INSTALL_DIR=/opt/uv/bin UV_NO_MODIFY_PATH=1 UV_UNMANAGED_INSTALL=1 sh /tmp/install-uv.sh
rm /tmp/install-uv.sh

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

# Install a default Python via uv. Calls the real uv directly (not the
# sfw shim) because this downloads a Python runtime binary from GitHub,
# not a package — sfw's TLS interception rejects GitHub's cert here.
/opt/uv/bin/uv python install $PYTHON_VERSION

# Pyright LSP. bun on PATH is the sfw shim from the base image.
bun install -g pyright

# oh-my-zsh plugins — zsh-only sugar
sed -i -E 's/^plugins=\(([^)]*)\)/plugins=(\1 python pip)/' ~/.zshrc
EOF
