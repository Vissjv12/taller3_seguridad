#!/bin/bash
# =====================================================================
#  Cualquier PC: comprobación rápida (10 segundos) de que este equipo llega
#  al servidor y confía en su certificado. Úsenla al reconectar en clase.
# =====================================================================
set -uo pipefail
cd "$(dirname "$0")/.."
HOST=mail.lab.test
OK=0; MAL=0
bien() { echo -e "  \e[32m✔\e[0m $*"; OK=$((OK+1)); }
mal()  { echo -e "  \e[31m✘\e[0m $*"; MAL=$((MAL+1)); }

echo "Comprobando $HOST desde $(hostname)..."

IP=$(getent hosts $HOST | awk '{print $1}')
[ -n "$IP" ] && bien "$HOST resuelve a $IP" || mal "$HOST no resuelve: ejecuten scripts/modo.sh (casa, clase o cliente)"

[ -f certs/ca.crt ] && bien "CA presente: $(openssl x509 -in certs/ca.crt -noout -subject | sed 's/.*CN *= *//')" \
  || mal "falta certs/ca.crt (en el PC 2: copiarla desde el PC 1)"

for p in 587 993 25; do
  if timeout 4 bash -c "</dev/tcp/$HOST/$p" 2>/dev/null; then bien "puerto $p accesible"
  else mal "puerto $p NO accesible (¿contenedores arriba? ¿IP correcta? ¿firewall/PC2_IP?)"; fi
done

if [ -f certs/ca.crt ]; then
  for p in 587 993; do
    st=(); [ $p = 587 ] && st=(-starttls smtp)
    r=$(timeout 8 openssl s_client "${st[@]}" -connect $HOST:$p -servername $HOST -CAfile certs/ca.crt \
        -verify_hostname $HOST -verify_return_error -brief </dev/null 2>&1)
    if grep -q "Verification: OK" <<<"$r"; then
      bien "TLS $p verificado ($(grep -m1 'Protocol version' <<<"$r" | sed 's/.*: //'))"
    else
      mal "TLS $p NO verifica: $(grep -m1 -iE 'verify error|error' <<<"$r" | cut -c1-90)"
      echo "     ¿La CA de este PC es la del servidor? En clase, usen la ca.crt del PC 1."
    fi
  done
fi

echo
[ $MAL -eq 0 ] && echo -e "\e[32mTodo listo ($OK comprobaciones).\e[0m" || echo -e "\e[31m$MAL problema(s). Ver README, sección Problemas frecuentes.\e[0m"
[ $MAL -eq 0 ]
