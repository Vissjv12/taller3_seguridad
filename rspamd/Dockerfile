# Rspamd de laboratorio: Debian 12 + paquete oficial de Debian (sin Redis)
FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends rspamd ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /run/rspamd && chown _rspamd:_rspamd /run/rspamd

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

EXPOSE 11332
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
