#!/bin/bash
# Arranque del contenedor: instala configuración y secretos con los
# permisos correctos, valida y lanza Dovecot + Postfix en primer plano.
set -euo pipefail

CFG=/etc/lab-config      # configuración del repositorio (solo lectura)
SEC=/run/lab-secrets     # secretos fuera de Git (solo lectura)

falta=0
for f in "$SEC/mail.key" "$SEC/users.passwd" /etc/ssl/lab/mail.crt; do
  if [ ! -s "$f" ]; then echo "ERROR: falta $f"; falta=1; fi
done
if [ "$falta" -eq 1 ]; then
  echo "Ejecuta primero: scripts/crear-ca.sh y scripts/crear-usuarios.sh"
  exit 1
fi

# --- Configuración de Postfix (propiedad de root, como exige postfix check)
for f in main.cf master.cf virtual_mailboxes sender_login_maps; do
  install -m 0644 -o root -g root "$CFG/postfix/$f" "/etc/postfix/$f"
done

# --- Configuración de Dovecot
install -m 0644 -o root -g root "$CFG/dovecot/dovecot.conf" /etc/dovecot/dovecot.conf

# --- Secretos con permisos mínimos
install -d -m 0700 -o root -g root /etc/ssl/lab/private
install -m 0600 -o root -g root "$SEC/mail.key" /etc/ssl/lab/private/mail.key
install -m 0640 -o root -g dovecot "$SEC/users.passwd" /etc/dovecot/users

# --- Buzones
chown vmail:vmail /var/mail/vhosts
chmod 0770 /var/mail/vhosts

echo "=== Versiones (registrar en el informe) ==="
postconf -h mail_version | sed 's/^/Postfix /'
echo "Dovecot $(dovecot --version)"
openssl version

echo "=== Validando configuración ==="
postfix check
doveconf -n >/dev/null

# --- Arranque en primer plano (logs visibles con: docker compose logs -f mail)
dovecot -F &
DOV=$!
postfix start-fg &
PFX=$!

parar() {
  echo "Deteniendo servicios..."
  postfix stop 2>/dev/null || true
  kill -TERM "$DOV" 2>/dev/null || true
}
trap parar TERM INT

# Si cualquiera de los dos procesos muere, el contenedor termina
wait -n "$DOV" "$PFX" || true
parar
wait || true
exit 1
