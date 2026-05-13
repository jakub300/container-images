# MSB Git Remote Helper Corruption Report

Date: 2026-05-13

## Summary

When running the Rails devcontainer image in MSB, HTTPS Git operations fail because the Git remote helper binaries under `/usr/local/libexec/git-core/` are corrupted inside the MSB VM.

The same image works correctly under Docker. The issue also reproduces with the upstream Rails base image directly, before any local Dockerfile changes are applied.

This points to an MSB image unpacking, filesystem, or overlay issue. The strongest lead is incorrect handling of tar hardlinks across OCI layers.

## Images Tested

Derived image:

```text
ghcr.io/jakub300/container-images/msb-rails-devcontainer:latest
```

Upstream base image:

```text
ghcr.io/rails/devcontainer/images/ruby:2.3.1-3.4.9
```

MSB CLI:

```text
Microsandbox CLI v0.4.4
```

Host context:

```text
macOS host
arm64 architecture
```

## User-Facing Failure

Command:

```sh
msb run --pull always --timeout 3m \
  ghcr.io/jakub300/container-images/msb-rails-devcontainer:latest \
  -- sh -lc 'rm -rf /tmp/skills && git clone --depth=1 https://github.com/xfiveco/skills.git /tmp/skills'
```

Failure:

```text
Cloning into '/tmp/skills'...
/usr/local/libexec/git-core/git-remote-https: 1: ...: not found
/usr/local/libexec/git-core/git-remote-https: 2: ...: not found
/usr/local/libexec/git-core/git-remote-https: 9: Syntax error: ")" unexpected
fatal: remote helper 'https' aborted session
```

Important detail: `git --version` works because `/usr/local/bin/git` itself is intact. The failure occurs when Git invokes the HTTPS remote helper.

## Minimal Reproduction With Upstream Image

This reproduces without the local derived image:

```sh
msb run --pull always --timeout 3m \
  ghcr.io/rails/devcontainer/images/ruby:2.3.1-3.4.9 \
  -- sh -lc 'rm -rf /tmp/skills && git clone --depth=1 https://github.com/xfiveco/skills.git /tmp/skills'
```

Observed result: same corrupted `/usr/local/libexec/git-core/git-remote-https` execution failure.

This rules out our local Dockerfile changes as the cause.

## Expected Behavior

The same GHCR image works under Docker:

```sh
docker run --rm \
  ghcr.io/jakub300/container-images/msb-rails-devcontainer:latest \
  sh -lc 'rm -rf /tmp/skills && git clone --depth=1 https://github.com/xfiveco/skills.git /tmp/skills && git -C /tmp/skills rev-parse --short HEAD'
```

Output:

```text
Cloning into '/tmp/skills'...
68c0eaf
```

Docker also shows the Git HTTPS helper starts with a normal ELF header:

```text
7f 45 4c 46
```

## Actual MSB Filesystem State

Inside MSB, with the Rails image:

```sh
msb run --pull if-missing --timeout 3m \
  ghcr.io/jakub300/container-images/msb-rails-devcontainer:latest \
  -- sh -lc 'set -eu; for p in /usr/local/bin/git /usr/local/libexec/git-core/git-remote-http /usr/local/libexec/git-core/git-remote-https /usr/local/libexec/git-core/git-remote-ftp /usr/local/libexec/git-core/git-remote-ftps /usr/bin/git /usr/lib/git-core/git-remote-http /usr/lib/git-core/git-remote-https; do [ -e "$p" ] || continue; echo "== $p"; ls -li "$p"; stat -c "mode=%a size=%s links=%h inode=%i" "$p"; sha256sum "$p"; head -c 16 "$p" | od -An -tx1; done'
```

Observed relevant output:

```text
== /usr/local/bin/git
165730 -rwxr-xr-x 148 root root 19826288 Apr 23 04:05 /usr/local/bin/git
mode=755 size=19826288 links=148 inode=165730
2593a8764a407670d5afedc2ac2bfe77da769b0576fb17d5281a69fbc166bb16  /usr/local/bin/git
 7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00

== /usr/local/libexec/git-core/git-remote-http
308784 -rwxr-xr-x 3 root root 11754864 Apr 23 04:05 /usr/local/libexec/git-core/git-remote-http
mode=755 size=11754864 links=3 inode=308784
6baca4d42c764fb1b0ab3c1ac6c5fcd03e11963f2fcc0e888bc755894fa39153  /usr/local/libexec/git-core/git-remote-http
 0a 2f 05 05 1f 05 01 31 05 30 06 03 79 20 05 02

== /usr/local/libexec/git-core/git-remote-https
309504 -rwxr-xr-x 4 root root 11754864 Apr 23 04:05 /usr/local/libexec/git-core/git-remote-https
mode=755 size=11754864 links=4 inode=309504
a5dbcaa15af2bc6b3d9babe0d09523b582fd7e8af045ce8183a254a054ab7cd0  /usr/local/libexec/git-core/git-remote-https
 00 11 13 05 00 00 0d e4 5d 01 00 06 73 01 10 4e

== /usr/local/libexec/git-core/git-remote-ftp
307344 -rwxr-xr-x 4 root root 11754864 Apr 23 04:05 /usr/local/libexec/git-core/git-remote-ftp
mode=755 size=11754864 links=4 inode=307344
ac50809cae093d1a24bb19c241b21a0cbfd550020b056c44e45a0e8875338814  /usr/local/libexec/git-core/git-remote-ftp
 16 68 04 e6 19 00 00 18 01 95 c7 03 00 16 6b 1b

== /usr/local/libexec/git-core/git-remote-ftps
308064 -rwxr-xr-x 2 root root 11754864 Apr 23 04:05 /usr/local/libexec/git-core/git-remote-ftps
mode=755 size=11754864 links=2 inode=308064
a33f9368615ef4a4bb7da146124560b849ad189975437400fe6aa518472124cb  /usr/local/libexec/git-core/git-remote-ftps
 60 62 00 91 23 73 02 94 60 02 40 f9 e1 03 15 aa

== /usr/bin/git
47505 -rwxr-xr-x 1 root root 4081272 Jul 30  2025 /usr/bin/git
mode=755 size=4081272 links=1 inode=47505
a0e562e4bd3c4c79379e91d8c07a10104b2cefe8fac966dc6bd4874a57a807f3  /usr/bin/git
 7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00

== /usr/lib/git-core/git-remote-http
134253 -rwxr-xr-x 1 root root 2460464 Jul 30  2025 /usr/lib/git-core/git-remote-http
mode=755 size=2460464 links=1 inode=134253
4ce8af294003904b841c87d331647f98c475c76f6c2e5fb6e21ac7bc8a969c1f  /usr/lib/git-core/git-remote-http
 7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
```

Key observation:

- `/usr/local/bin/git` is intact.
- `/usr/local/libexec/git-core/git-remote-*` files are corrupted.
- Debian Git under `/usr/bin` and `/usr/lib/git-core` is intact.

## Docker Filesystem State

The same paths in Docker:

```text
== /usr/local/libexec/git-core/git-remote-http
3548185 -rwxr-xr-x 4 root root 11754864 Apr 23 04:05 /usr/local/libexec/git-core/git-remote-http
bbf187e4593504a727a0a1bb32e0d1bcbf889602b32e10b80995263566bc969d
 7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00

== /usr/local/libexec/git-core/git-remote-https
3548185 -rwxr-xr-x 4 root root 11754864 Apr 23 04:05 /usr/local/libexec/git-core/git-remote-https
bbf187e4593504a727a0a1bb32e10b80995263566bc969d
 7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00

== /usr/local/libexec/git-core/git-remote-ftp
3548185 -rwxr-xr-x 4 root root 11754864 Apr 23 04:05 /usr/local/libexec/git-core/git-remote-ftp
bbf187e4593504a727a0a1bb32e0d1bcbf889602b32e10b80995263566bc969d
 7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00

== /usr/local/libexec/git-core/git-remote-ftps
3548185 -rwxr-xr-x 4 root root 11754864 Apr 23 04:05 /usr/local/libexec/git-core/git-remote-ftps
bbf187e4593504a727a0a1bb32e0d1bcbf889602b32e10b80995263566bc969d
 7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
```

Key observation:

- Docker preserves these four files as hardlinks to the same inode.
- Docker reports the same SHA-256 for all four files.
- Docker reports a valid ELF header for all four.

## Layer Metadata Evidence

The GHCR image was saved locally with:

```sh
docker save -o /private/tmp/msb-rails-ghcr.tar \
  ghcr.io/jakub300/container-images/msb-rails-devcontainer:latest
```

Layer search:

```sh
while read -r layer; do
  hit=$(tar -xOf /private/tmp/msb-rails-ghcr.tar "$layer" \
    | tar -tzf - 2>/dev/null \
    | rg 'usr/local/(bin/git$|libexec/git-core/git-remote-(http|https|ftp|ftps)$)' || true)
  if [ -n "$hit" ]; then
    echo "== $layer"
    printf '%s\n' "$hit"
  fi
done < <(jq -r '.[0].Layers[]' /private/tmp/manifest.json)
```

Relevant layers:

```text
blobs/sha256/a058d953c5868ea6bea91107f28610f7da5954a66806e29d9157a5d145e6698f
blobs/sha256/86b2b9428d498d933619be27c3315fec05bcf821cc8339a0680443048ddfa850
```

Both layers contain the Git install paths.

Tar metadata from those layers shows the remote helpers are a hardlink group:

```text
-rwxr-xr-x  0 0      0    11754864 Apr 23 06:05 usr/local/libexec/git-core/git-remote-ftp
hrwxr-xr-x  0 0      0           0 Apr 23 06:05 usr/local/libexec/git-core/git-remote-ftps link to usr/local/libexec/git-core/git-remote-ftp
hrwxr-xr-x  0 0      0           0 Apr 23 06:05 usr/local/libexec/git-core/git-remote-http link to usr/local/libexec/git-core/git-remote-ftp
hrwxr-xr-x  0 0      0           0 Apr 23 06:05 usr/local/libexec/git-core/git-remote-https link to usr/local/libexec/git-core/git-remote-ftp
```

Extracting the real file from the final relevant layer gives the expected ELF binary:

```sh
tar -xOf /private/tmp/msb-rails-ghcr.tar \
  blobs/sha256/86b2b9428d498d933619be27c3315fec05bcf821cc8339a0680443048ddfa850 \
  | tar -xzOf - usr/local/libexec/git-core/git-remote-ftp \
  | sha256sum
```

Expected final-layer SHA-256:

```text
bbf187e4593504a727a0a1bb32e0d1bcbf889602b32e10b80995263566bc969d
```

Expected header:

```text
7f 45 4c 46
```

MSB does not produce that result for the remote helper paths.

## Determinism

Repeated fresh MSB runs produce the same corrupted hashes:

```text
ac50809cae093d1a24bb19c241b21a0cbfd550020b056c44e45a0e8875338814  /usr/local/libexec/git-core/git-remote-ftp
6baca4d42c764fb1b0ab3c1ac6c5fcd03e11963f2fcc0e888bc755894fa39153  /usr/local/libexec/git-core/git-remote-http
a5dbcaa15af2bc6b3d9babe0d09523b582fd7e8af045ce8183a254a054ab7cd0  /usr/local/libexec/git-core/git-remote-https
a33f9368615ef4a4bb7da146124560b849ad189975437400fe6aa518472124cb  /usr/local/libexec/git-core/git-remote-ftps
```

This makes the issue look like deterministic bad extraction or deterministic bad layer application, not a transient runtime mutation.

## Related Observation: Hardlink Groups

The larger `/usr/local/bin/git` hardlink group is also not preserved as one inode in MSB, but file contents remain correct:

```text
== /usr/local/bin/git
165730 -rwxr-xr-x 148 root root 19826288 Apr 23 04:05 /usr/local/bin/git
2593a8764a407670d5afedc2ac2bfe77da769b0576fb17d5281a69fbc166bb16
 7f 45 4c 46

== /usr/local/libexec/git-core/git-clone
206686 -rwxr-xr-x 28 root root 19826288 Apr 23 04:05 /usr/local/libexec/git-core/git-clone
2593a8764a407670d5afedc2ac2bfe77da769b0576fb17d5281a69fbc166bb16
 7f 45 4c 46
```

So the bug may not be simply "all hardlinks are corrupt". It may be a narrower issue involving a hardlink group that is overwritten or replaced by a later layer, or hardlink handling combined with OCI/Docker media-type conversion.

## Workarounds Verified

Use Debian Git directly:

```sh
/usr/bin/git clone --depth=1 https://github.com/xfiveco/skills.git /tmp/skills
```

This succeeds and clones:

```text
68c0eaf
```

Keep `/usr/local/bin/git`, but force Git to use Debian's intact helper directory:

```sh
GIT_EXEC_PATH=/usr/lib/git-core git clone --depth=1 https://github.com/xfiveco/skills.git /tmp/skills
```

This also succeeds and clones:

```text
68c0eaf
```

Runtime repair test as root:

```sh
rm -f \
  /usr/local/libexec/git-core/git-remote-http \
  /usr/local/libexec/git-core/git-remote-https \
  /usr/local/libexec/git-core/git-remote-ftp \
  /usr/local/libexec/git-core/git-remote-ftps

ln -s /usr/lib/git-core/git-remote-http /usr/local/libexec/git-core/git-remote-http
ln -s /usr/lib/git-core/git-remote-http /usr/local/libexec/git-core/git-remote-https
ln -s /usr/lib/git-core/git-remote-http /usr/local/libexec/git-core/git-remote-ftp
ln -s /usr/lib/git-core/git-remote-http /usr/local/libexec/git-core/git-remote-ftps
```

After this, default `git clone https://...` succeeds.

## Probable Root Cause

Most likely MSB bug:

```text
OCI layer extraction or overlay materialization mishandles tar hardlinks for files overwritten across layers.
```

Specific suspect:

```text
/usr/local/libexec/git-core/git-remote-ftp
/usr/local/libexec/git-core/git-remote-http
/usr/local/libexec/git-core/git-remote-https
/usr/local/libexec/git-core/git-remote-ftps
```

These should be one hardlinked ELF binary in the final rootfs. In MSB they become separate regular files with deterministic corrupted contents.

## Suggested MSB Debugging Angles

1. Inspect layer application logic for tar hardlink entries (`typeflag = '1'`).
2. Verify behavior when a layer overwrites an existing hardlink group from an earlier layer.
3. Verify whether hardlink targets are resolved against:
   - current layer only
   - accumulated rootfs
   - final merged filesystem
4. Check whether hardlink copy-up accidentally writes from an uninitialized buffer or wrong offset.
5. Compare final rootfs hashes after extraction against Docker/containerd extraction for hardlinked files.
6. Add a fixture image with:
   - one real binary file
   - several hardlinks to it
   - a later layer replacing that same real file and hardlinks
7. Add validation that hardlinked paths have identical hashes after unpack.

## Short Repro Script For MSB Maintainers

```sh
set -eu

IMAGE=ghcr.io/rails/devcontainer/images/ruby:2.3.1-3.4.9

msb run --pull always --timeout 3m "$IMAGE" -- sh -lc '
  set -eu
  echo "Git versions:"
  /usr/local/bin/git --version
  /usr/bin/git --version

  echo
  echo "Remote helper hashes:"
  sha256sum \
    /usr/local/libexec/git-core/git-remote-ftp \
    /usr/local/libexec/git-core/git-remote-http \
    /usr/local/libexec/git-core/git-remote-https \
    /usr/local/libexec/git-core/git-remote-ftps

  echo
  echo "Remote helper headers:"
  for p in \
    /usr/local/libexec/git-core/git-remote-ftp \
    /usr/local/libexec/git-core/git-remote-http \
    /usr/local/libexec/git-core/git-remote-https \
    /usr/local/libexec/git-core/git-remote-ftps
  do
    echo "$p"
    head -c 16 "$p" | od -An -tx1
  done

  echo
  echo "Default git clone, expected to fail in affected MSB:"
  rm -rf /tmp/skills
  git clone --depth=1 https://github.com/xfiveco/skills.git /tmp/skills
'
```

Expected broken MSB hashes:

```text
ac50809cae093d1a24bb19c241b21a0cbfd550020b056c44e45a0e8875338814  /usr/local/libexec/git-core/git-remote-ftp
6baca4d42c764fb1b0ab3c1ac6c5fcd03e11963f2fcc0e888bc755894fa39153  /usr/local/libexec/git-core/git-remote-http
a5dbcaa15af2bc6b3d9babe0d09523b582fd7e8af045ce8183a254a054ab7cd0  /usr/local/libexec/git-core/git-remote-https
a33f9368615ef4a4bb7da146124560b849ad189975437400fe6aa518472124cb  /usr/local/libexec/git-core/git-remote-ftps
```

Expected correct Docker hash for all four helpers:

```text
bbf187e4593504a727a0a1bb32e0d1bcbf889602b32e10b80995263566bc969d
```

