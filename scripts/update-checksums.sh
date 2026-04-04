#!/usr/bin/env bash
#
# Updates hardcoded SHA256 checksums in base/Dockerfile when tool versions change.
# Called by Renovate via postUpgradeTasks.
#
set -euo pipefail

DOCKERFILE="base/Dockerfile"

YQ_VERSION=$(grep -oP 'ARG YQ_VERSION=\K.*' "$DOCKERFILE")
DELTA_VERSION=$(grep -oP 'ARG DELTA_VERSION=\K.*' "$DOCKERFILE")

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
