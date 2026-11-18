#!/bin/bash
# =====================================================================
#  PC 1: crea o cambia las contraseñas de ana y pedro (rotación de credenciales).
#  Se guardan como hash SHA512-CRYPT en secrets/mail/users.passwd.
#  Uso: scripts/crear-usuarios.sh
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
mkdir -p secrets/mail
SALIDA=secrets/mail/users.passwd
[ -d "$SALIDA" ] && rmdir "$SALIDA"   # carpeta creada por Docker

TMP=$(mktemp)
for usuario in ana@lab.test pedro@lab.test; do
  # Opcional, para automatizar: CLAVE_ANA=... CLAVE_PEDRO=... scripts/crear-usuarios.sh
  var=CLAVE_$(echo "${usuario%@*}" | tr a-z A-Z)
  if [ -n "${!var:-}" ]; then
    p1=${!var}
    [ ${#p1} -ge 10 ] || { echo "$var debe tener al menos 10 caracteres"; exit 1; }
    echo "${usuario}:{SHA512-CRYPT}$(printf '%s' "$p1" | openssl passwd -6 -stdin)" >> "$TMP"
    continue
  fi
  while true; do
    read -r -s -p "Contraseña para $usuario: " p1; echo
    read -r -s -p "Repítela: " p2; echo
    [ "$p1" = "$p2" ] && [ ${#p1} -ge 10 ] && break
    echo "No coinciden o tienen menos de 10 caracteres. Intenta de nuevo."
  done
  echo "${usuario}:{SHA512-CRYPT}$(printf '%s' "$p1" | openssl passwd -6 -stdin)" >> "$TMP"
done
install -m 600 "$TMP" "$SALIDA"; rm -f "$TMP"
echo "Guardado en $SALIDA (fuera de Git)."

if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx mail-lab; then
  docker compose restart mail >/dev/null && echo "Contenedor mail reiniciado: contraseñas nuevas activas."
  echo "Actualicen la contraseña guardada en Thunderbird."
fi
