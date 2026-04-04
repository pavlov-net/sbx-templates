ARG BASE_IMAGE=sandbox-templates:base
FROM ${BASE_IMAGE}

USER agent
RUN <<EOF
set -e

# Rust toolchain via rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
. "$HOME/.cargo/env"

# rust-analyzer LSP (ships with rustup)
rustup component add rust-analyzer

# Shell config
echo 'source "$HOME/.cargo/env"' >> ~/.zshrc
echo 'alias cargo="sfw cargo"' >> ~/.zshrc
sed -i 's/plugins=(git gh docker tmux fzf)/plugins=(git gh docker tmux fzf rust cargo)/' ~/.zshrc

# Claude plugins — language-specific
claude plugin install rust-analyzer-lsp@claude-plugins-official
EOF
