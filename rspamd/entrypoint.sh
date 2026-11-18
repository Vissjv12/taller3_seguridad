#!/bin/bash
set -euo pipefail

KEY_SRC=/run/lab-dkim/taller3.key
KEY_DST=/var/lib/rspamd/dkim/lab.test.taller3.key

if [ ! -f "$KEY_SRC" ]; then
  echo "ERROR: falta secrets/dkim/taller3.key. Ejecuta primero scripts/crear-dkim.sh"
  echo "(si Docker creó una carpeta vacía con ese nombre, bórrala: rm -r secrets/dkim/taller3.key)"
  exit 1
fi

# Clave DKIM legible solo por el usuario de Rspamd
install -d -m 0750 -o _rspamd -g _rspamd /var/lib/rspamd/dkim
install -m 0600 -o _rspamd -g _rspamd "$KEY_SRC" "$KEY_DST"

echo "=== Versión ==="
rspamd --version | head -1
echo "=== Validando configuración ==="
rspamadm configtest

exec rspamd -f -u _rspamd -g _rspamd
