# Video: PRC AI 2.0 en 2 minutos

**Publicado:** [PRC AI 2.0 en YouTube](https://www.youtube.com/watch?v=FhrSBxF6vFE),
en el canal A.M., público, el 2026-11-18. Se subió marcado como contenido
sintético (la voz es generada por IA), con el subidor de `D:\PRC Channel
Linkedin` (`services\security-alerts\lib\youtube.mjs`), que antes de subir
comprueba que el token es de ese canal. Si se vuelve a renderizar, el video
de YouTube no cambia: hay que subirlo de nuevo.

**En inglés:** [PRC AI 2.0 en YouTube](https://www.youtube.com/watch?v=7vM_9QslKjo),
en el mismo canal, público, el 2026-11-19 (2:09). Ver «El video en inglés»,
al final.

Un video corto (2:13, 1920×1080, 30 fps, en español) con lo más relevante
de PRC AI 2.0, narrado. La voz cuenta lo que hace cada escena, así que se
sigue sin leer la terminal; y como en LinkedIn el video arranca sin sonido,
todo lo que dice también está escrito en pantalla (el título y el pie de
cada escena). No lleva música.

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

## La narración

Está en [`narracion.txt`](narracion.txt), una línea por escena. No es salida
del programa: es la voz que la presenta, y solo cuenta lo que se ve en la
escena (el precio que dice es el de la captura: C$ 650).

- **Escrita como se dice:** las cifras y las siglas van en letras
  («seiscientos cincuenta córdobas», «pe erre ce, a i»), porque la voz lee lo
  que hay.
- **La voz** es la del canal de LinkedIn (`D:\PRC Channel Linkedin`,
  `services\daily-impact\lib\voice.mjs`): `gpt-4o-mini-tts` con la voz
  `cedar`, en español latinoamericano neutro, con un estilo más tranquilo que
  el de las noticias y tempo 1,1 (allí, 1,2). `voz.ps1` quita el silencio de
  los bordes, comprime y deja cada toma a −16 LUFS.
- **Se comprueba que dice el guion.** Whisper transcribe cada toma y se
  compara con el texto: si no se oye el 90 % de las palabras, o el final, la
  toma se repite (tres veces como mucho). La primera versión de «pregunta»
  terminaba en «No lo inventa.», y en las tres tomas esa frase no se oía; se
  reescribió para que no quede sola al final.
- **La voz manda en la duración:** cada toma empieza medio segundo después de
  su escena, y si no cabe, la escena se alarga quedándose en su último
  fotograma. Por eso el video pasa de 1:59 a 2:13.
- **Las tomas van en git** (`assets/voz/*.mp3`, 1,7 MB) con `voz.json`, que
  guarda de cada una su duración, lo que oyó Whisper y una huella del texto:
  el video se vuelve a montar sin pagar otra vez la voz, y `voz.ps1` solo
  rehace las líneas que cambiaron.

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
fotograma a fotograma, siempre igual) con GSAP para las animaciones. Lo único
de pago es la voz: unos 2 minutos, a 0,015 USD el minuto de voz y 0,006 el de
transcripción, unos 5 centavos con las tomas repetidas.

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
2. **Poner voz** (hace falta `OPENAI_API_KEY` en el entorno, y ffmpeg).
   Solo si cambió `narracion.txt`; `-Solo final` rehace una toma que dice el
   guion pero suena mal:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File docs\video\voz.ps1
   ```
3. **Montar:** `montar.ps1` escribe `index.html` y `compositions\*.html`,
   con la voz de `assets\voz` (sin ella, el video sale mudo). No se editan a
   mano: se regeneran.

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File docs\video\montar.ps1
   ```
4. **Revisar y renderizar** (Node; `npx` baja HyperFrames la primera vez):

   ```powershell
   cd docs\video
   npx --yes hyperframes@0.8.221 check
   npx --yes hyperframes@0.8.221 preview
   npx --yes hyperframes@0.8.221 render -o renders\prc-ai-2.0.mp4
   ```

El MP4 no va en git: `docs/video/renders/` está en `.gitignore`.

## El video en inglés

El mismo video, con el programa en inglés: es otro proyecto HyperFrames en
[`en/`](en), con sus capturas en [`capturas/en/`](capturas/en), su
narración en [`en/narracion.txt`](en/narracion.txt) y su voz en
`en/assets/voz/`. La regla es la misma: lo que sale en la terminal es salida
real del programa (con `AI_LANG=en`), y solo cambia el ritmo.

- **El negocio** es una cafetería inventada de EE. UU. con dos locales,
  Linden Street Coffee House, de `tests\negocio.ps1 -Crear <carpeta> -Idioma en`,
  con precios en dólares; el catálogo de pasteles es un PDF y la factura
  escaneada es la trampa.
- **La consulta web** lee la población y la superficie de Seattle de
  seattle.gov. La dirección se pega en la lista de páginas, que el programa
  permite («paste another address»): la búsqueda devolvía páginas distintas
  cada vez, y una (census.gov) contestaba 403.
- **La negrita del modelo** (`**45°F**`) sale en negrita, como en la
  terminal: en la captura, con la salida redirigida, venía con los
  asteriscos. Las capturas en español no tienen ninguna.
- **La voz** es la misma (`cedar`), con el estilo en inglés de EE. UU.;
  Whisper comprueba cada toma en inglés. Las cifras van en cifras, como las
  escribe Whisper.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\negocio.ps1 -Crear $env:TEMP\linden -Idioma en
robocopy "$env:TEMP\linden\Linden Street Coffee House" D:\MyBusiness /E /MOVE
powershell -NoProfile -ExecutionPolicy Bypass -File docs\video\capturar.ps1 -Idioma en -Entrada docs\video\capturas\en\3-preferences-documents.txt -Salida docs\video\capturas\en\3-preferences-documents.out
powershell -NoProfile -ExecutionPolicy Bypass -File docs\video\voz.ps1 -Idioma en -Dir docs\video\en
powershell -NoProfile -ExecutionPolicy Bypass -File docs\video\montar.ps1 -Idioma en
cd docs\video\en
npx --yes hyperframes@0.8.221 render -o renders\prc-ai-2.0-en.mp4
```

Las escenas en inglés (rótulo, título, pie y las líneas de cada captura)
están en `montar.ps1`, en el bloque `if ($Idioma -eq 'en')`.
