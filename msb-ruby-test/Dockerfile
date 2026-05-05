FROM mcr.microsoft.com/devcontainers/ruby:4.0-trixie

ARG DEBIAN_FRONTEND=noninteractive

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

COPY shared/msb-services/bin/* /usr/local/bin/
COPY shared/msb-services/systemd/*.service /etc/systemd/system/
COPY shared/msb-services/sysctl/*.conf /etc/sysctl.d/

# Install Tailscale using the official script.
RUN curl -fsSL https://tailscale.com/install.sh | sh \
    && rm -f /usr/local/bin/systemctl \
    && chmod +x /usr/local/bin/custom-* \
    && /usr/bin/systemctl enable postgresql tailscaled /etc/systemd/system/custom-*.service \
    && rm -rf /var/lib/apt/lists/*
