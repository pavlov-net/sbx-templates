ARG BASE_IMAGE=sandbox-templates:base
FROM ${BASE_IMAGE}

USER agent
RUN <<EOF
set -e

# uv (Python package manager)
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"

# Install a default Python via uv
uv python install

# Pyright LSP (via bun from base)
sfw bun install -g pyright

# Shell config
echo 'alias pip="sfw pip"' >> ~/.zshrc
echo 'alias uv="sfw uv"' >> ~/.zshrc
sed -i 's/plugins=(git gh docker tmux fzf)/plugins=(git gh docker tmux fzf python pip)/' ~/.zshrc

# Claude plugins — language-specific
claude plugin install pyright-lsp@claude-plugins-official
EOF
