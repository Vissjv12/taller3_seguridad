# Milter para Postfix: escucha en la red del laboratorio (172.30.53.11:11332)
bind_socket = "*:11332";
milter = yes;
timeout = 120s;
upstream "local" {
  default = yes;
  self_scan = yes;
}

# Texto del rechazo SMTP (5xx). El motivo exacto queda en el log de Rspamd:
#   docker compose logs rspamd | grep forced   -> "Action set by DMARC"
reject_message = "Rechazado por la politica de seguridad de lab.test (SPF/DKIM/DMARC o spam)";
