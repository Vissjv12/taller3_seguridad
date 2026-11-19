# Taller 3: correo con TLS y seguridad

Servidor de correo de laboratorio para el dominio ficticio `lab.test` (cuentas `ana@lab.test`
y `pedro@lab.test`) en contenedores Docker. **Funciona igual en un solo PC (en casa) y con
dos PCs en red (en clase)**: solo cambia el modo.

| Qué | Cómo |
|---|---|
| Envío (587) | STARTTLS obligatorio, autenticación solo dentro de TLS |
| Lectura (993) | TLS implícito; el 143 está deshabilitado |
| Recepción (25) | Como otro servidor de Internet; en clase, abierto a la red del grupo |
| Autenticidad | SPF, DKIM (con rotación de claves) y DMARC `p=reject`, en un DNS propio |
| Antisuplantación | Sobre (Postfix) y `From:` visible (regla propia en Rspamd) atados al usuario |
| Ataques | Protección contra SMTP smuggling, fuerza bruta y agotamiento de recursos |
| Adjuntos | Bloqueo por extensión + antivirus ClamAV integrado (rechaza si no puede analizar) |
| Contenedores | Cada uno ve solo sus secretos; capacidades mínimas en DNS y Rspamd y límites de memoria y CPU |

> Validación de referencia: **27 de 27 pruebas pasan** (`scripts/probar.sh`).
> El diseño, los límites y la relación con la rúbrica están en [`docs/DISENO.md`](docs/DISENO.md).

---

## Índice

1. [Requisitos (una vez por PC)](#1-requisitos-una-vez-por-pc)
2. [Trabajar en casa (un solo PC)](#2-trabajar-en-casa-un-solo-pc)
3. [En clase: juntar los dos PCs](#3-en-clase-juntar-los-dos-pcs)
4. [Configurar Thunderbird](#4-configurar-thunderbird)
5. [Pruebas automáticas](#5-pruebas-automáticas)
6. [Demostraciones para la presentación](#6-demostraciones-para-la-presentación)
7. [Actividades del taller y evidencias](#7-actividades-del-taller-y-evidencias)
8. [Capturas de tráfico](#8-capturas-de-tráfico)
9. [Antivirus (ClamAV)](#9-antivirus-clamav)
10. [Entregable](#10-entregable)
11. [Comandos útiles y problemas frecuentes](#11-comandos-útiles-y-problemas-frecuentes)
12. [Estructura del repositorio](#12-estructura-del-repositorio)

---

## 1. Requisitos (una vez por PC)

Linux (Ubuntu o Debian) con conexión a Internet **la primera vez** (para descargar las imágenes
y las firmas del antivirus). El antivirus usa **1–1,5 GB de RAM** adicionales.

```bash
sudo apt update
# Ubuntu: el plugin de Compose v2 viene en el paquete docker-compose-v2.
sudo apt install -y docker.io docker-compose-v2 git openssl netcat-openbsd thunderbird tcpdump wireshark
sudo usermod -aG docker $USER
# Cerrar sesión y volver a entrar (o reiniciar). Comprobar:
docker run --rm hello-world
docker compose version          # debe responder v2.x

git clone https://github.com/Vissjv12/taller3_seguridad.git
cd taller3_seguridad
chmod +x scripts/*.sh       # necesario si los archivos se subieron desde la web de GitHub
```

> **Debian:** el paquete `docker-compose-v2` solo existe en Ubuntu. En Debian 12 no hay
> plugin v2 en `apt`: instalen Docker y el plugin de Compose desde el
> [repositorio oficial](https://docs.docker.com/engine/install/debian/) y después el resto
> de paquetes con `apt`. En ambos casos, `docker compose version` debe responder v2.x.

> **Todos los comandos de esta guía se ejecutan desde la carpeta `taller3_seguridad`.**

---

## 2. Trabajar en casa (un solo PC)

Cada integrante puede montar el laboratorio completo en su PC. El mismo equipo hace de
servidor, de cliente (Ana y Pedro) y de "atacante".

```bash
scripts/modo.sh casa        # todo en 127.0.0.1: el servidor no es visible desde la red de casa
scripts/iniciar.sh          # la 1ª vez pide las contraseñas de ana y pedro y tarda varios minutos
scripts/comprobar-conexion.sh
LAB_USER=ana@lab.test scripts/probar.sh
```

`iniciar.sh` hace todo en orden y **se puede repetir sin miedo** (no duplica nada):

1. comprueba Docker y el modo;
2. crea los secretos que falten: CA, certificado TLS, contraseñas y clave DKIM;
3. construye y levanta los contenedores y **espera a que estén sanos** (la primera vez
   descarga las firmas de ClamAV, varios minutos);
4. aplica el firewall (pide la contraseña de `sudo`);
5. muestra un resumen con los pasos siguientes.

Después, configuren Thunderbird con **las dos cuentas en el mismo programa** ([sección 4](#4-configurar-thunderbird)).

> **Cómo funciona la demo de suplantación en un solo PC:** cuando el propio PC se conecta a un
> puerto publicado por Docker, el servidor ve la conexión como si viniera de `172.30.53.1`
> (la puerta de enlace de la red Docker), que **no** está autorizada por el SPF (`127.0.0.1`).
> Por eso el "ataque" se comporta igual que desde el PC 2. Pueden comprobarlo con
> `docker compose logs mail | grep "connect from"`.

**Al día siguiente:** `scripts/iniciar.sh` (los buzones y secretos se conservan).

---

## 3. En clase: juntar los dos PCs

En clase **solo cuentan los secretos del PC 1** (el servidor). El PC 2 solo necesita la CA
pública del PC 1. Así ninguna clave privada pasa de un equipo a otro.

### Antes de ir a clase (en casa, con Internet)

- PC 1: `scripts/iniciar.sh` funcionando y `scripts/probar.sh` en verde. Las imágenes quedan
  construidas, así que en clase no hace falta Internet.
- Respaldo opcional: `docker save taller3/mail:local taller3/rspamd:local taller3/dns:local taller3/clamav:local -o imagenes-taller3.tar` (a un USB).
- PC 2: `git pull` y `scripts/demo-suplantacion.sh` disponible.
- Los dos PCs en la **misma red** en clase (la misma Wi-Fi). Si la red de la universidad
  aísla a los equipos entre sí, usen el hotspot de un celular.

### Paso a paso en clase (unos 10 minutos)

| # | PC 1 (servidor) | PC 2 (cliente / "atacante") |
|---|---|---|
| 1 | Conectarse a la red | Conectarse a la **misma** red y anotar su IP: `ip -4 addr` |
| 2 | `git pull` | `git pull` |
| 3 | `scripts/modo.sh clase` → confirma su IP en la red | |
| 4 | `scripts/iniciar.sh` → al final muestra los comandos para el PC 2 | |
| 5 | | `scripts/modo.sh cliente IP_DEL_PC1` |
| 6 | | Traer la CA con el comando `scp` que mostró `iniciar.sh` en el PC 1 (o con un USB) |
| 7 | | `scripts/comprobar-conexion.sh` → todo en ✔ |
| 8 | | Thunderbird: importar **esa** `ca.crt` y verificar la cuenta de Pedro ([sección 4](#4-configurar-thunderbird)) |
| 9 | Thunderbird: cuenta de Ana (sin cambios si ya estaba) | `LAB_USER=ana@lab.test scripts/probar.sh` → todo en verde |

`modo.sh clase` cambia `.env` y `/etc/hosts`. `iniciar.sh` vuelve a publicar los puertos
en la IP de la red, regenera el SPF del DNS con esa IP, conserva los buzones y aplica el
firewall: bloquea la salida de los contenedores y deja que solo el contenedor de correo
use el milter de Rspamd (11332). El puerto 25 queda abierto a la red del grupo (en casa,
solo en `127.0.0.1`) y lo filtran SPF/DKIM/DMARC, Rspamd y los límites.

> **Las dos garantías del firewall (salida bloqueada y milter restringido) las aplica
> `scripts/firewall-lab.sh`, que necesita root.** Arrancar solo con `docker compose up`
> deja el milter y la salida sin restringir: usen `scripts/iniciar.sh` o ejecuten el script.

**Si `scp` no funciona** (el PC 1 sin servidor SSH): copien `certs/ca.crt` con un USB, o
instalen SSH en el PC 1 (`sudo apt install openssh-server`).

**Plan B** (falla la red de clase): en el PC 1, `scripts/modo.sh casa && scripts/iniciar.sh`
y presenten todo desde un solo PC. Las demos son idénticas.

### Si algo cambia durante la clase

| Situación | Qué hacer |
|---|---|
| Cambió la IP del PC 1 | PC 1: `scripts/modo.sh clase` + `scripts/iniciar.sh` · PC 2: `scripts/modo.sh cliente NUEVA_IP` |
| Se reinició el PC 1 | `scripts/iniciar.sh` (vuelve a aplicar el firewall) |
| El PC 2 no conecta | PC 2: `scripts/comprobar-conexion.sh` dice qué falla |

### Volver a casa

```bash
scripts/modo.sh casa && scripts/iniciar.sh       # PC 1 (y cualquiera que trabaje solo)
```

En el PC 2, si quieren volver a trabajar solos con su propio servidor, antes hay que
descartar la CA del PC 1: el PC 2 solo recibió `certs/ca.crt`, sin la clave privada de la CA,
y `iniciar.sh` no puede emitir un certificado con ella.

```bash
rm -f certs/ca.crt                  # era la CA del PC 1
scripts/modo.sh casa && scripts/iniciar.sh
```

Después importen en Thunderbird la CA nueva (`certs/ca.crt`, sección 4): en el PC 2 no
estaba importada "su propia" CA, sino la del PC 1.

---

## 4. Configurar Thunderbird

1. **Importar la CA en Thunderbird.** Thunderbird usa **su propio almacén**: no basta con
   instalarla en el sistema.
   *Configuración → Privacidad y seguridad → Certificados → Administrar certificados →
   Autoridades → Importar* `certs/ca.crt` → marcar *"Confiar en esta CA para identificar servidores"*.
   El nombre de la CA incluye el equipo que la creó (`CA Taller3 - nombre-del-pc`), así que
   la CA de casa y la del PC 1 no se confunden.
2. Crear las cuentas con **configuración manual**:

| | Servidor | Puerto | Seguridad | Autenticación | Usuario |
|---|---|---|---|---|---|
| Entrada (IMAP) | mail.lab.test | 993 | SSL/TLS | Contraseña normal | ana@lab.test |
| Salida (SMTP) | mail.lab.test | 587 | STARTTLS | Contraseña normal | ana@lab.test |

   Igual para `pedro@lab.test`. En casa, las dos cuentas en el mismo Thunderbird; en clase,
   Ana en el PC 1 y Pedro en el PC 2.
3. **Nunca acepten una excepción de seguridad.** Si aparece una advertencia de certificado,
   la CA importada no es la del servidor (en clase: la del PC 1).
4. "SSL/TLS" en Thunderbird significa **TLS implícito**, no el protocolo SSL antiguo.
5. **Remitente = cuenta.** El servidor rechaza un `From:` distinto del usuario autenticado
   (prueba D7). No configuren identidades adicionales con otras direcciones.
6. Para ver las cabeceras de seguridad de un correo: abrirlo y pulsar **Ctrl+U**.

---

## 5. Pruebas automáticas

En casa, en el mismo PC. En clase, **desde el PC 2**.

```bash
scripts/comprobar-conexion.sh                    # comprobación rápida de acceso y TLS
LAB_USER=ana@lab.test scripts/probar.sh          # 27 pruebas (pide la contraseña de Ana)
```

Cada ejecución crea `evidencias/pruebas-FECHA/` con la salida cruda de cada prueba y un
`reporte.html` listo para el informe. Las credenciales se ocultan automáticamente.

| ID | Qué demuestra | Esperado |
|---|---|---|
| A587, A993 | Certificado válido de la CA; versión TLS y suite | `Verification: OK`, TLSv1.3 |
| A3, A4 | Rechazo de CA no confiable y de nombre incorrecto | error de verificación |
| A5 | El servidor rechaza TLS 1.1 | handshake fallido |
| B1 | Antes de STARTTLS se anuncia STARTTLS pero **no** AUTH | sin `250-AUTH` |
| B2, B3 | AUTH y envío sin TLS rechazados | `530 Must issue a STARTTLS command first` |
| B4 | IMAP sin cifrado (143) cerrado | conexión rechazada |
| B5 | Con TLS pero sin autenticar no se envía | `554 Access denied` |
| C1, C5 | Autenticación correcta en 587 e IMAP | `235`, `a1 OK` |
| C2 | Ana no puede usar la dirección de Pedro en el **sobre** | `553 not owned by user` |
| C3 | Autenticada, pero destino externo rechazado | `554 Relay access denied` |
| C4 | IMAP rechaza contraseña incorrecta | `a1 NO [AUTHENTICATIONFAILED]` |
| C6 | Envío legítimo Ana → Pedro | `250 queued` |
| D1 | El 25 recibe correo de un dominio ajeno (control) | `250 queued` |
| D2 | Suplantación total por el 25 | `554` (DMARC) |
| D3 | Solo el `From:` visible falso (phishing típico) | `554` (DMARC) |
| D4, D5 | Adjunto `.exe` rechazado (también con `filename*`); `.pdf` aceptado | `550` / `250` |
| D6 | Lo enviado por 587 sale firmado con DKIM | `d=lab.test; s=taller3-N` |
| D7 | Autenticada como Ana, sobre correcto pero `From: pedro` (suplantación interna) | `554 Suplantacion interna...` |
| D8 | SMTP smuggling: el correo escondido no se acepta | 1 solo `250 queued` |
| D9 | Antivirus: adjunto EICAR rechazado (ClamAV) | rechazo 5xx (mensaje según Rspamd) |
| D10 | Fuerza bruta: tras 6 AUTH fallidos se corta la sesión | `421 too many errors` |

> - **D2 y D3 fallan a propósito con DMARC desactivado** (`scripts/dmarc.sh off`): es la demo "antes".
> - **D10 va al final** porque deja a ese equipo frenado ~1 minuto: esperen antes de usar Thunderbird.
> - **A5-993:** Dovecot solo cierra la conexión; la evidencia fuerte está en
>   `docker compose logs mail | grep "unsupported protocol"`.

---

## 6. Demostraciones para la presentación

Comandos marcados **PC 1** o **PC 2**. En casa, todos en el mismo PC.

### 6.1 Suplantación (phishing) antes y después de DMARC

| # | PC 1 | PC 2 |
|---|---|---|
| 1 | `scripts/dmarc.sh off` → "Registro publicado: (ninguno)" | |
| 2 | | `scripts/demo-suplantacion.sh` → **ENTREGADO** |
| 3 | | Thunderbird de Pedro: llega "de Ana". Ctrl+U: `dmarc=none`, `spf=fail` |
| 4 | `scripts/dmarc.sh on` | |
| 5 | | `scripts/demo-suplantacion.sh` → **554 rechazado** |
| 6 | `docker compose logs rspamd \| grep forced` → `Action set by DMARC` | |
| 7 | | `scripts/demo-suplantacion.sh cabecera` → solo el `From:` falso: también rechazado |

### 6.2 Suplantación interna (usuario autenticado)

DMARC no actúa sobre usuarios autenticados, y Postfix solo controla el **sobre**. Antes de esta
mejora, Ana podía enviar con sobre `ana@lab.test` pero `From: pedro@lab.test`, y Pedro recibía
un correo "suyo". La regla propia de Rspamd (`rspamd/rspamd.local.lua`) lo cierra.

| # | Comando | Resultado |
|---|---|---|
| 1 | `scripts/demo-suplantacion.sh interna` (pide la contraseña de Ana) | `554 5.7.1 Suplantacion interna: From: pedro@lab.test no coincide con el usuario ana@lab.test` |
| 2 | En Thunderbird de Ana, una identidad con `pedro@lab.test` | `553 ... not owned by user`: Thunderbird usa la misma dirección en sobre y `From:`, así que Postfix lo frena antes (prueba C2) |

Son dos capas complementarias: Postfix ata el **sobre** al usuario y Rspamd ata el **`From:` visible**.

### 6.3 SMTP smuggling antes y después

| # | PC 1 | PC 2 |
|---|---|---|
| 1 | `docker compose exec mail postconf -e smtpd_forbid_bare_newline=no smtpd_forbid_unauth_pipelining=no` y `docker compose exec mail postfix reload` (el valor por defecto en Postfix < 3.9) | |
| 2 | | `scripts/demo-smuggling.sh` → **VULNERABLE: 2 correos** (el "CONTRABANDO" llega aparte) |
| 3 | `docker compose restart mail` (vuelve a la configuración del repositorio) | |
| 4 | | `scripts/demo-smuggling.sh` → **PROTEGIDO: 1 correo** |

### 6.4 Firma DKIM y rotación de claves (PC 1)

Primero envíen un correo cualquiera desde Thunderbird (Ana → Pedro). Luego:

```bash
scripts/verificar-dkim.sh pedro      # intacto: R_DKIM_ALLOW · alterado: R_DKIM_REJECT
scripts/rotar-dkim.sh                # paso 1: firma con taller3-2, taller3-1 sigue publicado
#   envíen otro correo: su cabecera DKIM-Signature dirá s=taller3-2
scripts/rotar-dkim.sh retirar        # paso 2: retira taller3-1 y destruye su clave privada
scripts/rotar-dkim.sh estado
```

Lección validada: durante la transición, un correo firmado con la clave vieja sigue siendo
válido (`R_DKIM_ALLOW`). **Después de retirarla** da `R_DKIM_PERMFAIL` y DMARC lo rechazaría.
Por eso la rotación se hace en dos pasos.

### 6.5 Rotación de los demás secretos (PC 1)

| Secreto | Comando | Efecto en los clientes |
|---|---|---|
| Certificado TLS (clave nueva) | `scripts/renovar-certificado.sh` | Ninguno: confían en la CA |
| Contraseñas | `scripts/crear-usuarios.sh` | Actualizar la contraseña en Thunderbird |
| Clave DKIM | `scripts/rotar-dkim.sh` (+ `retirar`) | Ninguno |
| CA | No se rota en el laboratorio (ver `docs/DISENO.md`) | Habría que reimportarla en todos los Thunderbird |

### 6.6 Fuerza bruta y adjuntos

- **Fuerza bruta:** la prueba D10 envía AUTH con una contraseña errónea: 6 respuestas `535` y luego `421 too many errors`.
- **Adjuntos:** en Thunderbird adjunten un archivo renombrado a `prueba.exe` → *"550 5.7.1 Adjunto peligroso no permitido (.exe)"*.

### 6.7 Lo que ve el administrador (actividad 9)

```bash
scripts/ver-buzon.sh pedro           # PC 1
```

El cuerpo está **en claro**. La cabecera `Received: ... (using TLSv1.3 ...)` prueba que llegó
por TLS, y `DKIM-Signature` que está firmado. Pero el servidor lo tiene legible: ni TLS ni DKIM cifran
lo almacenado.

---

## 7. Actividades del taller y evidencias

| # | Actividad | Cómo se cumple | Evidencia |
|---|---|---|---|
| 1 | Entrega local, buzones y versiones | Dominio virtual, LMTP a Dovecot, Maildir | `scripts/evidencias-config.sh`, C6 |
| 2 | Certificado con SAN, privada protegida, confianza en clientes | `crear-ca.sh` / `renovar-certificado.sh`; clave `0600` montada solo en `mail` | A587, A993 |
| 3 | 587 con STARTTLS obligatorio, relay restringido | `smtpd_tls_security_level=encrypt`, `smtpd_tls_auth_only`, `reject_unauth_destination` | B1–B3, B5, C1, C3 |
| 4 | 993 con TLS, sin acceso en claro | `ssl = required`, 143 deshabilitado | B4, C5 |
| 5 | Thunderbird 587/STARTTLS y 993/SSL-TLS | Sección 4 | Capturas de pantalla |
| 6 | Verificar certificados antes de enviar credenciales | `openssl s_client` del enunciado y `comprobar-conexion.sh` | Salidas de openssl |
| 7 | Envío Ana ↔ Pedro, captura, versión TLS y suite | Thunderbird + tcpdump (sección 8) | `.pcapng`, A587/A993 |
| 8 | Rechazo sin TLS y con certificado no confiable | Pruebas automáticas + intento en Thunderbird | A3, A4, B2, B3, B4 |
| 9 | Inspeccionar el mensaje almacenado | `scripts/ver-buzon.sh pedro` | Salida del script |

`scripts/evidencias-config.sh` (PC 1) guarda las versiones, la configuración efectiva, los
registros DNS, los límites de cada contenedor y qué secretos monta cada uno.

---

## 8. Capturas de tráfico

```bash
# En clase, en el PC 2 (interfaz: ip -4 addr):
sudo tcpdump -i <interfaz> -w evidencias/captura-587.pcapng host mail.lab.test and port 587
# En casa (un solo PC):
sudo tcpdump -i any -w evidencias/captura-587.pcapng port 587
```

Igual con `port 993` y `port 25`. Filtro de Wireshark: `smtp || tls`.

- **587:** en claro solo el saludo, `EHLO`, `250-STARTTLS` (**sin AUTH**) y `STARTTLS`. Después, todo cifrado.
- **993:** cifrado desde el primer paquete.
- **25 (demo):** todo en claro, incluido el `From:` falso y el `554` final.
- **Con TLS 1.3 el certificado viaja cifrado** y no aparece en la captura. Tomen sus datos de
  `evidencias/pruebas-*/A-tls-valido-*.txt`.
- **Opcional, descifrar:** `SSLKEYLOGFILE=$HOME/tls-keylog.txt thunderbird` y cargar el archivo en
  Wireshark (*Preferencias → Protocols → TLS*). **No entreguen ese archivo.**

---

## 9. Antivirus (ClamAV)

El antivirus es **parte del servicio**, no un extra: `clamav-lab` arranca siempre y Rspamd
depende de su healthcheck. Si Rspamd no puede analizar un mensaje (clamd caído o arrancando),
**no lo acepta**: devuelve `451 4.7.1` y el cliente lo reintenta. Nunca entra correo sin analizar.

```bash
docker compose logs clamav | head     # version y firmas cargadas
```

- La primera construcción descarga las firmas oficiales (unos minutos, ~400 MB) y necesita
  Internet; después quedan dentro de la imagen. En ejecución usa **1–1,5 GB de RAM**.
- La prueba D9 usa **EICAR**, el archivo de prueba estándar de los antivirus: es inofensivo.
  Se detecta también renombrado (`.pdf`) o dentro de un `.zip`.
- Si la descarga de firmas falla al construir, la imagen queda con una **firma local solo
  para EICAR** y el log lo avisa. Para reintentar: `docker compose build --no-cache clamav`.
- Las firmas quedan congeladas en la fecha de construcción (el laboratorio no tiene Internet).
- No se desactiva por configuración: para trabajar sin antivirus hay que editar
  `docker-compose.yml` y `rspamd/local.d/`.

---

## 10. Entregable

| Pide el taller | Dónde está |
|---|---|
| Configuración sin contraseñas ni privadas | Este repositorio + `evidencias/config-efectiva-*.txt` |
| Capturas | `evidencias/captura-*.pcapng` + pantallazos de Wireshark |
| Correo recibido | Pantallazo en Thunderbird + `scripts/ver-buzon.sh pedro` |
| Pruebas negativas | `evidencias/pruebas-*/reporte.html` y sus `.txt` |
| Diagrama de tramos | `docs/DISENO.md` (tabla de tramos); el diagrama va en la carpeta `entregable/`, que crea el equipo |
| Seguridad adicional | `evidencias/demo-*.txt`, `evidencias/dkim-*/`, pruebas D |

Antes de entregar o hacer `git push`:

```bash
git status       # no debe aparecer nada de secrets/, ca-privada/, certs/, dkim-publica/ ni .env
grep -rIl "PRIVATE KEY" . --exclude-dir=.git --exclude-dir=secrets --exclude-dir=ca-privada --exclude=README.md   # vacío
```

---

## 11. Comandos útiles y problemas frecuentes

| Acción (PC 1) | Comando |
|---|---|
| Arrancar o reparar todo | `scripts/iniciar.sh` |
| Ver o cambiar el modo | `scripts/modo.sh estado` / `casa` / `clase` |
| Aplicar cambios en `mail/config/` | `docker compose restart mail` |
| Aplicar cambios en `rspamd/` | `docker compose restart rspamd` |
| Aplicar cambios en `dns/config/` | `docker compose restart dns` |
| Cambios en un `Dockerfile` o `entrypoint.sh` | `scripts/iniciar.sh` (reconstruye) |
| Actualizar las imágenes base | `docker compose build --pull` (necesita Internet); háganlo antes de la entrega o cada cierto tiempo |
| Logs en vivo | `docker compose logs -f mail rspamd dns` |
| Estado de DMARC | `scripts/dmarc.sh estado` |
| Detener todo (se conservan buzones) | `docker compose down` |
| Empezar de cero (**borra los buzones**) | `docker compose down -v` |

| Síntoma | Causa probable | Solución |
|---|---|---|
| `Falta LAB_IP` / falta `.env` | No se eligió el modo | `scripts/modo.sh casa` (o `clase`) |
| `iniciar.sh`: "Docker no responde" | El usuario no está en el grupo `docker` | `sudo usermod -aG docker $USER` y reiniciar sesión |
| Un contenedor no queda "healthy" | Error de configuración o falta un secreto | `docker compose logs <servicio>`; repetir `scripts/iniciar.sh` |
| `address already in use` en el puerto 25 | Hay otro servidor de correo en el PC (exim, postfix) | `sudo systemctl disable --now exim4 postfix` |
| `comprobar-conexion.sh`: TLS no verifica | La CA local no es la del servidor | En clase, traer la `ca.crt` del PC 1 |
| El PC 2 no llega a ningún puerto | Redes distintas o red que aísla equipos | Misma Wi-Fi o hotspot; `scripts/comprobar-conexion.sh` |
| `451 4.7.1 Service unavailable` al enviar | Rspamd todavía arrancando (el correo se reintenta) | Esperar unos segundos |
| `451 4.7.1 Antivirus no disponible` | ClamAV arrancando o caído; el correo se reintenta | `docker compose ps clamav`; `docker compose logs clamav` |
| Thunderbird advierte del certificado | CA no importada en **Thunderbird** o CA de otro equipo | Sección 4, paso 1. No aceptar la excepción |
| `535 Authentication failed` | Contraseña o usuario sin `@lab.test` | Revisar; cambiar con `scripts/crear-usuarios.sh` |
| `421 too many errors` o envíos frenados | Se acaba de ejecutar D10 (fuerza bruta) | Esperar 1 minuto |
| `553 not owned by user` desde Thunderbird | Identidad con una dirección distinta de la cuenta | Usar la identidad de la propia cuenta |
| D2/D3 dicen "250 queued" | DMARC desactivado | `scripts/dmarc.sh on` |
| Tras reiniciar el PC, el contenedor puede salir a Internet | Las reglas de iptables se pierden | `scripts/iniciar.sh` |
| Se arrancó solo con `docker compose up` | El firewall no se aplicó: milter y salida sin restringir | `sudo scripts/firewall-lab.sh` (o `scripts/iniciar.sh`) |

---

## 12. Estructura del repositorio

```
taller3_seguridad/
├── docker-compose.yml          4 servicios (ClamAV incluido), red 172.30.53.0/24, límites y privilegios
├── .env.example                Referencia; el .env real lo escribe scripts/modo.sh
├── docs/DISENO.md              Decisiones, límites, tramos y rúbrica
├── mail/                       Postfix + Dovecot (Dockerfile, entrypoint, config/)
├── rspamd/                     local.d/ (DKIM, DMARC, antivirus, force_actions), override.d/, rspamd.local.lua (regla propia)
├── dns/                        bind9: zona lab.test (SPF, DKIM, DMARC on/off)
├── clamav/                     ClamAV (firmas oficiales + respaldo EICAR)
├── scripts/
│   ├── modo.sh                 casa | clase | cliente | estado
│   ├── iniciar.sh              PC 1 · arranca o repara todo
│   ├── comprobar-conexion.sh   Cualquier PC · ¿llego al servidor y confío en él?
│   ├── probar.sh               Pruebas A–D + reporte HTML
│   ├── demo-suplantacion.sh    Ataque por el 25 (total | cabecera | interna · 587)
│   ├── demo-smuggling.sh       SMTP smuggling
│   ├── dmarc.sh                PC 1 · on | off | estado
│   ├── verificar-dkim.sh       PC 1 · firma intacta vs. alterada
│   ├── rotar-dkim.sh           PC 1 · rotar | retirar | estado
│   ├── renovar-certificado.sh  PC 1 · certificado TLS con clave nueva
│   ├── crear-ca.sh  crear-usuarios.sh  crear-dkim.sh   (los usa iniciar.sh)
│   ├── lib-dkim.sh             Auxiliar: genera claves DKIM (crear-dkim · rotar-dkim)
│   ├── firewall-lab.sh         PC 1 · DOCKER-USER (lo usa iniciar.sh)
│   ├── ver-buzon.sh            PC 1 · actividad 9
│   └── evidencias-config.sh    PC 1 · versiones y configuración efectiva
└── entregable/                 (lo crea el equipo) informe, diagrama y presentación

Generados en cada equipo, fuera de Git:
  .env  certs/  secrets/mail/  secrets/dkim/  dkim-publica/  ca-privada/  evidencias/
```

### Flujo de Git

```bash
git checkout main && git pull
git checkout -b nombre/cambio
# editar...
git add -A && git status        # nada de secrets/, certs/, .env
git commit -m "descripción del cambio"
git push -u origin nombre/cambio      # PR en GitHub, revisado por otro integrante
```

> Todas las pruebas de suplantación y ataque se hacen **solo** con las cuentas ficticias de
> `lab.test` y dentro de la red del laboratorio.
