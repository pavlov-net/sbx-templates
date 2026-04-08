ARG BASE_IMAGE=sbx-templates:base
FROM ${BASE_IMAGE}

# renovate: datasource=golang-version depName=go
ARG GO_VERSION=1.26.2

USER root
RUN <<EOF
set -e
ARCH=$(dpkg --print-architecture)
curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" | tar -C /usr/local -xz
EOF

ENV PATH="/usr/local/go/bin:/home/agent/go/bin:${PATH}"

USER agent
RUN <<EOF
set -e

# Append golang plugin to the oh-my-zsh plugins list (zsh-only sugar)
sed -i -E 's/^plugins=\(([^)]*)\)/plugins=(\1 golang)/' ~/.zshrc

# gopls LSP
go install golang.org/x/tools/gopls@latest

# Claude plugins — language-specific
claude plugin install gopls-lsp@claude-plugins-official
EOF
