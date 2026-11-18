#!/bin/bash
# =====================================================================
#  PC 1: reglas de firewall del laboratorio (ejecutar con sudo, DESPUÉS
#  de "docker compose up -d"). Reemplaza a bloquear-salida.sh.
#
#  IMPORTANTE: ufw NO filtra los puertos que publica Docker, porque Docker
#  inserta sus reglas antes que las de ufw. Por eso se usa la cadena
#  DOCKER-USER, que Docker evalúa primero para el tráfico de contenedores.
#
#  Reglas:
#   1. Ningún contenedor puede ABRIR conexiones hacia fuera de la red del
#      laboratorio (las respuestas a los clientes siguen funcionando).
#   2. El puerto 25 del servidor solo acepta conexiones desde el PC 2.
#
#  Las reglas se pierden al reiniciar Docker o el equipo: volver a ejecutar.
#  Uso: sudo scripts/firewall-lab.sh          (aplicar)
#       sudo scripts/firewall-lab.sh quitar   (retirar)
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

[ "$(id -u)" -eq 0 ] || { echo "Ejecutar con sudo"; exit 1; }
[ -f .env ] || { echo "Falta .env"; exit 1; }
PC2_IP=$(grep -E '^PC2_IP=' .env | cut -d= -f2 | tr -d ' "')
[ -n "$PC2_IP" ] || { echo "Define PC2_IP en .env"; exit 1; }

SUBRED=172.30.53.0/24
MAIL=172.30.53.10

R1=(-s "$SUBRED" ! -d "$SUBRED" -m conntrack --ctstate NEW -j REJECT)
R2=(-d "$MAIL" -p tcp --dport 25 ! -s "$PC2_IP" -m conntrack --ctstate NEW -j REJECT)

regla() {  # regla aplicar|quitar args...
  local accion=$1; shift
  if iptables -C DOCKER-USER "$@" 2>/dev/null; then
    [ "$accion" = quitar ] && iptables -D DOCKER-USER "$@"
  else
    [ "$accion" = aplicar ] && iptables -I DOCKER-USER "$@"
  fi
  return 0
}

if [ "${1:-}" = quitar ]; then
  regla quitar "${R1[@]}"; regla quitar "${R2[@]}"
  echo "Reglas retiradas."; exit 0
fi

regla aplicar "${R1[@]}"
regla aplicar "${R2[@]}"

echo "Reglas activas en DOCKER-USER:"
iptables -L DOCKER-USER -n --line-numbers | grep -E "REJECT|num"

echo
echo "Comprobación de salida (debe FALLAR):"
if docker exec mail-lab bash -c 'timeout 5 bash -c "</dev/tcp/1.1.1.1/25"' 2>/dev/null; then
  echo "❌ El contenedor PUEDE abrir conexiones hacia fuera"
else
  echo "✅ El contenedor no puede abrir conexiones hacia fuera"
fi
echo "Puerto 25: solo se acepta desde $PC2_IP (comprobarlo desde otro equipo o con probar.sh en el PC 2)."
