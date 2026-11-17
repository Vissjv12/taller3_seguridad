#!/bin/bash
# Crea la CA de laboratorio y el certificado del servidor con SAN mail.lab.test.
#   certs/ca.crt          -> público: se instala en los clientes (Thunderbird)
#   certs/mail.crt        -> público: certificado del servidor
#   secrets/mail.key      -> PRIVADO: clave del servidor (fuera de Git)
#   ca-privada/ca.key     -> PRIVADO: clave de la CA. Después de usarla,
#                            muévanla a un USB u otro equipo.
set -euo pipefail
cd "$(dirname "$0")/.."

HOST=mail.lab.test
DIAS_CA=365
DIAS_SRV=180

umask 077
mkdir -p certs secrets ca-privada

if [ -f ca-privada/ca.key ] || [ -f certs/ca.crt ]; then
  echo "Ya existe una CA. Bórrenla a propósito si quieren regenerarla."
  exit 1
fi

echo "== 1/3 CA de laboratorio (ECDSA P-256)"
openssl ecparam -name prime256v1 -genkey -noout -out ca-privada/ca.key
openssl req -x509 -new -key ca-privada/ca.key -sha256 -days "$DIAS_CA" \
  -subj "/O=Taller3 Lab/CN=CA de laboratorio Taller3" \
  -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -out certs/ca.crt

echo "== 2/3 Clave y solicitud del servidor"
openssl ecparam -name prime256v1 -genkey -noout -out secrets/mail.key
openssl req -new -key secrets/mail.key -subj "/O=Taller3 Lab/CN=$HOST" -out /tmp/mail.csr

echo "== 3/3 Firma del certificado del servidor (SAN + serverAuth)"
cat > /tmp/mail.ext <<EOF
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature
extendedKeyUsage=serverAuth
subjectAltName=DNS:$HOST
EOF
openssl x509 -req -in /tmp/mail.csr -CA certs/ca.crt -CAkey ca-privada/ca.key \
  -CAcreateserial -days "$DIAS_SRV" -sha256 -extfile /tmp/mail.ext -out certs/mail.crt
rm -f /tmp/mail.csr /tmp/mail.ext certs/ca.srl

chmod 644 certs/ca.crt certs/mail.crt
chmod 600 secrets/mail.key ca-privada/ca.key

echo
echo "Verificación de la cadena:"
openssl verify -CAfile certs/ca.crt certs/mail.crt
openssl x509 -in certs/mail.crt -noout -subject -issuer -dates -ext subjectAltName,extendedKeyUsage
echo
echo "IMPORTANTE: muevan ca-privada/ca.key fuera de este equipo cuando terminen."
