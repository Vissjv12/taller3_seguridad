---
target: presentación Taller 3
total_score: 17
max_score: 24
na_heuristics: 5,7,9,10
p0_count: 1
p1_count: 2
target_identity: "file:/home/davidjuz/Documentos/taller3_seguridad/entregable/presentacion/index.html"
target_fingerprint: "sha256:5e75804312d46944a1e2b3967ae37e28e0291e89f4b8a07124a9d92989cab057"
target_path: /home/davidjuz/Documentos/taller3_seguridad/entregable/presentacion/index.html
timestamp: 2026-11-19T12-41-04Z
slug: entregable-presentacion-index-html
---
# Crítica: entregable/presentacion/index.html
Puntuación 17/24 (heurísticas 5, 7, 9 y 10 no aplican). Especificidad: cambiable por cualquier charla técnica; no aparece nada propio del correo (SMTP, DNS, cabeceras).
Detector: 0 hallazgos en el CLI; blinking-cursor en #8 (falso positivo). --line tiene 1.45:1 de contraste (menos de 3:1 en elementos no textuales).
## Prioridades
- [P0] Legibilidad en proyector: bordes y cajas se funden; las etiquetas de #2 quedan en 10-13 px reales a 1280x720; .ruta y .pie en unos 14 px. Arreglo: --line y --panel más claros, stroke 3, texto SVG de al menos 26 px, quitar .ruta.
- [P1] Las diapositivas 4-7 son cuatro tablas idénticas con prosa de informe. Arreglo: composición propia en cada una (openssl, registros DNS, diagrama resaltado, transcripción SMTP con 530).
- [P1] Sin momento pico; el 27/27 queda enterrado. Arreglo: 27/27 como cifra protagonista y líneas A-D que aparecen en secuencia.
- [P2] Diapositiva 2: contradicción del PC 1, sin leyenda, ruido de etiquetas. Arreglo: el PC 1 como recinto, leyenda y revelado por capas.
- [P3] Mitad derecha de la portada vacía; .ayuda visible. Arreglo: cabecera Authentication-Results y ocultar la ayuda tras la primera tecla.
