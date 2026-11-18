#!/bin/bash
set -euo pipefail

if ! ls /run/lab-dkim/*.txt >/dev/null 2>&1; then
  echo "ERROR: no hay registros DKIM en dkim-publica/. Ejecuta scripts/iniciar.sh o scripts/crear-dkim.sh"
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
