#!/bin/sh
set -eu

version="${VERSION:-latest}"
arch="${TARGETARCH:-$(dpkg --print-architecture)}"

case "${arch}" in
    amd64|x86_64|x64) arch="amd64" ;;
    arm64|aarch64) arch="arm64" ;;
    *) echo "unsupported arch: ${arch}" >&2; exit 1 ;;
esac

if [ "${version}" = "latest" ]; then
    version="$(curl -fsSL https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases/permalink/latest | sed -n 's/.*"tag_name":"v\([^"]*\)".*/\1/p')"
    [ -n "${version}" ]
    release="permalink/latest"
else
    release="v${version}"
fi

asset="glab_${version}_linux_${arch}.tar.gz"
base_url="https://gitlab.com/gitlab-org/cli/-/releases/${release}/downloads"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

curl -fsSL -o "${tmp_dir}/${asset}" "${base_url}/${asset}"
curl -fsSL -o "${tmp_dir}/checksums.txt" "${base_url}/checksums.txt"

(cd "${tmp_dir}" && grep "  ${asset}$" checksums.txt | sha256sum -c -)
tar -xzf "${tmp_dir}/${asset}" -C "${tmp_dir}"
install -m 0755 "${tmp_dir}/bin/glab" /usr/local/bin/glab
