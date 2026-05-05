FROM mcr.microsoft.com/devcontainers/ruby:4.0-trixie

ARG DEBIAN_FRONTEND=noninteractive

# Install PostgreSQL and systemd.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dbus \
        postgresql \
        postgresql-contrib \
        systemd \
        systemd-sysv \
    && rm -rf /var/lib/apt/lists/*

# Install Tailscale using the official script.
RUN curl -fsSL https://tailscale.com/install.sh | sh \
    && rm -f /usr/local/bin/systemctl \
    && /usr/bin/systemctl enable postgresql tailscaled \
    && rm -rf /var/lib/apt/lists/*
