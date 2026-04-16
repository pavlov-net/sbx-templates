ARG BASE_IMAGE=sbx-templates:base
FROM ${BASE_IMAGE}

# renovate: datasource=github-releases depName=rust-lang/rust
ARG RUST_VERSION=1.95.0

# rustup is a self-mutating toolchain manager (add/remove components, update
# toolchains, install targets), so it needs write access to its own home.
# Install it under /home/agent as the agent user — this avoids the permission
# issues a root-owned /opt/rust layout causes. Appended to PATH so the sfw
# shim at /opt/socket/bin/cargo takes precedence.
ENV PATH="${PATH}:/home/agent/.cargo/bin"

USER root
RUN <<EOF
set -e

# sfw shim for cargo, pointing at the agent-owned rustup install below.
# /opt/socket/bin is root-owned, so the shim creation has to run as root.
cat > /opt/socket/bin/cargo <<SHIM
#!/bin/bash
exec /opt/socket/bin/sfw /home/agent/.cargo/bin/cargo "\$@"
SHIM
chmod +x /opt/socket/bin/cargo
EOF

USER agent
RUN <<EOF
set -e

# Rust toolchain via rustup, installed into ~/.rustup + ~/.cargo (defaults).
# --no-modify-path keeps it from touching shell rc files (we manage PATH via
# ENV).
curl -fsSL https://sh.rustup.rs -o /tmp/install-rustup.sh
sh /tmp/install-rustup.sh -y --no-modify-path --default-toolchain ${RUST_VERSION}
rm /tmp/install-rustup.sh

# rust-analyzer LSP (ships via rustup component).
~/.cargo/bin/rustup component add rust-analyzer

# oh-my-zsh plugins — zsh-only sugar
sed -i -E 's/^plugins=\(([^)]*)\)/plugins=(\1 rust)/' ~/.zshrc
EOF
