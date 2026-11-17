# Historial de cambios de PRC AI 2.0

Qué cambió, por qué y qué se aprendió en cada paso. El cómo se usa está en el
[README](README.md); aquí queda la razón de cada decisión, para no volver a
discutirla sin datos nuevos.

Las fechas son las de los commits. Lo más nuevo va arriba.

---

## 2026-11-17 — Olvidar, y una batería con un negocio entero

Esta entrada y la de documentos, de la rama `documentos`, se fusionaron
juntas en main el mismo día.

**Las peticiones.**

- «También quiero una opción para quitar dicho aprendizaje, o que olvide
  algunos aspectos».
- Después: unos documentos de prueba de todo lo que se había comentado (el
  negocio, sus servicios, empleados, funcionamiento, procedimientos,
  horarios y políticas), y que lo probara yo primero, con una batería de
  conocimiento y otra de procesamiento de documentos.

**Olvidar.** Son reglas en `documentos-olvidos.json`; los ficheros del
usuario no se tocan.

- **Qué se olvida:** todo, una carpeta, un documento, un apartado o un tema.
- **Cómo se pide:** con «olvida lo de los sueldos» o con
  `/documentos olvidar`. Siempre se enseña qué se va a olvidar, con
  ejemplos, y se pide un sí.
- **Cómo se deshace:** con `/documentos recordar`.
- **Un documento olvidado ni se lee,** y lo leído de él se borra del equipo.
- **Un tema** se quitaba al principio con su fragmento entero. Al olvidar
  «pintura» se iba también la fila de «Corte de llaves», que estaba en el
  mismo fragmento. Ahora se quitan solo las líneas del tema, y en una fila
  de tabla solo su dato («Sueldo: 25000»). Si el dato es el primero de la
  fila, se va la fila entera, para no dejar un precio huérfano.
- **El orden de búsqueda importa.** «Permisos» se tomaba por el documento
  «Vacaciones y permisos», porque su nombre lo contiene. Ahora gana lo
  exacto, sea un documento o un apartado.

**La batería, `tests/negocio.ps1`.** Es la Panadería y Cafetería La Espiga,
inventada:

- 13 ficheros en los doce formatos, más un PDF, una imagen y un temporal de
  Word.
- Trampas: datos que no están (sueldos, tarjeta, domicilio, correo) y dos
  sucursales con horarios distintos.
- **Procesamiento (sin modelo, 52 comprobaciones):** lo que se lee de cada
  fichero, que cada una de las 32 preguntas lleve su documento al modelo, y
  olvidar.
  - **El primer fallo era del propio generador:** PowerShell aplanaba las
    listas de párrafos y salían Word rotos. La batería lo cazó.
- **Conocimiento (con Gemma 4 E4B, 34 preguntas, 6,5 s de media):**
  - Dio bien los 26 datos con su documento, incluidas tablas de Word, horas
    de Excel, una pregunta de seguimiento y el texto en Windows-1252.
  - Las 4 que no están contestaron «no viene en los documentos», sin
    inventar.
  - La lista de documentos salió bien, y lo olvidado ya no lo sabía.
  - **Lo que se arregló:** sin internet, a «¿cuál es la capital de
    Francia?» contestó «no tengo esa información». La nota de no inventar
    lo cohibía también fuera de los documentos. Ahora la nota dice que lo
    demás se contesta como siempre, y contestó «París».
  - **Tres fallos más eran de la corrección, no del modelo:** exigía la
    hora de cierre cuando se preguntaba la de apertura, y «prohíbe» no
    casaba por el acento.
- **`tests\negocio.ps1 -Crear <carpeta>`** deja los documentos para probarlos
  a mano. Están hechos para el lector, no para Office: llevan solo el XML
  con el texto, y Word o Excel pueden negarse a abrirlos.

---

## 2026-11-17 — Documentos: contestar con lo que dicen los del negocio

**La petición.** Que la terminal, a partir de una carpeta de ficheros,
«pueda aprender acerca de un tema». El motivo del dueño: «permite
identificar todo acerca de un negocio, sus necesidades, sus servicios, sus
empleados, su funcionamiento interno, los procedimientos establecidos,
horarios de servicio, políticas internas».

**Qué se hizo** (`lib/documentos.ps1`, órdenes `/documentos` y la frase
«aprende de los documentos de D:\...»):

- La carpeta se lee una vez.
- En cada pregunta se buscan los fragmentos que vienen al caso, y viajan
  con ella, cada uno con su fichero.
- El modelo contesta con ellos y dice de qué documento sale el dato.

**Las decisiones:**

- **Buscar, no entrenar.** «Aprender» no puede ser reentrenar el modelo: en
  un equipo modesto no se puede, y un modelo ajustado con unos documentos
  los mezcla y rellena los huecos inventando. Eso choca con la primera
  prioridad del dueño, que es no dar nunca un dato falso. Buscando, cada
  dato sale de un fichero que se nombra, y lo que no está se dice.
- **Búsqueda por palabras, sin embeddings.**
  - Los embeddings habrían exigido arrancar llama-server con `--embeddings`
    o con un segundo modelo, y ese servidor solo lo reinicia el dueño.
  - Un modelo de 4B tampoco da buenos vectores.
  - BM25 sobre las palabras recortadas no pide nada más (sin acentos, sin
    plural ni género, sin las terminaciones verbales -an/-en/-ar...) y
    tiene unos pocos sinónimos de negocio.
- **Cuándo viajan los fragmentos.** El mejor fragmento tiene que traer una
  palabra de la pregunta que no salga en media colección, y al menos la
  quinta parte del peso de la pregunta. Se prefirió mandar de más:
  - unos fragmentos que no vienen al caso cuestan unos segundos, y el
    modelo los ignora;
  - una pregunta del negocio contestada sin ellos sale inventada.
  - El primer umbral, la mitad del peso, dejaba fuera «¿de qué color es el
    uniforme?», donde «color» no sale en ningún documento.
- **Las tablas, sin emparejar a ciegas.** Una primera fila solo se toma por
  cabecera («Precio: 50») si es todo texto y alguna columna trae cifras
  debajo. Si no, va como «Columnas (primera fila)» y cada fila tal cual.
  Una tabla de dos columnas «Gerente | Ana Pérez» tomada por cabecera
  habría dado «Gerente: Cajero». En Excel, las fechas y horas se convierten
  según el formato de la celda: 45971 tal cual no es «10/11/2025».
- **Formatos sin instalar nada.** Word, Excel, PowerPoint y OpenDocument son
  zips con XML, y se leen con lo que trae .NET. RTF, CSV (con punto y coma,
  como guarda el Excel en español), HTML y texto se leen en UTF-8 o
  Windows-1252. Los PDF no: sin una biblioteca, sus tipos de letra dan texto
  roto en muchos ficheros, y un texto roto acabaría en datos falsos. Se
  dice cuáles no se leyeron y qué hacer.
- **Solo a los proveedores locales.** Los documentos de un negocio llevan
  datos de empleados y clientes. A xAI u OpenAI no se mandan salvo
  `/documentos nube on` o `"documentos_nube": true`.

**Velocidad** (400 documentos inventados, 2,4 MB de texto):

- La primera versión tardaba 13 s en leerlos y otros 11 s en cada arranque,
  para montar el índice palabra a palabra en PowerShell.
  - El recorte de palabras pasó a expresiones de .NET sobre el texto
    entero. Bajó a 7 s.
  - El índice pasó a ser un solo texto con un fragmento por fila. Cada
    palabra se busca de una pasada. Bajó a 4 s.
  - Ahora el índice se guarda, y si nada cambió se carga en 0,3 s.
- Hoy: 5 s la primera vez, 0,3 s al arrancar, unos 0,2 s por pregunta.
- **Un fallo de esa prisa:** los fragmentos se armaban con `AppendLine`,
  que en Windows mete `\r\n`. Al guardar el índice, cada `\r` partía un
  fragmento en dos líneas y el índice no volvía a cargar. Lo cazó la prueba
  que compara el índice guardado con el recién hecho.

**Lo que se midió con Gemma 4 E4B:**

- **Las preguntas:** 22 preguntas seguidas sobre la ferretería inventada de
  las pruebas (`tests\documentos.ps1 -Crear`), entre 3 y 12 s cada una.
- **Lo que salió bien:**
  - Horarios, la gerente y su turno, un precio y su fecha, la política de
    devoluciones, las vacaciones, quién cierra la caja los sábados (una
    tabla de Word), las existencias (una hoja de OpenDocument) y el
    proveedor (una página HTML), cada dato con su documento.
  - «¿y los domingos?» se buscó junto con la pregunta anterior.
  - «¿Cuánto gana Luis Mora?»: «no especifica su salario», sin inventarlo.
  - «¿Cuál es la capital de Francia?» no sacó documentos.
- **Tres arreglos tras la primera vuelta:**
  - **«¿Qué hora es?»** mandaba fragmentos de horarios y tardaba el doble.
    Ahora las preguntas del reloj no buscan en los documentos.
  - **«¿Venden cemento?»** no encontraba «Vendemos», y el modelo, en vez de
    usar la herramienta, preguntó «¿quieres que use consultar_documentos?».
    Ahora se recortan también los verbos, y la nota le dice que la use sin
    preguntar. Contestó «los documentos no indican si venden cemento».
  - **«¿Qué documentos tienes?»:** dijo que el PDF no se pudo leer «porque
    está dañado», y no lo está. La lista no llevaba el motivo y lo inventó.
    Ahora lo lleva.
- **Abierto:** a «¿a qué hora abren los sábados?» dio la hora de la bodega,
  que estaba en otra hoja del Excel. La de la tienda también le llegó y
  coincidía. Con dos horarios distintos podría elegir mal.

**Pruebas:** `tests/documentos.ps1`, 94 comprobaciones sin modelo.

- Cubren cada lector, los fragmentos y lo que se relee y lo que no: un
  fichero cambiado, uno nuevo, uno borrado y una carpeta que no está.
- También el índice guardado, 15 preguntas que deben encontrar su
  fragmento y 6 que no deben sacar ninguno, las peticiones conversadas y el
  orden de las órdenes `/documentos`.
- Los documentos se crean al vuelo, así que en el repositorio no hay
  binarios.
- La web (Gemma Portable) no tiene documentos: es solo de la terminal.

---

## 2026-11-16 — Consultas web: datos de una página, en JSON

**La petición.** «Agrégame un comando para obtener los datos del último
sorteo de la lotería de Nicaragua. Podrías usar curl para consultarlo a
través de DuckDuckGo […] y entregármelos en JSON». Hacía falta una consulta
fácil de definir que lea el HTML de una página fija y saque datos concretos.

**Por qué no bastaban los comandos guardados.** Las reglas ya dejan
`Invoke-WebRequest` contra una dirección fija, pero detrás solo pueden ir
filtros como `Select-String`, que devuelven filas de HTML, no datos. Y un
comando que trocee HTML necesitaría variables o bloques `{ }`, que las
reglas prohíben con razón.

**Qué se hizo: un segundo tipo de comando guardado** (`"tipo": "web"` en
`comandos.json`, código en `lib/consultas.ps1`). Lleva la dirección y una
lista de campos, cada uno con su **rótulo**: el texto fijo que en la página
va justo antes del dato («Ganador:» → «12010»). Se lista, se ejecuta y
dispara el atajo igual que los demás.

**Las decisiones:**

- **Rótulos, no expresiones regulares.** Un rótulo se escribe sin saber
  programar, el modelo lo copia de la página y el programa comprueba que
  está en ella. Además, solo se buscan textos: ninguna expresión que venga de
  fuera puede dejar colgada la consola.
- **El modelo no saca los datos.** Solo propone los rótulos al guardar la
  consulta. Los valores los saca el programa, tal cual vienen en la página
  («09065» conserva su cero), y los ves antes de guardarla. Al ejecutarla, el
  modelo no interviene hasta redactar la respuesta.
- **Bloques.** El rótulo que sale primero en la página marca dónde empieza
  cada bloque, y los demás datos se buscan solo dentro del suyo. Si al
  primer sorteo le falta un dato, sale `null` en vez del dato del sorteo
  siguiente. Así lo comprueba la página de prueba (`tests/datos/consulta.html`).
- **DuckDuckGo se usa para encontrar la página, al guardarla.** Después se
  va directo a ella. Así es más rápido (1,7 s en leer la página de la
  lotería y sacar los datos) y la fuente es siempre la misma: si cada vez se
  tomara el primer resultado de una búsqueda, podría salir otra lotería.
- **Sin curl.** La página se lee con lo mismo que usa la búsqueda
  (`Get-AIWebPage`): sin instalar nada, con plazo, tope de tamaño, solo
  `https` a servidores públicos y cada redirección revisada antes de
  seguirla.
- **Cuándo es una consulta web.** Cuando la petición del comando habla de
  internet, de una página, de una web, de DuckDuckGo o de curl, o trae una
  dirección. Si un comando de PowerShell no sale, escribir «web» lo intenta
  en internet.

**Lo que se midió con Gemma 4 E4B y la frase del dueño, tal cual:**

- **Primer intento: un dato falso a un Enter de distancia.** El modelo
  buscó «API lotería Nicaragua datos sorteo JSON», porque la frase pedía
  JSON. El primer resultado era `loteriasapi.com`, una API de la lotería de
  **España**, con fecha 2026-09-26. Además, como esa página es JSON, los
  valores salían mal cortados (`": "2026-09-26",`).
  - **Arreglo:** la búsqueda ya no lleva el formato, «API», «curl» ni
    «DuckDuckGo» (lo pide la instrucción y lo quita el programa).
  - **Arreglo:** en una página JSON, el valor es lo que va entre comillas.
- **Después:** buscó «Resultados sorteo lotería Nicaragua página oficial»,
  y los cinco resultados eran de `loterianacional.com.ni`. Los rótulos
  propuestos fueron `Sorteo`, `Ganador:`, `Premio:`, `Fecha:` y `Sucursal:`.
  Sacó el sorteo 2304 exacto y el diálogo duró 19 s.
- **«Quita la sucursal y dame los últimos 3 sorteos»:** quitó el campo y
  puso `registros=3`, a la primera.
- **Al preguntar** «¿cuál fue el último sorteo de la lotería de
  nicaragua?», el atajo ejecutó la consulta y la respuesta copió los cinco
  datos con la página de origen (9 s). Pidiéndolo «en json», devolvió el
  JSON sin tocarlo.

**Pruebas:** `tests/consultas.ps1`, 58 comprobaciones sin red y 6 más con
`-Red`, contra la página de verdad. `tests/agregar.ps1` ya contaba las
órdenes de `/comando` y su orden: ahora son ocho, y se comprueba que
`/comando web` a medias da el modo de uso y no ejecuta nada.

**La rama salió de `hora-y-preferencias`** porque las dos tocan los mismos
ficheros (el atajo, `comandos.ps1`, el README). Se fusionaron juntas en main.

---

## 2026-11-16 — Una hora inventada, y las preferencias

**La incidencia.** El dueño preguntó tres veces seguidas «dame la fecha y
hora, y el precio de btc, en un formato json». Tenía guardados `fecha-hora`
(`Get-Date`, local) y `precio-btc` (la API de Coinbase). La tercera respuesta
decía «8:04:07 AM» cuando ya eran más de las 8:05: ni se ejecutó el comando
ni se miró el reloj. El modelo copió su respuesta anterior y cambió los
segundos. El precio era también el de antes.

**Por qué pasó.**

- **El atajo no saltó.** La pregunta nombraba los dos comandos, pero el atajo
  tiene un freno para las compras que salta con «precio», y «precio» es parte
  del nombre `precio-btc`. Además, el atajo solo ejecutaba un comando.
- **Sin atajo, el modelo decide.** Unas veces pedía los dos comandos y otras
  no pedía nada. En la memoria solo quedan la pregunta y la respuesta, no lo
  leído, y la respuesta anterior tenía los datos a la vista.

Se reprodujo con la sesión del dueño (diez turnos): en el décimo, Gemma 4 E4B
contestó «8:30:19» a una pregunta hecha a las 8:30:30, sin ejecutar nada.

**Qué cambia.**

- **El atajo ejecuta hasta dos comandos por pregunta**, el mismo tope que
  cuando los pide el modelo.
- **Los frenos del atajo** miran la pregunta sin las palabras de los nombres
  que encajan. «Cuál es el mejor precio de btc» sigue frenado por «mejor».
- **Una nota nueva al modelo** cuando hay turnos anteriores: las horas y los
  precios de respuestas anteriores eran de aquel momento, así que no se
  copian. Se vuelven a leer con el reloj de la nota o con la herramienta.

Con el arreglo, la misma sesión de diez turnos ejecuta los dos comandos en
cada una de las tres preguntas, y la hora es la del momento.

**Las preferencias.** El dueño pidió una memoria de preferencias: el uso de
comandos, dólares para las cifras y córdobas para la lotería de Nicaragua.

- **Cómo se guardan:** con «recuerda que...» (y otros arranques parecidos) o
  con `/preferencia agregar`. Siempre se pide confirmación antes de guardar.
- **Dónde viven:** en `preferencias.json`, como mucho 12 de hasta 200
  caracteres.
- **Cómo llegan al modelo:** al final de la instrucción de sistema y, después
  de una búsqueda, otra vez detrás de los resultados. Solo con la instrucción
  de sistema, Gemma 4 E4B las pasaba por alto al redactar con una página
  delante.
- **El modelo no tiene herramienta para guardarlas**, para que una página web
  no pueda colarle una preferencia que dure.
- **Sin preferencias, la nota avisa** de que el modelo no puede recordar nada
  por su cuenta. A «te lo explico para que lo recuerdes» contestaba como si
  fuera a recordarlo; ahora dice que no puede y explica cómo guardarlo.

**Lo que se arregló de paso.**

- **Un fallo que la búsqueda dejaba apagado.** Con dos búsquedas en un turno,
  la petición no cabía en los 4096 tokens del servidor local. El programa
  tomaba ese HTTP 400 por «el modelo no acepta herramientas» y apagaba la
  búsqueda el resto de la sesión: las dos preguntas siguientes contestaron
  «No puedo buscar». Ahora la segunda búsqueda de un turno lee menos (una
  página de 1200 caracteres). Si aun así no cabe, se recortan a la mitad los
  resultados del turno y se repite, como mucho dos veces. Se probó con una
  búsqueda falsa de 26.000 caracteres: contestó con el dato, y la pregunta
  siguiente volvió a buscar.

**Lo que no se consiguió.** Con «cifras en dólares» guardado y una página en
córdobas, Gemma 4 E4B casi nunca busca el tipo de cambio:

- da la cifra de la fuente y ofrece convertirla;
- o, con un precio en dólares a mano, da ese;
- la vez que sí lo buscó fue la que desbordó el contexto.

En ningún caso inventó un cambio. Con la lotería sí respeta los córdobas.

**Cómo se probó.**

- `tests\probar.ps1 -Red -Modelo`: 6 de 6 pruebas sin fallos. Son 244
  comprobaciones de comandos (cinco nuevas sobre el atajo), 37 de preferencias
  (prueba nueva), 41 del diálogo y los nueve casos de `/comando agregar`.
- Aparte, con un arnés:
  - la confirmación en el modo interactivo;
  - el duplicado;
  - el fichero roto, que no se sobrescribe;
  - `/preferencia quitar` hasta dejar la lista vacía. La primera versión
    fallaba al quitar la última.

---

## 2026-11-15 — Las pruebas, dentro del repositorio

**Qué cambia.** Hay una carpeta `tests/` nueva. `tests\probar.ps1` pasa las
pruebas y sale con el número de las que fallan. Sin opciones son cuatro
pruebas sin modelo, de unos 20 segundos. `-Red` añade peticiones a internet y
`-Modelo` añade el diálogo y `/comando agregar` con el modelo de verdad. El
README lo explica en «Pruebas». `tools/build.ps1` también pone el BOM a los
`.ps1` de `tests/`.

**Por qué.** Las pruebas de los comandos guardados, de los datos del equipo y
del diálogo se escribieron mientras se hacían esas funciones, pero vivían en
una carpeta temporal de la sesión de trabajo y se iban a perder. Sin ellas,
un cambio en las reglas no se podía comprobar sin rehacerlas.

**Qué se tocó al pasarlas.**

- Cada prueba encuentra sola la raíz del repositorio y sus datos.
- Las tres que no lo hacían salen ahora con su número de fallos.
- En la salida, el usuario se llama «Usuario».
- Los ejemplos ya no llevan datos reales: la ruta de la clave SSH es
  `C:\Users\usuario\` y la frase de la memoria dice «me llamo Ana».
- La comprobación de `hostname` compara con `$env:COMPUTERNAME`, así que no
  deja el nombre del equipo en ningún fichero.
- `tests\agregar.ps1` se había quedado atrás. Cuando el diálogo se partió en
  piezas, `Add-AIComando` pasó a usar `Show-AIComandoRevision` y
  `Save-AIComandoNuevo`, y la prueba no las cargaba. Ahora las carga, y si
  falta una función lo dice en vez de romperse a mitad.

**Cómo se probó.**

- Sin modelo y con `-Red`: cero fallos en las cuatro pruebas. Son 239
  comprobaciones de comandos (235 sin `-Red`), 60 frases del equipo, los datos
  del equipo y 23 peticiones.
- Con `-Modelo` y Gemma 4 E4B: cero fallos en las cinco pruebas.
  - Las once escenas del diálogo dan 41 comprobaciones bien, en 130 s.
  - Los nueve casos de `/comando agregar` pasan en 29 s.

---

## 2026-11-15 — Gemma por defecto

**Commit:** `636d930`

**Qué cambia.** Sin `-Provider`, sin `AI_PROVIDER` y sin `settings.json`, `AI`
arranca con `gemma` (Gemma 4 E4B en el llama-server local de
`http://127.0.0.1:8080`). Antes arrancaba con `xai` (Grok).

**Por qué.** Lo pidió el dueño. Además `xai` sin `XAI_API_KEY` no arrancaba y
mandaba la conversación a la nube. `gemma` no pide clave y nada sale de la
laptop, salvo las búsquedas en internet cuando hacen falta.

**Qué no cambia.** El orden de precedencia sigue siendo `-Provider`,
`AI_PROVIDER`, `settings.json` y, si no hay nada, el de fábrica. Grok sigue
disponible con `-Provider grok`.

---

## 2026-11-15 — Guardar un comando conversando

**Commits:** `26f0b63` (el diálogo) y `d67fcd6` (la guía del modelo).

**Qué cambia.** Basta pedirlo en el chat («agrégame un comando para ver mi IP
pública») y se abre un diálogo de preguntas fijas:

1. Si no se da el comando, el chat pregunta qué dato se quiere y el modelo
   propone uno. Lo propuesto pasa por las mismas reglas que lo tecleado; si no
   las pasa, se le dice por qué y se le dan dos intentos más.
2. Se enseña el comando, el veredicto de las reglas, a qué servidor sale y la
   explicación del modelo, y se pregunta si vale o qué cambiarle.
3. Se piden el nombre y para qué sirve, con una sugerencia que se acepta con
   Enter.
4. Las preguntas se cierran con un resumen y **una** confirmación.
5. Se prueba el comando y se enseña el resultado. Solo se guarda si la prueba
   funciona y devuelve algo.

«cancelar» corta el diálogo en cualquier momento.

**Decisiones.**
- **Las preguntas son fijas**, no las redacta el modelo, para que el diálogo
  no dependa de que el modelo se acuerde de pedir confirmación.
- **Una prueba que no devuelve nada cuenta como fallo.** Antes se guardaba un
  comando que no servía para nada.
- **Lo abren las frases que empiezan por «agrega», «añade», «guarda» o
  «registra» y nombran un comando.** «Crea un comando de git para...» no lo
  abre, porque pide que se escriba uno, no que se guarde.
- **El nombre que propone el modelo se limpia** de verbos y relleno y se deja
  en dos palabras, porque es lo que dispara el atajo. Con `ip-publica-obtener`,
  «¿cuál es mi IP pública?» no lo habría disparado.
- **La guía del modelo pide el dato por su propiedad, no buscando un texto.**
  Para «cuánto lleva encendido el equipo», Gemma 4 E4B proponía
  `systeminfo | Select-String "Fecha de último arranque"`, que en un Windows
  en inglés no devuelve nada (3 de 3). La guía dice ahora que ese texto cambia
  con el idioma y trae ejemplos con `Get-CimInstance`. Con eso propone
  `Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty LastBootUpTime`
  (3 de 3).

**Cómo se probó.** Once conversaciones con el modelo de verdad y las
respuestas del usuario ya escritas: dato sin comando, cambios, comando y
nombre dados, petición dañina, comando dañino pegado, «no» final, cancelar a
mitad, prueba que falla, prueba vacía y nombre repetido. Además, 23 frases
para comprobar qué abre el diálogo y qué no. Todas terminaron como debían.
El dueño lo probó después tecleando en la consola y funcionó.

---

## 2026-11-15 — Comandos de solo lectura guardados

**Commit:** `a7b4b1b`

**El problema.** «¿Cuál es mi IP pública?» no tenía respuesta. No está en el
equipo: hay que preguntársela a un servidor de fuera (por ejemplo
`Invoke-RestMethod -Uri https://api.ipify.org`).

**Qué cambia.** El usuario guarda comandos de PowerShell de solo lectura
(`/comando agregar <nombre> <comando>`, y desde `26f0b63` también
conversando) y el modelo los pide por su nombre con la herramienta
`comando_guardado`.

**La decisión principal: las reglas deciden, el modelo solo explica.** El
dueño pidió que «el chat verifique» si un comando es peligroso. Se acordó que
el veredicto no lo dé el modelo, porque un modelo de 4B se puede equivocar o
dejarse convencer, sino unas reglas fijas en `lib/comandos.ps1`:

- **El texto se analiza con el analizador de PowerShell**
  (`Parser::ParseInput`). Tiene que ser una sola canalización con argumentos
  constantes, y la lista de nodos permitidos es cerrada: fuera variables,
  sustituciones, paréntesis, bloques, métodos, tipos, redirecciones,
  comentarios, `;`, `&` y `.`.
- **Cada cmdlet sale de una lista cerrada** (`$AI_CMD_CMDLETS`), con su nombre
  completo y desde un módulo de la carpeta de Windows. Los programas
  (`$AI_CMD_EXES`) tienen que estar en System32, firmados por Microsoft y con
  formas de argumentos permitidas.
- **Cada parámetro sale de la lista de su comando.** Las abreviaturas y los
  posicionales los resuelve `StaticParameterBinder` antes de comparar.
- **Lo que sale a internet:** https, dirección fija, servidor público, GET,
  sin redirecciones y solo como primer comando.
- **Fuera a propósito:** leer ficheros, el registro, el portapapeles y los
  sucesos, y `ForEach-Object` (llamaría a métodos).

**El texto no se ejecuta nunca.** De la validación sale un plan, y lo que se
ejecuta es el plan, pieza a pieza (`AddCommand` / `AddParameter`), en un
espacio de ejecución aparte, con plazo de 15 s y un tope de 4.000 caracteres
de salida. Cada ejecución vuelve a pasar las reglas, así que un
`comandos.json` cambiado a mano no cuela nada. Al arrancar, los comandos se
cargan sin validar (costaba 0,8 s); se validan al usarlos.

**Otros detalles.**
- Tras la salida de un comando guardado no se ofrecen más herramientas en ese
  turno.
- El atajo se dispara cuando todas las palabras del nombre aparecen en la
  pregunta, en cualquier orden.
- La salida va al modelo con la indicación de no añadirle unidades: con los
  segundos de procesador, el modelo les ponía «%».

**Cómo se probó.** 158 comandos contra las reglas (29 pasan y 129 se
rechazan; 239 comprobaciones contando la red), la ejecución, el guardado y un
`comandos.json` manipulado. En vivo, con Gemma 4 E4B, Gemma 3 4B y Qwen3 8B.

**Para ampliar lo permitido** se añaden entradas a `$AI_CMD_CMDLETS` o a
`$AI_CMD_EXES`. Nada más.

---

## 2026-11-15 — Lo que el equipo ya sabe

**Commit:** `8aa6224`

**El problema.** El dueño preguntó en la terminal por su IP y el modelo le
contestó que no podía saberla. La misma función ya existía en la interfaz web
de Gemma Portable, pero **las dos aplicaciones tienen código separado**: lo
hecho en una no llega a la otra.

**Qué cambia.** `lib/equipo.ps1`, con tres piezas:

1. **El reloj** va en la instrucción de sistema de cada petición: hora, fecha
   y zona horaria del equipo.
2. **El atajo:** si la pregunta pide a las claras un dato de este equipo, se
   lee antes de preguntar al modelo y viaja pegado a la pregunta, solo en esa
   petición.
3. **La herramienta `datos_equipo`**, para lo que el atajo no reconoce.

Son ocho lecturas fijas y de solo lectura: batería, red, equipo, sistema,
procesador, memoria, disco y gráfica. Del modelo llega el nombre de una
lectura, nunca una orden, y ninguna lectura sale a internet. Lo que Windows
no da se dice que no se pudo leer.

**Errores encontrados y corregidos.**
- **El atajo dio un dato falso.** «¿Qué procesador trae la Lenovo Legion 5?»
  se contestó con el procesador de esta laptop. Ahora el atajo exige el tema
  **y** una marca de «este equipo» («mi», «tengo», «esta laptop»), y se
  anula si el mensaje nombra otro aparato, una marca, a otra persona o una
  computadora cualquiera, o si pide una explicación, un cómo se hace, código o
  una compra.
- **Con la herramienta a la vista, E4B dejó de buscar** «¿cuánta batería
  tiene el iPhone 15?» (3 de 3). Si se nombra otro aparato no se lee nada ni
  se ofrece la herramienta.
- **E4B volvía a pedir la herramienta** después del atajo. Ya no se le
  ofrece si el atajo ya leyó.
- **El modelo repetía la nota del reloj** («No hace falta internet.»). Se
  reescribió la nota.
- **La IP pública:** la línea dice que no está en el equipo, porque la
  asigna el proveedor de internet, y que la de arriba es la local.

**Gemma 3 4B se queda sin herramientas** (`Tools = $false` en
`lib/providers.ps1`). No sabe pedirlas: con `buscar_web` a la vista no
buscaba y contestaba «Según búsqueda web, el dólar está a 37 córdobas» sin
haber buscado (3 de 3), y con `datos_equipo` inventaba una IP y un porcentaje
de batería. Sin herramientas dice que no puede buscar, y `/buscar` y el atajo
le siguen sirviendo.

**Cómo se probó.** En vivo, con Gemma 4 E4B (34 preguntas, con y sin
internet), Gemma 3 4B (18) y Qwen3 8B (3). Además, 60 frases para el
reconocimiento del atajo.

---

## 2026-11-14 — Búsqueda en internet

**Commit:** `5ceef78`

El modelo puede llamar a `buscar_web` (DuckDuckGo HTML y las dos primeras
páginas legibles), pero solo si en ese momento hay salida a internet. Si no
la hay, contesta sin buscar y lo avisa. Las fuentes se enseñan al final.
Nuevos: `/buscar`, `/web on|off`, `-NoWeb`, `"web": false` y la línea
Internet en `-Check`.

---

## 2026-11-14 — `gemma` pasa a ser Gemma 4 E4B

**Commit:** `3f6ca2b`

La evaluación de Gemma Portable comparó los modelos sobre 181 preguntas con
respuesta libre. Gemma 4 E4B acertó el 96,7 % con 1 dato falso, y Gemma 3 4B
el 63,5 % con 57, a cambio de unos 7,6 s por turno en vez de 4–5. El
proveedor `gemma` pide desde entonces `gemma-4-e4b` (alias `gemma4`, `e4b`,
`llama`, `llamacpp`), y Gemma 3 4B queda como la entrada `gemma3`.

---

## 2026-10-08 — Modelos locales sobre llama-server

**Commit:** `d496be4`

Entradas `gemma` y `qwen` contra un mismo llama-server en modo router
(`127.0.0.1:8080`), con plazo de espera por proveedor (`Timeout`) y un texto
de ayuda cuando el servidor está parado (`Hint`). Un flujo que se corta sin
terminar es un error, no una respuesta válida. El `model` de `settings.json`
solo se aplica a su proveedor: `grok-4.3` no existe en un servidor local.

---

## 2026-09-03 — PRC AI 2.0

**Commits:** `72d4517`, `3da8c4b` y `373b2fc`

Reescritura completa sobre PowerShell 5.1, con un núcleo HTTP propio y
streaming SSE, una tabla de proveedores (OpenAI, xAI, Ollama), README, claves
en `HKCU\Environment` con `Set-AIKey` y licencia MIT.

---

## Reglas de trabajo que salieron de todo esto

- **Ningún dato falso.** Ante la duda, el programa dice que no lo sabe o que
  no lo pudo leer. Un atajo que pega datos a la pregunta tiene que exigir una
  marca de «este equipo».
- **Lo que decide la seguridad es código fijo, no el modelo.** El modelo
  explica y propone; las reglas aceptan o rechazan.
- **Cada `.ps1` necesita BOM.** Después de editar hay que pasar
  `tools/build.ps1`. Los comentarios y las expresiones regulares van en ASCII;
  las frases para el usuario pueden llevar acentos en minúscula.
- **Las dos aplicaciones (la web y esta terminal) no comparten código.** Una
  función nueva de cara al usuario hay que pensarla para las dos.
- **Para probar el modo una-respuesta desde Bash** hay que pasar `</dev/null`;
  si no, se queda esperando la entrada estándar.

## Lo que sigue sin probar

- OpenAI, xAI y Ollama con las herramientas nuevas (búsqueda, datos del
  equipo y comandos guardados).
- PowerShell fuera de Windows.
