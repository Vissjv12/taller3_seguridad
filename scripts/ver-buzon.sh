#!/bin/bash
# Actividad 9: lo que ve el ADMINISTRADOR en el almacenamiento del servidor.
# Uso: scripts/ver-buzon.sh [pedro|ana]
set -euo pipefail
U=${1:-pedro}
case "$U" in ana|pedro) ;; *) echo "Usuario no válido: $U (use ana o pedro)"; exit 2 ;; esac
DIR=/var/mail/vhosts/lab.test/$U/Maildir

echo "=== Archivos en el buzón de $U ==="
docker exec mail-lab bash -c "ls -l $DIR/new $DIR/cur 2>/dev/null"
echo
echo "=== Último mensaje, tal como está guardado en disco ==="
docker exec mail-lab bash -c "ls -t $DIR/new/* $DIR/cur/* 2>/dev/null | head -1 | xargs cat"
echo
echo ">> Observen: el cuerpo está en claro y las cabeceras Received: indican"
echo ">> que llegó por TLS. TLS protegió el viaje, no el almacenamiento."
