# sbx-templates

Custom sandbox templates for [Docker AI Sandboxes](https://docs.docker.com/ai/sandboxes/) (`sbx`). Built on top of [`docker/sandbox-templates:claude-code-minimal`](https://github.com/docker/sbx-releases).

## Architecture

A shared **base** image contains common tooling, with thin per-language layers on top:

```
docker/sandbox-templates:claude-code-minimal
  +-- base
        +-- bun       (Bun + TypeScript LSP)
        +-- rust      (Rust + rust-analyzer)
        +-- golang    (Go + gopls)
        +-- python    (Python/uv + Pyright)
```

## What's in the base image

### Developer tools

| Tool | Description |
|------|-------------|
| [Bun](https://bun.sh) | JavaScript runtime (also provides npm/npx for LSP servers) |
| [GitHub CLI](https://cli.github.com) | GitHub from the command line |
| [1Password CLI](https://developer.1password.com/docs/cli/) | Secrets management |
| [delta](https://github.com/dandavison/delta) | Syntax-highlighted git diffs |
| [yq](https://github.com/mikefarah/yq) | YAML processor (jq for YAML) |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Fast recursive search |
| [fd](https://github.com/sharkdp/fd) | Fast file finder |
| [bat](https://github.com/sharkdp/bat) | cat with syntax highlighting |
| [eza](https://github.com/eza-community/eza) | Modern ls replacement |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder |
| [tmux](https://github.com/tmux/tmux) | Terminal multiplexer |
| [zsh](https://www.zsh.org) + [oh-my-zsh](https://ohmyz.sh) | Shell with plugins (git, gh, docker, tmux, fzf) |

### Security

| Tool | Description |
|------|-------------|
| [gitsign](https://github.com/sigstore/gitsign) | Keyless commit signing via Sigstore |
| [cosign](https://github.com/sigstore/cosign) | Container/artifact signing (used to verify gitsign) |
| [Socket Firewall](https://github.com/SocketDev/sfw-free) | Supply chain protection for package installs |

### Claude Code plugins

Plugins from [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) and [stuartparmenter/claude-plugin](https://github.com/stuartparmenter/claude-plugin):

agent-sdk-dev, claude-code-setup, claude-md-management, code-review, commit-commands, explanatory-output-style, feature-dev, github, mcp-server-dev, plugin-dev, pr-review-toolkit, security-guidance, serena, skill-creator, auto-format, efficient-commands

## Language images

| Image | Runtime | LSP | Claude plugin | sfw alias |
|-------|---------|-----|---------------|-----------|
| **bun** | Bun | typescript-language-server | typescript-lsp, frontend-design | `bun`, `bunx` |
| **rust** | rustup + stable toolchain | rust-analyzer | rust-analyzer-lsp | `cargo` |
| **golang** | Go (system-wide) | gopls | gopls-lsp | — |
| **python** | uv + default Python | Pyright | pyright-lsp | `pip`, `uv` |

## Local build

```bash
# Build base first
docker build -t sbx-templates:base base/

# Build language images
docker build -t sbx-templates:bun bun/
docker build -t sbx-templates:rust rust/
docker build -t sbx-templates:golang golang/
docker build -t sbx-templates:python python/
```

## CI

Images are built and pushed to GHCR on every push to `main`:

1. Build base image
2. Parallel-build all language images on top of the base (by digest)
3. Sign all images with [cosign](https://github.com/sigstore/cosign) (keyless via GitHub OIDC)

## Supply chain verification

Binary dependencies are verified during the build:

| Dependency | Verification method |
|------------|-------------------|
| **cosign** | [TUF](https://theupdateframework.io/) root of trust via Sigstore's `artifact.pub` key |
| **gitsign** | cosign signature verification (Sigstore identity) |
| **yq**, **delta** | SHA256 checksums (hardcoded, auto-updated by Renovate) |
| **apt packages** | GPG-signed repos (GitHub CLI, 1Password) |

## Dependency management

[Renovate](https://github.com/renovatebot/renovate) tracks and auto-updates:

- Upstream base image digest (`docker/sandbox-templates:claude-code-minimal`)
- Tool versions (gitsign, cosign, delta, yq, Go)
- GitHub Actions versions
- `golang` build stage digest

Checksums for yq and delta are automatically recomputed via `postUpgradeTasks` when their versions are bumped.
