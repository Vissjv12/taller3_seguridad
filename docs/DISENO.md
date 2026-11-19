# Taller 3: diseño, decisiones y límites

Complemento del [README](../README.md), que explica cómo ejecutar. Este documento explica
**por qué** el laboratorio está construido así y **qué no protege**. Sirve de base para el
informe y la presentación.

## 1. Arquitectura

```
                 ┌─────────────────────── red Docker 172.30.53.0/24 ───────────────────────┐
 Cliente(s) ───► │ mail-lab .10        milter      rspamd-lab .11     DNS      dns-lab .53  │
 25/587/993      │ Postfix + Dovecot ───────────►  DKIM/SPF/DMARC  ───────►  bind9         │
 en LAB_IP       │                                 reglas propias                         │
                 │                                       │ (opcional)                       │
                 │                                       ▼                                  │
                 │                                 clamav-lab .12                           │
                 └──────────────────────────────────────────────────────────────────────────┘
```

| Modo | `LAB_IP` | Quién se conecta | IP que ve el servidor |
|---|---|---|---|
| Casa (un PC) | `127.0.0.1` | El mismo PC | `172.30.53.1` (puerta de enlace Docker) |
| Clase (dos PCs) | IP del PC 1 en la red | PC 2 (y el PC 1) | IP real del PC 2 |

En ambos modos el cliente **no** es la IP autorizada por SPF, por eso la demo de suplantación
se comporta igual.

## 2. Versiones

| Componente | Imagen `debian:12-slim` (corrida del equipo) | Validación en vivo |
|---|---|---|
| Postfix | 3.7.11 | 3.8.6 |
| Dovecot | 2.3.19.1 (sintaxis 2.3) | 2.3.21 |
| OpenSSL | 3.0.22 | 3.0.13 |
| Rspamd | 3.4.x | 3.8.1 |
| BIND | 9.18.x | 9.18.39 |
| ClamAV (opcional) | 1.0.x | 1.5.4 |

Cada contenedor valida su configuración al arrancar (`postfix check`, `doveconf -n`,
`rspamadm configtest`, `named-checkconf`, `named-checkzone`) y se detiene si algo no es
compatible con su versión.

## 3. Tramos (para el diagrama del entregable)

| Tramo | Protección | Conclusión |
|---|---|---|
| Cliente → submission 587 | STARTTLS obligatorio; AUTH solo tras TLS | Protege esa conexión. La fase previa a STARTTLS va en claro, pero sin credenciales |
| Cliente → IMAP 993 | TLS implícito | Protege la lectura desde el primer byte |
| Servidor → servidor (25) | SPF, DKIM y DMARC (autenticidad). TLS solo oportunista | Otro tramo, otra política. Aquí se demuestra **autenticidad**, no confidencialidad |
| Buzón almacenado | Ninguna (texto claro en Maildir) | TLS no da cifrado en reposo ni de extremo a extremo |

## 4. Decisiones

### Fase base

| Tema | Decisión | Motivo |
|---|---|---|
| Imágenes | Propias, desde `debian:12-slim` con paquetes oficiales | Poder mostrar y explicar cada archivo de configuración |
| Postfix y Dovecot | Un solo contenedor | Socket SASL y LMTP locales; menos piezas |
| Certificado | ECDSA P-256, SAN `mail.lab.test`, `serverAuth`, 180 días | Los clientes validan el SAN, no el CN |
| TLS mínimo | TLS 1.2 | 1.0/1.1 están obsoletos (A5) |
| Contraseñas | SHA512-CRYPT | Nunca texto plano en disco |
| Aislamiento | `default_transport = error` + regla `DOCKER-USER` | Doble barrera: ni por configuración ni por red sale correo |

### Fase de seguridad

| # | Tema | Decisión | Nota |
|---|---|---|---|
| 1 | DNS | bind9 solo para el servidor; clientes con `/etc/hosts`; `recursion no` | Dominios ajenos reciben `REFUSED` al instante |
| 2 | Rspamd | Contenedor aparte, milter `172.30.53.11:11332`, sin Redis | Sin Redis no hay Bayes, greylisting ni ratelimit propio |
| 3 | Puerto 25 | Publicado en `LAB_IP`; en clase limitado a `PC2_IP` con `DOCKER-USER` | **ufw no filtra puertos de Docker** |
| 3b | Milter 11332 | `DOCKER-USER`: solo el contenedor de correo puede conectar | El milter no autentica clientes y firma DKIM; sin esta regla, cualquier contenedor podría pedirle firmas |
| 4 | DMARC | `p=reject; adkim=s; aspf=s`, sin `rua=` | El rechazo llega como `554 5.7.1` |
| 5 | SPF | `ip4:<LAB_IP> -all` | Se regenera al cambiar de modo |
| 6 | DKIM | RSA 2048, selectores `taller3-N`, rotación en dos pasos | Ver sección 5 |
| 7 | IP locales | `local_addrs` solo loopback, en `override.d` | Por defecto Rspamd no aplica SPF/DMARC a IP privadas; en `local.d` la lista se **suma** en vez de reemplazarse |
| 8 | Milter caído | `milter_default_action = tempfail` | Nunca entra correo sin analizar |

### Mejoras de seguridad (segunda iteración)

| Mejora | Implementación | Prueba |
|---|---|---|
| **SMTP smuggling** (CVE-2023-51764) | `smtpd_forbid_bare_newline = normalize`, `smtpd_forbid_unauth_pipelining = yes`, sin CHUNKING. En Postfix < 3.9 viene **desactivado**; `normalize` exige Postfix ≥ 3.7.10 | D8 · `demo-smuggling.sh`: vulnerable = 2 correos, protegido = 1 |
| **Sobre vs. encabezado** | Postfix: `reject_sender_login_mismatch` (sobre). Rspamd: regla `LAB_FROM_NO_COINCIDE` (`From:` visible = usuario, un solo `From:`, sobre = `From:`) | C2, D7 · `demo-suplantacion.sh interna` |
| **Fuerza bruta** | Postfix: `smtpd_hard_error_limit = 6`, `smtpd_client_auth_rate_limit = 10`/min. Dovecot: `auth_failure_delay = 2s` | D10 |
| **Agotamiento de recursos** | Postfix: conexiones simultáneas, destinatarios, comandos basura, tamaño de mensaje. Dovecot: `mail_max_userip_connections`. Docker: `mem_limit`, `cpus`, `pids_limit` por contenedor | `evidencias-config.sh` |
| **Mínimo privilegio** | `mail` solo ve `secrets/mail/`; `rspamd` solo `secrets/dkim/` (y copia solo la clave activa); `dns` solo las claves públicas. `cap_drop: ALL` + capacidades mínimas en `dns` y `rspamd`; `no-new-privileges` en todos | `evidencias-config.sh` (montajes y capacidades) |
| **Rotación de secretos** | DKIM (selectores), certificado TLS (clave nueva), contraseñas | Demo 6.4 y 6.5 del README |
| **Antivirus** (opcional) | ClamAV como perfil de Compose, integrado en Rspamd; firma local EICAR de respaldo | D9 |

**Por qué fail2ban no:** en contenedores tendría que leer los logs de Docker y bloquear en
`DOCKER-USER`, con más piezas que fallen. Los límites de Postfix y Dovecot cubren el mismo
objetivo (frenar y cortar intentos repetidos) y se demuestran con D10. Queda como mejora documentada.

**Por qué la CA no se rota:** obliga a reimportarla en todos los clientes. En producción se
rota con antelación y con un período de convivencia de las dos CA. En el laboratorio se documenta.

## 5. Rotación de DKIM: por qué en dos pasos

| Momento | DNS publica | Rspamd firma con | Correo firmado con la clave vieja |
|---|---|---|---|
| Antes | `taller3-1` | `taller3-1` | válido |
| Paso 1 (`rotar-dkim.sh`) | `taller3-1` y `taller3-2` | `taller3-2` | **válido** (`R_DKIM_ALLOW`) |
| Paso 2 (`rotar-dkim.sh retirar`) | `taller3-2` | `taller3-2` | **inválido** (`R_DKIM_PERMFAIL` → DMARC rechaza) |

Si se retirara la clave vieja de inmediato, los correos firmados con ella que aún estén en
tránsito o en colas fallarían DMARC. Todo esto se validó en vivo.

## 6. Límites: qué NO protege este laboratorio

- **TLS no cifra lo almacenado** ni da cifrado de extremo a extremo (actividad 9). Para eso hace
  falta OpenPGP o S/MIME en los clientes (Thunderbird trae OpenPGP integrado).
- **DKIM y DMARC dan autenticidad, no confidencialidad.**
- **El filtro de adjuntos por extensión** solo mira el nombre. El antivirus opcional analiza el
  contenido y dentro de comprimidos, pero con firmas congeladas en la fecha de construcción.
- **DMARC solo protege el dominio propio.** Dominios parecidos (`1ab.test`) o nombres visibles
  engañosos (`"Ana - Soporte" <x@otro.test>`) pasan DMARC: ahí entran la formación de usuarios y
  mostrar la dirección completa del remitente.
- **El tramo servidor-a-servidor real** usa TLS oportunista. Exigirlo requiere MTA-STS o DANE,
  que dependen de DNS público: solo se documentan.
- **Sin Redis** no hay aprendizaje bayesiano ni greylisting.
- **Sin reputación externa** (listas negras, hashes compartidos): requieren Internet.
- **Los límites de fuerza bruta frenan, no bloquean**: un atacante paciente puede seguir
  probando despacio. Contraseñas largas (mínimo 10 caracteres, exigido por `crear-usuarios.sh`) siguen siendo la defensa principal.

## 7. Relación con la rúbrica

| Criterio | Puntos | Evidencia |
|---|---|---|
| Servicio funcional | 3 | C1, C5, C6, Thunderbird enviando y recibiendo |
| TLS y validación | 3 | Serie A, B1, capturas, `comprobar-conexion.sh` |
| Pruebas negativas | 2 | A3, A4, B2–B5, C2–C4 + serie D |
| Explicación de límites | 2 | Actividad 9 (`ver-buzon.sh`), tabla de tramos y sección 6 |
