FROM mcr.microsoft.com/devcontainers/ruby:4.0-trixie

ARG DEBIAN_FRONTEND=noninteractive

COPY tailscale-up-if-authkey /usr/local/bin/tailscale-up-if-authkey
COPY tailscale-up-if-authkey.service /etc/systemd/system/tailscale-up-if-authkey.service

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

# Install Tailscale using the official script.
RUN curl -fsSL https://tailscale.com/install.sh | sh \
    && rm -f /usr/local/bin/systemctl \
    && chmod +x /usr/local/bin/tailscale-up-if-authkey \
    && /usr/bin/systemctl enable postgresql tailscaled tailscale-up-if-authkey \
    && rm -rf /var/lib/apt/lists/*
