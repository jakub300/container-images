FROM buildpack-deps:trixie-curl

ARG DEBIAN_FRONTEND=noninteractive
ARG MINIO_VERSION=RELEASE.2025-09-07T16-13-09Z
ARG MINIO_SHA256_AMD64=7c5bd8512c6e966455b1d198209358b2d191c77a83ab377c4073281065fb855f
ARG MINIO_SHA256_ARM64=5c83cd2cf151717ba0243f73e1c7802ff36e272b67144bdd7f1f7d684fd6f03d
ARG OVERMIND_VERSION=v2.5.1
ARG OVERMIND_SHA256_AMD64=a17159b8e97d13f3679a4e8fbc9d4747f82d5af9f6d32597b72821378b5d0b6f
ARG OVERMIND_SHA256_ARM64=42cb6d79c8adcf4c68dfb2ddf09e63a0803b023af5b17d42e05ccbfa4b86bee2
ARG TARGETARCH

USER root

# Match devcontainers/base user defaults before features run.
RUN groupadd --gid 1000 vscode \
    && useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash vscode

# Install core services and CLI tools.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bubblewrap \
        ca-certificates \
        curl \
        dbus \
        git \
        jq \
        postgresql \
        postgresql-contrib \
        redis-server \
        ripgrep \
        systemd \
        systemd-sysv \
        tmux \
    && rm -rf /var/lib/apt/lists/*

# Install small service binaries used by Rails apps.
RUN set -eux; \
    arch="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    case "${arch}" in \
        amd64) overmind_sha="${OVERMIND_SHA256_AMD64}"; minio_sha="${MINIO_SHA256_AMD64}" ;; \
        arm64) overmind_sha="${OVERMIND_SHA256_ARM64}"; minio_sha="${MINIO_SHA256_ARM64}" ;; \
        *) echo "unsupported arch: ${arch}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/overmind.gz "https://github.com/DarthSim/overmind/releases/download/${OVERMIND_VERSION}/overmind-${OVERMIND_VERSION}-linux-${arch}.gz"; \
    printf '%s  /tmp/overmind.gz\n' "${overmind_sha}" | sha256sum -c -; \
    gzip -dc /tmp/overmind.gz > /usr/local/bin/overmind; \
    chmod +x /usr/local/bin/overmind; \
    curl -fsSL -o /usr/local/bin/minio "https://github.com/minio/minio/releases/download/${MINIO_VERSION}/minio.linux-${arch}.${MINIO_VERSION}"; \
    printf '%s  /usr/local/bin/minio\n' "${minio_sha}" | sha256sum -c -; \
    chmod +x /usr/local/bin/minio; \
    rm -f /tmp/overmind.gz

COPY --from=shared msb-services/bin/custom-postgres-configure-defaults /usr/local/bin/
COPY --from=shared msb-services/systemd/custom-minio.service /etc/systemd/system/
COPY --from=shared msb-services/systemd/custom-postgres-configure-defaults.service /etc/systemd/system/
COPY --from=shared msb-services/sysctl/*.conf /etc/sysctl.d/

# Install Tailscale using the official script.
# Mask units that hang in msb: hvc0 getty waits forever; modules-load is unsupported.
RUN curl -fsSL https://tailscale.com/install.sh | sh \
    && rm -f /usr/local/bin/systemctl \
    && printf '%s\n' '' 'eval "$(mise activate --shims)"' >> /home/vscode/.profile \
    && chmod +x /usr/local/bin/custom-* \
    && mkdir -p /var/lib/minio \
    && chown vscode:vscode /var/lib/minio \
    && /usr/bin/systemctl enable postgresql redis-server custom-postgres-configure-defaults.service \
    && /usr/bin/systemctl mask serial-getty@hvc0.service systemd-modules-load.service \
    && mkdir -p /workspaces \
    && chown vscode:vscode /workspaces \
    && rm -rf /var/lib/apt/lists/*

USER vscode
WORKDIR /workspaces
