# MSB Dev Containers Git Feature Corruption Reproduction

## Summary

MSB appears to corrupt Git helper binaries installed by the Dev Containers Git feature when booting an image built from `ghcr.io/superradcompany/debian-systemd:12-2026-05-11`.

The issue is reproducible with a small image that only applies `ghcr.io/devcontainers/features/git:1` to that base image. Docker preserves the Git helper hardlinks and file contents. MSB does not preserve the hardlink identity and also changes the bytes of the helper binaries. As a result, `git clone https://...` fails because `/usr/local/libexec/git-core/git-remote-https` is no longer a valid ELF binary.

This is stronger than the generic hardlink issue:

- simple hardlink test images show MSB does not preserve hardlink identity
- the Dev Containers Git feature image also shows byte-level corruption

## Environment

- Host: macOS arm64
- Docker: Docker Desktop `27.4.0`
- MSB: `0.4.4`
- Base image: `ghcr.io/superradcompany/debian-systemd:12-2026-05-11`
- Feature: `ghcr.io/devcontainers/features/git:1`
- Dev Containers CLI observed version: `0.87.0`
- Git installed by feature: `2.54.0`

## Minimal Image

Create this file at `/tmp/msb-git-feature-hardlink/.devcontainer/devcontainer.json`:

```json
{
  "name": "msb-git-feature-hardlink",
  "image": "ghcr.io/superradcompany/debian-systemd:12-2026-05-11",
  "features": {
    "ghcr.io/devcontainers/features/git:1": {
      "version": "latest"
    }
  }
}
```

Build and tag it:

```sh
npx --yes @devcontainers/cli build \
  --workspace-folder /tmp/msb-git-feature-hardlink \
  --image-name localhost:5000/container-images/msb-git-feature-hardlink:latest
```

Push to a local registry:

```sh
docker push localhost:5000/container-images/msb-git-feature-hardlink:latest
```

Observed pushed digest:

```text
sha256:7724f48ab73a042c60b30d98891799e00af85f7d277186358e059f630e76633b
```

Pull into MSB:

```sh
msb image pull --force --insecure localhost:5000/container-images/msb-git-feature-hardlink:latest
```

## Verification Command

Use the same command in Docker and MSB:

```sh
sh -lc '
set -eu
git --version
command -v git

for f in \
  /usr/local/libexec/git-core/git-remote-ftp \
  /usr/local/libexec/git-core/git-remote-ftps \
  /usr/local/libexec/git-core/git-remote-http \
  /usr/local/libexec/git-core/git-remote-https
do
  stat -c "%n inode=%i links=%h size=%s" "$f"
  sha256sum "$f"
  od -An -tx1 -N8 "$f"
done

[ /usr/local/libexec/git-core/git-remote-ftp -ef /usr/local/libexec/git-core/git-remote-https ] \
  && echo helpers=same \
  || echo helpers=different

rm -rf /tmp/skills
git clone --depth=1 https://github.com/xfiveco/skills.git /tmp/skills
git -C /tmp/skills rev-parse --short HEAD
'
```

Docker invocation:

```sh
docker run --rm localhost:5000/container-images/msb-git-feature-hardlink:latest sh -lc '...'
```

MSB invocation:

```sh
msb run --pull never --timeout 2m \
  localhost:5000/container-images/msb-git-feature-hardlink:latest \
  -- sh -lc '...'
```

## Expected Docker Result

Docker preserves the helper binaries correctly.

Observed:

```text
git version 2.54.0
/usr/local/bin/git

/usr/local/libexec/git-core/git-remote-ftp   inode=447542 links=4 size=11718360
/usr/local/libexec/git-core/git-remote-ftps  inode=447542 links=4 size=11718360
/usr/local/libexec/git-core/git-remote-http  inode=447542 links=4 size=11718360
/usr/local/libexec/git-core/git-remote-https inode=447542 links=4 size=11718360

sha256 for all four:
dc2bb87ae01e72fddced21e1b62171117228b7e48a087daff9ed3a4f163abcff

first 8 bytes for all four:
7f 45 4c 46 02 01 01 00

helpers=same
git clone succeeds
cloned commit: 68c0eaf
```

The `7f 45 4c 46` prefix is the ELF magic header.

## Actual MSB Result

MSB does not preserve the hardlink group, and the file contents differ from Docker and from each other.

Observed:

```text
git version 2.54.0
/usr/local/bin/git

/usr/local/libexec/git-core/git-remote-ftp inode=181363 links=4 size=11718360
3741c032a9d27252f84a9adbd337a6bbc067eff71180ff70300d35af850eff88
00 00 00 20 00 00 00 a0

/usr/local/libexec/git-core/git-remote-ftps inode=182081 links=2 size=11718360
d79da8f38ff74d7ae85aa3138328067ac8ecea4e5399a835b2bc3972d3247849
65 64 5f 6f 62 6a 66 69

/usr/local/libexec/git-core/git-remote-http inode=182799 links=3 size=11718360
4dabd869597577be8bbb8fee96369f062bac80787ea21a5b1926463c348df546
00 00 00 8e 35 00 00 06

/usr/local/libexec/git-core/git-remote-https inode=183517 links=4 size=11718360
0e508b0e11df99f71e4fc428ac7e808be95dc386218290bb4e277cdbe7a63c81
0c c4 0c 00 04 b0 09 b0

helpers=different
```

`git clone` fails:

```text
Cloning into '/tmp/skills'...
/usr/local/libexec/git-core/git-remote-https: 1: ...: not found
/usr/local/libexec/git-core/git-remote-https: 14: Syntax error: ")" unexpected
fatal: remote helper 'https' aborted session
```

## Why This Looks Like Image Materialization Corruption

The same image behaves correctly in Docker and incorrectly in MSB.

In Docker:

- all four helper paths are one hardlink group
- the link count is `4`
- all checksums match
- all files start with an ELF header
- `git clone` works

In MSB:

- the helper paths are no longer the same file
- inode values differ
- link counts are inconsistent
- checksums differ from Docker and from each other
- none of the helpers start with an ELF header
- `git clone` fails because the remote helper is interpreted as a shell script

The likely failing area is OCI layer extraction, hardlink handling, or root filesystem materialization in MSB.

## Related Synthetic Tests

Separate synthetic images were built from the same base with:

- small hardlinked text files
- large hardlinked random blobs
- hardlinked ELF binaries
- hardlink groups replaced across layers
- tar archives containing hardlinks
- repeated `ADD` of tar archives over the same hardlink paths

Those tests reproduced loss of hardlink identity in MSB, but did not reproduce byte corruption. File checksums still matched Docker.

That narrows the corruption trigger: hardlinks are part of the issue, but the Dev Containers Git feature install creates a layer/filesystem shape that triggers actual byte corruption.

## Workarounds

Potential image-side workarounds:

- prefer Debian Git by setting `GIT_EXEC_PATH=/usr/lib/git-core`
- remove or replace `/usr/local/libexec/git-core/git-remote-*`
- symlink `/usr/local/libexec/git-core/git-remote-{ftp,ftps,http,https}` to the Debian helper under `/usr/lib/git-core`
- avoid installing Git from source into `/usr/local` with the Dev Containers Git feature

These are workarounds, not fixes. The underlying MSB behavior still appears incorrect because an image that runs correctly in Docker is materialized differently in MSB.

## Short Reproduction Summary

```sh
mkdir -p /tmp/msb-git-feature-hardlink/.devcontainer

cat > /tmp/msb-git-feature-hardlink/.devcontainer/devcontainer.json <<'JSON'
{
  "name": "msb-git-feature-hardlink",
  "image": "ghcr.io/superradcompany/debian-systemd:12-2026-05-11",
  "features": {
    "ghcr.io/devcontainers/features/git:1": {
      "version": "latest"
    }
  }
}
JSON

npx --yes @devcontainers/cli build \
  --workspace-folder /tmp/msb-git-feature-hardlink \
  --image-name localhost:5000/container-images/msb-git-feature-hardlink:latest

docker push localhost:5000/container-images/msb-git-feature-hardlink:latest

msb image pull --force --insecure localhost:5000/container-images/msb-git-feature-hardlink:latest

msb run --pull never --timeout 2m \
  localhost:5000/container-images/msb-git-feature-hardlink:latest \
  -- sh -lc '
    set -eu
    git --version
    for f in /usr/local/libexec/git-core/git-remote-{ftp,ftps,http,https}; do
      stat -c "%n inode=%i links=%h size=%s" "$f"
      sha256sum "$f"
      od -An -tx1 -N8 "$f"
    done
    rm -rf /tmp/skills
    git clone --depth=1 https://github.com/xfiveco/skills.git /tmp/skills
  '
```

Expected from a correct runtime: helper binaries remain ELF files and `git clone` succeeds.

Observed in MSB `0.4.4`: helper binaries contain different bytes and `git clone` fails.
