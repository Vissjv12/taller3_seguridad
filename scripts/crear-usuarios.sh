#!/bin/bash
# Crea secrets/users.passwd con las cuentas del laboratorio.
# Las contraseñas se piden por teclado y se guardan como hash SHA512-CRYPT.
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
mkdir -p secrets

SALIDA=secrets/users.passwd
: > "$SALIDA"

for usuario in ana@lab.test pedro@lab.test; do
  while true; do
    read -r -s -p "Contraseña para $usuario: " p1; echo
    read -r -s -p "Repítela: " p2; echo
    [ "$p1" = "$p2" ] && [ ${#p1} -ge 10 ] && break
    echo "No coinciden o tienen menos de 10 caracteres. Intenta de nuevo."
  done
  hash=$(printf '%s' "$p1" | openssl passwd -6 -stdin)
  echo "${usuario}:{SHA512-CRYPT}${hash}" >> "$SALIDA"
done

chmod 600 "$SALIDA"
echo "Creado $SALIDA (no se sube a Git). Reinicien el contenedor para aplicarlo."
