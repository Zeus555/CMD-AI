# Video: PRC AI 2.0 en 2 minutos

Un video corto (1:59, 1920×1080, 30 fps, en español y sin sonido) con lo más
relevante de PRC AI 2.0. Va sin voz a propósito: en LinkedIn y en la mayoría
de redes el video arranca sin sonido, así que todo se lee en pantalla. El
ritmo deja leer cada respuesta y es fácil ponerle voz encima si algún día se
quiere.

## La regla: todo lo que sale en la terminal es real

Cada escena de terminal sale de una conversación de verdad con el programa,
grabada con `capturar.ps1` el 2026-11-18 con Gemma 4 E4B en el llama-server
local (`http://127.0.0.1:8080`); la 3 se volvió a grabar al añadir los PDF.
Las conversaciones enteras están en [`capturas/`](capturas): los `.txt` son
lo que se tecleó y los `.out`, lo que salió.

- **El texto no se reescribe a mano.** `montar.ps1` copia las líneas de los
  `.out` por su número. Donde se salta un trozo sale una línea `...`.
- **Lo único que cambia es el ritmo.** Lo tecleado aparece letra a letra y
  las esperas del modelo se acortan. El pie de cada escena lo dice.
- **Sin datos personales.** La captura corre con una carpeta de datos vacía y
  con el usuario de Windows cambiado a «usuario», así que el prompt sale como
  `Usuario >`. Se eligieron preguntas que no enseñan la IP, la wifi ni el
  nombre del equipo. Lo que sí sale del equipo es la memoria RAM y el espacio
  libre de los discos.
- **El negocio es inventado:** la Panadería y Cafetería La Espiga, de
  `tests\negocio.ps1 -Crear`. El catálogo de pasteles es un PDF; una factura
  escaneada, también, y es lo que dice que no puede leer.

## Escenas

| # | Escena | Qué cuenta | Captura, líneas |
| --- | --- | --- | --- |
| 0 | `intro` (4,5 s) | PRC AI 2.0. Una IA en la terminal de Windows, en tu equipo, sin nube. PowerShell puro, cero dependencias, en español. | — |
| 1 | `local` | Chat local con Gemma 4 E4B: sin clave y sin nube. | `1-chat-web-equipo.out` 2-6 |
| 2 | `web` | Busca en internet cuando la pregunta lo pide, y cita las fuentes. | `1-chat-web-equipo.out` 7-10 |
| 3 | `equipo` | Sabe datos del propio equipo (la memoria) sin internet. | `1-chat-web-equipo.out` 11-13 |
| 4 | `comandos` | Guarda un comando de solo lectura conversando; las reglas lo aprueban; luego se usa al preguntar. | `2-comandos-consultas.out` 5, 8, 10-12, 39-43 |
| 5 | `consultas` | Consulta web: elige la página y saca los datos en JSON. | `2-comandos-consultas.out` 44, 47, 49-50, 64, 66, 69-75 |
| 6 | `preferencias` | «Recuerda que me contestes siempre en frases cortas». | `3-preferencias-documentos.out` 5-8 |
| 7 | `aprende` | Aprende de la carpeta del negocio (Word, Excel, PDF...); dice qué no puede leer (la factura escaneada). | `3-preferencias-documentos.out` 9-16 |
| 8 | `pregunta` | Contesta con lo que dicen los documentos y dice de cuál sale (el precio del pastel, del PDF, con su apartado); lo que no está, lo dice. | `3-preferencias-documentos.out` 17-28 |
| 9 | `buscar` | `/documentos buscar`: de dónde sale un dato, sin preguntar al modelo; aquí, la tabla de precios leída del PDF. | `3-preferencias-documentos.out` 29-35, 41 |
| 10 | `olvida` | «Olvida lo de la extensión»: enseña qué olvida, pide un sí, y en una conversación nueva ya no la da. | `3-preferencias-documentos.out` 42-59 |
| 11 | `recuerda` | `/documentos olvidos` y `/documentos recordar 1` lo deshacen. | `3-preferencias-documentos.out` 61-65 |
| 12 | `final` (6 s) | Aprende de los documentos de tu negocio. Y olvida lo que le pidas. Si un dato no está, te lo dice. El repositorio y la guía. | — |

Los textos de cada escena (rótulo, título y pie) y las líneas que toma están
al principio de `montar.ps1`. El enlace al repositorio de la escena final
está en la plantilla `$final` del mismo fichero.

## Cómo se hace

Es la misma vía que los videos de `D:\PRC Channel Linkedin`: una composición
[HyperFrames](https://hyperframes.heygen.com) (HTML que se renderiza a MP4
fotograma a fotograma, siempre igual) con GSAP para las animaciones. No hay
voz, ni música, ni modelos de pago: el coste es cero.

1. **Capturar** (hace falta el llama-server en marcha, e internet para las
   escenas que buscan). Cada captura lanza el `AI` de verdad con lo tecleado
   ya escrito:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File tests\negocio.ps1 -Crear $env:TEMP\espiga
   robocopy "$env:TEMP\espiga\Panadería La Espiga" D:\MiNegocio /E /MOVE
   powershell -NoProfile -ExecutionPolicy Bypass -File docs\video\capturar.ps1 -Entrada docs\video\capturas\3-preferencias-documentos.txt -Salida docs\video\capturas\3-preferencias-documentos.out
   ```

   Las respuestas del modelo cambian de una vez a otra: si se vuelve a
   capturar, revisa los números de línea de las escenas en `montar.ps1`.
2. **Montar:** `montar.ps1` escribe `index.html` y `compositions\*.html`.
   No se editan a mano: se regeneran.

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File docs\video\montar.ps1
   ```
3. **Revisar y renderizar** (Node; `npx` baja HyperFrames la primera vez):

   ```powershell
   cd docs\video
   npx --yes hyperframes@0.8.221 check
   npx --yes hyperframes@0.8.221 preview
   npx --yes hyperframes@0.8.221 render -o renders\prc-ai-2.0.mp4
   ```

El MP4 no va en git: `docs/video/renders/` está en `.gitignore`.
