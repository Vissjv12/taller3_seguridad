#!/bin/bash
set -euo pipefail
echo "=== Versión ==="
clamd --version
echo "=== Firmas ==="
ls -lh /var/lib/clamav | grep -E '\.(cvd|cld|hdb)$' || true
if [ "$(cat /var/lib/clamav/ESTADO-FIRMAS 2>/dev/null)" = completas ]; then
  echo "Firmas oficiales cargadas (congeladas en la fecha de construcción de la imagen)."
else
  echo "AVISO: SIN firmas oficiales. Solo detecta el archivo de prueba EICAR."
  echo "Para reintentar la descarga (con Internet): docker compose build --no-cache clamav"
fi
echo "Cargando firmas en memoria (30-60 s)..."
exec clamd --foreground=true --config-file=/etc/clamav/clamd.conf
