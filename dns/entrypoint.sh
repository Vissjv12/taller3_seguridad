#!/bin/bash
set -euo pipefail

if [ ! -f /run/lab-dkim/taller3.txt ]; then
  echo "ERROR: falta secrets/dkim/taller3.txt. Ejecuta primero scripts/crear-dkim.sh"
  echo "(si Docker creó una carpeta vacía con ese nombre, bórrala: rm -r secrets/dkim/taller3.txt)"
  exit 1
fi

[ -f /etc/bind/rndc.key ] || rndc-confgen -a -c /etc/bind/rndc.key
chown root:bind /etc/bind/rndc.key && chmod 640 /etc/bind/rndc.key

echo "=== Versión ==="
named -v

/usr/local/bin/generar-zona.sh
named-checkconf /etc/lab-dns/named.conf

echo "=== Zona lab.test generada ==="
grep -vE '^\s*;|^\s*$' /var/cache/bind/db.lab.test

# -g: primer plano, logs a la salida del contenedor
exec named -g -u bind -c /etc/lab-dns/named.conf
