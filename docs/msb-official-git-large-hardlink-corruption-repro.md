# MSB Official Git Large Hardlink Corruption Repro

## Summary

This reproduces MSB file corruption without Dev Containers and without building Git from source.

The image uses only Debian-packaged Git binaries. It artificially pads `/usr/local/bin/git` to the same size as the source-built Git binary observed in the earlier failure, creates a large hardlink group from that file, then creates a second hardlink group for Git remote helpers.

Docker materializes both hardlink groups with valid bytes. MSB preserves the first large hardlink group but corrupts the later helper hardlink group.

## Environment

- Host: macOS arm64
- MSB: `0.4.5`
- Docker: Docker Desktop `27.4.0`
- Base image: `ghcr.io/superradcompany/debian-systemd:12-2026-05-11`

## Image

```text
localhost:5000/container-images/msb-git-official-biggit-multigroup:latest
```

Digest:

```text
sha256:c2cf9455a007b1beb0759f534268f89fa3ae0103688eb68270c2799a658ec59a
```

## Dockerfile

```Dockerfile
FROM ghcr.io/superradcompany/debian-systemd:12-2026-05-11

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

# Official Debian binaries only, but make the first hardlink group source-Git-sized.
RUN set -eux; \
    mkdir -p /usr/local/bin /usr/local/libexec/git-core; \
    cp /usr/bin/git /usr/local/bin/git; \
    current="$(stat -c %s /usr/local/bin/git)"; \
    target=19834024; \
    head -c "$((target - current))" /dev/zero >> /usr/local/bin/git; \
    chmod 755 /usr/local/bin/git; \
    for i in $(seq -w 1 150); do \
      ln /usr/local/bin/git "/usr/local/libexec/git-core/git-alias-$i"; \
    done; \
    cp /usr/lib/git-core/git-remote-http /usr/local/libexec/git-core/git-remote-ftp; \
    current="$(stat -c %s /usr/local/libexec/git-core/git-remote-ftp)"; \
    target=11710936; \
    head -c "$((target - current))" /dev/zero >> /usr/local/libexec/git-core/git-remote-ftp; \
    chmod 755 /usr/local/libexec/git-core/git-remote-ftp; \
    cd /usr/local/libexec/git-core; \
    ln git-remote-ftp git-remote-ftps; \
    ln git-remote-ftp git-remote-http; \
    ln git-remote-ftp git-remote-https
```

## Build And Push

```sh
docker build -t localhost:5000/container-images/msb-git-official-biggit-multigroup:latest .
docker push localhost:5000/container-images/msb-git-official-biggit-multigroup:latest
msb image pull --insecure localhost:5000/container-images/msb-git-official-biggit-multigroup:latest
```

## Verification Command

```sh
set -eu
stat -c "%n inode=%i links=%h size=%s" \
  /usr/local/bin/git \
  /usr/local/libexec/git-core/git-alias-001 \
  /usr/local/libexec/git-core/git-remote-ftp \
  /usr/local/libexec/git-core/git-remote-ftps \
  /usr/local/libexec/git-core/git-remote-http \
  /usr/local/libexec/git-core/git-remote-https

sha256sum \
  /usr/local/bin/git \
  /usr/local/libexec/git-core/git-alias-001 \
  /usr/local/libexec/git-core/git-remote-ftp \
  /usr/local/libexec/git-core/git-remote-ftps \
  /usr/local/libexec/git-core/git-remote-http \
  /usr/local/libexec/git-core/git-remote-https

od -An -tx1 -N8 /usr/local/libexec/git-core/git-remote-https
GIT_EXEC_PATH=/usr/local/libexec/git-core git --version
```

Run with Docker:

```sh
docker run --rm localhost:5000/container-images/msb-git-official-biggit-multigroup:latest sh -lc '<verification-command>'
```

Run with MSB:

```sh
msb run --pull never --timeout 60s localhost:5000/container-images/msb-git-official-biggit-multigroup:latest -- sh -lc '<verification-command>'
```

## Docker Baseline

Docker sees both hardlink groups with valid bytes:

```text
/usr/local/bin/git inode=568859 links=151 size=19834024
/usr/local/libexec/git-core/git-alias-001 inode=568859 links=151 size=19834024
/usr/local/libexec/git-core/git-remote-ftp inode=568860 links=4 size=11710936
/usr/local/libexec/git-core/git-remote-http inode=568860 links=4 size=11710936

c67250cf55e0b5518459b4a7278c164d54cc8f625535b1f0fefd319d41f82ef1  /usr/local/bin/git
c67250cf55e0b5518459b4a7278c164d54cc8f625535b1f0fefd319d41f82ef1  /usr/local/libexec/git-core/git-alias-001
c2fafba835badc5856fd06ad555d278dab42342ca204ae233e45ce0aa1a26a80  /usr/local/libexec/git-core/git-remote-ftp
c2fafba835badc5856fd06ad555d278dab42342ca204ae233e45ce0aa1a26a80  /usr/local/libexec/git-core/git-remote-http

first 8 bytes of git-remote-https:
7f 45 4c 46 02 01 01 00

git version 2.39.5
```

## MSB Failure

MSB preserves the first large hardlink group bytes, but corrupts the later helper hardlink group:

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

git version 2.39.5
```

Note that MSB also breaks hardlink identity: paths in the same hardlink group receive different inode numbers and inconsistent link counts. The more important failure here is that file bytes in the second group are changed.

## Negative Controls

These related images did not corrupt bytes in MSB:

- `localhost:5000/container-images/msb-git-apt-hardlink:latest`
  - Debian helper hardlinks only.
- `localhost:5000/container-images/msb-git-apt-padded-hardlink:latest`
  - Debian helper padded to `11710936` bytes with a sparse hole.
- `localhost:5000/container-images/msb-git-apt-fullpad-hardlink:latest`
  - Debian helper padded to `11710936` bytes with allocated zero bytes.
- `localhost:5000/container-images/msb-git-official-multigroup:latest`
  - Large count of hardlinks to the normal-size Debian `/usr/bin/git`, followed by the helper group.
- `localhost:5000/container-images/msb-git-official-late-helper:latest`
  - Helper group placed after a `120000000` byte regular filler file.

Those controls suggest the trigger is not simply:

- hardlinks
- helper file size
- sparse vs allocated padding
- many hardlink entries
- late offset in a large layer

## Further Narrowing

### Preceding Group Size

Image:

```text
localhost:5000/container-images/msb-git-size-matrix:latest
```

Digest:

```text
sha256:32531087bfcc9d0bb528321c57b346f7fab253f96baaed9f3c0c2542010f48dc
```

This image creates independent layers with a preceding `/opt/msb-cases/<case>/bin/git` hardlink group of different sizes. Each layer then creates the same `11710936` byte helper hardlink group.

All cases use 150 aliases for the preceding Git file, so the total link count is `151`.

MSB result:

```text
04m  preceding group size  4194304  -> helper bytes valid
08m  preceding group size  8388608  -> helper bytes valid
12m  preceding group size 12582912  -> helper bytes valid
16m  preceding group size 16777216  -> helper bytes corrupted
19m  preceding group size 19834024  -> helper bytes corrupted
```

Fine-grained size image:

```text
localhost:5000/container-images/msb-git-size-matrix-13-fine:latest
```

Digest:

```text
sha256:768fa14f5020abd7348691f910c9d8136abac3551924c495d86eecd1da0a38b2
```

MSB result:

```text
13.25MiB  preceding group size 13893632 -> helper bytes valid
13.5MiB   preceding group size 14155776 -> helper group partially corrupted
13.75MiB  preceding group size 14417920 -> helper bytes corrupted
```

So with `151` total links in the preceding group, the corruption threshold is between `13893632` and `14155776` bytes.

### Preceding Group Link Count

Image:

```text
localhost:5000/container-images/msb-git-linkcount-matrix:latest
```

Digest:

```text
sha256:c5ab5de3a0976b8de4e87db1b3fe476195e3d47cc29e0a371bef3c751843a2d0
```

This image fixes the preceding Git file size at `14680064` bytes and varies the number of hardlink aliases. The helper group is unchanged.

MSB result:

```text
2 total links    -> helper bytes valid
5 total links    -> helper bytes valid
17 total links   -> helper bytes valid
65 total links   -> helper bytes valid
151 total links  -> helper bytes corrupted
```

Fine-grained count images:

```text
localhost:5000/container-images/msb-git-linkcount-fine:latest
localhost:5000/container-images/msb-git-linkcount-144:latest
```

Digests:

```text
sha256:429c6837e2ee4e48d1b74c16dfaf8508b8c79fb6e1b6a1bbe272e21f9e3f1cfc
sha256:31c85a310f2e16c2f0c8db7fbc54c8bf5b441194dc75b343845bc61a6e133649
```

MSB result:

```text
97 total links   -> helper bytes valid
129 total links  -> helper bytes valid
145 total links  -> helper group partially corrupted
151 total links  -> helper bytes corrupted
```

So at `14680064` bytes, the link-count threshold is between `129` and `145` total links.

## Current Hypothesis

The trigger appears to require:

1. A large preceding hardlink group.
2. A later hardlink group in the same layer.

The narrowed reproduction suggests both size and link count matter:

- With `151` total links, corruption starts between `13.25MiB` and `13.5MiB`.
- At `14MiB`, corruption starts somewhere between `129` and `145` total links.

In the original source-built Git image, the natural layout is:

1. Large `/usr/local/bin/git` hardlink group, around `19834024` bytes.
2. Later `git-remote-*` helper hardlink group, around `11710936` bytes.

In that original failure, corrupted helper prefixes matched byte slices from the preceding `/usr/local/bin/git` binary. The official-binary reproduction here shows the same class of failure can be triggered without source-built Git content, which points toward stale source data or hardlink-group state reuse during MSB layer materialization.
