#!/bin/sh
set -eu

version="${VERSION:-latest}"
arch="${TARGETARCH:-$(dpkg --print-architecture)}"

case "${arch}" in
    amd64|x86_64|x64) arch="amd64" ;;
    arm64|aarch64) arch="arm64" ;;
    *) echo "unsupported arch: ${arch}" >&2; exit 1 ;;
esac

apt-get update
apt-get install -y --no-install-recommends ca-certificates curl jq

if [ "${version}" = "latest" ]; then
    version="$(curl -fsSL https://api.github.com/repos/coder/code-server/releases/latest | jq -r '.tag_name | ltrimstr("v")')"
    [ -n "${version}" ]
fi

deb="code-server_${version}_${arch}.deb"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

# Match Coder's documented manual Debian package install.
curl -fsSL -o "${tmp_dir}/${deb}" "https://github.com/coder/code-server/releases/download/v${version}/${deb}"
apt-get install -y --no-install-recommends "${tmp_dir}/${deb}"
rm -rf /var/lib/apt/lists/*
