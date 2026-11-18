#!/bin/bash
# PC 1: guarda versiones y configuración efectiva (sin secretos) para el entregable.
set -uo pipefail   # informe: seguir aunque una sección quede vacía
cd "$(dirname "$0")/.."
mkdir -p evidencias
OUT=evidencias/config-efectiva-$(date +%Y%m%d-%H%M).txt
{
  echo "### Fecha: $(date)"
  echo "### Versiones"
  docker exec mail-lab postconf -h mail_version | sed 's/^/Postfix /'
  docker exec mail-lab dovecot --version | sed 's/^/Dovecot /'
  docker exec mail-lab openssl version
  docker exec rspamd-lab rspamd --version | head -1
  docker exec dns-lab named -v
  docker exec clamav-lab clamd --version 2>/dev/null || echo "ClamAV: perfil opcional no activo"
  echo "Modo: $(grep -E '^MODO=' .env | cut -d= -f2)  LAB_IP: $(grep -E '^LAB_IP=' .env | cut -d= -f2)"
  echo
  echo "### postconf -n (main.cf efectivo)"
  docker exec mail-lab postconf -n
  echo
  echo "### postconf -M (servicios de master.cf)"
  docker exec mail-lab postconf -M
  echo
  echo "### postconf -P (opciones -o de submission)"
  docker exec mail-lab postconf -P | grep '^submission'
  echo
  echo "### doveconf -n (Dovecot efectivo; doveconf oculta las claves)"
  docker exec mail-lab doveconf -n
  echo
  echo "### Certificado del servidor"
  openssl x509 -in certs/mail.crt -noout -subject -issuer -dates -ext subjectAltName,extendedKeyUsage
  echo
  echo "### DNS: registros de lab.test publicados por bind9"
  SEL=$(cat dkim-publica/activo)
  for r in "TXT lab.test" "TXT _dmarc.lab.test" "TXT $SEL._domainkey.lab.test" "MX lab.test" "A mail.lab.test"; do
    echo "--- $r"; docker exec dns-lab dig @127.0.0.1 +short $r
  done
  echo
  echo "### Rspamd: módulos clave"
  docker exec rspamd-lab rspamadm configdump dkim_signing
  docker exec rspamd-lab rspamadm configdump dmarc
  docker exec rspamd-lab rspamadm configdump options | grep -A4 local_addrs
  echo
  echo "### Límites de recursos y privilegios de los contenedores"
  for c in dns-lab rspamd-lab mail-lab; do
    docker inspect -f '{{.Name}}: mem={{.HostConfig.Memory}} cpus={{.HostConfig.NanoCpus}} pids={{.HostConfig.PidsLimit}} capdrop={{.HostConfig.CapDrop}} capadd={{.HostConfig.CapAdd}} secopt={{.HostConfig.SecurityOpt}}' $c
  done
  echo
  echo "### Montajes de secretos por contenedor (mínimo privilegio)"
  for c in dns-lab rspamd-lab mail-lab; do
    echo "--- $c"; docker inspect -f '{{range .Mounts}}{{.Source}} -> {{.Destination}} (rw={{.RW}}){{println}}{{end}}' $c | grep -E 'secrets|dkim|certs'
  done
} > "$OUT" 2>&1
echo "Guardado en $OUT"
