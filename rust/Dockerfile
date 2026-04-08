ARG BASE_IMAGE=sbx-templates:base
FROM ${BASE_IMAGE}

ENV PATH="/home/agent/.cargo/bin:${PATH}"

USER agent
RUN <<EOF
set -e

# Rust toolchain via rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# rust-analyzer LSP (ships with rustup)
rustup component add rust-analyzer

# Shell config (zsh-only sugar; PATH is set via ENV above)
echo 'alias cargo="sfw cargo"' >> ~/.zshrc
sed -i -E 's/^plugins=\(([^)]*)\)/plugins=(\1 rust cargo)/' ~/.zshrc

# Claude plugins — language-specific
claude plugin install rust-analyzer-lsp@claude-plugins-official
EOF
