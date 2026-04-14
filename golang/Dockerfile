ARG BASE_IMAGE=sbx-templates:base
FROM ${BASE_IMAGE}

# renovate: datasource=golang-version depName=go
ARG GO_VERSION=1.26.2

USER root
RUN <<EOF
set -e
mkdir -p /opt
ARCH=$(dpkg --print-architecture)
curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" | tar -C /opt -xz
EOF

# /opt/go/bin for the system toolchain, /home/agent/go/bin for user-installed
# `go install` targets. Appended so the base image's sfw shims in
# /opt/socket/bin would still win for any future wrapped tools.
ENV PATH="${PATH}:/opt/go/bin:/home/agent/go/bin"

USER agent
RUN <<EOF
set -e

# Append golang plugin to the oh-my-zsh plugins list (zsh-only sugar)
sed -i -E 's/^plugins=\(([^)]*)\)/plugins=(\1 golang)/' ~/.zshrc

# gopls LSP
go install golang.org/x/tools/gopls@latest
EOF
