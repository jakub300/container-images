FROM ghcr.io/rails/devcontainer/images/ruby:2.3.1-3.4.9

ARG DEBIAN_FRONTEND=noninteractive

USER root

# Install core services and CLI tools.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bubblewrap \
        ca-certificates \
        curl \
        dbus \
        jq \
        postgresql \
        postgresql-contrib \
        redis-server \
        ripgrep \
        systemd \
        systemd-sysv \
        tmux \
    && rm -rf /var/lib/apt/lists/*

COPY --from=shared msb-services/bin/custom-postgres-configure-defaults /usr/local/bin/
COPY --from=shared msb-services/systemd/custom-postgres-configure-defaults.service /etc/systemd/system/
COPY --from=shared msb-services/sysctl/*.conf /etc/sysctl.d/

# Install Tailscale using the official script.
# Mask units that hang in msb: hvc0 getty waits forever; modules-load is unsupported.
RUN curl -fsSL https://tailscale.com/install.sh | sh \
    && rm -f /usr/local/bin/systemctl \
    && chmod +x /usr/local/bin/custom-* \
    && /usr/bin/systemctl enable postgresql redis-server /etc/systemd/system/custom-*.service \
    && /usr/bin/systemctl mask serial-getty@hvc0.service systemd-modules-load.service \
    && mkdir -p /workspaces \
    && chown vscode:vscode /workspaces \
    && rm -rf /var/lib/apt/lists/*

USER vscode
WORKDIR /workspaces
