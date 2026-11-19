# Milter para Postfix: escucha SOLO en la interfaz del laboratorio.
# El milter no autentica clientes: firewall-lab.sh limita además el 11332 al
# contenedor de correo (DOCKER-USER). No publicar este puerto en Compose.
bind_socket = "172.30.53.11:11332";
milter = yes;
timeout = 30s;
upstream "local" {
  default = yes;
  self_scan = yes;
}

# Texto del rechazo SMTP (5xx). El motivo exacto queda en el log de Rspamd:
#   docker compose logs rspamd | grep forced   -> "Action set by DMARC"
reject_message = "Rechazado por la politica de seguridad de lab.test (SPF/DKIM/DMARC o spam)";
