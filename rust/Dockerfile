ARG BASE_IMAGE=sbx-templates:base
FROM ${BASE_IMAGE}

# renovate: datasource=github-releases depName=rust-lang/rust
ARG RUST_VERSION=1.99.1
# renovate: datasource=github-releases depName=cargo-bins/cargo-binstall
ARG CARGO_BINSTALL_VERSION=1.25.3
ARG CARGO_BINSTALL_SHA256_AMD64=1f72931713e9091478538c6c78c3f11f205b4f6f394f35e61835036b23929d2a
ARG CARGO_BINSTALL_SHA256_ARM64=19ef7a058397f83d6b2cc83727fb8d38babd8ad657210c921b7771a9e8b3a6fb
# renovate: datasource=crate depName=wild-linker
ARG WILD_VERSION=0.11.0
ARG WILD_SHA256_AMD64=25012a78de164686f552b7703b5d0223adab4829c79cd1fb351108221d61c7d8
ARG WILD_SHA256_ARM64=d8c77589f3024230bab58a7792abd4a3871cf097b2342004e1204850f1406071
# cargo-cache ships no upstream binaries; we pull the cargo-quickinstall
# rebuild, so checksums are computed by scripts/update-checksums.sh.
# renovate: datasource=crate depName=cargo-cache
ARG CARGO_CACHE_VERSION=0.8.3
ARG CARGO_CACHE_SHA256_AMD64=d15a838e33b52fbc50b991ad46414ac68dd2c5eb01e2bbd19a5712188998864e
ARG CARGO_CACHE_SHA256_ARM64=f73d3057c23d72c5210e1fd855a7f58568b9ba35c5c5cf3ba3b3d6482d3a7bd8

# rustup is a self-mutating toolchain manager (add/remove components, update
# toolchains, install targets), so it needs write access to its own home.
# Install it under /home/agent as the agent user — this avoids the permission
# issues a root-owned /opt/rust layout causes. Appended to PATH so the sfw
# shim at /opt/socket/bin/cargo takes precedence.
ENV PATH="${PATH}:/home/agent/.cargo/bin"

USER root
RUN <<EOF
set -e

# sfw shim for cargo, pointing at the agent-owned rustup install below.
# /opt/socket/bin is root-owned, so the shim creation has to run as root.
cat > /opt/socket/bin/cargo <<SHIM
#!/bin/bash
exec /opt/socket/bin/sfw /home/agent/.cargo/bin/cargo "\$@"
SHIM
chmod +x /opt/socket/bin/cargo
EOF

USER agent
RUN <<EOF
set -e

# Rust toolchain via rustup, installed into ~/.rustup + ~/.cargo (defaults).
# --no-modify-path keeps it from touching shell rc files (we manage PATH via
# ENV). --profile minimal drops the bundled rust-docs (and source) to keep the
# image small; the dev components we actually want are added back below.
curl -fsSL https://sh.rustup.rs -o /tmp/install-rustup.sh
sh /tmp/install-rustup.sh -y --no-modify-path --profile minimal --default-toolchain ${RUST_VERSION}
rm /tmp/install-rustup.sh

# Components: rust-analyzer LSP, plus clippy + rustfmt that the minimal profile
# omits (the default profile would have bundled these along with rust-docs).
~/.cargo/bin/rustup component add rust-analyzer clippy rustfmt

# Cargo tooling installed as pinned, checksum-verified prebuilt binaries,
# dropped straight into ~/.cargo/bin alongside the rustup toolchain (already
# on PATH). Arch -> Rust target triple for the release asset names.
ARCH=$(dpkg --print-architecture)
case "$ARCH" in
  amd64) TRIPLE=x86_64-unknown-linux-gnu;  MUSL_TRIPLE=x86_64-unknown-linux-musl ;;
  arm64) TRIPLE=aarch64-unknown-linux-gnu; MUSL_TRIPLE=aarch64-unknown-linux-musl ;;
  *) echo "unsupported arch: $ARCH" >&2; exit 1 ;;
esac

# cargo-binstall — installs Rust binaries as prebuilt artifacts instead of
# compiling from source. Static musl build.
CARGO_BINSTALL_SHA256=$([ "$ARCH" = "amd64" ] && echo "$CARGO_BINSTALL_SHA256_AMD64" || echo "$CARGO_BINSTALL_SHA256_ARM64")
curl -fsSL "https://github.com/cargo-bins/cargo-binstall/releases/download/v${CARGO_BINSTALL_VERSION}/cargo-binstall-${MUSL_TRIPLE}.tgz" -o /tmp/cargo-binstall.tgz
echo "${CARGO_BINSTALL_SHA256}  /tmp/cargo-binstall.tgz" | sha256sum -c -
tar -xzf /tmp/cargo-binstall.tgz -C ~/.cargo/bin cargo-binstall
rm /tmp/cargo-binstall.tgz

# wild (fast linker; ships the `wild` binary). Tarball nests everything under
# a versioned dir, so strip it and extract just the binary. Placed on PATH but
# not wired as the default linker — matching how the base image ships mold for
# projects to opt into.
WILD_SHA256=$([ "$ARCH" = "amd64" ] && echo "$WILD_SHA256_AMD64" || echo "$WILD_SHA256_ARM64")
curl -fsSL "https://github.com/wild-linker/wild/releases/download/${WILD_VERSION}/wild-linker-${WILD_VERSION}-${TRIPLE}.tar.gz" -o /tmp/wild.tar.gz
echo "${WILD_SHA256}  /tmp/wild.tar.gz" | sha256sum -c -
tar -xzf /tmp/wild.tar.gz -C ~/.cargo/bin --strip-components=1 "wild-linker-${WILD_VERSION}-${TRIPLE}/wild"
rm /tmp/wild.tar.gz

# cargo-cache (cargo registry/cache inspector & cleaner). Upstream publishes no
# binary releases, so this is the cargo-quickinstall prebuilt (cargo-bins'
# rebuild service, same org as cargo-binstall above).
CARGO_CACHE_SHA256=$([ "$ARCH" = "amd64" ] && echo "$CARGO_CACHE_SHA256_AMD64" || echo "$CARGO_CACHE_SHA256_ARM64")
curl -fsSL "https://github.com/cargo-bins/cargo-quickinstall/releases/download/cargo-cache-${CARGO_CACHE_VERSION}/cargo-cache-${CARGO_CACHE_VERSION}-${TRIPLE}.tar.gz" -o /tmp/cargo-cache.tar.gz
echo "${CARGO_CACHE_SHA256}  /tmp/cargo-cache.tar.gz" | sha256sum -c -
tar -xzf /tmp/cargo-cache.tar.gz -C ~/.cargo/bin cargo-cache
rm /tmp/cargo-cache.tar.gz

# oh-my-zsh plugins — zsh-only sugar
sed -i -E 's/^plugins=\(([^)]*)\)/plugins=(\1 rust)/' ~/.zshrc
EOF
