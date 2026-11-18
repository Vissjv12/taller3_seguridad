#!/bin/bash
# =====================================================================
#  PC 2: demo de suplantación (phishing) por el puerto 25.
#  Envía un correo FICTICIO con "From: Ana <ana@lab.test>" sin autenticarse,
#  como lo haría un atacante desde otro servidor. Muestra el diálogo SMTP
#  completo en pantalla (ideal para la presentación y la captura).
#
#  Demo "antes":   en el PC 1, scripts/dmarc.sh off  -> el correo falso SE ENTREGA
#  Demo "después": en el PC 1, scripts/dmarc.sh on   -> 554 rechazado
#
#  Uso: scripts/demo-suplantacion.sh [total|cabecera|interna]
#    total    : sobre y From: con ana@lab.test (por defecto)
#    cabecera : sobre atacante@otro.test, solo el From: visible es falso
#    interna  : Ana AUTENTICADA por el 587, sobre correcto (ana) pero
#               From: pedro@lab.test. Lo frena la regla propia de Rspamd.
#               Pide la contraseña de Ana.
#  SOLO dentro del laboratorio y con las cuentas ficticias.
# =====================================================================
set -uo pipefail
cd "$(dirname "$0")/.."
HOST=${HOST:-mail.lab.test}
MODO=${1:-total}
[ "$MODO" = cabecera ] && SOBRE=atacante@otro.test || SOBRE=ana@lab.test
TS=$(date +%Y%m%d-%H%M%S)
mkdir -p evidencias
OUT=evidencias/demo-suplantacion-$MODO-$TS.txt

if [ "$MODO" = interna ]; then
  [ -f certs/ca.crt ] || { echo "Falta certs/ca.crt"; exit 1; }
  read -r -s -p "Contraseña de ana@lab.test: " CLAVE; echo
  AUTH=$(printf '\0%s\0%s' ana@lab.test "$CLAVE" | base64 -w0)
  echo "Ana se autentica por el 587 (TLS) y envía con sobre ana@lab.test pero From: Pedro..."
  echo
  {
    sleep 2
    for c in "EHLO pc-ana.lab.test" "AUTH PLAIN $AUTH" "MAIL FROM:<ana@lab.test>" "RCPT TO:<pedro@lab.test>" "DATA" \
             "From: Pedro <pedro@lab.test>" "To: Pedro <pedro@lab.test>" "Subject: Nota para mi mismo" \
             "Date: $(date -R)" "" "(Mensaje FALSO generado en el laboratorio)" "." "QUIT"; do
      printf '%s\r\n' "$c"
      case "$c" in AUTH*) printf 'C: AUTH PLAIN [oculto]\n' >&2 ;; *) printf 'C: %s\n' "$c" >&2 ;; esac
      sleep 1
    done
  } 2> >(sed 's/^/\x1b[36m/;s/$/\x1b[0m/') \
    | openssl s_client -starttls smtp -connect "$HOST:587" -servername "$HOST" -CAfile certs/ca.crt \
        -verify_hostname "$HOST" -verify_return_error -quiet 2>/dev/null | sed 's/^/S: /' | tee "$OUT"
  echo
  if grep -q "Suplantacion interna" "$OUT"; then
    echo -e "\e[32m>> RECHAZADO por la regla propia de Rspamd (From: distinto del usuario autenticado).\e[0m"
  elif grep -qE "^S: 250 .*queued" "$OUT"; then
    echo -e "\e[31m>> ENTREGADO: Pedro recibió un correo 'suyo' que envió Ana.\e[0m"
  fi
  echo "Evidencia: $OUT"
  exit 0
fi

echo "Conectando a $HOST:25 como un servidor externo (sin autenticación)..."
echo
{
  sleep 1
  for c in "EHLO atacante.example" "MAIL FROM:<$SOBRE>" "RCPT TO:<pedro@lab.test>" "DATA" \
           "From: Ana <ana@lab.test>" "To: Pedro <pedro@lab.test>" \
           "Subject: Urgente: confirma tu clave hoy" \
           "Message-ID: <demo-$(date +%s%N)@atacante.example>" "Date: $(date -R)" "" \
           "Hola Pedro, necesito que confirmes tu clave en http://lab-test-soporte.example/login" \
           "(Mensaje FALSO generado en el laboratorio)" "." "QUIT"; do
    printf '%s\r\n' "$c"; printf 'C: %s\n' "$c" >&2; sleep 1
  done
} 2> >(sed 's/^/\x1b[36m/;s/$/\x1b[0m/') | nc -w 8 "$HOST" 25 | sed 's/^/S: /' | tee "$OUT"

echo
if grep -qE "^S: 250 .*queued" "$OUT"; then
  echo -e "\e[31m>> ENTREGADO: Pedro verá un correo 'de Ana' que Ana nunca envió.\e[0m"
  echo "   Ábranlo en Thunderbird (Ctrl+U) y revisen Authentication-Results y X-Spamd-Result."
elif grep -qE "^S: 5[0-9][0-9]" "$OUT"; then
  echo -e "\e[32m>> RECHAZADO en la sesión SMTP: el correo falso nunca llegó al buzón.\e[0m"
  echo "   En el PC 1: docker compose logs rspamd | grep forced   -> 'Action set by DMARC'"
fi
echo "Evidencia: $OUT"
