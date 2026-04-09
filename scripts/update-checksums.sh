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
