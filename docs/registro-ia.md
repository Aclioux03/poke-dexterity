# Registro de uso de IA

Insumo para la **sección 10** del documento. Cada uso se registra con el prompt exacto y qué se aceptó o cambió.
Herramienta: **Claude (Anthropic), modelo Claude Opus 5.5**.

| N.º | Parte | Prompt exacto | Qué se aceptó o cambió | Responsable |
|---|---|---|---|---|
| 1 | Planeación (BD, back, front) | Ver prompt 1 abajo. Se adjuntaron `Proyecto_Pokedex_Regional_BD.docx` y `Arquitectura_Pokedex_Regional_para_Claude.txt` | Se aceptó el plan de 7 fases (0 a 6) con fechas hasta el 26 nov | _(completar)_ |
| 2 | BD (modelo) | Ver prompt 2 | Se definieron PK, tipos, categoría de ataque, evolución, auditoría y datos por región. El equipo ajustó: `id_pokemon` como nombre de la PK, distinguir varias regiones de formas regionales, dejar fuera formas regionales por ahora, imágenes 64×64 y criterios de selección de Pokémon | _(completar)_ |
| 3 | BD (datos) | Ver prompt 3 | El equipo exigió datos verídicos de ataques (sin inventar movimientos ni valores). Se acordó usar el dataset oficial de PokéAPI y verificar una muestra contra otra fuente | _(completar)_ |
| 4 | BD (datos) y repositorio | Ver prompt 4 | Se fijó Escarlata/Púrpura como juego de referencia, todos los ataques por nivel (nivel 0 = al evolucionar) y numeración de corrido para Pokédex divididas. Como Claude no tiene acceso de escritura al repo, el equipo sube los archivos | _(completar)_ |

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
