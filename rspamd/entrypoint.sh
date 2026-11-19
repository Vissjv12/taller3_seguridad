#!/bin/bash
# Arranque de Rspamd: instala configuración y SOLO la clave DKIM activa.
set -euo pipefail

CFG=/etc/lab-rspamd            # carpeta rspamd/ del repositorio (solo lectura)
PRIV=/run/lab-dkim/privada     # secrets/dkim/   (claves privadas)
PUB=/run/lab-dkim/publica      # dkim-publica/   (selector activo)

SEL=$(cat "$PUB/activo" 2>/dev/null || true)
if [ -z "$SEL" ] || [ ! -f "$PRIV/$SEL.key" ]; then
  echo "ERROR: falta la clave DKIM activa ('${SEL:-ninguna}')."
  echo "Ejecuta scripts/iniciar.sh (o scripts/crear-dkim.sh) en el PC 1."
  exit 1
fi

# --- Configuración
mkdir -p /etc/rspamd/local.d /etc/rspamd/override.d
cp "$CFG"/local.d/*    /etc/rspamd/local.d/
cp "$CFG"/override.d/* /etc/rspamd/override.d/
cp "$CFG"/rspamd.local.lua /etc/rspamd/rspamd.local.lua
# El antivirus es obligatorio: local.d/antivirus.conf + force_actions. Si clamd
# no responde, Rspamd devuelve 451 y el correo se reintenta (nunca entra sin analizar).
echo "Antivirus (ClamAV): integrado (sin clamd => 451, no se acepta sin analizar)"

# --- Clave DKIM: solo la activa, legible solo por el usuario de Rspamd
install -d -m 0750 -o _rspamd -g _rspamd /var/lib/rspamd/dkim
rm -f /var/lib/rspamd/dkim/*.key
install -m 0600 -o _rspamd -g _rspamd "$PRIV/$SEL.key" "/var/lib/rspamd/dkim/lab.test.$SEL.key"
echo "lab.test $SEL" > /var/lib/rspamd/dkim/selectores.map
chown _rspamd:_rspamd /var/lib/rspamd/dkim/selectores.map
echo "DKIM: firmando con el selector $SEL"

echo "=== Versión ==="
rspamd --version | head -1
echo "=== Validando configuración ==="
rspamadm configtest

exec rspamd -f -u _rspamd -g _rspamd
