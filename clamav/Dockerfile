# OPCIONAL (perfil "antivirus"): Debian 12 + ClamAV.
# Las firmas se descargan AL CONSTRUIR la imagen (con Internet) y quedan
# dentro de ella: el laboratorio no tiene salida para actualizarlas después.
# La imagen pesa unos 400 MB y clamd usa entre 1 y 1,5 GB de RAM.
FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends clamav-daemon clamav-freshclam clamdscan ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Firma LOCAL para el archivo de prueba estándar EICAR (hash MD5 público).
# Garantiza que la demo funcione aunque falle la descarga de firmas oficiales.
RUN printf '44d88612fea8a8f36de82e1278abb02f:68:Taller3.EICAR-Prueba\n' > /var/lib/clamav/taller3-eicar.hdb \
 && chown clamav:clamav /var/lib/clamav/taller3-eicar.hdb

# Firmas oficiales (puede tardar varios minutos). Si el servidor de firmas
# no responde, la imagen se construye igual, solo con la firma de EICAR.
RUN if freshclam --stdout --foreground; then echo completas > /var/lib/clamav/ESTADO-FIRMAS; \
    else echo "solo-eicar" > /var/lib/clamav/ESTADO-FIRMAS; \
         echo "AVISO: no se pudieron descargar las firmas oficiales; solo detectará EICAR"; fi \
 && ls -lh /var/lib/clamav

COPY clamd.conf /etc/clamav/clamd.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh \
 && mkdir -p /run/clamav && chown clamav:clamav /run/clamav

EXPOSE 3310
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
