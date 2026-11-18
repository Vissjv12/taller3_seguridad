# DNS autoritativo de laboratorio: Debian 12 + bind9 oficial
FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends bind9 bind9-utils bind9-dnsutils \
 && rm -rf /var/lib/apt/lists/*

COPY generar-zona.sh /usr/local/bin/generar-zona.sh
COPY lab-dmarc       /usr/local/bin/lab-dmarc
COPY lab-recargar    /usr/local/bin/lab-recargar
COPY entrypoint.sh   /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/generar-zona.sh /usr/local/bin/lab-dmarc /usr/local/bin/lab-recargar /usr/local/bin/entrypoint.sh

EXPOSE 53/udp 53/tcp
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
