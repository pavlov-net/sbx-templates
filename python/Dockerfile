ARG BASE_IMAGE=sbx-templates:base
FROM ${BASE_IMAGE}

USER root
RUN <<EOF
set -e

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

# Pyright LSP. bun on PATH is the sfw shim from the base image. The default
# Python that pyright resolves against is installed in the base image.
bun install -g pyright

# oh-my-zsh plugins — zsh-only sugar
sed -i -E 's/^plugins=\(([^)]*)\)/plugins=(\1 python pip)/' ~/.zshrc
EOF
