# MSB Source Git Hardlink Corruption Narrowing

## Summary

The Git helper corruption in MSB does not require Dev Containers.

It can be reproduced by manually building Git `2.54.0` from source into `/usr/local` on top of `ghcr.io/superradcompany/debian-systemd:12-2026-05-11`.
It also reproduces when the Git source archive and build tree are placed under `/usr/src` instead of `/tmp`, so `/tmp` is not the trigger.
It can also be reproduced without compiling Git in the repro Dockerfile by copying an already installed `/usr/local` Git tree into a fresh image with hardlinks preserved.

The failure appears tied to Git's source install creating regular-file hardlinks for:

```text
/usr/local/libexec/git-core/git-remote-ftp
/usr/local/libexec/git-core/git-remote-ftps
/usr/local/libexec/git-core/git-remote-http
/usr/local/libexec/git-core/git-remote-https
```

Docker materializes those files correctly. MSB corrupts their bytes and breaks the hardlink relationship. `git clone https://...` then fails because `git-remote-https` is no longer a valid ELF binary.

## Environment

- Host: macOS arm64
- MSB: `0.4.5`
- Docker: Docker Desktop `27.4.0`
- Base image: `ghcr.io/superradcompany/debian-systemd:12-2026-05-11`
- Manual Git version: `2.54.0`

## Tested Images

### 1. Debian Git Control

Image:

```text
localhost:5000/container-images/msb-git-apt-control:latest
```

Digest:

```text
sha256:60e45a120d87cd083cc253bc72646c609d000a058dea00cab1de5b0c833a171a
```

Dockerfile:

```Dockerfile
FROM ghcr.io/superradcompany/debian-systemd:12-2026-05-11

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates git; \
    rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
```

Result in MSB:

- Git version: `2.39.5`
- Uses Debian-packaged Git under `/usr/bin/git`
- Remote helper aliases are symlinks to `git-remote-http`
- File bytes are valid ELF
- `git clone https://github.com/xfiveco/skills.git` succeeds

Observed MSB output:

```text
git version 2.39.5
/usr/bin/git

/usr/lib/git-core/git-remote-ftp inode=19403 links=1 size=15 type=symbolic link
0699d47b53a7c87226298b403efbe77c0d81e57198a8740554774f9f0ab8c1cf
7f 45 4c 46 02 01 01 00

/usr/lib/git-core/git-remote-ftps inode=19406 links=1 size=15 type=symbolic link
0699d47b53a7c87226298b403efbe77c0d81e57198a8740554774f9f0ab8c1cf
7f 45 4c 46 02 01 01 00

/usr/lib/git-core/git-remote-http inode=19409 links=1 size=2260456 type=regular file
0699d47b53a7c87226298b403efbe77c0d81e57198a8740554774f9f0ab8c1cf
7f 45 4c 46 02 01 01 00

/usr/lib/git-core/git-remote-https inode=19549 links=1 size=15 type=symbolic link
0699d47b53a7c87226298b403efbe77c0d81e57198a8740554774f9f0ab8c1cf
7f 45 4c 46 02 01 01 00

helpers=same
68c0eaf
```

### 2. Manual Source Git

Image:

```text
localhost:5000/container-images/msb-git-source-manual:latest
```

Digest:

```text
sha256:00896aa0814741534fe0f88567d2dbc64ee84600ab5f38fe4e10903728baaf96
```

Dockerfile:

```Dockerfile
FROM ghcr.io/superradcompany/debian-systemd:12-2026-05-11

ARG GIT_VERSION=2.54.0

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      curl \
      gettext \
      libcurl4-openssl-dev \
      libexpat1-dev \
      libpcre2-dev \
      libssl-dev \
      make \
      perl \
      zlib1g-dev; \
    curl -fsSL "https://github.com/git/git/archive/refs/tags/v${GIT_VERSION}.tar.gz" -o /tmp/git.tar.gz; \
    mkdir -p /tmp/git-src; \
    tar -xzf /tmp/git.tar.gz -C /tmp/git-src --strip-components=1; \
    make -C /tmp/git-src prefix=/usr/local all -j"$(nproc)"; \
    make -C /tmp/git-src prefix=/usr/local install; \
    rm -rf /tmp/git-src /tmp/git.tar.gz /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
```

Docker baseline:

```text
git version 2.54.0
/usr/local/bin/git

/usr/local/libexec/git-core/git-remote-ftp   inode=559337 links=4 size=11710936 type=regular file
/usr/local/libexec/git-core/git-remote-ftps  inode=559337 links=4 size=11710936 type=regular file
/usr/local/libexec/git-core/git-remote-http  inode=559337 links=4 size=11710936 type=regular file
/usr/local/libexec/git-core/git-remote-https inode=559337 links=4 size=11710936 type=regular file

sha256 for all four:
5ac7fad61c5c32d2ef0e17728b6795aa047c6963a8f2c9af40f85974ee8136cc

first 8 bytes for all four:
7f 45 4c 46 02 01 01 00

helpers=same
git clone succeeds
cloned commit: 68c0eaf
```

MSB result:

```text
git version 2.54.0
/usr/local/bin/git

/usr/local/libexec/git-core/git-remote-ftp inode=181663 links=4 size=11710936 type=regular file
c450f185be14feb9fbc65de3d6e94fd758cbe80a0266e7cc99d365be367bbd09
08 01 8b 52 05 00 12 24

/usr/local/libexec/git-core/git-remote-ftps inode=182380 links=2 size=11710936 type=regular file
ed3fb47281b0f0f023a221f32534d9b9faa79b76fa4525c22d01e40e4c3296fb
63 00 80 52 a1 0e 80 52

/usr/local/libexec/git-core/git-remote-http inode=183097 links=3 size=11710936 type=regular file
528496a835601d82a062a2a8eb42fc6c97122d5f5c5e57a65d89470ec9be48f2
05 1d 03 79 3c 05 03 27

/usr/local/libexec/git-core/git-remote-https inode=183814 links=4 size=11710936 type=regular file
54d9fa1977a66c6e3cd2a7390f25dfb6135a650b65f5a0cf45155d681d9b2f9d
00 00 02 01 50 02 8c 00

helpers=different
```

Clone failure:

```text
Cloning into '/tmp/skills'...
/usr/local/libexec/git-core/git-remote-https: 3: Syntax error: "(" unexpected
fatal: remote helper 'https' aborted session
```

### 3. Symlink Alias Variant

Image:

```text
localhost:5000/container-images/msb-git-source-symlink:latest
```

Digest:

```text
sha256:7f6f102e9a04ec368755b85bdc645f558720b716504f933387c17c1da895ee22
```

Dockerfile:

```Dockerfile
FROM localhost:5000/container-images/msb-git-source-manual:latest

RUN set -eux; \
    cd /usr/local/libexec/git-core; \
    for helper in git-remote-ftp git-remote-ftps git-remote-https; do \
      rm -f "$helper"; \
      ln -s git-remote-http "$helper"; \
    done

CMD ["sleep", "infinity"]
```

Result:

- Still fails in MSB
- The aliases are symlinks, but the real `git-remote-http` file is inherited from the corrupted hardlink layer
- The symlinks point to corrupted bytes

Observed MSB output:

```text
git version 2.54.0
/usr/local/bin/git

/usr/local/libexec/git-core/git-remote-ftp inode=181663 links=1 size=15 type=symbolic link
528496a835601d82a062a2a8eb42fc6c97122d5f5c5e57a65d89470ec9be48f2
05 1d 03 79 3c 05 03 27

/usr/local/libexec/git-core/git-remote-ftps inode=181666 links=1 size=15 type=symbolic link
528496a835601d82a062a2a8eb42fc6c97122d5f5c5e57a65d89470ec9be48f2
05 1d 03 79 3c 05 03 27

/usr/local/libexec/git-core/git-remote-http inode=181669 links=3 size=11710936 type=regular file
528496a835601d82a062a2a8eb42fc6c97122d5f5c5e57a65d89470ec9be48f2
05 1d 03 79 3c 05 03 27

/usr/local/libexec/git-core/git-remote-https inode=182386 links=1 size=15 type=symbolic link
528496a835601d82a062a2a8eb42fc6c97122d5f5c5e57a65d89470ec9be48f2
05 1d 03 79 3c 05 03 27

helpers=same
```

Clone failure:

```text
fatal: remote helper 'https' aborted session
```

This shows that changing only the aliases is not enough if the original target file came from the corrupted hardlink group.

### 4. Source Build Under /usr/src

Image:

```text
localhost:5000/container-images/msb-git-source-usrsrc:latest
```

Digest:

```text
sha256:1b01e16c2306aba50779d8332dc53599b83ddf9e4e8624b61553c96bdcd2071a
```

Dockerfile:

```Dockerfile
FROM ghcr.io/superradcompany/debian-systemd:12-2026-05-11

ARG GIT_VERSION=2.54.0

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      curl \
      gettext \
      libcurl4-openssl-dev \
      libexpat1-dev \
      libpcre2-dev \
      libssl-dev \
      make \
      perl \
      zlib1g-dev; \
    mkdir -p /usr/src/git-build; \
    curl -fsSL "https://github.com/git/git/archive/refs/tags/v${GIT_VERSION}.tar.gz" -o /usr/src/git.tar.gz; \
    tar -xzf /usr/src/git.tar.gz -C /usr/src/git-build --strip-components=1; \
    make -C /usr/src/git-build prefix=/usr/local all -j"$(nproc)"; \
    make -C /usr/src/git-build prefix=/usr/local install; \
    rm -rf /usr/src/git-build /usr/src/git.tar.gz /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
```

Docker baseline:

```text
git version 2.54.0
/usr/local/bin/git

/usr/local/libexec/git-core/git-remote-ftp   inode=567018 links=4 size=11710944 type=regular file
/usr/local/libexec/git-core/git-remote-ftps  inode=567018 links=4 size=11710944 type=regular file
/usr/local/libexec/git-core/git-remote-http  inode=567018 links=4 size=11710944 type=regular file
/usr/local/libexec/git-core/git-remote-https inode=567018 links=4 size=11710944 type=regular file

sha256 for all four:
4fa7b8e0ccc8def3bc3ceda350469e605389755e9a570113dfcf269e69343275

first 8 bytes for all four:
7f 45 4c 46 02 01 01 00

helpers=same
git clone succeeds
cloned commit: 68c0eaf
```

MSB result:

```text
git version 2.54.0
/usr/local/bin/git

/usr/local/libexec/git-core/git-remote-ftp inode=181663 links=4 size=11710944 type=regular file
9f246f7937417ac8964b6178a1d1c468f5a40c2929635cbfabd7c18a35473114
08 01 8b 52 05 00 12 24

/usr/local/libexec/git-core/git-remote-ftps inode=182380 links=2 size=11710944 type=regular file
386c3d6afbba85381a7411bb71238e1dfe4a6980000ca3c770740921cb8341b1
63 00 80 52 a1 0e 80 52

/usr/local/libexec/git-core/git-remote-http inode=183097 links=3 size=11710944 type=regular file
174b329edfc3b6463145ba828b0f3d80fe8c1c51fda71bbf2e0eb64032c54533
05 1d 03 79 3c 05 03 27

/usr/local/libexec/git-core/git-remote-https inode=183814 links=4 size=11710944 type=regular file
b95962b55842f2aa0199cad610f8950edf3628749e48465e1afa6ad21165d8b2
00 00 02 01 50 02 8c 00

helpers=different
```

Clone failure:

```text
Cloning into '/tmp/skills'...
/usr/local/libexec/git-core/git-remote-https: 3: Syntax error: "(" unexpected
fatal: remote helper 'https' aborted session
```

This shows that the temporary build path is not required for reproduction. The same failure happens when the archive and source tree are under `/usr/src`.

### 5. No-Source Copied Tree Reproduction

This variant does not compile Git. It installs Debian runtime dependencies, then copies the already installed `/usr/local` tree from the known source-built image into a fresh image with `cp -a`.

Image:

```text
localhost:5000/container-images/msb-git-copy-usrlocal-tree-runnable:latest
```

Digest:

```text
sha256:2272afc28a139dd4ad89464134c773eabe125c139cccfee9de29fbd72dbe0ed3
```

Dockerfile:

```Dockerfile
# syntax=docker/dockerfile:1.7
FROM localhost:5000/container-images/msb-git-source-manual:latest AS git-source

FROM ghcr.io/superradcompany/debian-systemd:12-2026-05-11

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git libcurl4 \
    && rm -rf /var/lib/apt/lists/*

RUN --mount=from=git-source,source=/usr/local,target=/mnt/usr/local,ro \
    set -eux; \
    cp -a /mnt/usr/local/. /usr/local/
```

Docker baseline:

```text
/usr/local/bin/git
git version 2.54.0

/usr/local/libexec/git-core/git-remote-ftp   inode=568691 links=4 size=11710936
/usr/local/libexec/git-core/git-remote-ftps  inode=568691 links=4 size=11710936
/usr/local/libexec/git-core/git-remote-http  inode=568691 links=4 size=11710936
/usr/local/libexec/git-core/git-remote-https inode=568691 links=4 size=11710936

sha256 for all four:
5ac7fad61c5c32d2ef0e17728b6795aa047c6963a8f2c9af40f85974ee8136cc

first 8 bytes:
7f 45 4c 46 02 01 01 00

git clone succeeds
cloned commit: 68c0eaf
```

MSB result:

```text
/usr/local/bin/git
git version 2.54.0

/usr/local/libexec/git-core/git-remote-ftp inode=157360 links=4 size=11710936
c450f185be14feb9fbc65de3d6e94fd758cbe80a0266e7cc99d365be367bbd09

/usr/local/libexec/git-core/git-remote-ftps inode=158077 links=2 size=11710936
ed3fb47281b0f0f023a221f32534d9b9faa79b76fa4525c22d01e40e4c3296fb

/usr/local/libexec/git-core/git-remote-http inode=158794 links=3 size=11710936
528496a835601d82a062a2a8eb42fc6c97122d5f5c5e57a65d89470ec9be48f2

/usr/local/libexec/git-core/git-remote-https inode=159511 links=4 size=11710936
c04608442c0fe5d198e35f64e7db87dcfa94d8ff5cb623785f161f92fde01963

first 8 bytes of git-remote-https:
00 00 02 01 50 02 8c 00
```

Clone failure:

```text
Cloning into '/tmp/skills'...
/usr/local/libexec/git-core/git-remote-https: 3: Syntax error: "(" unexpected
fatal: remote helper 'https' aborted session
```

This shows the repro Dockerfile does not need to build Git from source. The failing input can be reduced to a layer created by copying an installed Git tree while preserving hardlinks.

Related no-source controls:

- `localhost:5000/container-images/msb-git-apt-hardlink:latest` replaces Debian's helper symlinks with hardlinks. MSB breaks hardlink identity, but bytes remain valid and clone succeeds.
- `localhost:5000/container-images/msb-git-copy-hardlink:latest` copies only `git-remote-http` in one layer and creates helper hardlinks in a later layer. MSB breaks hardlink identity, but bytes remain valid.
- `localhost:5000/container-images/msb-git-copy-hardlink-samelayer:latest` copies only `git-remote-http` and creates helper hardlinks in the same layer. MSB breaks hardlink identity, but bytes remain valid.
- `localhost:5000/container-images/msb-git-apt-padded-hardlink:latest` pads Debian's helper to `11710936` bytes with a sparse hole. MSB breaks hardlink identity, but bytes remain valid and clone succeeds.
- `localhost:5000/container-images/msb-git-apt-fullpad-hardlink:latest` pads Debian's helper to `11710936` bytes with allocated zero bytes. MSB breaks hardlink identity, but bytes remain valid and clone succeeds.
- `localhost:5000/container-images/msb-git-official-multigroup:latest` adds a 151-link group for Debian's normal `/usr/bin/git` before the helper group. MSB breaks hardlink identity, but bytes remain valid.
- `localhost:5000/container-images/msb-git-official-late-helper:latest` places Debian's helper group after a `120000000` byte regular filler file. MSB breaks hardlink identity, but bytes remain valid and clone succeeds.

Official-binary reproduction:

- `localhost:5000/container-images/msb-git-official-biggit-multigroup:latest` uses only Debian Git binaries, but pads `/usr/local/bin/git` to `19834024` bytes and creates 150 hardlink aliases before the helper group.
- Docker sees valid bytes for both groups.
- MSB preserves the padded `/usr/local/bin/git` bytes, but corrupts the later helper group.
- This indicates the trigger is not Git source compilation and not the official-vs-source helper binary content. The trigger appears to involve a large preceding hardlink group followed by another hardlink group in the same layer.

Observed MSB output for the official-binary reproduction:

```text
/usr/local/bin/git inode=22477 links=151 size=19834024
/usr/local/libexec/git-core/git-alias-001 inode=23708 links=2 size=19834024
/usr/local/libexec/git-core/git-remote-ftp inode=205658 links=4 size=11710936
/usr/local/libexec/git-core/git-remote-ftps inode=206375 links=2 size=11710936
/usr/local/libexec/git-core/git-remote-http inode=207092 links=3 size=11710936
/usr/local/libexec/git-core/git-remote-https inode=207809 links=4 size=11710936

c67250cf55e0b5518459b4a7278c164d54cc8f625535b1f0fefd319d41f82ef1  /usr/local/bin/git
c67250cf55e0b5518459b4a7278c164d54cc8f625535b1f0fefd319d41f82ef1  /usr/local/libexec/git-core/git-alias-001
0cf331f80c1d83c8616c286d81feab8e9b2c980fbb9466ba13a90c884a813877  /usr/local/libexec/git-core/git-remote-ftp
472c627f5b855368dddca6a563f91abc198d4dc082bef9de899a5f21f6cc1409  /usr/local/libexec/git-core/git-remote-ftps
bc3d64ed83f07f0c03307b89c2dc042634ecc2da9a2cfc3ab335a8485ebcfcdb  /usr/local/libexec/git-core/git-remote-http
89aa4c69e80e8004f2c7ccb0cfd45ff7472cc0555fb52de95d4dad5374fe02d4  /usr/local/libexec/git-core/git-remote-https

first 8 bytes of git-remote-https:
00 00 00 00 00 00 00 00
```

### 6. Copyfix Variant

Image:

```text
localhost:5000/container-images/msb-git-source-copyfix:latest
```

Digest:

```text
sha256:1124712b650e6d97a6fbdd823bca5292850241bca20c9a60287a0c83ad003ba0
```

Dockerfile:

```Dockerfile
FROM localhost:5000/container-images/msb-git-source-manual:latest

RUN set -eux; \
    cd /usr/local/libexec/git-core; \
    cp git-remote-http /tmp/git-remote-http.copy; \
    rm -f git-remote-ftp git-remote-ftps git-remote-http git-remote-https; \
    mv /tmp/git-remote-http.copy git-remote-http; \
    chmod 755 git-remote-http; \
    for helper in git-remote-ftp git-remote-ftps git-remote-https; do \
      ln -s git-remote-http "$helper"; \
    done

CMD ["sleep", "infinity"]
```

Result in MSB:

- Passes
- The hardlink group is removed
- `git-remote-http` is rewritten as a standalone regular file in a later layer
- Aliases are symlinks
- Bytes remain valid ELF
- `git clone` succeeds

Observed MSB output:

```text
git version 2.54.0
/usr/local/bin/git

/usr/local/libexec/git-core/git-remote-ftp inode=181663 links=1 size=15 type=symbolic link
5ac7fad61c5c32d2ef0e17728b6795aa047c6963a8f2c9af40f85974ee8136cc
7f 45 4c 46 02 01 01 00

/usr/local/libexec/git-core/git-remote-ftps inode=181666 links=1 size=15 type=symbolic link
5ac7fad61c5c32d2ef0e17728b6795aa047c6963a8f2c9af40f85974ee8136cc
7f 45 4c 46 02 01 01 00

/usr/local/libexec/git-core/git-remote-http inode=181669 links=1 size=11710936 type=regular file
5ac7fad61c5c32d2ef0e17728b6795aa047c6963a8f2c9af40f85974ee8136cc
7f 45 4c 46 02 01 01 00

/usr/local/libexec/git-core/git-remote-https inode=182386 links=1 size=15 type=symbolic link
5ac7fad61c5c32d2ef0e17728b6795aa047c6963a8f2c9af40f85974ee8136cc
7f 45 4c 46 02 01 01 00

helpers=same
68c0eaf
```

## Verification Command

Use this inside each image:

```sh
set -eu
git --version
command -v git

for f in \
  /usr/local/libexec/git-core/git-remote-ftp \
  /usr/local/libexec/git-core/git-remote-ftps \
  /usr/local/libexec/git-core/git-remote-http \
  /usr/local/libexec/git-core/git-remote-https
do
  stat -c "%n inode=%i links=%h size=%s type=%F" "$f"
  sha256sum "$f"
  od -An -tx1 -N8 "$f"
done

[ /usr/local/libexec/git-core/git-remote-ftp -ef /usr/local/libexec/git-core/git-remote-https ] \
  && echo helpers=same \
  || echo helpers=different

rm -rf /tmp/skills
git clone --depth=1 https://github.com/xfiveco/skills.git /tmp/skills
git -C /tmp/skills rev-parse --short HEAD
```

For the Debian Git control, use `/usr/lib/git-core/...` instead of `/usr/local/libexec/git-core/...`.

## Current Narrowing

The current narrowing is:

- MSB handles Debian-packaged Git correctly
- MSB corrupts manually source-built Git `2.54.0` without Dev Containers
- The corruption still reproduces when the source archive and build tree use `/usr/src` instead of `/tmp`
- The corruption can be reproduced without compiling Git in the repro image by copying an installed `/usr/local` Git tree with hardlinks preserved
- The corruption can also be reproduced with official Debian Git binaries only, if `/usr/local/bin/git` is padded to source-Git size and hardlinked many times before the helper group
- The corrupted files are the regular-file hardlink group created by Git's source `make install`
- The source-built helper corruption includes byte prefixes that match slices of the preceding `/usr/local/bin/git` binary, suggesting stale source data or hardlink-group state is reused while materializing a later group
- Symlinking only the aliases in a later layer is not enough because the inherited real target file remains corrupted
- Rewriting the real target file as a fresh standalone file in a later layer fixes the image

Most likely failing area:

- OCI layer extraction
- hardlink materialization
- filesystem construction from tar entries involving regular-file hardlinks

## Practical Workaround

For affected images, break the source Git remote-helper hardlink group in a later layer:

```Dockerfile
RUN set -eux; \
    cd /usr/local/libexec/git-core; \
    cp git-remote-http /tmp/git-remote-http.copy; \
    rm -f git-remote-ftp git-remote-ftps git-remote-http git-remote-https; \
    mv /tmp/git-remote-http.copy git-remote-http; \
    chmod 755 git-remote-http; \
    for helper in git-remote-ftp git-remote-ftps git-remote-https; do \
      ln -s git-remote-http "$helper"; \
    done
```

This preserves Git behavior and avoids the MSB corruption in the tested image.
