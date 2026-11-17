#!/bin/bash
# =====================================================================
#  Pruebas positivas y negativas del Taller 3. Ejecutar desde el PC 2.
#  Requisitos: openssl, netcat-openbsd (nc), y certs/ca.crt del repositorio.
#
#  Uso:
#    scripts/probar.sh                  -> solo pruebas sin credenciales
#    LAB_USER=ana@lab.test scripts/probar.sh   -> pide la contraseña y
#                                          agrega las pruebas autenticadas
#  Salida: evidencias/pruebas-FECHA/ (salida cruda de cada prueba)
#          evidencias/pruebas-FECHA/reporte.html (tabla para el informe)
# =====================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

HOST=${HOST:-mail.lab.test}
CA=${CA:-certs/ca.crt}
TS=$(date +%Y%m%d-%H%M%S)
OUT=evidencias/pruebas-$TS
mkdir -p "$OUT"

[ -f "$CA" ] || { echo "No encuentro $CA"; exit 1; }
command -v nc >/dev/null || { echo "Instala netcat-openbsd (nc)"; exit 1; }

LAB_USER=${LAB_USER:-}
LAB_PASS=${LAB_PASS:-}
if [ -n "$LAB_USER" ] && [ -z "$LAB_PASS" ]; then
  read -r -s -p "Contraseña de $LAB_USER: " LAB_PASS; echo
fi

VERDE=$'\e[32m'; ROJO=$'\e[31m'; GRIS=$'\e[90m'; NORMAL=$'\e[0m'
TOTAL=0; OK=0
FILAS=""

html_esc() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

# registrar ID "descripción" "esperado" exito(0/1) archivo "línea de evidencia"
registrar() {
  local id=$1 desc=$2 esperado=$3 exito=$4 archivo=$5 linea=$6
  TOTAL=$((TOTAL+1))
  if [ "$exito" -eq 0 ]; then
    OK=$((OK+1)); estado="PASA"; color=$VERDE; clase=ok
  else
    estado="FALLA"; color=$ROJO; clase=ko
  fi
  printf '%s[%s]%s %-4s %s\n' "$color" "$estado" "$NORMAL" "$id" "$desc"
  printf '       %sevidencia: %s%s\n' "$GRIS" "$linea" "$NORMAL"
  FILAS+="<tr class=\"$clase\"><td>$id</td><td>$(echo "$desc" | html_esc)</td><td>$(echo "$esperado" | html_esc)</td><td><b>$estado</b></td><td><code>$(echo "$linea" | html_esc)</code><br><small>$(basename "$archivo")</small></td></tr>"
}

# Comprueba que el archivo contiene el patrón (exito=0) y devuelve la línea
buscar() { grep -m1 -E "$2" "$1"; }

# --- Ayudantes de conexión ------------------------------------------------
tls_info() {  # tls_info puerto [opciones extra de s_client...]
  local puerto=$1; shift
  local starttls=()
  [ "$puerto" = 587 ] && starttls=(-starttls smtp)
  timeout 15 openssl s_client "${starttls[@]}" -connect "$HOST:$puerto" \
    -servername "$HOST" -brief "$@" </dev/null 2>&1
}

smtp_claro() {  # comandos SMTP sin TLS por el 587
  { sleep 1; for c in "$@"; do printf '%s\r\n' "$c"; sleep 1; done; } \
    | timeout 20 nc -w 5 "$HOST" 587 2>&1
}

smtp_tls() {  # comandos SMTP dentro de STARTTLS (con validación completa)
  { sleep 2; for c in "$@"; do printf '%s\r\n' "$c"; sleep 1; done; } \
    | timeout 30 openssl s_client -starttls smtp -connect "$HOST:587" \
        -servername "$HOST" -CAfile "$CA" -verify_hostname "$HOST" \
        -verify_return_error -quiet 2>&1
}

imap_tls() {
  { sleep 2; for c in "$@"; do printf '%s\r\n' "$c"; sleep 4; done; } \
    | timeout 40 openssl s_client -connect "$HOST:993" \
        -servername "$HOST" -CAfile "$CA" -verify_hostname "$HOST" \
        -verify_return_error -quiet 2>&1
}

echo "== Pruebas contra $HOST  ($(date))"
echo

# ===== Bloque A: TLS y validación =======================================
for p in 587 993; do
  f=$OUT/A-tls-valido-$p.txt
  tls_info $p -CAfile "$CA" -verify_hostname "$HOST" -verify_return_error > "$f"
  buscar "$f" "Verification: OK" >/dev/null; e=$?
  v=$(grep -m1 "Protocol version" "$f"); s=$(grep -m1 "Ciphersuite" "$f")
  registrar "A$p" "TLS en $p con certificado de la CA del laboratorio" \
    "Verification: OK" $e "$f" "$v | $s"
done

f=$OUT/A-cert-no-confiable.txt
tls_info 587 -no-CAfile -no-CApath -no-CAstore -verify_return_error > "$f"
! grep -q "Verification: OK" "$f"; e=$?
registrar "A3" "Rechazo de certificado sin CA de confianza" \
  "error de verificación" $e "$f" "$(grep -m1 -iE 'verify error|verification error|unable' "$f")"

f=$OUT/A-nombre-incorrecto.txt
tls_info 993 -CAfile "$CA" -verify_hostname otro.lab.test -verify_return_error > "$f"
! grep -q "Verification: OK" "$f"; e=$?
registrar "A4" "Rechazo si el nombre no coincide con el SAN" \
  "hostname mismatch" $e "$f" "$(grep -m1 -iE 'mismatch|verify error|verification error' "$f")"

for p in 587 993; do
  f=$OUT/A-tls11-$p.txt
  # SECLEVEL=0 hace que el CLIENTE sí ofrezca TLS 1.1; si falla, lo rechazó el servidor
  tls_info $p -tls1_1 -cipher 'DEFAULT:@SECLEVEL=0' > "$f"
  ! grep -q "Protocol version: TLSv1.1" "$f"; e=$?
  registrar "A5-$p" "Servidor rechaza TLS 1.1 en $p" "handshake fallido" $e "$f" \
    "$(grep -m1 -iE 'alert|error|unsupported|no protocols' "$f")"
done

# ===== Bloque B: nada de credenciales ni envío sin TLS ==================
f=$OUT/B-ehlo-sin-tls.txt
smtp_claro "EHLO prueba.lab.test" "QUIT" > "$f"
grep -q "STARTTLS" "$f" && ! grep -q "AUTH" "$f"; e=$?
registrar "B1" "Antes de STARTTLS se anuncia STARTTLS pero NO AUTH" \
  "250-STARTTLS sin 250-AUTH" $e "$f" "$(grep -m1 STARTTLS "$f")"

f=$OUT/B-auth-sin-tls.txt
smtp_claro "EHLO prueba.lab.test" "AUTH PLAIN dGVzdAB0ZXN0AHRlc3Q=" "QUIT" > "$f"
buscar "$f" "^5[0-9][0-9].*" >/dev/null && grep -qE "^530|^503" "$f"; e=$?
registrar "B2" "AUTH sin TLS rechazado (587)" "530 Must issue a STARTTLS" $e "$f" \
  "$(grep -m1 -E '^5[0-9][0-9]' "$f")"

f=$OUT/B-envio-sin-tls.txt
smtp_claro "EHLO prueba.lab.test" "MAIL FROM:<ana@lab.test>" "QUIT" > "$f"
grep -q "^530" "$f"; e=$?
registrar "B3" "Envío sin TLS rechazado (587)" "530 Must issue a STARTTLS" $e "$f" \
  "$(grep -m1 -E '^5[0-9][0-9]' "$f")"

f=$OUT/B-imap-143.txt
if nc -z -w 3 "$HOST" 143 > "$f" 2>&1; then e=1; l="puerto 143 ABIERTO"; else e=0; l="puerto 143 cerrado"; fi
registrar "B4" "IMAP sin cifrado (143) no disponible" "conexión rechazada" $e "$f" "$l"

f=$OUT/B-envio-sin-auth.txt
smtp_tls "EHLO prueba.lab.test" "MAIL FROM:<ana@lab.test>" "RCPT TO:<pedro@lab.test>" "QUIT" > "$f"
grep -qiE "^5[0-9][0-9].*(denied|rejected)" "$f"; e=$?
registrar "B5" "Dentro de TLS pero SIN autenticar: envío rechazado" "554 Access denied" $e "$f" \
  "$(grep -m1 -E '^5[0-9][0-9]' "$f")"

# ===== Bloque C: pruebas autenticadas ===================================
if [ -n "$LAB_USER" ]; then
  AUTH=$(printf '\0%s\0%s' "$LAB_USER" "$LAB_PASS" | base64 -w0)
  if [ "$LAB_USER" = "ana@lab.test" ]; then OTRO=pedro@lab.test; else OTRO=ana@lab.test; fi

  f=$OUT/C-auth-ok.txt
  smtp_tls "EHLO prueba.lab.test" "AUTH PLAIN $AUTH" "QUIT" > "$f"
  grep -q "^235" "$f"; e=$?
  registrar "C1" "Autenticación correcta dentro de STARTTLS" "235 Authentication successful" $e "$f" \
    "$(grep -m1 -E '^235|^535' "$f")"

  f=$OUT/C-suplantacion.txt
  smtp_tls "EHLO prueba.lab.test" "AUTH PLAIN $AUTH" "MAIL FROM:<$OTRO>" "RCPT TO:<$OTRO>" "QUIT" > "$f"
  grep -qi "not owned by user" "$f"; e=$?
  registrar "C2" "$LAB_USER no puede enviar como $OTRO" "553 Sender address rejected: not owned by user" $e "$f" \
    "$(grep -m1 -E '^5[0-9][0-9]' "$f")"

  f=$OUT/C-relay-externo.txt
  smtp_tls "EHLO prueba.lab.test" "AUTH PLAIN $AUTH" "MAIL FROM:<$LAB_USER>" "RCPT TO:<alguien@example.com>" "QUIT" > "$f"
  grep -qi "Relay access denied" "$f"; e=$?
  registrar "C3" "Autenticado, pero destino externo rechazado" "554 Relay access denied" $e "$f" \
    "$(grep -m1 -E '^5[0-9][0-9]' "$f")"

  f=$OUT/C-imap-clave-mala.txt
  imap_tls "a1 LOGIN $LAB_USER clave-equivocada" "a2 LOGOUT" > "$f"
  grep -q "^a1 NO" "$f"; e=$?
  registrar "C4" "IMAP rechaza contraseña incorrecta" "a1 NO [AUTHENTICATIONFAILED]" $e "$f" \
    "$(grep -m1 '^a1' "$f")"

  f=$OUT/C-imap-ok.txt
  imap_tls "a1 LOGIN $LAB_USER $LAB_PASS" "a2 LOGOUT" > "$f"
  grep -q "^a1 OK" "$f"; e=$?
  registrar "C5" "IMAP con TLS implícito: login correcto" "a1 OK Logged in" $e "$f" \
    "$(grep -m1 '^a1' "$f")"

  f=$OUT/C-envio-legitimo.txt
  smtp_tls "EHLO prueba.lab.test" "AUTH PLAIN $AUTH" "MAIL FROM:<$LAB_USER>" "RCPT TO:<$OTRO>" \
    "DATA" "From: <$LAB_USER>" "To: <$OTRO>" "Subject: Prueba automatizada $TS" "" \
    "Mensaje ficticio enviado por scripts/probar.sh" "." "QUIT" > "$f"
  grep -qE "^250 .*queued" "$f"; e=$?
  registrar "C6" "Envío legítimo $LAB_USER -> $OTRO" "250 queued" $e "$f" \
    "$(grep -E '^250 .*queued|^5[0-9][0-9]' "$f" | head -1)"
  # No dejar la credencial en las evidencias
  sed -i "s#$AUTH#[credencial-oculta]#g; s#$LAB_PASS#[clave-oculta]#g" "$OUT"/C-*.txt
else
  echo "${GRIS}(Pruebas autenticadas omitidas: usen LAB_USER=ana@lab.test scripts/probar.sh)${NORMAL}"
fi

echo
echo "== Resultado: $OK de $TOTAL pruebas pasan"

cat > "$OUT/reporte.html" <<EOF
<!DOCTYPE html><html lang="es"><head><meta charset="utf-8">
<title>Taller 3 - Pruebas $TS</title>
<style>
 body{font-family:system-ui,sans-serif;margin:2rem;color:#222}
 table{border-collapse:collapse;width:100%} td,th{border:1px solid #ccc;padding:.4rem .6rem;vertical-align:top;font-size:.9rem}
 th{background:#f2f2f2;text-align:left} tr.ok td:nth-child(4){color:#137333} tr.ko td:nth-child(4){color:#b3261e}
 code{font-size:.8rem;white-space:pre-wrap} .res{font-size:1.4rem;margin:1rem 0}
</style></head><body>
<h1>Taller 3: pruebas de correo con TLS</h1>
<p>Servidor: <b>$HOST</b> · Fecha: $(date) · Equipo cliente: $(hostname)</p>
<p class="res"><b>$OK de $TOTAL</b> pruebas pasan</p>
<table><tr><th>ID</th><th>Prueba</th><th>Esperado</th><th>Resultado</th><th>Evidencia</th></tr>
$FILAS
</table>
<p><small>Salida completa de cada prueba en los archivos .txt de esta carpeta. Generado sin conexión a ningún servicio web.</small></p>
</body></html>
EOF
echo "Reporte: $OUT/reporte.html"
[ "$OK" -eq "$TOTAL" ]
