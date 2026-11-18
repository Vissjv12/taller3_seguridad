#!/bin/bash
# Genera la clave DKIM de lab.test (RSA 2048, selector "taller3").
#   secrets/dkim/taller3.key  -> PRIVADA: la usa Rspamd para firmar (fuera de Git)
#   secrets/dkim/taller3.txt  -> registro DNS público que bind9 publica
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
mkdir -p secrets/dkim

KEY=secrets/dkim/taller3.key
TXT=secrets/dkim/taller3.txt

# Docker crea una carpeta si se montó un archivo inexistente: limpiarla
for f in "$KEY" "$TXT"; do [ -d "$f" ] && rmdir "$f"; done

if [ -f "$KEY" ]; then
  echo "Ya existe $KEY. Bórrenla a propósito si quieren rotar la clave."
  exit 1
fi

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$KEY" 2>/dev/null
P=$(openssl pkey -in "$KEY" -pubout -outform DER | base64 -w0)

# Un registro TXT admite cadenas de máx. 255 caracteres: se parte en trozos
{
  echo 'taller3._domainkey IN TXT ( "v=DKIM1; k=rsa; "'
  echo "p=$P" | fold -w 200 | sed 's/.*/    "&"/'
  echo '  )'
} > "$TXT"

chmod 600 "$KEY"; chmod 644 "$TXT"
echo "Clave privada: $KEY"
echo "Registro DNS:  $TXT"
cat "$TXT"
