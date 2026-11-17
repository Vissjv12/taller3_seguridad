# Imagen propia: Debian 12 + paquetes oficiales.
# No usamos imágenes "todo en uno" para poder mostrar y explicar la configuración.
FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN echo "postfix postfix/main_mailer_type select No configuration" | debconf-set-selections \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      postfix dovecot-core dovecot-imapd dovecot-lmtpd \
      ca-certificates openssl procps \
 && rm -rf /var/lib/apt/lists/*

# Usuario dueño de los buzones virtuales
RUN groupadd -g 5000 vmail \
 && useradd -u 5000 -g vmail -d /var/mail/vhosts -s /usr/sbin/nologin vmail \
 && mkdir -p /var/mail/vhosts /etc/ssl/lab/private \
 && (test -f /usr/share/dovecot/dh.pem || openssl dhparam -out /usr/share/dovecot/dh.pem 2048)

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

EXPOSE 25 587 993
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
