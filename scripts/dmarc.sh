#!/bin/bash
# PC 1: publica o retira el registro DMARC de lab.test (para la demo antes/después).
# Uso: scripts/dmarc.sh on | off | estado
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose exec -T dns lab-dmarc "${1:-estado}"
