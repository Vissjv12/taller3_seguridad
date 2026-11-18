#!/bin/bash
# Auxiliar: genera una clave DKIM RSA 2048 para un selector.
# Uso interno: scripts/lib-dkim.sh generar <selector>
set -euo pipefail
cd "$(dirname "$0")/.."
[ "${1:-}" = generar ] && [ -n "${2:-}" ] || { echo "Uso: lib-dkim.sh generar <selector>"; exit 2; }
SEL=$2

umask 077
mkdir -p secrets/dkim
umask 022
mkdir -p dkim-publica
# Docker crea carpetas si se montó algo inexistente: limpiarlas
for f in "secrets/dkim/$SEL.key" "dkim-publica/$SEL.txt"; do [ -d "$f" ] && rmdir "$f"; done

KEY=secrets/dkim/$SEL.key
TXT=dkim-publica/$SEL.txt
[ -f "$KEY" ] && { echo "Ya existe $KEY"; exit 1; }

(umask 077; openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$KEY" 2>/dev/null)
P=$(openssl pkey -in "$KEY" -pubout -outform DER | base64 -w0)

# Un registro TXT admite cadenas de máx. 255 caracteres: se parte en trozos
{
  echo "$SEL._domainkey IN TXT ( \"v=DKIM1; k=rsa; \""
  echo "p=$P" | fold -w 200 | sed 's/.*/    "&"/'
  echo '  )'
} > "$TXT"
chmod 600 "$KEY"; chmod 644 "$TXT"
echo "Clave DKIM creada: $KEY (privada) y $TXT (pública)"
