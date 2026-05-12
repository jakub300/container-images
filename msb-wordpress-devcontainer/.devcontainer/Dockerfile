FROM wordpress:php8.4-apache

ARG DEBIAN_FRONTEND=noninteractive
ENV PHPIZE_DEPS="autoconf dpkg-dev file g++ gcc libc-dev make pkg-config re2c"

# Install MariaDB, tmux, and systemd.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dbus \
        mariadb-server \
        systemd \
        systemd-sysv \
        tmux \
    && rm -rf /var/lib/apt/lists/*

COPY --from=shared msb-services/bin/custom-mariadb-configure-defaults /usr/local/bin/
COPY --from=shared msb-services/bin/custom-apache-set-document-root /usr/local/bin/
COPY --from=shared msb-services/systemd/custom-mariadb-configure-defaults.service /etc/systemd/system/
COPY --from=shared msb-services/sysctl/*.conf /etc/sysctl.d/
COPY .devcontainer/docker-php-entrypoint /usr/local/bin/docker-php-entrypoint

# Install Tailscale using the official script.
# Mask units that hang in msb: hvc0 getty waits forever; modules-load is unsupported.
RUN curl -fsSL https://tailscale.com/install.sh | sh \
    && rm -f /usr/local/bin/systemctl \
    && chmod +x /usr/local/bin/custom-* /usr/local/bin/docker-php-entrypoint \
    && /usr/bin/systemctl enable apache2 mariadb /etc/systemd/system/custom-*.service \
    && /usr/bin/systemctl mask serial-getty@hvc0.service systemd-modules-load.service \
    && mkdir -p /workspaces \
    && chown 1000:1000 /workspaces \
    && printf 'ServerName localhost\n' > /etc/apache2/conf-available/custom-server-name.conf \
    && rm -f /var/log/apache2/access.log /var/log/apache2/error.log /var/log/apache2/other_vhosts_access.log \
    && touch /var/log/apache2/access.log /var/log/apache2/error.log /var/log/apache2/other_vhosts_access.log \
    && chown -R 1000:1000 /var/log/apache2 /var/run/apache2 /var/lock/apache2 \
    && custom-apache-set-document-root /workspaces \
    && a2enconf custom-server-name \
    && a2enmod rewrite \
    && sed -ri 's!^: \$\{APACHE_RUN_USER:=.*\}!: ${APACHE_RUN_USER:=vscode}!' /etc/apache2/envvars \
    && sed -ri 's!^: \$\{APACHE_RUN_GROUP:=.*\}!: ${APACHE_RUN_GROUP:=vscode}!' /etc/apache2/envvars \
    && rm -rf /var/lib/apt/lists/*

USER vscode
WORKDIR /workspaces
ENTRYPOINT ["docker-php-entrypoint"]
CMD ["apache2-foreground"]
