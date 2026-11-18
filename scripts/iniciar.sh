#!/bin/bash
# =====================================================================
#  PC 1: deja el laboratorio funcionando con un solo comando.
#  Se puede ejecutar todas las veces que haga falta (no duplica nada):
#   1. Comprueba herramientas y el modo (.env)
#   2. Crea los secretos que falten (CA, certificado, contraseñas, DKIM)
#   3. Construye y levanta los contenedores, y espera a que estén sanos
#   4. Aplica el firewall del laboratorio (pide sudo)
#   5. Muestra el resumen y los pasos siguientes
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
S=$(dirname "$0")
VERDE=$'\e[32m'; ROJO=$'\e[31m'; NEGRITA=$'\e[1m'; NORMAL=$'\e[0m'
paso() { echo; echo "${NEGRITA}== $*${NORMAL}"; }
fallo() { echo "${ROJO}ERROR: $*${NORMAL}"; exit 1; }

paso "1/5 Comprobaciones"
for c in docker openssl; do command -v $c >/dev/null || fallo "falta '$c' (ver README, requisitos)"; done
docker compose version >/dev/null 2>&1 || fallo "falta Docker Compose v2 (paquete docker-compose-v2)"
docker info >/dev/null 2>&1 || fallo "Docker no responde. ¿Están en el grupo docker? (sudo usermod -aG docker \$USER y reiniciar sesión)"
[ -f .env ] || fallo "falta .env. Ejecuten primero: scripts/modo.sh casa  (o: scripts/modo.sh clase)"
set -a; . ./.env; set +a
echo "Modo: ${MODO:-?}   LAB_IP: $LAB_IP   PC2_IP: ${PC2_IP:-(ninguna)}   Perfiles: ${COMPOSE_PROFILES:-(ninguno)}"
chmod +x scripts/*.sh 2>/dev/null || true

paso "2/5 Secretos (solo se crean los que faltan)"
"$S/crear-ca.sh"
[ -f secrets/mail/mail.key ] && [ -f certs/mail.crt ] || "$S/renovar-certificado.sh" --sin-reinicio
[ -f secrets/mail/users.passwd ] || "$S/crear-usuarios.sh"
"$S/crear-dkim.sh"
echo "CA: $(openssl x509 -in certs/ca.crt -noout -subject | sed 's/.*CN *= *//')"
echo "Certificado del servidor válido hasta: $(openssl x509 -in certs/mail.crt -noout -enddate | cut -d= -f2)"

paso "3/5 Contenedores (la primera vez tarda varios minutos)"
if ! docker compose up -d --build --wait --wait-timeout 300; then
  docker compose ps
  fallo "algún contenedor no arrancó. Revisen: docker compose logs <servicio>"
fi
docker compose ps --format 'table {{.Name}}\t{{.Status}}'

paso "4/5 Firewall del laboratorio (pide la contraseña de sudo)"
sudo "$S/firewall-lab.sh"

paso "5/5 Resumen"
"$S/dmarc.sh" estado
"$S/rotar-dkim.sh" estado 2>/dev/null | head -2 || true
echo
echo "${VERDE}Laboratorio listo en modo ${MODO:-?}.${NORMAL}"
if [ "${MODO:-}" = clase ]; then
  cat <<EOF

En el PC 2:
  scripts/modo.sh cliente $LAB_IP
  scp $(whoami)@$LAB_IP:$(pwd)/certs/ca.crt certs/      (o copiar certs/ca.crt con un USB)
  scripts/comprobar-conexion.sh
  LAB_USER=ana@lab.test scripts/probar.sh
EOF
else
  cat <<EOF

Siguientes pasos en este mismo PC:
  scripts/comprobar-conexion.sh
  LAB_USER=ana@lab.test scripts/probar.sh
EOF
fi
