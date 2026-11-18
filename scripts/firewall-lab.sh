#!/bin/bash
# =====================================================================
#  PC 1: reglas de firewall del laboratorio (sudo). Lo llama iniciar.sh.
#
#  ufw NO filtra los puertos que publica Docker (Docker inserta sus reglas
#  antes que las de ufw). Por eso se usa la cadena DOCKER-USER.
#
#   1. Ningún contenedor puede ABRIR conexiones hacia fuera de la red del
#      laboratorio (las respuestas a los clientes siguen funcionando).
#   2. Modo clase: el puerto 25 solo acepta conexiones desde PC2_IP.
#      Modo casa: no hace falta (los puertos solo existen en 127.0.0.1).
#
#  Se puede repetir sin duplicar reglas. Si PC2_IP cambia, la regla vieja
#  se reemplaza. Las reglas se pierden al reiniciar Docker o el equipo.
#  Uso: sudo scripts/firewall-lab.sh [quitar]
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

[ "$(id -u)" -eq 0 ] || { echo "Ejecutar con sudo"; exit 1; }
[ -f .env ] || { echo "Falta .env (scripts/modo.sh)"; exit 1; }
PC2_IP=$(grep -E '^PC2_IP=' .env | cut -d= -f2 | tr -d ' "' || true)

SUBRED=172.30.53.0/24
MAIL=172.30.53.10
iptables -N DOCKER-USER 2>/dev/null || true

# Quitar reglas anteriores del laboratorio (salida y puerto 25)
quitar_todo() {
  local reglas
  reglas=$(iptables -S DOCKER-USER | grep -E -- "-s $SUBRED ! -d $SUBRED|-d $MAIL/32 .*--dport 25" || true)
  [ -z "$reglas" ] && return 0
  echo "$reglas" | sed 's/^-A /-D /' | while read -r r; do eval iptables "$r"; done
}

quitar_todo
if [ "${1:-}" = quitar ]; then echo "Reglas del laboratorio retiradas."; exit 0; fi

iptables -I DOCKER-USER -s "$SUBRED" ! -d "$SUBRED" -m conntrack --ctstate NEW -j REJECT
if [ -n "$PC2_IP" ]; then
  iptables -I DOCKER-USER -d "$MAIL" -p tcp --dport 25 ! -s "$PC2_IP" -m conntrack --ctstate NEW -j REJECT
  echo "Puerto 25: solo desde el PC 2 ($PC2_IP)."
else
  echo "Puerto 25: modo casa, solo accesible en 127.0.0.1."
fi
echo "Salida a Internet de los contenedores: bloqueada."

if docker exec mail-lab bash -c 'timeout 4 bash -c "</dev/tcp/1.1.1.1/25"' 2>/dev/null; then
  echo "❌ ATENCIÓN: el contenedor PUEDE abrir conexiones hacia fuera"; exit 1
else
  echo "✅ Comprobado: el contenedor no puede abrir conexiones hacia fuera"
fi
