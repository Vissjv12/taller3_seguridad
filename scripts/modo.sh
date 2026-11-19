#!/bin/bash
# =====================================================================
#  Cambia el modo de trabajo. Solo configura; después ejecuten iniciar.sh.
#
#   scripts/modo.sh casa              Un solo PC (en casa). Todo en 127.0.0.1:
#                                     el servidor no es visible desde la red.
#   scripts/modo.sh clase [IP_PC1]    PC 1 en clase: detecta su IP en la red
#                                     (o se la pasan) y la publica.
#   scripts/modo.sh cliente IP_PC1    PC 2 en clase: solo apunta mail.lab.test
#                                     a la IP del PC 1 (no levanta contenedores).
#   scripts/modo.sh estado            Muestra la configuración actual.
#
#  Modifica .env y la línea de mail.lab.test en /etc/hosts (pide sudo).
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

ip_valida() { [[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; }

poner_hosts() {  # poner_hosts IP
  local tmp; tmp=$(mktemp)
  grep -v 'mail\.lab\.test' /etc/hosts > "$tmp" || true
  echo "$1  mail.lab.test  # taller3" >> "$tmp"
  sudo cp "$tmp" /etc/hosts; rm -f "$tmp"
  echo "/etc/hosts: mail.lab.test -> $1"
}

escribir_env() {  # escribir_env MODO LAB_IP
  cat > .env <<EOF
# Generado por scripts/modo.sh $1 ($(date '+%Y-%m-%d %H:%M'))
MODO=$1
# IP donde se publican 25/587/993 y única IP autorizada por el SPF de lab.test
LAB_IP=$2
EOF
  chmod 600 .env
  echo ".env: MODO=$1  LAB_IP=$2"
}

case "${1:-estado}" in
  casa)
    escribir_env casa 127.0.0.1
    poner_hosts 127.0.0.1
    echo; echo "Siguiente paso: scripts/iniciar.sh"
    ;;

  clase)
    DETECTADA=$(ip -4 route get 1.1.1.1 2>/dev/null | grep -oP 'src \K[0-9.]+' || true)
    read -r -p "IP de ESTE PC (PC 1) en la red de clase [${DETECTADA:-?}]: " LIP
    LIP=${LIP:-$DETECTADA}
    ip_valida "$LIP" || { echo "IP no válida: '$LIP'"; exit 1; }
    escribir_env clase "$LIP"
    poner_hosts "$LIP"
    echo; echo "Siguiente paso: scripts/iniciar.sh"
    ;;

  cliente)
    P1=${2:-}
    [ -n "$P1" ] || read -r -p "IP del PC 1 (servidor): " P1
    ip_valida "$P1" || { echo "IP no válida: '$P1'"; exit 1; }
    poner_hosts "$P1"
    echo
    echo "Siguientes pasos en este PC (PC 2):"
    echo "  1. Traer la CA del PC 1:  scp USUARIO@$P1:RUTA/taller3_seguridad/certs/ca.crt certs/"
    echo "  2. Comprobar:             scripts/comprobar-conexion.sh"
    echo "  3. Importar certs/ca.crt en Thunderbird (si es la primera vez con esta CA)"
    ;;

  estado)
    if [ -f .env ]; then grep -E '^(MODO|LAB_IP)=' .env; else echo "Sin .env (ejecuten modo.sh casa o modo.sh clase)"; fi
    echo "/etc/hosts: $(grep 'mail\.lab\.test' /etc/hosts || echo '(sin entrada para mail.lab.test)')"
    ;;

  *) sed -n '3,14p' "$0"; exit 2 ;;
esac
