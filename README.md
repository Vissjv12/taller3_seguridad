# Taller 3: correo con TLS (Postfix + Dovecot en contenedores)

Servidor de correo de laboratorio para `lab.test`, con cuentas `ana@lab.test` y `pedro@lab.test`.

- **587**: SMTP submission con STARTTLS **obligatorio** y autenticación obligatoria.
- **993**: IMAP con TLS implícito.
- **143**: deshabilitado. **25**: no publicado (solo para la demo de seguridad).

| Componente | Versión (imagen `debian:12-slim`) |
|---|---|
| Postfix | 3.7.x (registrar la exacta con `scripts/evidencias-config.sh`) |
| Dovecot | 2.3.19 (sintaxis **2.3**; la 2.4 es distinta) |
| OpenSSL | 3.0.x |

> La configuración se validó con Postfix 3.8.6, Dovecot 2.3.21 y OpenSSL 3.0.13 (misma rama): 17 de 17 pruebas pasan.

---

## Topología

```
 PC 1 (Linux)                                 PC 2 (Linux)
 ┌──────────────────────────────┐            ┌──────────────────────────┐
 │ Docker: contenedor mail-lab  │  587 / 993 │ Thunderbird (Pedro)      │
 │  Postfix + Dovecot           │◄───────────│ Wireshark / tcpdump      │
 │  red 172.30.53.0/24          │   LAN del  │ scripts/probar.sh        │
 │ Thunderbird (Ana)            │ laboratorio│                          │
 └──────────────────────────────┘            └──────────────────────────┘
```

En **ambos PCs**, agregar a `/etc/hosts` (con la IP real del PC 1):

```
192.168.1.50   mail.lab.test
```

---

## Puesta en marcha (PC 1)

```bash
# 0. Requisitos
sudo apt install docker.io docker-compose-v2 git openssl     # o Docker CE
sudo usermod -aG docker $USER    # cerrar sesión y volver a entrar

# 1. Clonar y configurar la IP del laboratorio
git clone <url-del-repo> && cd taller3-correo
cp .env.example .env && nano .env          # LAB_IP = IP del PC 1 (ip -4 addr)

# 2. CA, certificado y cuentas (los secretos quedan fuera de Git)
scripts/crear-ca.sh
scripts/crear-usuarios.sh

# 3. Construir y levantar
docker compose up -d --build
docker compose logs -f mail     # ver versiones y arranque; Ctrl+C para salir

# 4. Aislamiento: el contenedor no puede abrir conexiones hacia fuera
sudo scripts/bloquear-salida.sh

# 5. Guardar versiones y configuración efectiva para el entregable
scripts/evidencias-config.sh
```

Después de cambiar algo en `mail/config/`: `docker compose restart mail`
(el arranque valida con `postfix check` y `doveconf -n` y se detiene si hay errores).

### Secretos

| Archivo | Qué es | ¿Se entrega? |
|---|---|---|
| `certs/ca.crt`, `certs/mail.crt` | Certificados públicos | Sí |
| `secrets/mail.key` | Clave privada del servidor | **No** |
| `secrets/users.passwd` | Hashes de contraseñas | **No** |
| `ca-privada/ca.key` | Clave de la CA | **No**. Muévanla a un USB al terminar |

El `.gitignore` ya los excluye. Antes de cada `git push`, revisen `git status`.

---

## Clientes (PC 1 y PC 2)

1. Copiar `certs/ca.crt` al PC 2 (viene en el repositorio).
2. **Thunderbird usa su propio almacén de certificados.** Ir a *Configuración → Privacidad y seguridad → Certificados → Administrar certificados → Autoridades → Importar* `ca.crt`, y marcar *"Confiar en esta CA para identificar servidores"*.
3. Cuenta nueva con configuración manual:

| | Servidor | Puerto | Seguridad | Autenticación | Usuario |
|---|---|---|---|---|---|
| Entrada (IMAP) | mail.lab.test | 993 | SSL/TLS | Contraseña normal | ana@lab.test |
| Salida (SMTP) | mail.lab.test | 587 | STARTTLS | Contraseña normal | ana@lab.test |

4. **Nunca** aceptar una excepción de seguridad. Si aparece la advertencia, la CA no está bien importada.

---

## Pruebas (PC 2)

```bash
sudo apt install openssl netcat-openbsd
scripts/probar.sh                              # sin credenciales (11 pruebas)
LAB_USER=ana@lab.test scripts/probar.sh        # + pruebas autenticadas (17)
```

Cada ejecución crea `evidencias/pruebas-FECHA/` con la salida cruda de cada prueba y un `reporte.html` para el informe. Las credenciales se ocultan automáticamente en las evidencias.

| ID | Qué demuestra | Actividad |
|---|---|---|
| A587, A993 | Certificado válido, versión TLS y suite | 6, 7 |
| A3, A4 | Rechazo de CA no confiable y de nombre incorrecto | 8 |
| A5 | El servidor rechaza TLS 1.1 | Seguridad |
| B1 | Antes de STARTTLS no se anuncia AUTH | 3, 7 |
| B2, B3 | AUTH y envío sin TLS rechazados (530) | 8 |
| B4 | IMAP 143 cerrado | 4 |
| B5 | Con TLS pero sin autenticar no se envía | 3 |
| C1, C5 | Autenticación correcta en 587 e IMAP | 3, 4 |
| C2 | Ana no puede enviar como Pedro (antisuplantación) | Seguridad |
| C3 | Autenticado pero destino externo rechazado | 3 |
| C4 | IMAP rechaza contraseña errónea | 8 |
| C6 | Envío legítimo Ana → Pedro | 7 |

**Nota sobre A5-993:** Dovecot simplemente cierra la conexión. La evidencia fuerte está en el log del servidor (`docker compose logs mail | grep "unsupported protocol"`).

**Límite de la prueba C2:** solo controla el remitente del *sobre* (`MAIL FROM`). La cabecera `From:` visible aún podría falsificarse. Eso es lo que resuelve DMARC (fase de seguridad).

---

## Capturas de tráfico (PC 2)

```bash
# Interfaz de red del PC 2: ip -4 addr
sudo tcpdump -i <interfaz> -w evidencias/captura-587.pcapng host mail.lab.test and port 587
sudo tcpdump -i <interfaz> -w evidencias/captura-993.pcapng host mail.lab.test and port 993
```

- **En 587** se ve en claro: saludo `220`, `EHLO`, `250-STARTTLS` (sin AUTH), `STARTTLS` y `220 Ready to start TLS`. Después solo hay registros TLS cifrados. Filtro de Wireshark: `smtp || tls`.
- **Con TLS 1.3 el certificado viaja cifrado.** No aparecerá en la captura. Tomen los datos del certificado de `evidencias/pruebas-*/A-tls-valido-*.txt` o de `openssl s_client -showcerts`.
- **Opcional, descifrar la captura:** lanzar Thunderbird con `SSLKEYLOGFILE=$HOME/tls-keylog.txt thunderbird` y cargar ese archivo en Wireshark (*Preferencias → Protocols → TLS → (Pre)-Master-Secret log*). **No entreguen el archivo de claves.**

---

## Actividad 9: lo que ve el administrador

```bash
scripts/ver-buzon.sh pedro
```

Muestra el mensaje tal como está en disco: el cuerpo en claro y la cabecera
`Received: ... (using TLSv1.3 with cipher ...) ... with ESMTPSA`. Es decir, llegó por TLS
y autenticado, pero **el servidor lo tiene legible**.

---

## Estructura

```
taller3-correo/
├── docker-compose.yml        Servicio, puertos (ligados a LAB_IP), red fija, volumen
├── .env.example              Plantilla de LAB_IP
├── mail/
│   ├── Dockerfile            Debian 12 + paquetes oficiales
│   ├── entrypoint.sh         Instala config y secretos, valida y arranca
│   └── config/
│       ├── postfix/          main.cf, master.cf, virtual_mailboxes, sender_login_maps
│       └── dovecot/          dovecot.conf (sintaxis 2.3)
├── scripts/
│   ├── crear-ca.sh           CA + certificado con SAN mail.lab.test
│   ├── crear-usuarios.sh     Hashes SHA512-CRYPT de ana y pedro
│   ├── bloquear-salida.sh    Regla DOCKER-USER: sin conexiones salientes
│   ├── probar.sh             17 pruebas + reporte HTML
│   ├── ver-buzon.sh          Actividad 9
│   └── evidencias-config.sh  Versiones y configuración efectiva
├── certs/                    Públicos (se generan con crear-ca.sh)
├── secrets/  ca-privada/     Privados (fuera de Git)
├── evidencias/               Salidas de pruebas y capturas
└── entregable/               Informe final, diagrama, presentación
```

## Flujo de trabajo con Git

```bash
git pull                                   # antes de empezar
# editar en mail/config/...
git add -A && git status                   # revisar que no aparezca nada de secrets/
git commit -m "submission: exigir TLS antes de AUTH"
git push
# en el PC 1: git pull && docker compose restart mail
```

## Problemas frecuentes

| Síntoma | Causa probable |
|---|---|
| El contenedor se detiene al arrancar | Faltan `secrets/` o `certs/mail.crt`, o hay error de sintaxis: `docker compose logs mail` |
| `LAB_IP` no definido | Falta el archivo `.env` |
| PC 2 no conecta | `/etc/hosts`, firewall del PC 1 (`sudo ufw allow 587,993/tcp`), IP de `LAB_IP` incorrecta |
| Thunderbird advierte del certificado | CA no importada en *Thunderbird* (no basta con el sistema) |
| `535 Authentication failed` | Contraseña, o usuario sin `@lab.test` |
| Tras reiniciar el PC, el contenedor puede salir | La regla de iptables se pierde: volver a ejecutar `bloquear-salida.sh` |

## Fase siguiente: seguridad (pendiente)

- DNS local (`dns/`) con `mail.lab.test`, SPF, DKIM y DMARC para `lab.test`.
- Rspamd: firma DKIM, verificación DMARC y filtro de spam.
- Demostración de suplantación por el puerto 25 antes y después de DMARC.
- Filtro de adjuntos peligrosos (`mime_header_checks`).
