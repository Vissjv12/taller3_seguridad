#!/bin/bash
# =====================================================================
#  PC 1: rotación de la clave DKIM en dos pasos (como en producción).
#
#  Paso 1:  scripts/rotar-dkim.sh
#     Crea el selector siguiente (taller3-2, taller3-3...), lo publica en el
#     DNS JUNTO al anterior y pasa a firmar con el nuevo. Los correos ya
#     firmados con la clave vieja siguen verificándose.
#
#  Paso 2:  scripts/rotar-dkim.sh retirar
#     Cuando ya no quedan correos "en tránsito" con la firma vieja, retira
#     del DNS los selectores antiguos y destruye sus claves privadas.
#
#  Ver estado: scripts/rotar-dkim.sh estado
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f dkim-publica/activo ] || { echo "No hay claves DKIM: ejecuten scripts/crear-dkim.sh"; exit 1; }
ACTIVO=$(cat dkim-publica/activo)

recargar() {
  if docker ps --format '{{.Names}}' | grep -qx dns-lab; then
    docker compose exec -T dns lab-recargar >/dev/null
    docker compose restart rspamd >/dev/null
    echo "DNS recargado y Rspamd reiniciado."
  fi
}

estado() {
  echo "Selector activo (firma): $(cat dkim-publica/activo)"
  echo "Publicados en el DNS:    $(ls dkim-publica/*.txt | xargs -n1 basename | sed 's/\.txt$//' | tr '\n' ' ')"
  if docker ps --format '{{.Names}}' | grep -qx dns-lab; then
    for t in dkim-publica/*.txt; do
      s=$(basename "$t" .txt)
      r=$(docker compose exec -T dns dig @127.0.0.1 +short TXT "$s._domainkey.lab.test" | cut -c1-40)
      echo "  $s._domainkey.lab.test -> ${r:-(no responde)}..."
    done
  fi
}

case "${1:-rotar}" in
  rotar)
    N=$(ls dkim-publica/taller3-*.txt | sed -E 's/.*taller3-([0-9]+)\.txt/\1/' | sort -n | tail -1)
    NUEVO=taller3-$((N+1))
    "$(dirname "$0")/lib-dkim.sh" generar "$NUEVO"
    echo "$NUEVO" > dkim-publica/activo
    recargar
    echo
    echo "Rotación (paso 1): ahora se firma con $NUEVO; $ACTIVO sigue publicado."
    estado
    echo
    echo "Cuando terminen de comprobar, ejecuten: scripts/rotar-dkim.sh retirar"
    ;;
  retirar)
    for t in dkim-publica/taller3-*.txt; do
      s=$(basename "$t" .txt)
      [ "$s" = "$ACTIVO" ] && continue
      rm -f "$t"
      if [ -f "secrets/dkim/$s.key" ]; then
        shred -u "secrets/dkim/$s.key" 2>/dev/null || rm -f "secrets/dkim/$s.key"
      fi
      echo "Retirado $s (registro DNS y clave privada destruida)"
    done
    recargar
    estado
    ;;
  estado) estado ;;
  *) echo "Uso: rotar-dkim.sh [rotar|retirar|estado]"; exit 2 ;;
esac
