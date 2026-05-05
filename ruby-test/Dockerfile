FROM mcr.microsoft.com/devcontainers/ruby:4.0-trixie

ARG DEBIAN_FRONTEND=noninteractive

# Install PostgreSQL server packages.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        postgresql \
        postgresql-contrib \
    && rm -rf /var/lib/apt/lists/*

# Install Tailscale using the official script.
RUN curl -fsSL https://tailscale.com/install.sh | sh \
    && rm -rf /var/lib/apt/lists/*
