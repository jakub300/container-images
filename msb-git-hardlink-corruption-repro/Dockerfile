# syntax=docker/dockerfile:1.7
FROM ghcr.io/superradcompany/debian-systemd:12-2026-05-11

# Install Debian's official Git package. The repro does not build Git from source.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

# Build both hardlink groups in one layer. Splitting this into multiple layers
# changes the failure shape and no longer reproduces the helper corruption.
RUN <<'EOF'
set -eu

# Create directories that mirror Git's usual /usr/local install layout.
mkdir -p /usr/local/bin /usr/local/libexec/git-core

# Copy the official Debian git binary into /usr/local so the first hardlink
# group is controlled and independent from the distro package files.
cp /usr/bin/git /usr/local/bin/git
chmod 755 /usr/local/bin/git

# Pad the first hardlink-group target to the size class that triggers the MSB
# corruption. Appending zero bytes keeps the binary executable for `git --version`.
current="$(stat -c %s /usr/local/bin/git)"
target=19834024
head -c "$((target - current))" /dev/zero >> /usr/local/bin/git

# Create a large hardlink group for /usr/local/bin/git. This preceding group is
# needed for MSB to corrupt the later helper group in this repro.
for i in $(seq -w 1 150); do
  ln /usr/local/bin/git "/usr/local/libexec/git-core/git-alias-$i"
done

# Copy Debian's official remote helper and pad it to a larger helper size. The
# helper remains a valid ELF binary under Docker.
cp /usr/lib/git-core/git-remote-http /usr/local/libexec/git-core/git-remote-ftp
current="$(stat -c %s /usr/local/libexec/git-core/git-remote-ftp)"
target=11710936
head -c "$((target - current))" /dev/zero >> /usr/local/libexec/git-core/git-remote-ftp
chmod 755 /usr/local/libexec/git-core/git-remote-ftp

# Create the second hardlink group. Docker preserves valid bytes for all four
# helpers; MSB corrupts this later group after the large preceding group above.
cd /usr/local/libexec/git-core
ln git-remote-ftp git-remote-ftps
ln git-remote-ftp git-remote-http
ln git-remote-ftp git-remote-https
EOF
