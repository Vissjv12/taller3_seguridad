# Taller 3 - CRÍTICO para la demo de suplantación.
# Por defecto Rspamd considera "locales" todas las IP privadas (192.168.x,
# 10.x, 172.16-31.x) y NO les aplica SPF, DKIM ni DMARC. El PC 2 tiene una IP
# privada, así que solo el propio contenedor se considera local.
# Va en override.d (no en local.d) porque en local.d las listas se SUMAN a
# las predeterminadas en vez de reemplazarlas.
local_addrs = ["127.0.0.0/8", "::1"];
