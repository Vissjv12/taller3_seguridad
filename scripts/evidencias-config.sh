#!/bin/bash
# PC 1: guarda versiones y configuración efectiva (sin secretos) para el entregable.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p evidencias
OUT=evidencias/config-efectiva-$(date +%Y%m%d-%H%M).txt
{
  echo "### Fecha: $(date)"
  echo "### Versiones"
  docker exec mail-lab postconf -h mail_version | sed 's/^/Postfix /'
  docker exec mail-lab dovecot --version | sed 's/^/Dovecot /'
  docker exec mail-lab openssl version
  docker exec rspamd-lab rspamd --version | head -1
  docker exec dns-lab named -v
  echo
  echo "### postconf -n (main.cf efectivo)"
  docker exec mail-lab postconf -n
  echo
  echo "### postconf -M (servicios de master.cf)"
  docker exec mail-lab postconf -M
  echo
  echo "### postconf -P (opciones -o de submission)"
  docker exec mail-lab postconf -P | grep '^submission'
  echo
  echo "### doveconf -n (Dovecot efectivo; doveconf oculta las claves)"
  docker exec mail-lab doveconf -n
  echo
  echo "### Certificado del servidor"
  openssl x509 -in certs/mail.crt -noout -subject -issuer -dates -ext subjectAltName,extendedKeyUsage
  echo
  echo "### DNS: registros de lab.test publicados por bind9"
  for r in "TXT lab.test" "TXT _dmarc.lab.test" "TXT taller3._domainkey.lab.test" "MX lab.test" "A mail.lab.test"; do
    echo "--- $r"; docker exec dns-lab dig @127.0.0.1 +short $r
  done
  echo
  echo "### Rspamd: módulos clave"
  docker exec rspamd-lab rspamadm configdump dkim_signing
  docker exec rspamd-lab rspamadm configdump dmarc
  docker exec rspamd-lab rspamadm configdump options | grep -A4 local_addrs
} > "$OUT" 2>&1
echo "Guardado en $OUT"
