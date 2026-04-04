ARG BASE_IMAGE=sandbox-templates:base
FROM ${BASE_IMAGE}

ARG GO_VERSION=1.24.2

USER root
RUN <<EOF
set -e
ARCH=$(dpkg --print-architecture)
curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" | tar -C /usr/local -xz
EOF

USER agent
RUN <<EOF
set -e

# Go environment
export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"
echo 'export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"' >> ~/.zshrc
sed -i 's/plugins=(git gh docker tmux fzf)/plugins=(git gh docker tmux fzf golang)/' ~/.zshrc

# gopls LSP
go install golang.org/x/tools/gopls@latest

# Claude plugins — language-specific
claude plugin install gopls-lsp@claude-plugins-official
EOF
