# Taller 3: correo con TLS y seguridad (Postfix + Dovecot + Rspamd + bind9)

Servidor de correo de laboratorio para el dominio ficticio `lab.test`, con las cuentas
`ana@lab.test` y `pedro@lab.test`, en contenedores Docker sobre un PC Linux, con un
segundo PC Linux como cliente y como "atacante".

**Fase base (taller):**
- **587**: SMTP submission con STARTTLS **obligatorio** y autenticación obligatoria.
- **993**: IMAP con TLS implícito. **143**: deshabilitado.

**Fase de seguridad:**
- **25**: recepción servidor-a-servidor, solo accesible desde el PC 2 (demo de suplantación).
- **SPF, DKIM y DMARC** para `lab.test`, publicados por un DNS propio (bind9) y aplicados por Rspamd.
- Firma DKIM de todo lo que sale por 587, rechazo de adjuntos peligrosos y antisuplantación del remitente.

> Resultado de la validación de referencia: **23 de 23 pruebas pasan** (`scripts/probar.sh`).

---

## Índice

1. [Arquitectura](#1-arquitectura)
2. [Reparto del trabajo](#2-reparto-del-trabajo)
3. [Puesta en marcha del servidor (PC 1)](#3-puesta-en-marcha-del-servidor-pc-1)
4. [Preparación del cliente (PC 2)](#4-preparación-del-cliente-pc-2)
5. [Configurar Thunderbird (ambos PCs)](#5-configurar-thunderbird-ambos-pcs)
6. [Ejecutar las pruebas](#6-ejecutar-las-pruebas)
7. [Guía por actividades del taller](#7-guía-por-actividades-del-taller)
8. [Fase de seguridad: demostraciones](#8-fase-de-seguridad-demostraciones)
9. [Capturas de tráfico](#9-capturas-de-tráfico)
10. [Decisiones de diseño](#10-decisiones-de-diseño)
11. [Límites: qué NO protege este laboratorio](#11-límites-qué-no-protege-este-laboratorio)
12. [Entregable](#12-entregable)
13. [Operación diaria y problemas frecuentes](#13-operación-diaria-y-problemas-frecuentes)
14. [Estructura del repositorio](#14-estructura-del-repositorio)

---

## 1. Arquitectura

```
 PC 1 (Linux) - servidor                                PC 2 (Linux) - cliente / "atacante"
 ┌──────────────────────────────────────────────┐      ┌───────────────────────────────┐
 │ Docker, red lab 172.30.53.0/24               │      │ Thunderbird (Pedro)           │
 │                                              │ 587  │ scripts/probar.sh             │
 │  ┌────────────────┐  milter  ┌────────────┐  │◄─────│ scripts/demo-suplantacion.sh  │
 │  │ mail-lab  .10  │─────────►│ rspamd .11 │  │ 993  │ tcpdump / Wireshark           │
 │  │ Postfix        │  :11332  │ DKIM/SPF/  │  │◄─────│                               │
 │  │ Dovecot        │          │ DMARC/spam │  │  25  │                               │
 │  └────────────────┘          └─────┬──────┘  │◄─────│ (solo esta IP: PC2_IP)        │
 │                                    │ DNS     │      └───────────────────────────────┘
 │                              ┌─────▼──────┐  │
 │                              │ dns-lab .53│  │      Clientes: /etc/hosts
 │                              │ bind9      │  │      mail.lab.test -> LAB_IP
 │                              └────────────┘  │
 │ Thunderbird (Ana)                            │
 └──────────────────────────────────────────────┘
```

| Contenedor | IP | Función | Puertos publicados en `LAB_IP` |
|---|---|---|---|
| `mail-lab` | 172.30.53.10 | Postfix (SMTP) + Dovecot (IMAP, LMTP, SASL) | 25, 587, 993 |
| `rspamd-lab` | 172.30.53.11 | Milter: firma DKIM, verifica SPF/DKIM/DMARC, puntuación de spam | ninguno |
| `dns-lab` | 172.30.53.53 | bind9 autoritativo para `lab.test` (SPF, DKIM, DMARC) | ninguno |

### Versiones

| Componente | Imagen `debian:12-slim` (corrida de referencia del equipo) | Validación en vivo |
|---|---|---|
| Postfix | **3.7.11** | 3.8.6 |
| Dovecot | **2.3.19.1** (sintaxis **2.3**; la 2.4 usa otros nombres) | 2.3.21 |
| OpenSSL | **3.0.22** | 3.0.13 |
| Rspamd | 3.4.x (paquete de Debian 12) | 3.8.1 |
| BIND | 9.18.x | 9.18.39 |

Registren las versiones exactas de **su** ejecución con `scripts/evidencias-config.sh`.
La fase de seguridad se validó con Rspamd 3.8.1. Debian 12 trae la 3.4: el contenedor
ejecuta `rspamadm configtest` al arrancar y se detiene si alguna opción no es compatible.

---

## 2. Reparto del trabajo

| Quién | Equipo | Responsabilidades |
|---|---|---|
| Integrante A | **PC 1** | Docker, contenedores, secretos (CA, usuarios, DKIM), `main.cf`, firewall, `dmarc.sh`, `verificar-dkim.sh`, Thunderbird de Ana |
| Integrante B | **PC 2** | Thunderbird de Pedro, `probar.sh`, `demo-suplantacion.sh`, capturas, revisión de cabeceras `Authentication-Results` |
| Integrante C | Sin PC fijo | Revisión de configuraciones en Git, bitácora de evidencias, diagrama de tramos, informe y presentación. Ejecuta en persona al menos una prueba y la demo en algún momento |

Regla de Git: cada cambio en una rama propia y entra a `main` con un PR revisado por otro integrante.

---

## 3. Puesta en marcha del servidor (PC 1)

### 3.1 Requisitos (una sola vez)

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-v2 git openssl     # o Docker CE oficial
sudo usermod -aG docker $USER
# Cerrar sesión y volver a entrar (o reiniciar) para usar docker sin sudo
docker run --rm hello-world   # comprobación
```

### 3.2 Clonar y configurar las IP

```bash
git clone https://github.com/Vissjv12/taller3_seguridad.git
cd taller3_seguridad
chmod +x scripts/*.sh          # los permisos se pierden si se suben archivos desde la web de GitHub
ip -4 addr                     # anotar la IP del PC 1 en la red del laboratorio
cp .env.example .env
nano .env                      # LAB_IP = IP del PC 1 ; PC2_IP = IP del PC 2
```

`LAB_IP` se usa para publicar los puertos **y** para el registro SPF. `PC2_IP` es la única IP
que podrá conectarse al puerto 25. Si alguna IP cambia, editen `.env` y ejecuten
`docker compose up -d` (y de nuevo `sudo scripts/firewall-lab.sh`).

Agreguen también en el PC 1 la línea a `/etc/hosts`:

```bash
echo "$(grep ^LAB_IP= .env | cut -d= -f2)  mail.lab.test" | sudo tee -a /etc/hosts
```

### 3.3 Generar los secretos (quedan fuera de Git)

```bash
scripts/crear-ca.sh          # CA del laboratorio + certificado con SAN mail.lab.test
scripts/crear-usuarios.sh    # pide la contraseña de ana y pedro (mínimo 10 caracteres)
scripts/crear-dkim.sh        # clave DKIM RSA 2048, selector "taller3"
```

| Archivo generado | Qué es | ¿Se versiona? | ¿Se entrega? |
|---|---|---|---|
| `certs/ca.crt` | Certificado público de la CA | No (se copia al PC 2) | Sí |
| `certs/mail.crt` | Certificado del servidor | No | Sí |
| `secrets/mail.key` | Clave privada TLS del servidor | **No** | **No** |
| `secrets/users.passwd` | Hashes SHA512-CRYPT de las contraseñas | **No** | **No** |
| `secrets/dkim/taller3.key` | Clave privada DKIM | **No** | **No** |
| `secrets/dkim/taller3.txt` | Registro DNS público de DKIM | No | Sí (es pública) |
| `ca-privada/ca.key` | Clave privada de la CA | **No** | **No**. Muévanla a un USB al terminar |

> **Importante:** generen los secretos **antes** de `docker compose up`. Si Docker arranca sin
> ellos, crea carpetas vacías con esos nombres. Los scripts las limpian, pero si ven el error
> "falta ...", borren la carpeta indicada y vuelvan a generar.

### 3.4 Construir y levantar

```bash
docker compose up -d --build
docker compose ps                      # los tres contenedores en estado "running"
```

Revisen el arranque de cada contenedor (Ctrl+C para salir de los logs):

```bash
docker compose logs dns    | head -40  # versión de BIND y la zona lab.test generada
docker compose logs rspamd | head -10  # versión de Rspamd y "syntax OK"
docker compose logs mail   | head -15  # versiones de Postfix/Dovecot/OpenSSL, sin errores
```

Cada contenedor **valida su configuración al arrancar** (`postfix check`, `doveconf -n`,
`rspamadm configtest`, `named-checkconf`, `named-checkzone`) y se detiene si hay errores.

### 3.5 Firewall del laboratorio

```bash
sudo scripts/firewall-lab.sh
```

Aplica dos reglas en la cadena `DOCKER-USER` de iptables:

1. Ningún contenedor puede **abrir** conexiones hacia fuera de la red del laboratorio (aislamiento).
2. El puerto 25 solo acepta conexiones nuevas desde `PC2_IP`.

> **¿Por qué no ufw?** ufw **no** filtra los puertos publicados por Docker: Docker inserta sus
> reglas de iptables antes que las de ufw. Una regla `ufw allow from PC2 to any port 25`
> daría la falsa impresión de estar protegido. Para 587 y 993 en el host sí pueden usar
> `sudo ufw allow 587,993/tcp` si ufw está activo, pero el control real del 25 está en `DOCKER-USER`.

Las reglas se pierden al reiniciar Docker o el equipo: vuelvan a ejecutar el script.
Para retirarlas: `sudo scripts/firewall-lab.sh quitar`.

### 3.6 Comprobar el DNS y guardar la configuración efectiva

```bash
scripts/dmarc.sh estado                # DMARC: on + registro publicado
scripts/evidencias-config.sh           # versiones, postconf, doveconf, DNS y Rspamd
```

---

## 4. Preparación del cliente (PC 2)

```bash
sudo apt update
sudo apt install -y git openssl netcat-openbsd thunderbird wireshark tcpdump
git clone https://github.com/Vissjv12/taller3_seguridad.git
cd taller3_seguridad
chmod +x scripts/*.sh

# mail.lab.test apunta a la IP del PC 1 (LAB_IP)
echo "192.168.1.50  mail.lab.test" | sudo tee -a /etc/hosts     # usar la IP real

# Traer SOLO la CA pública desde el PC 1 (no se versiona)
mkdir -p certs
scp usuario@IP_DEL_PC1:~/taller3_seguridad/certs/ca.crt certs/
# (sin SSH: copiarla con un USB)

# Comprobación rápida (debe decir "Verification: OK")
openssl s_client -connect mail.lab.test:993 -servername mail.lab.test \
  -CAfile certs/ca.crt -verify_hostname mail.lab.test -verify_return_error -brief </dev/null
```

---

## 5. Configurar Thunderbird (ambos PCs)

1. **Importar la CA en Thunderbird.** Thunderbird usa **su propio almacén de certificados**:
   instalar la CA en el sistema no basta.
   *Configuración → Privacidad y seguridad → Certificados → Administrar certificados →
   Autoridades → Importar* `certs/ca.crt` → marcar *"Confiar en esta CA para identificar servidores"*.
2. Crear la cuenta con **configuración manual** (Ana en el PC 1, Pedro en el PC 2):

| | Servidor | Puerto | Seguridad | Autenticación | Usuario |
|---|---|---|---|---|---|
| Entrada (IMAP) | mail.lab.test | 993 | SSL/TLS | Contraseña normal | ana@lab.test |
| Salida (SMTP) | mail.lab.test | 587 | STARTTLS | Contraseña normal | ana@lab.test |

3. **Nunca** acepten una excepción de seguridad. Si aparece una advertencia de certificado,
   la CA no está bien importada: arreglen eso, no "confíen igual".
4. "SSL/TLS" en Thunderbird significa **TLS implícito**, no el protocolo SSL antiguo.
   La versión real negociada (TLS 1.3) se ve en las pruebas y en la captura.
5. Para ver las cabeceras de seguridad de un correo: abrirlo y pulsar **Ctrl+U** (código fuente).

---

## 6. Ejecutar las pruebas

Desde el **PC 2** (su IP es la única autorizada en el puerto 25):

```bash
scripts/probar.sh                              # A, B y D1-D3 (sin credenciales)
LAB_USER=ana@lab.test scripts/probar.sh        # las 23 pruebas (pide la contraseña)
```

Cada ejecución crea `evidencias/pruebas-FECHA/` con la salida cruda de cada prueba (`.txt`)
y un `reporte.html` listo para el informe. Las credenciales se ocultan automáticamente.
`probar.sh` termina con código 0 solo si todas pasan.

| ID | Qué demuestra | Esperado | Actividad |
|---|---|---|---|
| A587, A993 | Certificado válido de la CA del laboratorio; versión TLS y suite | `Verification: OK` | 6, 7 |
| A3 | Rechazo si la CA no es de confianza | `unable to get local issuer certificate` | 8 |
| A4 | Rechazo si el nombre no coincide con el SAN | `hostname mismatch` | 8 |
| A5-587, A5-993 | El servidor rechaza TLS 1.1 | `alert protocol version` | Seguridad |
| B1 | Antes de STARTTLS se anuncia STARTTLS pero **no** AUTH | `250-STARTTLS` sin `AUTH` | 3, 7 |
| B2, B3 | AUTH y envío sin TLS rechazados | `530 5.7.0 Must issue a STARTTLS command first` | 8 |
| B4 | IMAP sin cifrado (143) no disponible | conexión rechazada | 4 |
| B5 | Con TLS pero sin autenticar no se puede enviar | `554 ... Access denied` | 3 |
| C1, C5 | Autenticación correcta en 587 e IMAP | `235`, `a1 OK` | 3, 4 |
| C2 | Ana no puede usar la dirección de Pedro como remitente | `553 ... not owned by user` | Seguridad |
| C3 | Autenticado, pero destino externo rechazado | `554 ... Relay access denied` | 3 |
| C4 | IMAP rechaza contraseña incorrecta | `a1 NO [AUTHENTICATIONFAILED]` | 8 |
| C6 | Envío legítimo Ana → Pedro | `250 ... queued` | 7 |
| D1 | El 25 recibe correo legítimo de un dominio ajeno (control) | `250 ... queued` | Seguridad |
| D2 | Suplantación total por el 25 (`MAIL FROM` y `From:` = ana) | `554 Rechazado...` | Seguridad |
| D3 | Solo el `From:` visible falso (phishing típico) | `554 Rechazado...` | Seguridad |
| D4 | Adjunto `.exe` rechazado | `550 5.7.1 Adjunto peligroso no permitido (.exe)` | Seguridad |
| D5 | Adjunto `.pdf` aceptado (control) | `250 ... queued` | Seguridad |
| D6 | Lo enviado por 587 sale firmado con DKIM | `DKIM-Signature: ... d=lab.test; s=taller3` | Seguridad |

> **D2 y D3 fallan a propósito si DMARC está desactivado** (`scripts/dmarc.sh off`): esa es la demo "antes".
> **A5-993:** Dovecot solo cierra la conexión. La evidencia fuerte está en el servidor:
> `docker compose logs mail | grep "unsupported protocol"`.

---

## 7. Guía por actividades del taller

| # | Actividad | Cómo se cumple | Evidencia |
|---|---|---|---|
| 1 | Entrega local y buzones; versiones | Dominio virtual `lab.test`, entrega LMTP a Dovecot, Maildir | `evidencias-config.sh`, prueba C6 |
| 2 | Certificado con SAN firmado por la CA; privada protegida; confianza en clientes | `crear-ca.sh` (ECDSA P-256, SAN, `serverAuth`); clave `0600` dentro del contenedor; CA importada en Thunderbird | A587, A993, `evidencias-config.sh` |
| 3 | Submission 587 con STARTTLS obligatorio, relay restringido | `master.cf`: `smtpd_tls_security_level=encrypt`, `smtpd_tls_auth_only=yes`, `reject_unauth_destination` | B1, B2, B3, B5, C1, C3 |
| 4 | IMAP 993 con TLS implícito, sin acceso en claro | `ssl = required`, `disable_plaintext_auth = yes`, 143 con `port = 0` | B4, C5 |
| 5 | Thunderbird 587/STARTTLS y 993/SSL-TLS | Sección 5 de esta guía | Capturas de pantalla de la configuración |
| 6 | Verificar certificados antes de enviar credenciales | Comandos `openssl s_client` del enunciado (también automatizados en A587/A993) | Salida de openssl |
| 7 | Envío Ana ↔ Pedro, captura, versión TLS, suite, certificado | Thunderbird + `tcpdump` (sección 9) | `.pcapng`, A587/A993, cabecera `Received:` |
| 8 | Rechazo sin TLS y con certificado no confiable | Pruebas automáticas | A3, A4, B2, B3, C4 + intento manual en Thunderbird |
| 9 | Inspeccionar el mensaje almacenado | `scripts/ver-buzon.sh pedro` | Salida del script |

### Actividad 9: lo que ve el administrador

```bash
scripts/ver-buzon.sh pedro
```

Muestra el mensaje tal como está en disco: el cuerpo **en claro**, la cabecera
`Received: ... (using TLSv1.3 with cipher TLS_AES_256_GCM_SHA384 ...) ... with ESMTPSA`
y la firma `DKIM-Signature`. Es decir, llegó por TLS, autenticado y firmado,
pero **el servidor lo tiene legible**. Ni TLS ni DKIM cifran el contenido almacenado.

### Tabla de tramos (para el diagrama)

| Tramo | Protección | Conclusión |
|---|---|---|
| Cliente → submission 587 | STARTTLS obligatorio + AUTH solo tras TLS | Protege esa conexión; la fase previa a STARTTLS viaja en claro, pero sin credenciales |
| Cliente → IMAP 993 | TLS implícito | Protege la lectura desde el primer byte |
| Servidor → servidor (25) | SPF, DKIM y DMARC (autenticidad del remitente). TLS solo oportunista | Es otro tramo con su propia política. Aquí se demuestra la **autenticidad**, no la confidencialidad |
| Buzón almacenado | Ninguna (texto claro en Maildir) | TLS no da cifrado en reposo ni de extremo a extremo |

---

## 8. Fase de seguridad: demostraciones

### 8.1 Demo de suplantación (phishing) antes y después de DMARC

Necesita los dos PCs. Recomendación: el PC 2 graba la pantalla y captura el puerto 25 (sección 9).

| Paso | PC 1 | PC 2 |
|---|---|---|
| 1. Antes | `scripts/dmarc.sh off` → "Registro publicado: (ninguno)" | |
| 2. Ataque | | `scripts/demo-suplantacion.sh` → **ENTREGADO** |
| 3. Mostrar | | Thunderbird de Pedro: llega "de Ana". Ctrl+U: `dmarc=none`, `spf=fail` |
| 4. Defensa | `scripts/dmarc.sh on` → `v=DMARC1; p=reject; adkim=s; aspf=s` | |
| 5. Ataque | | `scripts/demo-suplantacion.sh` → **554 Rechazado** |
| 6. Prueba | `docker compose logs rspamd \| grep forced` → `Action set by DMARC` | |
| 7. Variante | | `scripts/demo-suplantacion.sh cabecera`: sobre ajeno, solo el `From:` falso → también rechazado |

**Qué explicar:**
- Sin autenticación de dominio, cualquier servidor puede poner `From: ana@lab.test`.
- **SPF** dice qué IP puede enviar por `lab.test` (solo `LAB_IP`, `-all` para el resto).
- **DKIM** firma criptográficamente lo que sale por 587 (clave privada en Rspamd, pública en DNS).
- **DMARC** une ambos con el `From:` visible: si ni SPF ni DKIM validan **alineados** con ese
  dominio, aplica la política publicada (`p=reject`). Basta con que **uno** valide.
- C2 (`reject_sender_login_mismatch`) solo controla el **sobre** de usuarios autenticados.
  El `From:` visible y el puerto 25 los cubre DMARC: son controles complementarios.

### 8.2 Firma DKIM: válida e inválida (PC 1)

Primero envíen un correo cualquiera desde Thunderbird (Ana → Pedro). Luego:

```bash
scripts/verificar-dkim.sh pedro
```

| Mensaje | Resultado de Rspamd | Significado |
|---|---|---|
| intacto | `R_DKIM_ALLOW [lab.test:s=taller3]` | La firma coincide con la clave pública del DNS |
| alterado (se agrega una línea al cuerpo) | `R_DKIM_REJECT [lab.test:s=taller3]` | Cualquier modificación en tránsito rompe la firma |

Hace falta este paso porque el correo interno (587 → buzón local) se firma pero no se reverifica
al entregarse. En el alterado, DMARC puede seguir en `ALLOW` porque SPF valida (se analiza con
`--ip LAB_IP`): es un buen ejemplo de que DMARC necesita solo **uno** de los dos.

### 8.3 Adjuntos peligrosos

Lo cubren D4 y D5. Para hacerlo a mano: en Thunderbird, adjunten un archivo renombrado a
`prueba.exe` → el envío falla con *"550 5.7.1 Adjunto peligroso no permitido (.exe)"*.

### 8.4 Ver los registros DNS

```bash
docker compose exec dns dig @127.0.0.1 +short TXT lab.test                      # SPF
docker compose exec dns dig @127.0.0.1 +short TXT taller3._domainkey.lab.test   # DKIM
docker compose exec dns dig @127.0.0.1 +short TXT _dmarc.lab.test               # DMARC
```

---

## 9. Capturas de tráfico

En el **PC 2** (ver la interfaz con `ip -4 addr`):

```bash
sudo tcpdump -i <interfaz> -w evidencias/captura-587.pcapng host mail.lab.test and port 587
sudo tcpdump -i <interfaz> -w evidencias/captura-993.pcapng host mail.lab.test and port 993
sudo tcpdump -i <interfaz> -w evidencias/captura-25.pcapng  host mail.lab.test and port 25
```

- **587:** en claro se ve el saludo `220`, `EHLO`, `250-STARTTLS` (**sin AUTH**), `STARTTLS` y
  `220 2.0.0 Ready to start TLS`. Después, solo registros TLS cifrados. Filtro en Wireshark: `smtp || tls`.
- **993:** todo es TLS desde el primer paquete (`Client Hello`).
- **25 (demo):** todo en claro, incluido el `From:` falso y el `554` final. Sirve para explicar
  que el tramo servidor-a-servidor tiene su propia política.
- **Con TLS 1.3 el certificado viaja cifrado** y no aparece en la captura. Tomen sus datos de
  `evidencias/pruebas-*/A-tls-valido-*.txt` o de `openssl s_client -showcerts`.
- **Opcional, descifrar:** lanzar Thunderbird con `SSLKEYLOGFILE=$HOME/tls-keylog.txt thunderbird`
  y cargar el archivo en Wireshark (*Preferencias → Protocols → TLS → (Pre)-Master-Secret log*).
  **No entreguen el archivo de claves** (el `.gitignore` lo excluye).

---

## 10. Decisiones de diseño

### Fase base

| Tema | Decisión | Motivo |
|---|---|---|
| Imágenes | Propias, desde `debian:12-slim` con paquetes oficiales | Poder mostrar y explicar cada archivo de configuración |
| Postfix y Dovecot | Un solo contenedor `mail` | Socket SASL y LMTP locales; menos piezas móviles |
| Certificado | ECDSA P-256, SAN `mail.lab.test`, `serverAuth`, 180 días | Los clientes modernos validan el SAN, no el CN |
| TLS mínimo | TLS 1.2 en Postfix y Dovecot | TLS 1.0/1.1 están obsoletos (A5) |
| Contraseñas | SHA512-CRYPT en `passwd-file` | Nunca texto plano en disco |
| chroot de Postfix | Desactivado | En un contenedor no añade aislamiento y complica DNS |
| Aislamiento | `default_transport = error` + regla `DOCKER-USER` | Doble barrera: ni por configuración ni por red sale correo |

### Fase de seguridad (diseño acordado y ajustes tras la validación)

| # | Tema | Decisión | Nota |
|---|---|---|---|
| 1 | Resolución DNS | Contenedor DNS **solo para el servidor**; los clientes siguen con `/etc/hosts` | Rspamd necesita registros TXT |
| 2 | Servidor DNS | **bind9**, zona `lab.test`, IP `172.30.53.53`, `recursion no` | Dominios ajenos reciben `REFUSED` al instante: sin esperas por falta de Internet |
| 3 | Rspamd | Contenedor aparte, `172.30.53.11`, milter `inet:172.30.53.11:11332`, **sin Redis** | Sin Redis no hay Bayes, greylisting ni ratelimit (desactivados explícitamente) |
| 4 | Puerto 25 | Publicado en `LAB_IP`, limitado a `PC2_IP` | **Ajuste:** con `DOCKER-USER`, no con ufw (ufw no filtra puertos de Docker) |
| 5 | DMARC | `v=DMARC1; p=reject; adkim=s; aspf=s`, sin `rua=` | **Ajuste:** el rechazo llega como `554 5.7.1` (código que usa el milter de Rspamd), no `550` |
| 6 | SPF | `v=spf1 ip4:<LAB_IP> -all` | `-all` da `fail` duro |
| 7 | DKIM | RSA 2048, selector `taller3`, `secrets/dkim/` | El DNS solo monta la parte pública; Rspamd solo la privada |
| 8 | Evidencia DKIM | `verificar-dkim.sh`: intacto vs. alterado | **Ajuste:** en Rspamd los símbolos se llaman `R_DKIM_ALLOW` y `R_DKIM_REJECT` |
| 9 | Adjuntos | `mime_header_checks` en Postfix → `550 5.7.1` | Solo mira el nombre del archivo (ver límites) |
| 10 | Pruebas | Serie **D** en `probar.sh` | Mismo formato de evidencias y `reporte.html` |
| 11 | Milter caído | `milter_default_action = tempfail` | Si Rspamd no responde, el correo se reintenta (4xx); nunca entra sin analizar |
| 12 | **IP locales** | `local_addrs` solo loopback, en `rspamd/override.d/` | **Hallazgo de la validación:** por defecto Rspamd trata las IP privadas (como la del PC 2) como "locales" y **no** les aplica SPF ni DMARC. Sin este ajuste la demo falla. Debe ir en `override.d`, porque en `local.d` la lista se suma a la predeterminada en lugar de reemplazarla |

---

## 11. Límites: qué NO protege este laboratorio

- **TLS no cifra el contenido almacenado** ni ofrece cifrado de extremo a extremo (actividad 9).
  Para eso hace falta OpenPGP o S/MIME en los clientes (Thunderbird trae OpenPGP integrado).
- **DKIM y DMARC dan autenticidad, no confidencialidad.** Un correo legítimo y firmado sigue
  siendo legible por el administrador y por quien lo intercepte en un tramo sin TLS.
- **El filtro de adjuntos solo mira el nombre**: no detecta un `.exe` renombrado a `.pdf`
  ni archivos dentro de un `.zip`. Para eso harían falta un antivirus (ClamAV) o reglas de Rspamd.
- **DMARC solo protege el dominio propio.** Un dominio parecido (`1ab.test`, `lab-test.com`) o un
  nombre visible engañoso (`"Ana - Soporte" <x@otro.test>`) pasan DMARC: ahí entran la formación
  de usuarios y que Thunderbird muestre la dirección completa del remitente.
- **El tramo servidor-a-servidor real** usa TLS oportunista. Exigirlo requiere MTA-STS o DANE,
  que dependen de DNS público: solo se documentan.
- **Sin Redis** no hay aprendizaje bayesiano, greylisting ni límites de tasa en Rspamd. Los límites
  de tasa de Postfix (`smtpd_client_*_rate_limit`) y el `auth_failure_delay` de Dovecot cubren lo básico.
- **No hay reputación externa** (listas negras, fuzzy hashes): requieren Internet y están desactivadas.

---

## 12. Entregable

| Pide el taller | Dónde está |
|---|---|
| Configuración sin contraseñas ni privadas | Este repositorio + `evidencias/config-efectiva-*.txt` |
| Capturas | `evidencias/captura-*.pcapng` + pantallazos de Wireshark |
| Correo recibido | Pantallazo en Thunderbird + `scripts/ver-buzon.sh pedro` |
| Pruebas negativas | `evidencias/pruebas-*/reporte.html` y sus `.txt` |
| Diagrama de tramos | Sección 7 (tabla de tramos) + diagrama en `entregable/` |
| Seguridad (valor agregado) | `evidencias/demo-suplantacion-*.txt`, `evidencias/dkim-*/`, pruebas D |

**Rúbrica:** servicio funcional (3) → C1, C5, C6 y Thunderbird · TLS y validación (3) → serie A,
B1 y capturas · pruebas negativas (2) → A3, A4, B2–B5, C2–C4 · explicación de límites (2) →
actividad 9, tabla de tramos y sección 11.

Antes de entregar o hacer `git push`:

```bash
git status                          # no debe aparecer nada de secrets/, ca-privada/ ni .env
grep -rIl "PRIVATE KEY" . --exclude-dir=.git --exclude-dir=secrets --exclude-dir=ca-privada  # debe salir vacío
```

---

## 13. Operación diaria y problemas frecuentes

### Comandos útiles (PC 1)

| Acción | Comando |
|---|---|
| Aplicar cambios en `mail/config/` | `docker compose restart mail` |
| Aplicar cambios en `rspamd/` | `docker compose restart rspamd` |
| Aplicar cambios en `dns/config/` | `docker compose restart dns` |
| Cambiar un `Dockerfile` o `entrypoint.sh` | `docker compose up -d --build` |
| Ver logs en vivo | `docker compose logs -f mail rspamd dns` |
| Estado de DMARC | `scripts/dmarc.sh estado` |
| Cola de Postfix | `docker compose exec mail postqueue -p` |
| Detener todo | `docker compose down` (los buzones se conservan) |
| Empezar de cero (**borra los buzones**) | `docker compose down -v` |

Tras reiniciar el PC 1: `docker compose up -d` y `sudo scripts/firewall-lab.sh`.
Estado de DMARC: `docker compose restart dns` conserva el último estado (`on`/`off`);
si el contenedor se recrea (`docker compose down` y `up`), vuelve a `on`. Compruébenlo siempre
con `scripts/dmarc.sh estado` antes de una demo.

### Problemas frecuentes

| Síntoma | Causa probable | Solución |
|---|---|---|
| Un contenedor se detiene al arrancar | Faltan secretos o hay un error de sintaxis | `docker compose logs <servicio>`; generar lo que falte (sección 3.3) |
| "falta secrets/dkim/taller3.txt" (o `.key`) | Se levantó antes de `crear-dkim.sh` y Docker creó carpetas vacías | `rm -r secrets/dkim/taller3.*` (solo si son carpetas) y `scripts/crear-dkim.sh` |
| `LAB_IP` no definido | Falta el archivo `.env` | `cp .env.example .env` y editarlo |
| El PC 2 no conecta a 587/993 | `/etc/hosts`, IP de `LAB_IP` incorrecta o firewall del PC 1 | `ping mail.lab.test`; `sudo ufw allow 587,993/tcp` si ufw está activo |
| El PC 2 no conecta al 25 | `PC2_IP` incorrecta en `.env` | Corregir y repetir `sudo scripts/firewall-lab.sh` |
| `451 4.7.1 Service unavailable` al enviar | Rspamd no está listo (el milter falla en modo `tempfail`) | Esperar unos segundos tras el arranque; `docker compose logs rspamd` |
| Thunderbird advierte del certificado | CA no importada **en Thunderbird** | Sección 5, paso 1. No aceptar la excepción |
| `535 Authentication failed` | Contraseña o usuario sin `@lab.test` | Revisar; regenerar con `crear-usuarios.sh` y `docker compose restart mail` |
| D2/D3 dicen "250 queued" | DMARC desactivado | `scripts/dmarc.sh on` en el PC 1 |
| La demo "antes" se rechaza igual | Rspamd trata la IP del PC 2 como local | Confirmar que `rspamd/override.d/options.inc` está montado: `docker compose exec rspamd rspamadm configdump options \| grep -A3 local_addrs` |
| Tras reiniciar el PC, el contenedor puede salir a Internet | Las reglas de iptables se pierden | `sudo scripts/firewall-lab.sh` |

---

## 14. Estructura del repositorio

```
taller3_seguridad/
├── docker-compose.yml           3 servicios, red fija 172.30.53.0/24, puertos ligados a LAB_IP
├── .env.example                 Plantilla de LAB_IP y PC2_IP
├── .gitignore                   Excluye .env, secrets/, ca-privada/, certs/, evidencias/, *.key, keylogs
├── mail/
│   ├── Dockerfile               Debian 12 + Postfix + Dovecot
│   ├── entrypoint.sh            Instala config y secretos con permisos mínimos, valida y arranca
│   └── config/
│       ├── postfix/             main.cf, master.cf, virtual_mailboxes, sender_login_maps, mime_header_checks
│       └── dovecot/             dovecot.conf (sintaxis 2.3)
├── rspamd/
│   ├── Dockerfile               Debian 12 + Rspamd
│   ├── entrypoint.sh            Instala la clave DKIM, configtest y arranca
│   ├── local.d/                 Milter, DKIM, DMARC, cabeceras, DNS, módulos desactivados
│   └── override.d/              local_addrs (solo loopback)
├── dns/
│   ├── Dockerfile               Debian 12 + bind9
│   ├── entrypoint.sh            Genera la zona, valida y arranca named
│   ├── generar-zona.sh          Plantilla + LAB_IP + DKIM + DMARC on/off
│   ├── lab-dmarc                Activa/desactiva el registro DMARC
│   └── config/                  named.conf, lab.test.zone.plantilla
├── scripts/
│   ├── crear-ca.sh              PC 1 · CA + certificado con SAN mail.lab.test
│   ├── crear-usuarios.sh        PC 1 · hashes SHA512-CRYPT de ana y pedro
│   ├── crear-dkim.sh            PC 1 · clave DKIM y registro DNS
│   ├── firewall-lab.sh          PC 1 · DOCKER-USER: sin salida + puerto 25 solo desde el PC 2
│   ├── dmarc.sh                 PC 1 · on | off | estado
│   ├── verificar-dkim.sh        PC 1 · firma intacta vs. alterada
│   ├── ver-buzon.sh             PC 1 · actividad 9
│   ├── evidencias-config.sh     PC 1 · versiones y configuración efectiva
│   ├── probar.sh                PC 2 · 23 pruebas (A, B, C, D) + reporte HTML
│   └── demo-suplantacion.sh     PC 2 · ataque por el 25 (total | cabecera)
├── certs/  secrets/  ca-privada/  evidencias/     Generados localmente, fuera de Git
└── entregable/                  Informe, diagrama y presentación
```

### Flujo de trabajo con Git

```bash
git checkout main && git pull
git checkout -b nombre/cambio
# editar...
git add -A && git status              # revisar que no aparezca nada de secrets/
git commit -m "rspamd: rechazar por politica DMARC"
git push -u origin nombre/cambio      # abrir el PR en GitHub; otro integrante lo revisa
# Tras el merge, en el PC 1:
git checkout main && git pull && docker compose up -d --build
```

> Todas las pruebas de suplantación se hacen **solo** con las cuentas ficticias de `lab.test`
> y dentro de la red aislada del laboratorio.
