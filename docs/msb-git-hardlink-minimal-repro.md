# MSB Git Hardlink Corruption Minimal Repro

## Purpose

This document describes one focused MSB corruption scenario. It does not require Dev Containers and does not build Git from source.

The image uses Debian's official Git binaries, then creates two hardlink groups in one image:

1. A large `/usr/local/bin/git` hardlink group.
2. A later `git-remote-*` helper hardlink group.

Docker preserves valid bytes for both groups. MSB changes file bytes while materializing the image, including the later helper group.

## CI Image

The repo builds this image in GitHub Actions:

```text
ghcr.io/<owner>/container-images/msb-git-hardlink-corruption-repro:latest
```

For this repository owner, the expected image ref is:

```text
ghcr.io/jakub300/container-images/msb-git-hardlink-corruption-repro:latest
```

## Dockerfile

The Dockerfile is intentionally small and commented:

[msb-git-hardlink-corruption-repro/Dockerfile](/Users/jakubbogucki/Projects/AI/container-images/msb-git-hardlink-corruption-repro/Dockerfile)

## Build Locally

```sh
docker build \
  -t localhost:5000/container-images/msb-git-hardlink-corruption-repro:latest \
  msb-git-hardlink-corruption-repro
```

Optional local registry push:

```sh
docker push localhost:5000/container-images/msb-git-hardlink-corruption-repro:latest
msb image pull --insecure localhost:5000/container-images/msb-git-hardlink-corruption-repro:latest
```

## Verification Command

Use the same command in Docker and MSB:

```sh
set -eu

stat -c "%n inode=%i links=%h size=%s" \
  /usr/local/bin/git \
  /usr/local/libexec/git-core/git-alias-001 \
  /usr/local/libexec/git-core/git-alias-150 \
  /usr/local/libexec/git-core/git-remote-ftp \
  /usr/local/libexec/git-core/git-remote-ftps \
  /usr/local/libexec/git-core/git-remote-http \
  /usr/local/libexec/git-core/git-remote-https

sha256sum \
  /usr/local/bin/git \
  /usr/local/libexec/git-core/git-alias-001 \
  /usr/local/libexec/git-core/git-alias-150 \
  /usr/local/libexec/git-core/git-remote-ftp \
  /usr/local/libexec/git-core/git-remote-ftps \
  /usr/local/libexec/git-core/git-remote-http \
  /usr/local/libexec/git-core/git-remote-https

od -An -tx1 -N8 /usr/local/libexec/git-core/git-remote-https
GIT_EXEC_PATH=/usr/local/libexec/git-core git --version
```

Docker:

```sh
docker run --rm \
  localhost:5000/container-images/msb-git-hardlink-corruption-repro:latest \
  sh -lc '<verification-command>'
```

MSB:

```sh
msb run --pull never --timeout 60s \
  localhost:5000/container-images/msb-git-hardlink-corruption-repro:latest \
  -- sh -lc '<verification-command>'
```

## Expected Docker Result

Docker should show:

- `/usr/local/bin/git`, `git-alias-001`, and `git-alias-150` have the same checksum.
- All four `git-remote-*` helpers have the same checksum.
- `git-remote-https` starts with the ELF header:

```text
7f 45 4c 46 02 01 01 00
```

## Expected MSB Failure

MSB should show:

- `/usr/local/bin/git` itself remains executable.
- Some hardlink aliases in the large first group may also change bytes.
- The later `git-remote-*` helper group has changed checksums.
- `git-remote-https` no longer starts with the ELF header.

Observed MSB output from the local arm64 build:

```text
/usr/local/bin/git inode=22477 links=151 size=19834024
/usr/local/libexec/git-core/git-alias-001 inode=23708 links=2 size=19834024
/usr/local/libexec/git-core/git-alias-150 inode=204445 links=151 size=19834024
/usr/local/libexec/git-core/git-remote-ftp inode=205658 links=4 size=11710936
/usr/local/libexec/git-core/git-remote-ftps inode=206375 links=2 size=11710936
/usr/local/libexec/git-core/git-remote-http inode=207092 links=3 size=11710936
/usr/local/libexec/git-core/git-remote-https inode=207809 links=4 size=11710936

c67250cf55e0b5518459b4a7278c164d54cc8f625535b1f0fefd319d41f82ef1  /usr/local/bin/git
c67250cf55e0b5518459b4a7278c164d54cc8f625535b1f0fefd319d41f82ef1  /usr/local/libexec/git-core/git-alias-001
2fd0ab4485a099e2e9bd8e839ada331ad8dea7bd87ea82d5b28b2ebacf490dff  /usr/local/libexec/git-core/git-alias-150
0cf331f80c1d83c8616c286d81feab8e9b2c980fbb9466ba13a90c884a813877  /usr/local/libexec/git-core/git-remote-ftp
472c627f5b855368dddca6a563f91abc198d4dc082bef9de899a5f21f6cc1409  /usr/local/libexec/git-core/git-remote-ftps
bc3d64ed83f07f0c03307b89c2dc042634ecc2da9a2cfc3ab335a8485ebcfcdb  /usr/local/libexec/git-core/git-remote-http
89aa4c69e80e8004f2c7ccb0cfd45ff7472cc0555fb52de95d4dad5374fe02d4  /usr/local/libexec/git-core/git-remote-https
```

The first bytes of `git-remote-https` became:

```text
00 00 00 00 00 00 00 00
```

That means MSB changed file contents while materializing the image.
