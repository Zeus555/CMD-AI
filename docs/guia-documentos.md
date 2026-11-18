# Guía: que la terminal conteste con los documentos de tu negocio

Esta guía es para quien lleva un negocio y quiere preguntarle a la terminal
`AI` cosas como «¿a qué hora abre la sucursal Norte el domingo?» o «¿cuántos
días de vacaciones me tocan?», y que conteste con lo que dicen **sus propios
documentos**. No hace falta saber de informática. El detalle técnico está en
la sección [«Documentos» del README](../README.md#documentos).

Los ejemplos de esta guía son salidas reales del programa con Gemma 4 E4B,
el modelo local, y una panadería inventada, la Panadería y Cafetería La
Espiga, la misma que usan las pruebas (la conversación entera está en
[`docs/video/capturas`](video/capturas/3-preferencias-documentos.out)). Donde
pone `Usuario >`, en tu pantalla saldrá tu nombre de usuario de Windows.

## Lo que hace y lo que no

- **Lee tus documentos y contesta con lo que dicen,** y te dice de qué
  documento sale cada dato.
- **Si algo no viene en tus documentos, te lo dice** en vez de inventarlo.
- **No cambia tus ficheros,** ni los borra, ni los mueve.
- **Todo se queda en tu equipo.** Con el modelo local (el que viene por
  defecto) nada sale a internet.
- **No «aprende» como una persona.** En cada pregunta busca los trozos de tus
  documentos que vienen al caso y se los enseña al modelo junto con la
  pregunta. Por eso, si cambias un documento, la próxima respuesta ya usa lo
  nuevo.

## 1. Prepara la carpeta

1. **Haz una carpeta para el negocio,** por ejemplo `D:\MiNegocio`. Puedes
   crear subcarpetas dentro (`Recursos humanos`, `Procedimientos`...): se
   leen todas.
2. **Pon dentro lo que quieras que sepa:** quiénes sois, servicios y precios,
   horarios, empleados y sus turnos, vacaciones y permisos, reglamento,
   procedimientos (apertura, cierre, quejas, pedidos), proveedores,
   inventario, metas...
3. **No pongas lo que no quieras que conteste.** Si un documento trae sueldos
   o datos personales y no quieres que salgan en una respuesta, déjalo fuera
   de la carpeta, o pídele después que lo olvide (ver el apartado 6).
4. **Unos consejos que mejoran mucho las respuestas:**
   - **Nombres claros:** `Horarios de las sucursales.xlsx` mejor que
     `doc1.xlsx`. El nombre del documento sale en cada respuesta.
   - **Títulos en los Word:** usa los estilos «Título 1», «Título 2»... Cada
     título es un apartado, y luego puedes comprobar u olvidar un apartado
     por su nombre.
   - **Tablas con una fila de cabecera:** en Excel, la primera fila con los
     nombres de las columnas (`Producto`, `Precio`, `Vigente desde`). Así
     cada dato va con su rótulo («Precio: 55»).
   - **Una sola versión de cada cosa.** Si hay dos horarios distintos en dos
     documentos, el modelo verá los dos y puede mezclarlos. Borra o saca de
     la carpeta lo viejo.
   - **Escribe las cosas como las preguntarías.** Busca por palabras: si el
     documento dice «uniforme» y preguntas por «la ropa de trabajo», puede no
     encontrarlo.
5. **Topes:** hasta 10 carpetas, 3000 ficheros entre todas y 30 MB por
   fichero. Para un negocio pequeño o mediano sobra.

## 2. Qué formatos sirven

| Sí los lee | Ejemplos |
| --- | --- |
| Word | `.docx` (con sus títulos, listas y tablas) |
| Excel | `.xlsx` (todas las hojas; las fechas y horas salen como fechas y horas) |
| PowerPoint | `.pptx` (cada diapositiva, en orden) |
| LibreOffice / OpenOffice | `.odt`, `.ods`, `.odp` |
| Texto | `.txt`, `.md`, `.csv`, `.html`, `.rtf` y otros de texto |

Las imágenes (fotos, logos) y los demás ficheros se ignoran sin más. Los
temporales de Word (los que empiezan por `~$`) y los ficheros ocultos,
también.

### Los PDF y los formatos viejos

**Los PDF todavía no los lee.** Al leer la carpeta te dirá cuáles hay. Qué
hacer con cada uno:

- **Si tienes el original** (el Word o el Excel del que salió el PDF), pon el
  original en la carpeta. Es lo mejor.
- **Si solo tienes el PDF,** ábrelo con Word (Archivo › Abrir, elige el PDF):
  Word lo convierte. Revisa que se vea bien y guárdalo como `.docx`.
- **O copia el texto:** abre el PDF, selecciona todo (Ctrl+E o Ctrl+A),
  cópialo y pégalo en un Bloc de notas. Guárdalo como `.txt` con un nombre
  claro.
- **Si el PDF es una foto o un escaneo** (no puedes seleccionar el texto con
  el ratón), no tiene texto que leer: hay que pasarlo a mano o con un
  programa de reconocimiento de texto (OCR) y guardar el resultado.

Los formatos viejos de Office tampoco se leen: ábrelos y usa «Guardar como»
con el formato nuevo (`.doc` → `.docx`, `.xls` → `.xlsx`, `.ppt` → `.pptx`).

## 3. Enséñale la carpeta

Abre la terminal, escribe `AI` y pídeselo con tus palabras, con la ruta de
la carpeta:

```
Usuario > aprende de los documentos de D:\MiNegocio
ia > Voy a leer los documentos de D:\MiNegocio para contestarte con lo que dicen. No los
     cambio ni los mando a ningún sitio: lo que lea se queda en este equipo.
ia > Hay 12 que sé leer (3 Word, 2 texto, 2 OpenDocument, 1 PowerPoint, 1 RTF, 1 CSV,
     1 HTML, 1 Excel). También hay 1 PDF, que todavía no sé leer.
ia > ¿De qué tratan, en pocas palabras? Así sé cuándo mirarlos; por ejemplo «mi ferretería:
     servicios, empleados, horarios y procedimientos». (Enter: «MiNegocio»; «cancelar»
     para dejarlo)
Usuario > mi panadería: servicios, precios, empleados, horarios y procedimientos
ia > Listo: leí 12 documentos (26 fragmentos) en 0.7 s. Pregúntame lo que quieras sobre mi
     panadería: servicios, precios, empleados, horarios y procedimientos y te diré de qué
     documento sale cada dato. Si cambias o añades ficheros en la carpeta, los vuelvo a
     leer solo.
ia > Estos no los pude leer:
  Catálogo de pasteles.pdf: PDF: todavía no sé leerlos; guárdalo como Word (.docx) o como texto
```

- **Te pregunta de qué tratan los documentos.** Contesta en pocas palabras:
  es lo que le dice cuándo mirarlos. Con Enter se queda con el nombre de la
  carpeta; con «cancelar» lo deja.
- **Te dice qué no pudo leer** y por qué (por ejemplo, el PDF).
- **Solo hace falta una vez.** Las siguientes veces que abras `AI` ya los
  tiene. Si cambias, añades o borras ficheros en la carpeta, lo nota solo
  (lo revisa cada cinco minutos). Si tienes prisa: `/documentos actualizar`.
- **Si la ruta tiene espacios,** también vale: `aprende de los documentos de
  D:\Mis documentos\Mi negocio`. Si no la encuentra, ponla entre comillas.

Para ver en cualquier momento qué carpetas tiene y cuánto leyó, escribe
`/documentos`.

## 4. Cómo preguntar

Pregunta como se lo preguntarías a un empleado que tiene los documentos
delante:

```
Usuario > ¿A qué hora abre la sucursal Norte los domingos?
ia > consultando tus documentos: Servicios y precios.xlsx, Procedimientos\Apertura y
     cierre.docx, Quiénes somos.docx
ia > La sucursal Norte abre a las 08:00 los domingos. Esto viene del documento Servicios y
     precios.xlsx, apartado «Hoja: Horarios».
   documentos: Servicios y precios.xlsx  Procedimientos\Apertura y cierre.docx  Quiénes somos.docx
Usuario > ¿Cuánto es el fondo de caja al abrir?
ia > consultando tus documentos: Procedimientos\Apertura y cierre.docx, Servicios y precios.xlsx
ia > El fondo de caja al abrir es de C$ 1,500. Esto viene del documento Procedimientos\Apertura
     y cierre.docx, apartado «Apertura y cierre de sucursal > Apertura».
   documentos: Procedimientos\Apertura y cierre.docx  Servicios y precios.xlsx
Usuario > ¿Cuánto gana Lucía Martínez?
ia > consultando tus documentos: Procedimientos\Apertura y cierre.docx, Empleados.csv
ia > No viene en los documentos.
   documentos: Procedimientos\Apertura y cierre.docx  Empleados.csv
```

Las respuestas son cortas porque en esa conversación se le había pedido
antes «recuerda que me contestes siempre en frases cortas» (ver
«Preferencias» en el README).

- **Antes de contestar dice qué documento consulta,** y en la respuesta, de
  cuál sale el dato.
- **Si no viene, lo dice.** Fíjate en el sueldo de la pregunta de arriba: no
  está en los documentos, y en vez de inventar una cifra lo dice. Eso es lo
  que tiene que pasar.
- **Una cosa por pregunta** funciona mejor que tres juntas.
- **Usa las palabras de tus documentos:** «sucursal Norte», «fondo de caja»,
  «pedido para eventos». Si en el negocio algo tiene un nombre propio, úsalo.
- **Puedes seguir la conversación:** después de «¿a qué hora abre la Central
  entre semana?», vale «¿y los sábados?».
- **Lo demás lo contesta como siempre.** «¿Cuál es la capital de Francia?» o
  «escríbeme un mensaje para felicitar a un cliente» no tocan tus documentos.

## 5. Comprueba de dónde sale un dato

Si una respuesta te extraña, mira qué trozos de tus documentos vería el
modelo con esa pregunta. No pregunta al modelo: es una búsqueda directa, al
instante.

```
Usuario > /documentos buscar fondo de caja
  1. Procedimientos\Apertura y cierre.docx > Apertura y cierre de sucursal > Apertura  (5.09 puntos)
     - A las 4:00 el jefe de panadería enciende los hornos.
     - A las 5:30 se limpian las vitrinas y el mostrador.
     - A las 5:45 la cajera cuenta el fondo de caja, que es de C$ 1,500.
     - Se abre al público a la hora del horario de cada sucursal.
  2. Procedimientos\Apertura y cierre.docx > Apertura y cierre de sucursal > Cierre  (2.9 puntos)
     - Se cuadra la caja y el efectivo se guarda en la caja fuerte.
     - Se apagan los hornos y se anota la temperatura final de las cámaras.
     - Se activa la alarma; el código solo lo tienen la encargada y la gerente.
(viajarían solos con esa pregunta; cobertura 1)
```

- **Cada resultado dice el documento y el apartado** (`Apertura y cierre.docx >
  ...`) y el texto tal cual se leyó.
- **Los puntos** dicen cuánto encaja con lo que buscas: el primero es el que
  más.
- **Al final dice si esos trozos viajarían solos** con esa pregunta. Si dice
  que no, prueba a preguntar con otras palabras, las del documento.
- **Si el dato está mal en el trozo, está mal en el documento:** corrígelo en
  el fichero y la próxima respuesta ya usará lo nuevo.

## 6. Olvidar, y deshacer

Puedes pedirle que deje de usar algo. **Tus ficheros no se tocan:** lo que se
olvida es lo que leyó de ellos.

```
Usuario > olvida lo de la extensión
ia > Voy a olvidar lo que hable de «extension» (6 líneas de Empleados.csv). Tus ficheros no se tocan.
  por ejemplo:
  - Empleados.csv: Extensión: 101
  - Empleados.csv: Extensión: 102
  - Empleados.csv: Extensión: 103
  - Empleados.csv: Extensión: 200
  - Empleados.csv: Extensión: 201
    y 1 más
ia > ¿Lo olvido? («sí» o «no»)
Usuario > sí
ia > Olvidado. Si te arrepientes: /documentos olvidos y /documentos recordar <número>.
ia > Lo que ya te dije en esta conversación sigue en su memoria; /new la vacía.
Usuario > /new
memoria vaciada
Usuario > ¿Cuál es la extensión de Ana Torres?
ia > consultando tus documentos: Procedimientos\Apertura y cierre.docx, Empleados.csv
ia > Ana Torres es Encargada de sucursal. Este dato sale de Empleados.csv.
   documentos: Procedimientos\Apertura y cierre.docx  Empleados.csv
Usuario > /documentos olvidos
  1. lo que hable de «extension»  (2026-11-18)
(/documentos recordar <número> deshace uno)
Usuario > /documentos recordar 1
vuelvo a usar lo que hable de «extension»
```

Después de olvidar la extensión, sigue sabiendo quién es Ana Torres y su
cargo, pero ya no da su extensión.

Qué puedes olvidar y cómo pedirlo:

| Qué | Cómo se pide |
| --- | --- |
| Un tema, en todos los documentos | «olvida lo de los sueldos» |
| Un documento entero | «olvida el documento Empleados.csv» |
| Un apartado de un documento | «olvida el apartado Permisos» |
| Una carpeta | «deja de usar la carpeta MiNegocio» |
| Todo | «olvida todo lo que aprendiste» |

- **Siempre te enseña qué va a olvidar,** con ejemplos, y espera tu «sí».
  Con «no» no olvida nada.
- **Un tema se quita con cuidado:** solo las líneas que hablan de él. En una
  tabla de empleados, «olvida lo de la extensión» quita la extensión de cada
  uno y deja su nombre, su cargo y su turno.
- **Lo que ya te dijo en la conversación lo sigue teniendo en la memoria de
  esa conversación.** Escribe `/new` para empezar una nueva, o cierra y
  vuelve a abrir `AI`.
- **Para deshacer:** `/documentos olvidos` lista lo olvidado, con un
  número, y `/documentos recordar <número>` lo vuelve a usar.
- **Olvidar una carpeta o todo no se deshace así:** la carpeta sale de la
  lista. Para volver a usarla, pídele otra vez que aprenda de ella.
- También puedes escribirlo como orden: `/documentos olvidar <documento,
  apartado, tema o todo>`.

## 7. Privacidad

- **Tus documentos no se modifican nunca.**
- **Lo que lee se guarda en tu equipo,** en
  `%LOCALAPPDATA%\PRC-CMD-AI\documentos\`, para no releerlo cada vez. Si
  olvidas todo, esa copia se borra.
- **Solo se usan con el modelo local** (Gemma, el que viene por defecto, o
  Qwen u Ollama), que funciona en tu propio equipo. Si cambias a un modelo de
  internet (OpenAI o Grok), los trozos de tus documentos saldrían del equipo,
  así que **no se mandan** y te avisa.
- **Si de verdad quieres usarlos con un modelo de internet,** escribe
  `/documentos nube on`. Vale solo para esa sesión; `/documentos nube off` lo
  quita. Piénsalo antes: lo que vaya en esos trozos (precios, empleados,
  procedimientos) llegará a esa empresa.
- **Para apagarlos un rato:** `/documentos off` (y `/documentos on` para
  volver).

## 8. Preguntas frecuentes

**¿Tengo que volver a enseñarle la carpeta cada día?**
No. Se acuerda de las carpetas de una vez para otra, y nota solo los cambios.

**Cambié un precio en el Excel y me sigue dando el viejo.**
Revisa las carpetas cada cinco minutos. Escribe `/documentos actualizar`
para que lo haga ya. Si sigue igual, comprueba con `/documentos buscar` qué
lee: puede que haya otro documento con el precio viejo.

**Me dijo un dato que no es.**
Usa `/documentos buscar` con las palabras de tu pregunta: verás qué trozos
le llegaron. Si el dato está bien en el trozo, el modelo lo leyó mal:
pregunta de forma más concreta. Si está mal en el trozo, corrige el
documento. Si hay dos documentos que dicen cosas distintas, deja solo uno.

**Me dice que no viene en los documentos, y sí viene.**
Suele ser porque la pregunta usa otras palabras. Prueba con
`/documentos buscar` y las palabras del documento, y pregunta con ellas.

**¿Puedo meter un PDF?**
Todavía no. Mira el apartado 2: pásalo a Word o a texto.

**¿Puede ver mis documentos alguien de fuera?**
Con el modelo local, no: todo ocurre en tu equipo. Solo saldrían si tú
activas `/documentos nube on` con un modelo de internet.

**¿Y si borro un documento de la carpeta?**
Lo nota en la siguiente revisión y deja de usarlo.

**¿Cuántos documentos puede leer?**
Hasta 3000 ficheros. Unos 400 documentos se leen la primera vez en unos
5 segundos, y luego cada pregunta busca en una fracción de segundo.

**¿Se puede usar en otra computadora?**
Sí, si tiene `AI` instalado y la carpeta. Cada equipo lee la carpeta por su
cuenta.

## Chuleta

| Para | Escribe |
| --- | --- |
| Leer una carpeta | `aprende de los documentos de D:\MiNegocio` |
| Ver qué carpetas tiene | `/documentos` |
| Ver de dónde saldría una respuesta | `/documentos buscar <palabras>` |
| Releer ya los cambios | `/documentos actualizar` |
| Olvidar algo | `olvida lo de <tema>` |
| Ver lo olvidado | `/documentos olvidos` |
| Deshacer un olvido | `/documentos recordar <número>` |
| Dejar de leer una carpeta | `/documentos quitar <nombre>` |
| Apagar o encender los documentos | `/documentos off` / `/documentos on` |
| Empezar una conversación nueva | `/new` |
