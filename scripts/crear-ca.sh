#!/bin/bash
# =====================================================================
#  PC 1: crea la CA del laboratorio y emite el primer certificado del servidor.
#    certs/ca.crt        -> público: se importa en Thunderbird (ambos PCs)
#    ca-privada/ca.key   -> PRIVADO: solo sirve para emitir certificados.
#                           Guárdenla en un USB cuando no la usen.
#  El nombre de la CA incluye el nombre del equipo, para que Thunderbird
#  no confunda la CA de casa con la del PC 1 en clase.
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
mkdir -p certs ca-privada

if [ -f ca-privada/ca.key ] || [ -f certs/ca.crt ]; then
  echo "Ya existe una CA en este equipo (certs/ca.crt). No se crea otra."
  echo "Para renovar solo el certificado del servidor: scripts/renovar-certificado.sh"
  exit 0
fi

EQUIPO=$(hostname -s)
echo "== CA de laboratorio (ECDSA P-256) para el equipo '$EQUIPO'"
openssl ecparam -name prime256v1 -genkey -noout -out ca-privada/ca.key
openssl req -x509 -new -key ca-privada/ca.key -sha256 -days 365 \
  -subj "/O=Taller3 Lab/CN=CA Taller3 - $EQUIPO" \
  -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -out certs/ca.crt
chmod 644 certs/ca.crt; chmod 600 ca-privada/ca.key

"$(dirname "$0")/renovar-certificado.sh" --sin-reinicio
