#!/bin/bash
# =====================================================================
#  PC 1: emite (o RENUEVA) el certificado TLS del servidor con una clave
#  privada NUEVA, firmado por la CA del laboratorio. Es la rotación del
#  secreto TLS: los clientes no necesitan cambios porque confían en la CA.
#    certs/mail.crt        -> certificado (SAN mail.lab.test, serverAuth)
#    secrets/mail/mail.key -> clave privada nueva (la anterior se descarta)
#  Uso: scripts/renovar-certificado.sh
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
HOST=mail.lab.test
DIAS=180

[ -f certs/ca.crt ] || { echo "Falta la CA: ejecuten scripts/crear-ca.sh"; exit 1; }
if [ ! -f ca-privada/ca.key ]; then
  echo "Falta ca-privada/ca.key. Si la guardaron en un USB, cópienla de vuelta"
  echo "temporalmente a ca-privada/ y vuelvan a ejecutar este script."
  exit 1
fi

mkdir -p secrets/mail
[ -d secrets/mail/mail.key ] && rmdir secrets/mail/mail.key   # carpeta creada por Docker

ANTES=""
[ -f certs/mail.crt ] && ANTES=$(openssl x509 -in certs/mail.crt -noout -serial)

TMP=$(mktemp -d)
openssl ecparam -name prime256v1 -genkey -noout -out "$TMP/mail.key"
openssl req -new -key "$TMP/mail.key" -subj "/O=Taller3 Lab/CN=$HOST" -out "$TMP/mail.csr"
cat > "$TMP/ext" <<EOF
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature
extendedKeyUsage=serverAuth
subjectAltName=DNS:$HOST
EOF
openssl x509 -req -in "$TMP/mail.csr" -CA certs/ca.crt -CAkey ca-privada/ca.key \
  -CAcreateserial -CAserial "$TMP/ca.srl" -days "$DIAS" -sha256 -extfile "$TMP/ext" \
  -out "$TMP/mail.crt" 2>/dev/null

openssl verify -CAfile certs/ca.crt "$TMP/mail.crt" >/dev/null
install -m 600 "$TMP/mail.key" secrets/mail/mail.key
install -m 644 "$TMP/mail.crt" certs/mail.crt
rm -rf "$TMP"

echo "Certificado del servidor emitido:"
openssl x509 -in certs/mail.crt -noout -subject -issuer -serial -dates -ext subjectAltName
[ -n "$ANTES" ] && echo "Serie anterior: $ANTES  (reemplazada)"

if [ "${1:-}" != "--sin-reinicio" ] && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx mail-lab; then
  docker compose restart mail >/dev/null && echo "Contenedor mail reiniciado con el certificado nuevo."
fi
