FROM ghcr.io/rails/devcontainer/images/ruby:2.3.1-3.4.9

ARG DEBIAN_FRONTEND=noninteractive

USER root

# Install PostgreSQL and systemd.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dbus \
        jq \
        postgresql \
        postgresql-contrib \
        systemd \
        systemd-sysv \
    && rm -rf /var/lib/apt/lists/*

COPY --from=shared msb-services/bin/* /usr/local/bin/
COPY --from=shared msb-services/systemd/*.service /etc/systemd/system/
COPY --from=shared msb-services/sysctl/*.conf /etc/sysctl.d/

# Install Tailscale using the official script.
RUN curl -fsSL https://tailscale.com/install.sh | sh \
    && rm -f /usr/local/bin/systemctl \
    && chmod +x /usr/local/bin/custom-* \
    && /usr/bin/systemctl enable postgresql tailscaled /etc/systemd/system/custom-*.service \
    && mkdir -p /workspace \
    && chown vscode:vscode /workspace \
    && rm -rf /var/lib/apt/lists/*

USER vscode
WORKDIR /workspace
