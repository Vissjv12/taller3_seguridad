#!/bin/bash
# Construye /var/cache/bind/db.lab.test a partir de la plantilla, la clave
# pública DKIM y el estado de DMARC (on/off). La usan el arranque y lab-dmarc.
set -euo pipefail

PLANTILLA=/etc/lab-dns/lab.test.zone.plantilla
DKIM_DIR=${DKIM_DIR:-/run/lab-dkim}
ESTADO=/var/cache/bind/dmarc.estado
ZONA=/var/cache/bind/db.lab.test

: "${LAB_IP:?Falta LAB_IP (archivo .env)}"
[ -f "$ESTADO" ] || echo on > "$ESTADO"

{
  sed -e "s/__SERIAL__/$(date +%s)/" -e "s/__LAB_IP__/$LAB_IP/g" "$PLANTILLA"
  echo
  echo "; --- DKIM: claves públicas (crear-dkim.sh / rotar-dkim.sh)."
  echo ";     Durante una rotación se publican la antigua y la nueva a la vez."
  for t in "$DKIM_DIR"/*.txt; do cat "$t"; echo; done
  if [ "$(cat "$ESTADO")" = "on" ]; then
    echo "; --- DMARC: si SPF y DKIM no validan alineados con el From:, rechazar."
    echo "; Sin rua=: no hay salida a Internet para enviar reportes."
    echo '_dmarc IN TXT "v=DMARC1; p=reject; adkim=s; aspf=s"'
  else
    echo "; --- DMARC DESACTIVADO (demo 'antes'). Activar con: scripts/dmarc.sh on"
  fi
} > "$ZONA.tmp"

named-checkzone -q lab.test "$ZONA.tmp" || { named-checkzone lab.test "$ZONA.tmp"; exit 1; }
mv "$ZONA.tmp" "$ZONA"
chown bind:bind "$ZONA" "$ESTADO"
