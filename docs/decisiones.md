# Decisiones de diseño

Registro corto de lo acordado. Sirve como base para la justificación del documento y la sustentación.

## Generales

| Tema | Decisión |
|---|---|
| Tecnologías | PostgreSQL 18, Java 21, Spring Boot 4.1.2 (MVC + JDBC), Thymeleaf, CSS y JS nativos, Maven Wrapper |
| Arquitectura | Monolito por capas; sin API REST en el alcance inicial |
| Repositorio | `Aclioux03/poke-dexterity`, una rama por fase, merge a `main` por Pull Request |
| Credenciales | Archivo `.env` local (fuera del repo) o variables de entorno; cuenta `pokedex_app` sin privilegios de superusuario |
| Fuente de datos | Dataset CSV oficial de PokéAPI (repositorio `PokeAPI/pokeapi`, `data/v2/csv`). Los INSERT se generan con un script en `tools/`, nunca a mano; se contrasta una muestra con Bulbapedia o Serebii |
| Fuente de los datos en la app | **Todos los datos de la Pokédex se insertan con un script SQL propio (`sql/04_datos.sql`) y viven en PostgreSQL.** La app nunca consulta una API para datos. Lo único externo son las imágenes |
| Imágenes | `pokemon.url_imagen`: sprite de PokéAPI por número nacional (96×96 px, verificado que existen los 1.025), mostrado a **64×64 px** sin `pixelated`. Si es NULL o falla, imagen de respaldo propia |

## Modelo de datos

| Tema | Decisión |
|---|---|
| Clave de `pokemon` | `id_pokemon` IDENTITY como PK; `numero_nacional` `UNIQUE NOT NULL` |
| Varias regiones y forma regional | `pokemon_region` = el mismo Pokémon (misma forma) aparece en la Pokédex de esa región. Las formas regionales quedan fuera por ahora; si se agregan, irán en una tabla aparte (`pokemon_forma`) sin romper el `UNIQUE` de `numero_nacional` |
| Número regional | En `pokemon_region`, `UNIQUE(id_region, numero_regional)`. Se usa la Pokédex más completa de cada región: Let's Go (Kanto), HG/SS (Johto), ROZA (Hoenn), Platino (Sinnoh), N2/B2 (Unova, empieza en 0 con Victini), USUL (Alola). Las divididas se numeran de corrido, continuando después del máximo de la anterior: Kalos (Centro → Costa → Montaña), Galar (Galar → Isla de la Armadura → Corona Nevada), Paldea (Paldea → Noroteo → Arándano) |
| Qué significa "aparece en una región" | Que la especie figura en la Pokédex de esa región. Además, cada Pokémon siempre se asocia a su región de origen; si no figura en esa Pokédex (algunos míticos, Meltan), su número regional queda NULL |
| Región de origen | `pokemon.id_region_origen`: la región de la generación en que se introdujo la especie |
| Tipos | `pokemon_tipo` con `slot IN (1,2)`, PK `(id_pokemon, id_tipo)` (sin tipos repetidos) y `UNIQUE(id_pokemon, slot)` (máximo dos). Un trigger diferido al COMMIT exige que cada Pokémon tenga tipo en el slot 1 (nunca sin tipo) |
| Categoría de ataque | Catálogo `categoria_ataque` (físico, especial, estado). `poder` es NULL en los ataques de estado y también en los de poder variable (Patada Baja, Sísmico); `precision` es NULL si el ataque nunca falla. El dataset trae `0` en algunos ataques de estado recientes: se normaliza a NULL |
| Ataques que aprende | Todos los que aprende **por nivel** en **Escarlata/Púrpura**. Si la especie no está en ese juego, el más reciente donde esté: Diamante Brillante/Perla Reluciente y luego Espada/Escudo (la lista está en `docs/reporte_datos.md`). `nivel` real; `nivel = 0` = "se aprende al evolucionar"; si un ataque aparece dos veces, se guarda el nivel menor. Poder y precisión con los valores vigentes |
| PK | IDENTITY `GENERATED ALWAYS`. La carga resuelve las FK con JOIN por nombre o número nacional, así que no depende de los valores generados |
| Búsqueda por nombre | "Empieza por" (`lower(nombre) LIKE 'pik%'`), para poder usar un índice B-tree |
| Permisos | `pokedex_app` puede leer y escribir datos, pero no modificar ni borrar la auditoría ni cambiar la estructura |
| Habilidades | `pokemon_habilidad` con marca `es_oculta` |
| Género | Catálogo `genero` (macho, hembra, ambos, sin género), FK en `pokemon` |
| Evolución | Tabla `evolucion(origen, destino, metodo, nivel)`, catálogo `metodo_evolucion`, `CHECK (origen <> destino)`, `UNIQUE(destino)`. Soporta ramificaciones (Eevee) y permite recorrer la cadena con `WITH RECURSIVE` |
| Auditoría de borrado | Columnas relacionales (sin JSONB): fecha, `usuario_bd` (`current_user`), `usuario_app` (enviado por el backend con `set_config('app.usuario', …)` en la misma transacción) y los datos del Pokémon eliminado |

## Datos

**Se cargan todas las especies de la Pokédex Nacional: 1.025 Pokémon** (aclaración del docente, reemplaza la selección por región que se había acordado).

- Las especies de Hisui (Wyrdeer, Kleavor, Ursaluna, Enamorus, …) son de la generación 8: su región de origen queda en Galar, la región de esa generación en el proyecto. Sus evoluciones se toman de Leyendas Pokémon: Arceus, el único juego donde existen.
- Juego de referencia de los ataques: Escarlata/Púrpura (733 especies), Espada/Escudo (143), Diamante Brillante/Perla Reluciente (140), Ultrasol/Ultraluna (9).
- Limpieza de datos del dataset: poder `0` y precisión `0` en algunos ataques de estado recientes → NULL.
- Evoluciones con decenas de variantes (Alcremie) guardan la primera condición + "(u otras variantes)" para respetar `VARCHAR(100)`.
- Descripción: la fuente no tiene entrada en español para Hisui (899–905) ni Paldea (906–1025). Esos 127 quedan en NULL. _Pendiente: decidir si se completan._
- En la carga, `id_pokemon` coincide con el número nacional (los INSERT van ordenados). Los Pokémon creados desde la app toman 1026 en adelante.

| Tabla | Filas |
|---|---|
| pokemon | 1.025 |
| ataque / habilidad | 691 / 284 |
| pokemon_ataque | 14.934 |
| pokemon_region | 3.255 |
| pokemon_habilidad / pokemon_tipo | 2.411 / 1.551 |
| evolucion | 484 |

## Reparto del trabajo

- **Base de datos (scripts `00`–`07`, `tools/`, documentación del modelo):** lista para entregar.
- **Backend y front:** el resto del equipo, a partir de `docs/guia_backend.md`.

## Pendiente de definir

- Decisiones de estilo visual (Fase 2 y Fase 5).
- Formas regionales: se reevalúa según el avance.
