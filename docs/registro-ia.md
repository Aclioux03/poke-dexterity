# Registro de uso de IA

Insumo para la **sección 10** del documento. Cada uso se registra con el prompt exacto y qué se aceptó o cambió.
Herramienta: **Claude (Anthropic), modelo Claude Opus 5.5**.

| N.º | Parte | Prompt exacto | Qué se aceptó o cambió | Responsable |
|---|---|---|---|---|
| 1 | Planeación (BD, back, front) | Ver prompt 1 abajo. Se adjuntaron `Proyecto_Pokedex_Regional_BD.docx` y `Arquitectura_Pokedex_Regional_para_Claude.txt` | Se aceptó el plan de 7 fases (0 a 6) con fechas hasta el 26 nov | _(completar)_ |
| 2 | BD (modelo) | Ver prompt 2 | Se definieron PK, tipos, categoría de ataque, evolución, auditoría y datos por región. El equipo ajustó: `id_pokemon` como nombre de la PK, distinguir varias regiones de formas regionales, dejar fuera formas regionales por ahora, imágenes 64×64 y criterios de selección de Pokémon | _(completar)_ |
| 3 | BD (datos) | Ver prompt 3 | El equipo exigió datos verídicos de ataques (sin inventar movimientos ni valores). Se acordó usar el dataset oficial de PokéAPI y verificar una muestra contra otra fuente | _(completar)_ |
| 4 | BD (datos) y repositorio | Ver prompt 4 | Se fijó Escarlata/Púrpura como juego de referencia, todos los ataques por nivel (nivel 0 = al evolucionar) y numeración de corrido para Pokédex divididas. Como Claude no tiene acceso de escritura al repo, el equipo sube los archivos | _(completar)_ |
| 5 | Configuración del entorno y repositorio | Ver prompts 5 | Se siguieron las instrucciones para pgAdmin, `.env`, Maven Wrapper (copiado de start.spring.io), GitHub web y GitHub Desktop. Se decidió mantener las ramas de cada fase como evidencia | _(completar)_ |
| 6 | BD (modelo, scripts y datos) | Ver prompt 6 | Se generaron `02_esquema.sql` (14 tablas), `03_logica.sql` (3 triggers), `04_datos.sql` (generado desde PokéAPI con `tools/generar_datos.py`) y la documentación del modelo. Se verificó una muestra de ataques contra otras fuentes. _(Registrar aquí lo que el equipo cambie al revisar)_ | _(completar)_ |
| 7 | BD (todos los Pokémon y cierre de la base) | Ver prompt 7 | Se cambió la carga a las 1.025 especies y se completaron vistas, función, procedimientos, 12 consultas, demostraciones y la guía para backend. _(Registrar aquí lo que el equipo cambie al revisar)_ | _(completar)_ |
| 8 | BD (inserción de datos e imágenes) | Ver prompt 8 | Se confirmó que todos los datos se insertan con `sql/04_datos.sql`; se agregó `pokemon.url_imagen` (único dato externo, mostrado a 64×64) y `sql/08_verificacion.sql` con 31 controles. Se detectó que la fuente no tiene descripción en español para 127 Pokémon (899–1025) | _(completar)_ |

## Prompts exactos

**Prompt 1**
> Ten en cuenta el word para el contexto del ejercicio, el .txt para las decisiones pues tenemos hasta el 27 por la mañana para hacerlo, la idea es que se vaya haciendo por fases ya que tiene un componente de repositorio en github entonces para irlo creando y subir las cosas por fases, listalas según lo veas y pregunta por cada decisión de diseño y estilo para el desarrollo del proyecto, para conversarlo y definir que utilizaremos, sin embargo las tecnologias propuestas en el .txt mantenlas

**Prompt 2**
> 1. No hemos creado el repositorio en Github, le pensamos llamar poke-dexterity, adjunto imagen previo a crearlo.
> 2. Trabajemos por ramas
> 3. Jose Alejandro Prieto Colina(BD, back), Juan Nicolas Moncada Avendaño(BD, front), Sebastian Camilo Sanchez Rubio(documento, BD).
> 4. Tengo la versión 18
> 5. PokeDexterity
> 6. Usemos el id con nombre id_pokemon y numero_nacional como unique not null, debemos tener en cuenta la distinción de estar en varias regiones con tener una forma regional.
> 7. Si, la idea es que existan pokemones de 1 tipo o 2 tipos pero nunca un pokemon sin tipo o un pokemon con 2 tipos iguales
> 8. Usemos la tabla para la normalización y el poder de ataque NULL para este caso de los de estado
> 9. Numero regional en pokemon_region considerando lo que mencione en 6, nivel de aprendizaje y con habilidad oculta
> 10. Si, aunque explica como se utilizaria y porque es mejor este enfoque que otro.
> 11. No usemos JSONB, guardemoslo en datos que nos permitan cumplir con lo especificado y tener la trazabilidad
> 12. De momento dejemoslas fuera, sin embargo es algo que viendo como va quedando lo vamos analizando
> 13. Si, la imagen debe ser 64x64, para los datos usemos esto, los 3 iniciales de cada región, el ave regional, bicho regional, en caso de aplicar el pseudolegendario, los legendarios propios de la región y el pokemon considerado clon de pikachu, togedemaru, pachirisu, minun y el propio pikachu y asi
>
> Las decisiones de diseño luego las vemos y lo de Whiteboard que es?

**Prompt 3**
> 1. Ya cree el repo
> 2. El integrante 4 no existe, no tenemos, solo somos esos 3
> 3. Linea evolutiva completa, si existen 2 pseudos en la región mete los 2
> 4. Para los ataques necesito que me indiques si puedes verificar la información de estos, propongo que muestres los que realmente aprende por la especie por nivel, no inventes movimientos para pokemones que no puedan aprenderlos, ni sus valores de poder y precisión ademas de la categoria, esto es fundamental asi que antes de hacer algo con eso aseguremonos que es información veridica
> 5. Omitimos en Johto
> 6. Mete a ambos en cada caso
> 7. Ambas aves en paldea
> 8. Si aplica en el juego incluye el mitico o los miticos introducidos o que son de esa región

**Prompt 4**
> No tengo acceso a la cuenta de correo, si no entonces indicame que debo subir y como debo subirlo a github, el repo es publico actualmente.
>
> Usaremos como referencia escarlata/púrpura como se recomienda.
>
> Se cargan todos los posibles ataques, guardemoslo con nivel 0 y lo indicamos con que es aprendido al evolucionar
>
> Si, la versión más completa para cada región, en kalos y si se presenta en otra región hagamoslo de corrido para evitar complicaciones y lo de aparecer en una región.

**Prompts 5** (soporte de configuración, en orden)
> como lo subo directamente a github
>
> no entiendo la estructura de las carpetas, porque tiene  primero main y luego java, en IDE como eclipse usamos el  nombre del proyecto como carpeta principal, luego src, los paquetes y asi el co.edu.unbosque con, para este caso usare el ide visual studio code
>
> pero es que no hay ninguna carpeta que se llame poke-dexterity, o se refiere a la de poke-dexterity-fase-0 o cual,
>
> me salia algo de una versión de runtime abajo a la derecha
>
> como se debe llamar la base de datos y como hago en pgadmin4 y lo del .env
>
> yo no recuerdo cual fue la clave que use para instalar postgres, que hago?
>
> listo ya hice todo, corregire y pondre algunos comentarios en los archivos y procederé a subir al github
>
> como hago lo de maven, que hago en vsc o donde se pone eso?
>
> listo, ahora que es lo que tengo que subir a github
>
> listo ya esta todo hecho con el merge
>
> no se subio con tools, pero ya esta. clonaré el repositorio en github desktop
>
> listo ahora si revisa si ya esta todo y mira la carpeta clonada, no me sale el .gitignore pero comprueba el repo ahora si
>
> como hago lo de las ramas?
>
> borro las ramas? pero no se supone que las ibamos a mantener por orden?

**Prompt 6**
> okay sigamos con la fase 1

**Prompt 7**
> El profesor hizo una aclaración, se debe de incluir a todos los pokemones, mis compañeros se deben encargar de la parte de front + backend, yo debo encargarme de la base de datos y dejarla lista. Como debemos proceder entonces

**Prompt 8**
> Los datos deben ser generados por medio de script, lo unico que se obtiene de api o algo externo al desarrollo propio es las imagenes, si contemplas las imagenes son de 64x64 y sobretodo que los datos de los pokemon queden bien insertados, debe haber un archivo sql para la inserción de datos, en la base de datos
