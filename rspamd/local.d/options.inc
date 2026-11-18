# Taller 3 - Rspamd: opciones globales
# (local_addrs está en override.d/options.inc)

# Resolver: solo el bind9 del laboratorio. Las consultas por dominios ajenos
# reciben REFUSED al instante (no hay salida a Internet).
dns {
  nameserver = ["172.30.53.53"];
  timeout = 2s;
  retransmits = 2;
}
