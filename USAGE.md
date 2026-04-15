# Using sbx-templates

This guide walks through installing `sbx`, doing one-time host setup, creating sandboxes from `sbx-templates` images, re-attaching to them, and wiring up git signing via ssh-agent-proxy.

`sbx` is early — expect some of the tips below to become unnecessary as rough edges get fixed upstream.

## 1. Install `sbx`

Download the `sbx` CLI from [docker/sbx-releases](https://github.com/docker/sbx-releases). See the [Docker AI Sandboxes docs](https://docs.docker.com/ai/sandboxes/) for full CLI reference and concepts.

## 2. One-time host setup

Run `sbx-up setup` once per machine. It adds the global network allow rules that `sbx-templates` images need — and because it's the first real `sbx` command you run, it also triggers sbx's first-run onboarding, prompting you to:

1. **Log in to Docker** — needed to pull signed sandbox templates.
2. **Pick a network mode** — `open`, `balanced`, or `strict`. **`balanced` is a good middle ground for development.**

```bash
scripts/sbx-up setup
```

The allow rules it applies are equivalent to:

```bash
sbx policy allow network '**.socket.dev:443'     # Socket Firewall (package-install supply-chain checks)
sbx policy allow network 'mcp.context7.com:443'  # Context7 MCP (library docs lookup)
```

If you use ssh-agent-proxy for git signing, also allow the host loopback:

```bash
scripts/sbx-up setup --ssh-agent-proxy host.docker.internal   # port defaults to 7221
```

## 3. One-time setup: store API credentials

Store credentials once in sbx's per-machine secret vault:

```bash
sbx secret set -g github       # prompts for token
sbx secret set -g anthropic    # Claude API key, if you use it
```

**How it works — and why this is safer than `gh auth login` inside the sandbox:** the sandbox never sees the raw token. When code inside the sandbox makes an HTTPS request to a known service endpoint (e.g. `api.github.com`, `api.anthropic.com`), sbx's egress proxy intercepts the request and injects the `Authorization` header on the way out. Tools like `gh`, `curl`, language SDKs, and Claude Code itself "just work" without any token ever being written to env, disk, or process memory inside the sandbox. A compromised or prompt-injected agent can use the credential for its intended service, but cannot exfiltrate it.

Available services include `github`, `anthropic`, `openai`, `google`, `aws`, and more — run `sbx secret set --help` for the full list. Secrets can also be piped in from a secret manager or another CLI:

```bash
gh auth token | sbx secret set -g github
```

## 4. Create a sandbox

```bash
scripts/sbx-up create -t bun /path/to/workspace
```

- `-t` — template name (`base`, `bun`, `golang`, `python`, `rust`) or any full image ref.
- `--name` — sandbox name (default: `claude-<workspace-basename>`).
- `--branch <name>` — create a git worktree on that branch.
- Append `:ro` to a path for read-only mounts; pass multiple paths for extra mounts.

**First run inside the sandbox:** `sbx-up create` drops you into a Claude Code session.

- **Claude.ai subscription users:** run `/login` inside the session to complete the OAuth flow. The token is stored in the sandbox's filesystem, so you only need to do it **once per sandbox** — subsequent `sbx run` / `sbx exec` sessions will already be authenticated.
- **Anthropic API users:** skip `/login`. Instead, store your API key once on the host with `sbx secret set -g anthropic`; Claude Code will pick it up via the egress proxy with no interactive step inside the sandbox.

## 5. Re-attach to an existing sandbox

Sandboxes are persistent containers — you create one per project and re-attach for each work session rather than re-creating. `sbx-up create` prints the sandbox name when it finishes (e.g. `claude-myproject`); use it with:

```bash
sbx run claude-myproject            # resume the Claude Code agent
sbx exec -it claude-myproject zsh   # drop into an interactive shell
```

List existing sandboxes with `sbx ls`; stop or remove with `sbx stop` / `sbx rm`.

## 6. Optional: git signing via ssh-agent-proxy

If you run an ssh-agent-proxy on your host, pass its address on `create` and the sandbox will be wired up to sign git commits via your host's SSH agent:

```bash
scripts/sbx-up create -t bun --ssh-agent-proxy host.docker.internal /path/to/workspace
```

Requires the matching `sbx-up setup --ssh-agent-proxy host.docker.internal` from step 2.

## Known issues

`sbx` is early; the full list of open problems lives in [docker/sbx-releases issues](https://github.com/docker/sbx-releases/issues). A few worth calling out:

- **Claude Code Remote Control is broken** — [docker/sbx-releases#8](https://github.com/docker/sbx-releases/issues/8).
