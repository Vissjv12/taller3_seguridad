# Guion: Taller 3, correo con TLS y seguridad

**Duración objetivo: 9 minutos** (1 minuto de margen sobre el límite de 10).

| Quién | Rol | Diapositivas | Tiempo |
|---|---|---|---|
| **A** | Quien construyó el servidor. Se queda con lo técnico. | 2, 4, 5, 8 | ~4:45 |
| **B** | Quien necesita saber lo suficiente. Se queda con lo conceptual y con la historia del ataque. | 1, 3, 6, 7 | ~4:15 |

- Hay solo 4 cambios de turno y cada uno lleva una frase de paso ya escrita.
- `[clic]` significa avanzar: dentro de una diapositiva, cada clic revela el siguiente paso.
- El texto es una guía para decirlo con sus palabras, no para leerlo. Lo que va en **negrita** es lo que no puede faltar.

---

## 1 · Portada · B · 0:45 (acumulado 0:45)

> Buenos días. Nuestro taller fue montar **un servidor de correo seguro** para un dominio ficticio, `lab.test`, con dos usuarios: Ana y Pedro.
>
> Todo corre en contenedores Docker y usa tres puertos: **587 para enviar**, **993 para leer**, los dos cifrados con TLS, y **25 para recibir de otros servidores**, protegido con DMARC.
>
> A la derecha ven las cabeceras de un correo real de Ana a Pedro: viajó con **TLS 1.3** y lleva la **firma DKIM** de `lab.test`. Eso es lo que vamos a explicar. *(nombre de A)* les muestra cómo está armado.

`[clic]`

## 2 · Arquitectura · A · 1:45 (acumulado 2:30)

> Son dos PCs. El **PC 1 es el servidor**: ahí está Ana con su Thunderbird. El **PC 2** es Pedro, y también hace de atacante en las pruebas.
>
> Todo lo que entra al PC 1 pasa primero por un **firewall**. El **587** y el **993** se publican en la IP del PC 1; el **25** queda abierto a la **red del grupo** para recibir correo de otros equipos (en casa, solo en localhost).

`[clic]`

> Detrás hay una red Docker. El contenedor principal es **mail-lab**:
> - **Postfix** envía y recibe.
> - **Dovecot** guarda los buzones y sirve el IMAP.
> - Los buzones quedan en **texto en claro**; lo retomaremos en un momento.
> - El servidor **no puede sacar correo a Internet**: está bloqueado por configuración y también por red.

`[clic]`

> Cada correo pasa por **Rspamd**, que verifica SPF, DKIM y DMARC y firma lo que sale. Para eso consulta nuestro **DNS propio** y le pide al **antivirus ClamAV** que revise los adjuntos. Si el antivirus no responde, el correo no entra.
>
> *(nombre de B)* les explica qué protege cada tramo.

`[clic]`

## 3 · Tramos · B · 1:15 (acumulado 3:45)

> La idea clave del taller es esta: **TLS protege la conexión, no el mensaje.**
>
> - Cuando Ana envía por el **587**, primero se cifra la conexión con STARTTLS y **solo después** pide la contraseña. Si alguien intenta enviar sin TLS, el servidor responde con un **error 530**.
> - Pedro lee por el **993**, que va cifrado **desde el primer byte**.
> - En medio, **el buzón guarda el correo en claro**: el administrador del servidor puede leerlo. TLS no cifra lo que está guardado.

`[clic]`

> El puerto 25 es otro caso: ahí llegan correos de otros servidores, o de un atacante. En ese tramo no buscamos confidencialidad sino **autenticidad**, es decir, comprobar quién envía. De eso se encargan **SPF, DKIM y DMARC**. *(nombre de A)* les muestra cómo se comprueba cada parte.

`[clic]`

## 4 · Cifrado · A · 1:00 (acumulado 4:45)

> Creamos **nuestra propia autoridad certificadora** y, con ella, un certificado **ECDSA P-256** para `mail.lab.test`. Exigimos **TLS 1.2 como mínimo**: el 1.0 y el 1.1 se rechazan.
>
> Antes de dar una contraseña, el cliente comprueba el certificado.

`[clic]`

> **Verification: OK**: el certificado es de nuestra CA, y la conexión se negoció con **TLS 1.3**. Las contraseñas tampoco se guardan en texto plano, solo como hash SHA512-CRYPT.

`[clic]`

## 5 · Autenticidad · A · 1:15 (acumulado 6:00)

> Para saber quién puede enviar en nombre de `lab.test`, el DNS publica tres registros.
>
> **SPF** dice que solo la IP del PC 1 puede enviar. El `-all` significa que cualquier otra IP falla.

`[clic]`

> **DKIM**: Rspamd firma cada correo con una clave privada y el DNS publica la clave pública. La rotamos en dos pasos, para que los correos que ya están en camino no fallen.

`[clic]`

> Y **DMARC con `p=reject`**: si el remitente no cuadra con SPF o con DKIM, **el correo se rechaza**. *(nombre de B)* les cuenta cómo aislamos cada pieza.

`[clic]`

## 6 · Aislamiento · B · 1:00 (acumulado 7:00)

> Cada contenedor tiene **lo mínimo**. Por ejemplo, Rspamd:
> - **No tiene privilegios de sistema.**
> - Tiene límites de memoria, CPU y procesos.
> - Solo ve la clave DKIM, **en modo lectura**.

`[clic]` `[clic]` (una por regla)

> Y el firewall aplica dos reglas:
> - El **milter de Rspamd**, solo desde el contenedor de correo.
> - **Ninguna salida a Internet.**
>
> El **puerto 25** no se filtra por IP: en clase lo usa la red del grupo y en casa solo
> escucha en localhost. En un servidor real también iría abierto; ahí defienden
> SPF, DKIM, DMARC y el propio Rspamd.

`[clic]`

## 7 · Un ataque, rechazado · B · 1:15 (acumulado 8:15)

> Ahora, un ataque. Desde el PC 2 me conecto al puerto 25 y **me hago pasar por Ana**: el remitente y el asunto son falsos, del tipo «Urgente: confirma tu clave hoy». Es phishing típico.

`[clic]`

> El servidor lo **rechaza con un 554**: mi IP no está en el SPF y el correo no tiene firma DKIM, así que DMARC dice que no.

`[clic]`

> Lo probamos al revés: con DMARC apagado, **el mismo correo le llega a Pedro como si fuera de Ana**. Esa es la diferencia que hace DMARC.

`[clic]`

## 8 · Resultado · A · 0:45 (acumulado 9:00)

> Todo esto lo comprobamos con un script de **27 pruebas automáticas**, y **pasan las 27**:
> - **A**: certificados y versiones de TLS.
> - **B**: sin TLS no se puede autenticar ni enviar.
> - **C**: cada usuario solo puede enviar como él mismo.
> - **D**: ataques de suplantación, SMTP smuggling, virus y fuerza bruta, todos rechazados.
>
> ¿Preguntas?

---

## Preguntas probables

Si la pregunta es técnica o sobre configuración, contesta A. Si es sobre conceptos, contesta B.

| Pregunta | Quién | Respuesta corta |
|---|---|---|
| ¿Por qué el buzón queda en claro? | B | TLS solo cifra el transporte. Para cifrar el contenido almacenado hace falta cifrado de extremo a extremo (S/MIME o PGP), que queda fuera del alcance del taller. |
| ¿Por qué el 25 no está restringido por IP? | A | En un servidor real el 25 tiene que aceptar correo de cualquier MTA, y aquí se comporta igual: lo que decide si un correo entra es SPF/DKIM/DMARC y Rspamd, no la IP. En casa, además, solo escucha en localhost. |
| ¿Qué pasa si se cae el antivirus? | A | El correo no se acepta: responde con un error temporal 451 y el cliente lo reintenta. Nunca entra correo sin analizar. |
| ¿Qué es SMTP smuggling? | A | Esconder un segundo correo dentro de otro usando finales de línea raros. Postfix está configurado para normalizarlos y no aceptar comandos encadenados sin autenticar. |
| ¿Y si Ana, ya autenticada, pone `From: pedro`? | A | Postfix ata el remitente técnico al usuario, y una regla propia de Rspamd ata el `From:` visible. Responde con un 554 de «suplantación interna». |
| ¿Por qué Docker y no instalar directo? | B | Cada pieza queda aislada, con solo sus secretos, y el laboratorio se levanta igual en cualquier PC con un solo script. |
| ¿Por qué no usaron una imagen de correo ya hecha? | A | Partimos de Debian 12 con paquetes oficiales para poder mostrar y explicar cada archivo de configuración. |
| ¿Qué es STARTTLS frente a TLS implícito? | B | STARTTLS empieza en claro y luego cifra (587). En TLS implícito todo va cifrado desde el inicio (993). |
| ¿Y la fuerza bruta? | A | Tras 6 errores de autenticación, Postfix corta la sesión (`421 too many errors`). |

### Lo mínimo que B debe tener claro

1. **587** es envío con STARTTLS, **993** es lectura con TLS y **25** es recepción entre servidores.
2. **TLS** protege la conexión y **DMARC** comprueba quién envía. Son cosas distintas.
3. **SPF** dice qué IP puede enviar, **DKIM** es la firma y **DMARC** decide qué hacer si fallan.
4. El buzón **no** está cifrado. Eso es una limitación conocida, no un error.
5. El **25** no se filtra por IP: en un servidor real también va abierto y lo que decide es **SPF/DKIM/DMARC** (y Rspamd).
6. Si no sabes una respuesta: «Eso lo configuró *(nombre de A)*, te lo explica».

## Ensayo

- Ensayen **con cronómetro** al menos una vez. Si pasan de 9:30, recorten primero la diapositiva 4.
- Comprueben antes que las salidas de las diapositivas 1, 4 y 7 coinciden con su ejecución real (`scripts/probar.sh`, `scripts/demo-suplantacion.sh`, Ctrl+U en Thunderbird).
- En el aula: **F** para pantalla completa y **T** para el tema claro si hay mucha luz.
