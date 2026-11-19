#!/bin/bash
# =====================================================================
#  PC 1: crea la PRIMERA clave DKIM de lab.test (selector taller3-1).
#  Para cambiarla después, usar scripts/rotar-dkim.sh.
#    secrets/dkim/taller3-1.key   -> PRIVADA: solo la monta Rspamd
#    dkim-publica/taller3-1.txt   -> registro DNS público: solo lo monta bind9
#    dkim-publica/activo          -> selector con el que firma Rspamd
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

if ls dkim-publica/taller3-*.txt >/dev/null 2>&1; then
  if [ ! -s dkim-publica/activo ]; then
    ls dkim-publica/taller3-*.txt | sed -E 's/.*(taller3-[0-9]+)\.txt$/\1/' | sort -V | tail -1 > dkim-publica/activo
    echo "Reparado dkim-publica/activo -> $(cat dkim-publica/activo)"
  fi
  echo "Ya hay claves DKIM ($(cat dkim-publica/activo) activa). No se crea otra."
  echo "Para cambiarla: scripts/rotar-dkim.sh"
  exit 0
fi
"$(dirname "$0")/lib-dkim.sh" generar taller3-1
echo taller3-1 > dkim-publica/activo
echo "Selector activo: taller3-1"
