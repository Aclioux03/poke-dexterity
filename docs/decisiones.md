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
| Imágenes | Sprites de PokéAPI por número nacional, mostrados a 64×64 px con `image-rendering: pixelated` y una imagen de respaldo si falla la fuente |

## Modelo de datos

| Tema | Decisión |
|---|---|
| Clave de `pokemon` | `id_pokemon` IDENTITY como PK; `numero_nacional` `UNIQUE NOT NULL` |
| Varias regiones y forma regional | `pokemon_region` = el mismo Pokémon (misma forma) aparece en la Pokédex de esa región. Las formas regionales quedan fuera por ahora; si se agregan, irán en una tabla aparte (`pokemon_forma`) sin romper el `UNIQUE` de `numero_nacional` |
| Número regional | En `pokemon_region`, `UNIQUE(id_region, numero_regional)`. Se usa la Pokédex más completa de cada región. Si la Pokédex de una región está dividida (Kalos: Centro, Costa, Montaña), se numera de corrido |
| Tipos | `pokemon_tipo` con `slot IN (1,2)`, PK `(id_pokemon, id_tipo)` (sin tipos repetidos) y `UNIQUE(id_pokemon, slot)` (máximo dos). Un trigger diferido al COMMIT exige que cada Pokémon tenga tipo en el slot 1 (nunca sin tipo) |
| Categoría de ataque | Catálogo `categoria_ataque` (físico, especial, estado). `poder` es NULL en los ataques de estado |
| Ataques que aprende | Todos los que aprende **por nivel** en **Escarlata/Púrpura** (o el juego principal más reciente donde esté el Pokémon). `nivel` real; `nivel = 0` significa "se aprende al evolucionar". Poder y precisión con los valores vigentes |
| Habilidades | `pokemon_habilidad` con marca `es_oculta` |
| Género | Catálogo `genero` (macho, hembra, ambos, sin género), FK en `pokemon` |
| Evolución | Tabla `evolucion(origen, destino, metodo, nivel)`, catálogo `metodo_evolucion`, `CHECK (origen <> destino)`, `UNIQUE(destino)`. Soporta ramificaciones (Eevee) y permite recorrer la cadena con `WITH RECURSIVE` |
| Auditoría de borrado | Columnas relacionales (sin JSONB): fecha, `usuario_bd` (`current_user`), `usuario_app` (enviado por el backend con `set_config('app.usuario', …)` en la misma transacción) y los datos del Pokémon eliminado |

## Datos por región

Por región: los 3 iniciales, el ave regional y el bicho regional (línea evolutiva completa), los pseudolegendarios (si hay dos, ambos, con su línea completa), los legendarios y los míticos de la región, y el "clon de Pikachu" (Pikachu, Plusle y Minun, Pachirisu, Emolga, Dedenne, Togedemaru, Morpeko, Pawmi). Johto no tiene clon. En Paldea se incluyen las dos aves (Squawkabilly y Wattrel).

## Pendiente de definir

- Decisiones de estilo visual (Fase 2 y Fase 5).
- Formas regionales: se reevalúa según el avance.
