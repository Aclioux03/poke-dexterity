# Diccionario de datos

Generado desde el catálogo de PostgreSQL con `tools/diccionario.sql` (las descripciones son los `COMMENT ON` de `02_esquema.sql`). Sección 5.4 del documento.

| Tabla | Columna | Tipo de dato | ¿Nulo? | Clave | Descripción |
|---|---|---|---|---|---|
| region | id_region | SMALLINT IDENTITY | No | PK | Identificador de la región. |
| region | nombre | VARCHAR(30) | No | UK | Nombre de la región (Kanto, Johto, ...). |
| region | slug | VARCHAR(30) | No | UK | Identificador estable en minúsculas para URLs y temas CSS (data-region). |
| region | generacion | SMALLINT | No | UK | Generación de juegos en que se introdujo la región. |
| tipo | id_tipo | SMALLINT IDENTITY | No | PK | Identificador del tipo. |
| tipo | nombre | VARCHAR(20) | No | UK | Nombre del tipo en español. |
| tipo | slug | VARCHAR(20) | No | UK | Identificador estable en minúsculas (fire, water, ...) para estilos CSS. |
| genero | id_genero | SMALLINT IDENTITY | No | PK | Identificador del género posible. |
| genero | nombre | VARCHAR(20) | No | UK | Macho, Hembra, Ambos o Sin género. |
| genero | descripcion | VARCHAR(100) | No |  | Texto explicativo para mostrar en el detalle. |
| categoria_ataque | id_categoria | SMALLINT IDENTITY | No | PK | Identificador de la categoría. |
| categoria_ataque | nombre | VARCHAR(20) | No | UK | Físico, Especial o Estado. |
| metodo_evolucion | id_metodo | SMALLINT IDENTITY | No | PK | Identificador del método. |
| metodo_evolucion | nombre | VARCHAR(40) | No | UK | Nombre del método (Subir de nivel, Usar objeto, ...). |
| habilidad | id_habilidad | INTEGER IDENTITY | No | PK | Identificador de la habilidad. |
| habilidad | nombre | VARCHAR(40) | No | UK | Nombre de la habilidad en español. |
| habilidad | descripcion | TEXT | Sí |  | Efecto de la habilidad. |
| ataque | id_ataque | INTEGER IDENTITY | No | PK | Identificador del ataque. |
| ataque | nombre | VARCHAR(40) | No | UK | Nombre del ataque en español. |
| ataque | id_tipo | SMALLINT | No | FK | Tipo del ataque. Referencia a tipo. |
| ataque | id_categoria | SMALLINT | No | FK | Categoría del ataque. Referencia a categoria_ataque. |
| ataque | poder | SMALLINT | Sí |  | NULL en ataques de estado y en ataques de poder variable (p. ej. Patada Baja). |
| ataque | precision | SMALLINT | Sí |  | NULL cuando el ataque nunca falla (p. ej. Rapidez) o no aplica. |
| pokemon | id_pokemon | INTEGER IDENTITY | No | PK | Identificador interno del Pokémon. |
| pokemon | numero_nacional | SMALLINT | No | UK | Número en la Pokédex Nacional. |
| pokemon | nombre | VARCHAR(40) | No | UK | Nombre del Pokémon. |
| pokemon | altura_m | NUMERIC(4,1) | No |  | Altura en metros. |
| pokemon | peso_kg | NUMERIC(5,1) | No |  | Peso en kilogramos. |
| pokemon | descripcion | TEXT | Sí |  | Entrada de la Pokédex en español. NULL si la fuente no la tiene en español (899-1025). |
| pokemon | url_imagen | VARCHAR(255) | Sí |  | Imagen externa (sprite de PokéAPI, 96×96) que la app muestra a 64×64. Es lo único que viene de fuera; NULL = imagen de respaldo. |
| pokemon | id_genero | SMALLINT | No | FK | Género posible del Pokémon. Referencia a genero. |
| pokemon | id_region_origen | SMALLINT | No | FK | Región de la generación en que se introdujo la especie. Referencia a region. |
| pokemon | es_legendario | BOOLEAN | No |  | TRUE si es legendario. Por defecto: false. |
| pokemon | es_mitico | BOOLEAN | No |  | TRUE si es mítico (excluyente con legendario). Por defecto: false. |
| pokemon | fecha_creacion | TIMESTAMPTZ | No |  | Fecha de registro en la base. Por defecto: now(). |
| pokemon | fecha_modificacion | TIMESTAMPTZ | No |  | La actualiza el trigger trg_pokemon_fecha_modificacion. Por defecto: now(). |
| evolucion | id_pokemon_origen | INTEGER | No | FK, PK | Pokémon que evoluciona (preevolución). Referencia a pokemon. |
| evolucion | id_pokemon_destino | INTEGER | No | FK, PK, UK | Pokémon resultante. Único: cada Pokémon tiene como máximo una preevolución. Referencia a pokemon. |
| evolucion | id_metodo | SMALLINT | No | FK | Método de evolución. Referencia a metodo_evolucion. |
| evolucion | nivel | SMALLINT | Sí |  | Nivel mínimo, si la evolución es por nivel. |
| evolucion | detalle | VARCHAR(100) | Sí |  | Condición adicional: objeto, amistad, momento del día, etc. |
| pokemon_region | id_pokemon | INTEGER | No | FK, PK | Pokémon. Referencia a pokemon. |
| pokemon_region | id_region | SMALLINT | No | FK, PK, UK | Región en cuya Pokédex aparece. Referencia a region. |
| pokemon_region | numero_regional | SMALLINT | Sí | UK | Número en la Pokédex regional. NULL si la especie es de esa región pero no figura en su Pokédex (algunos míticos). |
| pokemon_tipo | id_pokemon | INTEGER | No | FK, PK, UK | Pokémon. Referencia a pokemon. |
| pokemon_tipo | id_tipo | SMALLINT | No | FK, PK | Tipo del Pokémon. Referencia a tipo. |
| pokemon_tipo | slot | SMALLINT | No | UK | 1 = tipo principal, 2 = tipo secundario. |
| pokemon_ataque | id_pokemon | INTEGER | No | FK, PK | Pokémon. Referencia a pokemon. |
| pokemon_ataque | id_ataque | INTEGER | No | FK, PK | Ataque que aprende. Referencia a ataque. |
| pokemon_ataque | nivel | SMALLINT | No |  | Nivel en que lo aprende. 0 = lo aprende al evolucionar. Por defecto: 1. |
| pokemon_habilidad | id_pokemon | INTEGER | No | FK, PK | Pokémon. Referencia a pokemon. |
| pokemon_habilidad | id_habilidad | INTEGER | No | FK, PK | Habilidad que puede tener. Referencia a habilidad. |
| pokemon_habilidad | es_oculta | BOOLEAN | No |  | TRUE si es su habilidad oculta (como máximo una). Por defecto: false. |
| auditoria_borrado | id_auditoria | BIGINT IDENTITY | No | PK | Identificador del registro de auditoría. |
| auditoria_borrado | tabla_afectada | VARCHAR(40) | No |  | Tabla donde se borró el dato. Por defecto: 'pokemon'. |
| auditoria_borrado | id_registro | INTEGER | No |  | id_pokemon del registro borrado. |
| auditoria_borrado | numero_nacional | SMALLINT | Sí |  | Número nacional del Pokémon borrado. |
| auditoria_borrado | nombre | VARCHAR(40) | Sí |  | Nombre del Pokémon borrado. |
| auditoria_borrado | tipos | VARCHAR(60) | Sí |  | Tipos que tenía, en texto (copia histórica). |
| auditoria_borrado | regiones | VARCHAR(200) | Sí |  | Regiones donde aparecía, en texto (copia histórica). |
| auditoria_borrado | usuario_bd | VARCHAR(63) | No |  | Cuenta de PostgreSQL que ejecutó el DELETE (current_user). Por defecto: CURRENT_USER. |
| auditoria_borrado | usuario_app | VARCHAR(60) | Sí |  | Persona indicada por la aplicación con set_config('app.usuario', ...). NULL si el borrado se hizo fuera de la app. |
| auditoria_borrado | fecha | TIMESTAMPTZ | No |  | Fecha y hora del borrado. Por defecto: now(). |
