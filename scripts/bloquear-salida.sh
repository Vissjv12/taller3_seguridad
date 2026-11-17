#!/bin/bash
# Bloquea cualquier conexión NUEVA desde la red del laboratorio hacia fuera.
# Las respuestas a los clientes (conexiones ya establecidas) siguen funcionando.
# Ejecutar en el PC 1 con sudo, DESPUÉS de "docker compose up -d".
# La regla se pierde al reiniciar Docker o el equipo: volver a ejecutarla.
set -euo pipefail
SUBRED=172.30.53.0/24

if iptables -C DOCKER-USER -s "$SUBRED" ! -d "$SUBRED" -m conntrack --ctstate NEW -j REJECT 2>/dev/null; then
  echo "La regla ya existe."
else
  iptables -I DOCKER-USER -s "$SUBRED" ! -d "$SUBRED" -m conntrack --ctstate NEW -j REJECT
  echo "Salida bloqueada para $SUBRED."
fi
iptables -L DOCKER-USER -n -v | head -5

echo
echo "Comprobación (debe FALLAR):"
docker exec mail-lab bash -c 'timeout 5 bash -c "</dev/tcp/1.1.1.1/25"' \
  && echo "❌ El contenedor PUEDE salir" || echo "✅ El contenedor no puede abrir conexiones hacia fuera"
