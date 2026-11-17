#!/bin/bash
# Guarda versiones y configuración efectiva (sin secretos) para el entregable.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=evidencias/config-efectiva-$(date +%Y%m%d-%H%M).txt
{
  echo "### Fecha: $(date)"
  echo "### Versiones"
  docker exec mail-lab postconf -h mail_version | sed 's/^/Postfix /'
  docker exec mail-lab dovecot --version | sed 's/^/Dovecot /'
  docker exec mail-lab openssl version
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
} > "$OUT" 2>&1
echo "Guardado en $OUT"
