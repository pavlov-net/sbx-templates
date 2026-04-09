ARG BASE_IMAGE=sbx-templates:base
FROM ${BASE_IMAGE}

USER agent
RUN <<EOF
set -e

# TypeScript LSP + global packages. The bun binary on PATH is the sfw
# shim from the base image, so no explicit sfw wrapping needed here.
bun install -g typescript-language-server typescript @beads/bd

# Claude plugins — language-specific
claude plugin install typescript-lsp@claude-plugins-official
claude plugin install frontend-design@claude-plugins-official
EOF
