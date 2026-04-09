ARG BASE_IMAGE=sbx-templates:base
FROM ${BASE_IMAGE}

# System rustup install lives under /opt/rust, root-owned. RUSTUP_HOME
# stays set at runtime so the rustup proxies in /opt/rust/cargo/bin can
# locate the toolchain. CARGO_HOME is deliberately left unset so per-user
# cargo operations (builds, `cargo install`) use the default ~/.cargo
# cache — we don't want the user's work landing in root-owned /opt.
ENV RUSTUP_HOME=/opt/rust/rustup
# Append both the system rustup bin dir (cargo/rustc/rust-analyzer proxies)
# and ~/.cargo/bin (for user-installed crates). Appended so the sfw shim
# at /opt/socket/bin/cargo takes precedence.
ENV PATH="${PATH}:/opt/rust/cargo/bin:/home/agent/.cargo/bin"

USER root
RUN <<EOF
set -e

# Rust toolchain via rustup, installed to /opt/rust. --no-modify-path
# keeps it from touching any shell rc files (we manage PATH via ENV).
RUSTUP_HOME=/opt/rust/rustup \
CARGO_HOME=/opt/rust/cargo \
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path

# rust-analyzer LSP (ships via rustup component)
RUSTUP_HOME=/opt/rust/rustup \
CARGO_HOME=/opt/rust/cargo \
/opt/rust/cargo/bin/rustup component add rust-analyzer

# sfw shim for cargo, pointing at the system /opt install.
cat > /opt/socket/bin/cargo <<SHIM
#!/bin/bash
exec /opt/socket/bin/sfw /opt/rust/cargo/bin/cargo "\$@"
SHIM
chmod +x /opt/socket/bin/cargo
EOF

USER agent
RUN <<EOF
set -e

# oh-my-zsh plugins — zsh-only sugar
sed -i -E 's/^plugins=\(([^)]*)\)/plugins=(\1 rust cargo)/' ~/.zshrc

# Claude plugins — language-specific
claude plugin install rust-analyzer-lsp@claude-plugins-official
EOF
