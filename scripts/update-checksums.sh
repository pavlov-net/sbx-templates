#!/usr/bin/env bash
#
# Updates hardcoded SHA256 checksums in base/Dockerfile when tool versions change.
# Called by Renovate via postUpgradeTasks.
#
set -euo pipefail

DOCKERFILE="base/Dockerfile"

YQ_VERSION=$(grep -oP 'ARG YQ_VERSION=\K.*' "$DOCKERFILE")
DELTA_VERSION=$(grep -oP 'ARG DELTA_VERSION=\K.*' "$DOCKERFILE")
BUN_VERSION=$(grep -oP 'ARG BUN_VERSION=\K.*' "$DOCKERFILE")
SFW_VERSION=$(grep -oP 'ARG SFW_VERSION=\K.*' "$DOCKERFILE")
BEADS_VERSION=$(grep -oP 'ARG BEADS_VERSION=\K.*' "$DOCKERFILE")
PREK_VERSION=$(grep -oP 'ARG PREK_VERSION=\K.*' "$DOCKERFILE")

update_arg() {
  local arg_name="$1" sha="$2"
  sed -i "s/^ARG ${arg_name}=.*/ARG ${arg_name}=${sha}/" "$DOCKERFILE"
}

# --- yq checksums (download and hash, yq's checksum file format is non-standard) ---
if [ -n "$YQ_VERSION" ]; then
  for arch in amd64 arm64; do
    sha=$(curl -fsSL "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${arch}" | sha256sum | awk '{print $1}')
    update_arg "YQ_SHA256_$(echo "$arch" | tr '[:lower:]' '[:upper:]')" "$sha"
  done
  echo "Updated yq checksums for v${YQ_VERSION}"
fi

# --- delta checksums (no upstream checksum file, download and hash) ---
if [ -n "$DELTA_VERSION" ]; then
  for arch in amd64 arm64; do
    sha=$(curl -fsSL "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_${arch}.deb" | sha256sum | awk '{print $1}')
    update_arg "DELTA_SHA256_$(echo "$arch" | tr '[:lower:]' '[:upper:]')" "$sha"
  done
  echo "Updated delta checksums for v${DELTA_VERSION}"
fi

# --- bun checksums (zip download, bun uses x64/aarch64 arch naming) ---
if [ -n "$BUN_VERSION" ]; then
  for arch in amd64 arm64; do
    case "$arch" in
      amd64) bun_arch=x64 ;;
      arm64) bun_arch=aarch64 ;;
    esac
    sha=$(curl -fsSL "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-${bun_arch}.zip" | sha256sum | awk '{print $1}')
    update_arg "BUN_SHA256_$(echo "$arch" | tr '[:lower:]' '[:upper:]')" "$sha"
  done
  echo "Updated bun checksums for v${BUN_VERSION}"
fi

# --- sfw-free checksums (raw binary, uses x86_64/arm64 arch naming) ---
if [ -n "$SFW_VERSION" ]; then
  for arch in amd64 arm64; do
    case "$arch" in
      amd64) sfw_arch=x86_64 ;;
      arm64) sfw_arch=arm64 ;;
    esac
    sha=$(curl -fsSL "https://github.com/SocketDev/sfw-free/releases/download/v${SFW_VERSION}/sfw-free-linux-${sfw_arch}" | sha256sum | awk '{print $1}')
    update_arg "SFW_SHA256_$(echo "$arch" | tr '[:lower:]' '[:upper:]')" "$sha"
  done
  echo "Updated sfw-free checksums for v${SFW_VERSION}"
fi

# --- beads checksums (extracted from upstream checksums.txt) ---
if [ -n "$BEADS_VERSION" ]; then
  checksums=$(curl -fsSL "https://github.com/gastownhall/beads/releases/download/v${BEADS_VERSION}/checksums.txt")
  for arch in amd64 arm64; do
    sha=$(echo "$checksums" | awk -v f="beads_${BEADS_VERSION}_linux_${arch}.tar.gz" '$2 == f {print $1}')
    update_arg "BEADS_SHA256_$(echo "$arch" | tr '[:lower:]' '[:upper:]')" "$sha"
  done
  echo "Updated beads checksums for v${BEADS_VERSION}"
fi

# --- prek checksums (per-asset .sha256 sidecar files; aggregate sha256.sum
# only covers npm/source tarballs, not the platform builds we install) ---
if [ -n "$PREK_VERSION" ]; then
  for arch in amd64 arm64; do
    case "$arch" in
      amd64) prek_arch=x86_64 ;;
      arm64) prek_arch=aarch64 ;;
    esac
    sha=$(curl -fsSL "https://github.com/j178/prek/releases/download/v${PREK_VERSION}/prek-${prek_arch}-unknown-linux-gnu.tar.gz.sha256" | awk '{print $1}')
    update_arg "PREK_SHA256_$(echo "$arch" | tr '[:lower:]' '[:upper:]')" "$sha"
  done
  echo "Updated prek checksums for v${PREK_VERSION}"
fi

# --- rust/Dockerfile checksums -------------------------------------------------
# update_arg writes to the global $DOCKERFILE, so point it at rust/Dockerfile
# for the cargo tooling below. amd64/arm64 -> Rust target triple naming.
DOCKERFILE="rust/Dockerfile"

triple_for() { [ "$1" = "amd64" ] && echo "x86_64-unknown-linux-gnu" || echo "aarch64-unknown-linux-gnu"; }
musl_triple_for() { [ "$1" = "amd64" ] && echo "x86_64-unknown-linux-musl" || echo "aarch64-unknown-linux-musl"; }

CARGO_BINSTALL_VERSION=$(grep -oP 'ARG CARGO_BINSTALL_VERSION=\K.*' "$DOCKERFILE")
WILD_VERSION=$(grep -oP 'ARG WILD_VERSION=\K.*' "$DOCKERFILE")
CARGO_CACHE_VERSION=$(grep -oP 'ARG CARGO_CACHE_VERSION=\K.*' "$DOCKERFILE")

# --- cargo-binstall (musl tgz, no upstream checksum file, download and hash) ---
if [ -n "$CARGO_BINSTALL_VERSION" ]; then
  for arch in amd64 arm64; do
    sha=$(curl -fsSL "https://github.com/cargo-bins/cargo-binstall/releases/download/v${CARGO_BINSTALL_VERSION}/cargo-binstall-$(musl_triple_for "$arch").tgz" | sha256sum | awk '{print $1}')
    update_arg "CARGO_BINSTALL_SHA256_$(echo "$arch" | tr '[:lower:]' '[:upper:]')" "$sha"
  done
  echo "Updated cargo-binstall checksums for v${CARGO_BINSTALL_VERSION}"
fi

# --- wild (gnu tarball, no upstream checksum file, download and hash) ---
if [ -n "$WILD_VERSION" ]; then
  for arch in amd64 arm64; do
    sha=$(curl -fsSL "https://github.com/wild-linker/wild/releases/download/${WILD_VERSION}/wild-linker-${WILD_VERSION}-$(triple_for "$arch").tar.gz" | sha256sum | awk '{print $1}')
    update_arg "WILD_SHA256_$(echo "$arch" | tr '[:lower:]' '[:upper:]')" "$sha"
  done
  echo "Updated wild checksums for v${WILD_VERSION}"
fi

# --- cargo-cache (cargo-quickinstall prebuilt; upstream ships no binaries) ---
if [ -n "$CARGO_CACHE_VERSION" ]; then
  for arch in amd64 arm64; do
    sha=$(curl -fsSL "https://github.com/cargo-bins/cargo-quickinstall/releases/download/cargo-cache-${CARGO_CACHE_VERSION}/cargo-cache-${CARGO_CACHE_VERSION}-$(triple_for "$arch").tar.gz" | sha256sum | awk '{print $1}')
    update_arg "CARGO_CACHE_SHA256_$(echo "$arch" | tr '[:lower:]' '[:upper:]')" "$sha"
  done
  echo "Updated cargo-cache checksums for v${CARGO_CACHE_VERSION}"
fi
