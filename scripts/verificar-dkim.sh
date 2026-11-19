#!/bin/bash
# =====================================================================
#  PC 1: evidencia DKIM. Toma el último correo FIRMADO del buzón indicado
#  y lo pasa por Rspamd dos veces: intacto y con el cuerpo alterado.
#    intacto  -> R_DKIM_ALLOW  -> DMARC pasa aunque SPF falle
#    alterado -> R_DKIM_REJECT -> sin SPF ni DKIM válidos, DMARC rechaza
#  Se analiza como si llegara desde 192.0.2.10 (IP de documentación,
#  no autorizada por SPF): así se ve que DKIM por sí solo sostiene DMARC.
#  Uso: scripts/verificar-dkim.sh [pedro|ana]
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
U=${1:-pedro}
case "$U" in ana|pedro) ;; *) echo "Usuario no válido: $U (use ana o pedro)"; exit 2 ;; esac
IP_PRUEBA=192.0.2.10
OUT=evidencias/dkim-$(date +%Y%m%d-%H%M%S)
mkdir -p "$OUT"

DIR=/var/mail/vhosts/lab.test/$U/Maildir
ARCH=$(docker exec mail-lab bash -c "grep -l '^DKIM-Signature' $DIR/new/* $DIR/cur/* 2>/dev/null | xargs -r ls -t | head -1")
[ -n "$ARCH" ] || { echo "No hay correos firmados en el buzón de $U. Envíen uno desde Thunderbird (587)."; exit 1; }

docker exec mail-lab cat "$ARCH" > "$OUT/intacto.eml"
{ cat "$OUT/intacto.eml"; printf 'Linea agregada por un intermediario.\n'; } > "$OUT/alterado.eml"

echo "Firma del mensaje: $(grep -m1 -oE 'd=[^;]+; s=[^;]+' "$OUT/intacto.eml")"
echo
for m in intacto alterado; do
  echo "=== Mensaje $m (analizado desde $IP_PRUEBA) ==="
  docker exec -i rspamd-lab rspamc --ip "$IP_PRUEBA" < "$OUT/$m.eml" > "$OUT/$m-rspamc.txt"
  grep -E "Action|R_DKIM|DMARC_POLICY|R_SPF" "$OUT/$m-rspamc.txt"
  echo
done
echo "Evidencias en $OUT/"
