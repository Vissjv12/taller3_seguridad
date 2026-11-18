#!/bin/bash
# =====================================================================
#  PC 1: evidencia DKIM. Toma el último correo FIRMADO del buzón indicado
#  y lo pasa por Rspamd dos veces: intacto y con el cuerpo alterado.
#    intacto  -> R_DKIM_ALLOW   (firma válida)
#    alterado -> R_DKIM_REJECT  (la firma ya no coincide)
#  Hace falta porque el correo interno no se reverifica al entregarse.
#  Uso: scripts/verificar-dkim.sh [pedro|ana]
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
U=${1:-pedro}
LAB_IP=$(grep -E '^LAB_IP=' .env | cut -d= -f2 | tr -d ' "')
OUT=evidencias/dkim-$(date +%Y%m%d-%H%M%S)
mkdir -p "$OUT"

DIR=/var/mail/vhosts/lab.test/$U/Maildir
ARCH=$(docker exec mail-lab bash -c "grep -l '^DKIM-Signature' $DIR/new/* $DIR/cur/* 2>/dev/null | xargs -r ls -t | head -1")
[ -n "$ARCH" ] || { echo "No hay correos firmados en el buzón de $U. Envíen uno desde Thunderbird por el 587."; exit 1; }

docker exec mail-lab cat "$ARCH" > "$OUT/intacto.eml"
# Alteración: se agrega una línea al cuerpo (como haría un intermediario)
{ cat "$OUT/intacto.eml"; printf 'Linea agregada por un intermediario.\n'; } > "$OUT/alterado.eml"

# --ip LAB_IP: se analiza como si llegara desde el servidor autorizado de lab.test
for m in intacto alterado; do
  echo "=== Mensaje $m ==="
  docker exec -i rspamd-lab rspamc --ip "$LAB_IP" < "$OUT/$m.eml" | tee "$OUT/$m-rspamc.txt" \
    | grep -E "Action|DKIM|DMARC"
  echo
done

grep -A4 -m1 '^DKIM-Signature' "$OUT/intacto.eml" > "$OUT/cabecera-dkim.txt"
echo "Evidencias en $OUT/"
