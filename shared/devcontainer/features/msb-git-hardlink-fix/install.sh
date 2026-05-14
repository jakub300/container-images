#!/bin/sh
set -eu

fix_git_core() {
  git_core="$1"
  helper="${git_core}/git-remote-http"
  needs_fix=0

  [ -f "${helper}" ] || return 0

  for alias in git-remote-ftp git-remote-ftps git-remote-https; do
    if [ -f "${git_core}/${alias}" ] && [ ! -L "${git_core}/${alias}" ]; then
      needs_fix=1
    fi
  done

  [ "${needs_fix}" = "1" ] || return 0

  tmp="$(mktemp)"
  cp "${helper}" "${tmp}"

  # MSB mishandles this Git hardlink group, so keep one file and symlink aliases.
  rm -f \
    "${git_core}/git-remote-ftp" \
    "${git_core}/git-remote-ftps" \
    "${git_core}/git-remote-http" \
    "${git_core}/git-remote-https"

  mv "${tmp}" "${helper}"
  chmod 755 "${helper}"

  ln -s git-remote-http "${git_core}/git-remote-ftp"
  ln -s git-remote-http "${git_core}/git-remote-ftps"
  ln -s git-remote-http "${git_core}/git-remote-https"
}

fix_git_core /usr/local/libexec/git-core
fix_git_core /usr/lib/git-core

if command -v git >/dev/null 2>&1; then
  fix_git_core "$(git --exec-path)"
fi
