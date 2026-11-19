#!/bin/bash
# =====================================================================
#  PC 1: reglas de firewall del laboratorio (sudo). Lo llama iniciar.sh.
#
#  ufw NO filtra los puertos que publica Docker (Docker inserta sus reglas
#  antes que las de ufw). Por eso se usa la cadena DOCKER-USER.
#
#   1. Ningún contenedor puede ABRIR conexiones hacia fuera de la red del
#      laboratorio (las respuestas a los clientes siguen funcionando).
#   2. Solo el contenedor de correo puede hablar con el milter de Rspamd
#      (172.30.53.11:11332): el milter no autentica y firma DKIM.
#
#  El puerto 25 no se filtra por IP: en clase recibe correo de la red del
#  grupo y en casa se publica solo en 127.0.0.1. En un servidor real el 25
#  también va abierto; lo que defiende es SPF/DKIM/DMARC + Rspamd + límites.
#
#  Se puede repetir sin duplicar reglas: todas llevan la marca taller3-lab.
#  Las reglas se pierden al reiniciar Docker o el equipo; iniciar.sh las
#  vuelve a aplicar.
#  Uso: sudo scripts/firewall-lab.sh [quitar]
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

[ "$(id -u)" -eq 0 ] || { echo "Ejecutar con sudo"; exit 1; }
[ -f .env ] || { echo "Falta .env (scripts/modo.sh)"; exit 1; }

SUBRED=172.30.53.0/24
MAIL=172.30.53.10
RSPAMD=172.30.53.11
MARCA=taller3-lab
iptables -N DOCKER-USER 2>/dev/null || true

# Quitar reglas anteriores del laboratorio (salida y milter).
quitar_todo() {
  local reglas
  reglas=$(iptables -S DOCKER-USER \
    | grep -E -- "--comment $MARCA|-s $SUBRED ! -d $SUBRED|-d $RSPAMD/32 .*--dport 11332" \
    || true)
  [ -z "$reglas" ] && return 0
  echo "$reglas" | sed 's/^-A /-D /' | while read -r r; do eval iptables "$r"; done
}

comprobar() {  # comprobar "descripción" args...
  local que=$1; shift
  iptables -C DOCKER-USER "$@" 2>/dev/null || { echo "❌ No se pudo aplicar: $que"; exit 1; }
}

quitar_todo
if [ "${1:-}" = quitar ]; then echo "Reglas del laboratorio retiradas."; exit 0; fi

# 1. Salida de la red del laboratorio
R_SALIDA=(-s "$SUBRED" ! -d "$SUBRED" -m conntrack --ctstate NEW -m comment --comment "$MARCA" -j REJECT)
iptables -I DOCKER-USER "${R_SALIDA[@]}"

# 2. Milter de Rspamd, solo desde el contenedor de correo
R_MILTER=(-d "$RSPAMD" -p tcp --dport 11332 ! -s "$MAIL" -m conntrack --ctstate NEW -m comment --comment "$MARCA" -j REJECT)
iptables -I DOCKER-USER "${R_MILTER[@]}"

comprobar "bloqueo de salida de la red del laboratorio" "${R_SALIDA[@]}"
comprobar "milter 11332 solo desde $MAIL" "${R_MILTER[@]}"
echo "Salida a Internet de los contenedores: bloqueada."
echo "Milter 11332: solo accesible desde el contenedor de correo."
echo "Puerto 25: sin filtro por IP (red del grupo; en casa, solo 127.0.0.1)."

# Sondeo informativo: sin Internet, un timeout no distingue "bloqueado" de
# "inalcanzable"; la prueba real son las reglas comprobadas arriba.
if [ "$(docker inspect -f '{{.State.Running}}' mail-lab 2>/dev/null || echo false)" = true ]; then
  if docker exec mail-lab bash -c 'timeout 4 bash -c "</dev/tcp/1.1.1.1/443"' 2>/dev/null; then
    echo "❌ ATENCIÓN: el contenedor PUEDE abrir conexiones hacia fuera"; exit 1
  else
    echo "✅ El contenedor no abre conexiones hacia fuera (o no hay ruta a Internet)"
  fi
else
  echo "ℹ️  mail-lab no está corriendo: se omite el sondeo de salida."
fi
