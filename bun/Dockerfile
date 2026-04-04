ARG BASE_IMAGE=sandbox-templates:base
FROM ${BASE_IMAGE}

USER agent
RUN <<EOF
set -e

# Bun shell aliases (with Socket Firewall)
echo 'alias bun="sfw bun"' >> ~/.zshrc
echo 'alias bunx="sfw bunx"' >> ~/.zshrc

# TypeScript LSP + global packages
sfw bun install -g typescript-language-server typescript @beads/bd

# Claude plugins — language-specific
claude plugin install typescript-lsp@claude-plugins-official
claude plugin install frontend-design@claude-plugins-official
EOF
