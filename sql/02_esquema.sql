-- =====================================================================
-- PokeDexterity · 02_esquema.sql
-- Ejecutar conectado como postgres a la base "pokedex".
-- Crea las 14 tablas con sus restricciones e índices, y los permisos
-- de la cuenta de la aplicación (pokedex_app).
--
-- Convenciones:
--   * PK sustitutas IDENTITY (GENERATED ALWAYS): las genera PostgreSQL y
--     nunca se modifican. Por eso las FK usan ON UPDATE NO ACTION: no hay
--     actualizaciones de claves que propagar.
--   * Las tablas puente (N:M) usan PK compuesta por las dos FK.
--   * Políticas ON DELETE:
--       - CASCADE desde pokemon hacia sus tablas puente: si se borra un
--         Pokémon, sus tipos, regiones, ataques, habilidades y evoluciones
--         dejan de tener sentido.
--       - RESTRICT desde los catálogos (región, tipo, ataque, habilidad,
--         género, categoría, método): no se puede borrar un dato de catálogo
--         mientras algún Pokémon lo use.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Catálogos
-- ---------------------------------------------------------------------

CREATE TABLE region (
    id_region   SMALLINT     GENERATED ALWAYS AS IDENTITY,
    nombre      VARCHAR(30)  NOT NULL,
    slug        VARCHAR(30)  NOT NULL,
    generacion  SMALLINT     NOT NULL,
    CONSTRAINT pk_region            PRIMARY KEY (id_region),
    CONSTRAINT uq_region_nombre     UNIQUE (nombre),
    CONSTRAINT uq_region_slug       UNIQUE (slug),
    CONSTRAINT uq_region_generacion UNIQUE (generacion),
    CONSTRAINT ck_region_generacion CHECK (generacion BETWEEN 1 AND 20),
    CONSTRAINT ck_region_slug       CHECK (slug ~ '^[a-z0-9-]+$')
);
COMMENT ON TABLE  region      IS 'Catálogo de regiones del mundo Pokémon.';
COMMENT ON COLUMN region.slug IS 'Identificador estable en minúsculas para URLs y temas CSS (data-region).';

CREATE TABLE tipo (
    id_tipo  SMALLINT     GENERATED ALWAYS AS IDENTITY,
    nombre   VARCHAR(20)  NOT NULL,
    slug     VARCHAR(20)  NOT NULL,
    CONSTRAINT pk_tipo        PRIMARY KEY (id_tipo),
    CONSTRAINT uq_tipo_nombre UNIQUE (nombre),
    CONSTRAINT uq_tipo_slug   UNIQUE (slug)
);
COMMENT ON TABLE tipo IS 'Catálogo de tipos elementales (Fuego, Agua, ...).';

CREATE TABLE genero (
    id_genero    SMALLINT      GENERATED ALWAYS AS IDENTITY,
    nombre       VARCHAR(20)   NOT NULL,
    descripcion  VARCHAR(100)  NOT NULL,
    CONSTRAINT pk_genero        PRIMARY KEY (id_genero),
    CONSTRAINT uq_genero_nombre UNIQUE (nombre)
);
COMMENT ON TABLE genero IS 'Catálogo del género posible: macho, hembra, ambos o sin género.';

CREATE TABLE categoria_ataque (
    id_categoria  SMALLINT     GENERATED ALWAYS AS IDENTITY,
    nombre        VARCHAR(20)  NOT NULL,
    CONSTRAINT pk_categoria_ataque        PRIMARY KEY (id_categoria),
    CONSTRAINT uq_categoria_ataque_nombre UNIQUE (nombre)
);
COMMENT ON TABLE categoria_ataque IS 'Catálogo de categorías de ataque: Físico, Especial, Estado.';

CREATE TABLE metodo_evolucion (
    id_metodo  SMALLINT     GENERATED ALWAYS AS IDENTITY,
    nombre     VARCHAR(40)  NOT NULL,
    CONSTRAINT pk_metodo_evolucion        PRIMARY KEY (id_metodo),
    CONSTRAINT uq_metodo_evolucion_nombre UNIQUE (nombre)
);
COMMENT ON TABLE metodo_evolucion IS 'Catálogo de métodos de evolución (subir de nivel, usar objeto, ...).';

CREATE TABLE habilidad (
    id_habilidad  INTEGER      GENERATED ALWAYS AS IDENTITY,
    nombre        VARCHAR(40)  NOT NULL,
    descripcion   TEXT,
    CONSTRAINT pk_habilidad        PRIMARY KEY (id_habilidad),
    CONSTRAINT uq_habilidad_nombre UNIQUE (nombre)
);
COMMENT ON TABLE habilidad IS 'Catálogo de habilidades.';

CREATE TABLE ataque (
    id_ataque     INTEGER      GENERATED ALWAYS AS IDENTITY,
    nombre        VARCHAR(40)  NOT NULL,
    id_tipo       SMALLINT     NOT NULL,
    id_categoria  SMALLINT     NOT NULL,
    poder         SMALLINT,
    precision     SMALLINT,
    CONSTRAINT pk_ataque           PRIMARY KEY (id_ataque),
    CONSTRAINT uq_ataque_nombre    UNIQUE (nombre),
    CONSTRAINT fk_ataque_tipo      FOREIGN KEY (id_tipo)
        REFERENCES tipo (id_tipo) ON DELETE RESTRICT ON UPDATE NO ACTION,
    CONSTRAINT fk_ataque_categoria FOREIGN KEY (id_categoria)
        REFERENCES categoria_ataque (id_categoria) ON DELETE RESTRICT ON UPDATE NO ACTION,
    CONSTRAINT ck_ataque_poder     CHECK (poder IS NULL OR poder BETWEEN 1 AND 250),
    CONSTRAINT ck_ataque_precision CHECK (precision IS NULL OR precision BETWEEN 1 AND 100)
);
COMMENT ON TABLE  ataque           IS 'Movimientos con su tipo, categoría, poder y precisión.';
COMMENT ON COLUMN ataque.poder     IS 'NULL en ataques de estado y en ataques de poder variable (p. ej. Patada Baja).';
COMMENT ON COLUMN ataque.precision IS 'NULL cuando el ataque nunca falla (p. ej. Rapidez) o no aplica.';

-- ---------------------------------------------------------------------
-- Entidad principal
-- ---------------------------------------------------------------------

CREATE TABLE pokemon (
    id_pokemon          INTEGER       GENERATED ALWAYS AS IDENTITY,
    numero_nacional     SMALLINT      NOT NULL,
    nombre              VARCHAR(40)   NOT NULL,
    altura_m            NUMERIC(4,1)  NOT NULL,
    peso_kg             NUMERIC(5,1)  NOT NULL,
    descripcion         TEXT,
    url_imagen          VARCHAR(255),
    id_genero           SMALLINT      NOT NULL,
    id_region_origen    SMALLINT      NOT NULL,
    es_legendario       BOOLEAN       NOT NULL DEFAULT FALSE,
    es_mitico           BOOLEAN       NOT NULL DEFAULT FALSE,
    fecha_creacion      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    fecha_modificacion  TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT pk_pokemon                 PRIMARY KEY (id_pokemon),
    CONSTRAINT uq_pokemon_numero_nacional UNIQUE (numero_nacional),
    CONSTRAINT uq_pokemon_nombre          UNIQUE (nombre),
    CONSTRAINT fk_pokemon_genero          FOREIGN KEY (id_genero)
        REFERENCES genero (id_genero) ON DELETE RESTRICT ON UPDATE NO ACTION,
    CONSTRAINT fk_pokemon_region_origen   FOREIGN KEY (id_region_origen)
        REFERENCES region (id_region) ON DELETE RESTRICT ON UPDATE NO ACTION,
    CONSTRAINT ck_pokemon_numero_nacional CHECK (numero_nacional > 0),
    CONSTRAINT ck_pokemon_altura          CHECK (altura_m > 0),
    CONSTRAINT ck_pokemon_peso            CHECK (peso_kg > 0),
    CONSTRAINT ck_pokemon_leg_mitico      CHECK (NOT (es_legendario AND es_mitico)),
    CONSTRAINT ck_pokemon_url_imagen      CHECK (url_imagen IS NULL OR url_imagen ~ '^https?://')
);
COMMENT ON TABLE  pokemon                  IS 'Datos base de cada especie Pokémon.';
COMMENT ON COLUMN pokemon.id_region_origen IS 'Región de la generación en que se introdujo la especie.';
COMMENT ON COLUMN pokemon.fecha_modificacion IS 'La actualiza el trigger trg_pokemon_fecha_modificacion.';

-- ---------------------------------------------------------------------
-- Relaciones
-- ---------------------------------------------------------------------

-- Evolución: relación recursiva entre dos Pokémon (preevolución → evolución)
CREATE TABLE evolucion (
    id_pokemon_origen   INTEGER       NOT NULL,
    id_pokemon_destino  INTEGER       NOT NULL,
    id_metodo           SMALLINT      NOT NULL,
    nivel               SMALLINT,
    detalle             VARCHAR(100),
    CONSTRAINT pk_evolucion          PRIMARY KEY (id_pokemon_origen, id_pokemon_destino),
    CONSTRAINT uq_evolucion_destino  UNIQUE (id_pokemon_destino),
    CONSTRAINT fk_evolucion_origen   FOREIGN KEY (id_pokemon_origen)
        REFERENCES pokemon (id_pokemon) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT fk_evolucion_destino  FOREIGN KEY (id_pokemon_destino)
        REFERENCES pokemon (id_pokemon) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT fk_evolucion_metodo   FOREIGN KEY (id_metodo)
        REFERENCES metodo_evolucion (id_metodo) ON DELETE RESTRICT ON UPDATE NO ACTION,
    CONSTRAINT ck_evolucion_distintos CHECK (id_pokemon_origen <> id_pokemon_destino),
    CONSTRAINT ck_evolucion_nivel    CHECK (nivel IS NULL OR nivel BETWEEN 1 AND 100)
);
COMMENT ON TABLE  evolucion         IS 'Cada fila: un Pokémon (origen) evoluciona en otro (destino).';
COMMENT ON COLUMN evolucion.detalle IS 'Condición adicional: objeto, amistad, momento del día, etc.';

-- Pokémon ↔ región (N:M): el Pokémon aparece en la Pokédex de la región
CREATE TABLE pokemon_region (
    id_pokemon       INTEGER   NOT NULL,
    id_region        SMALLINT  NOT NULL,
    numero_regional  SMALLINT,
    CONSTRAINT pk_pokemon_region        PRIMARY KEY (id_pokemon, id_region),
    CONSTRAINT uq_pokemon_region_numero UNIQUE (id_region, numero_regional),
    CONSTRAINT fk_pokemon_region_pokemon FOREIGN KEY (id_pokemon)
        REFERENCES pokemon (id_pokemon) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT fk_pokemon_region_region  FOREIGN KEY (id_region)
        REFERENCES region (id_region) ON DELETE RESTRICT ON UPDATE NO ACTION,
    CONSTRAINT ck_pokemon_region_numero  CHECK (numero_regional IS NULL OR numero_regional >= 0)
);
COMMENT ON COLUMN pokemon_region.numero_regional IS
    'Número en la Pokédex regional. NULL si la especie es de esa región pero no figura en su Pokédex (algunos míticos).';

-- Pokémon ↔ tipo (N:M, máximo 2 por Pokémon)
CREATE TABLE pokemon_tipo (
    id_pokemon  INTEGER   NOT NULL,
    id_tipo     SMALLINT  NOT NULL,
    slot        SMALLINT  NOT NULL,
    CONSTRAINT pk_pokemon_tipo         PRIMARY KEY (id_pokemon, id_tipo),
    CONSTRAINT uq_pokemon_tipo_slot    UNIQUE (id_pokemon, slot),
    CONSTRAINT fk_pokemon_tipo_pokemon FOREIGN KEY (id_pokemon)
        REFERENCES pokemon (id_pokemon) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT fk_pokemon_tipo_tipo    FOREIGN KEY (id_tipo)
        REFERENCES tipo (id_tipo) ON DELETE RESTRICT ON UPDATE NO ACTION,
    CONSTRAINT ck_pokemon_tipo_slot    CHECK (slot IN (1, 2))
);
COMMENT ON TABLE pokemon_tipo IS
    'PK impide repetir un tipo; UNIQUE(id_pokemon, slot) + CHECK limita a dos. El trigger diferido exige el slot 1.';

-- Pokémon ↔ ataque (N:M): ataques que aprende por nivel
CREATE TABLE pokemon_ataque (
    id_pokemon  INTEGER   NOT NULL,
    id_ataque   INTEGER   NOT NULL,
    nivel       SMALLINT  NOT NULL DEFAULT 1,
    CONSTRAINT pk_pokemon_ataque         PRIMARY KEY (id_pokemon, id_ataque),
    CONSTRAINT fk_pokemon_ataque_pokemon FOREIGN KEY (id_pokemon)
        REFERENCES pokemon (id_pokemon) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT fk_pokemon_ataque_ataque  FOREIGN KEY (id_ataque)
        REFERENCES ataque (id_ataque) ON DELETE RESTRICT ON UPDATE NO ACTION,
    CONSTRAINT ck_pokemon_ataque_nivel   CHECK (nivel BETWEEN 0 AND 100)
);
COMMENT ON COLUMN pokemon_ataque.nivel IS 'Nivel en que lo aprende. 0 = lo aprende al evolucionar.';

-- Pokémon ↔ habilidad (N:M)
CREATE TABLE pokemon_habilidad (
    id_pokemon    INTEGER  NOT NULL,
    id_habilidad  INTEGER  NOT NULL,
    es_oculta     BOOLEAN  NOT NULL DEFAULT FALSE,
    CONSTRAINT pk_pokemon_habilidad           PRIMARY KEY (id_pokemon, id_habilidad),
    CONSTRAINT fk_pokemon_habilidad_pokemon   FOREIGN KEY (id_pokemon)
        REFERENCES pokemon (id_pokemon) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT fk_pokemon_habilidad_habilidad FOREIGN KEY (id_habilidad)
        REFERENCES habilidad (id_habilidad) ON DELETE RESTRICT ON UPDATE NO ACTION
);

-- ---------------------------------------------------------------------
-- Auditoría
-- ---------------------------------------------------------------------

CREATE TABLE auditoria_borrado (
    id_auditoria     BIGINT        GENERATED ALWAYS AS IDENTITY,
    tabla_afectada   VARCHAR(40)   NOT NULL DEFAULT 'pokemon',
    id_registro      INTEGER       NOT NULL,
    numero_nacional  SMALLINT,
    nombre           VARCHAR(40),
    tipos            VARCHAR(60),
    regiones         VARCHAR(200),
    usuario_bd       VARCHAR(63)   NOT NULL DEFAULT current_user,
    usuario_app      VARCHAR(60),
    fecha            TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT pk_auditoria_borrado PRIMARY KEY (id_auditoria)
);
COMMENT ON TABLE  auditoria_borrado             IS 'Registro de cada borrado de Pokémon (trigger trg_auditar_borrado_pokemon).';
COMMENT ON COLUMN auditoria_borrado.usuario_bd  IS 'Cuenta de PostgreSQL que ejecutó el DELETE (current_user).';
COMMENT ON COLUMN auditoria_borrado.usuario_app IS 'Persona indicada por la aplicación con set_config(''app.usuario'', ...). NULL si el borrado se hizo fuera de la app.';

-- ---------------------------------------------------------------------
-- Índices (además de los que crean automáticamente PK y UNIQUE)
-- ---------------------------------------------------------------------

-- Búsqueda por nombre en el listado: WHERE lower(nombre) LIKE lower(:q) || '%'
CREATE INDEX ix_pokemon_nombre_lower ON pokemon (lower(nombre) varchar_pattern_ops);
-- Filtro por género
CREATE INDEX ix_pokemon_genero ON pokemon (id_genero);
-- Filtro multirregión: EXISTS (... WHERE id_region IN (:regiones)). La PK empieza
-- por id_pokemon, así que hace falta un índice que empiece por id_region.
CREATE INDEX ix_pokemon_region_region ON pokemon_region (id_region, id_pokemon);
-- Filtro por tipo
CREATE INDEX ix_pokemon_tipo_tipo ON pokemon_tipo (id_tipo, id_pokemon);
-- Filtro por ataque ("Pokémon que aprenden X")
CREATE INDEX ix_pokemon_ataque_ataque ON pokemon_ataque (id_ataque, id_pokemon);
-- Habilidad → Pokémon
CREATE INDEX ix_pokemon_habilidad_habilidad ON pokemon_habilidad (id_habilidad);
-- Ranking de ataques por tipo (función de ventana) y join ataque → tipo
CREATE INDEX ix_ataque_tipo ON ataque (id_tipo);
-- Como mucho una habilidad oculta por Pokémon (índice único parcial)
CREATE UNIQUE INDEX ux_pokemon_habilidad_oculta ON pokemon_habilidad (id_pokemon) WHERE es_oculta;
-- Consulta de la auditoría por fecha
CREATE INDEX ix_auditoria_fecha ON auditoria_borrado (fecha DESC);

-- ---------------------------------------------------------------------
-- Descripción de columnas (alimenta el diccionario de datos)
-- ---------------------------------------------------------------------
COMMENT ON COLUMN region.id_region            IS 'Identificador de la región.';
COMMENT ON COLUMN region.nombre               IS 'Nombre de la región (Kanto, Johto, ...).';
COMMENT ON COLUMN region.generacion           IS 'Generación de juegos en que se introdujo la región.';
COMMENT ON COLUMN tipo.id_tipo                IS 'Identificador del tipo.';
COMMENT ON COLUMN tipo.nombre                 IS 'Nombre del tipo en español.';
COMMENT ON COLUMN tipo.slug                   IS 'Identificador estable en minúsculas (fire, water, ...) para estilos CSS.';
COMMENT ON COLUMN genero.id_genero            IS 'Identificador del género posible.';
COMMENT ON COLUMN genero.nombre               IS 'Macho, Hembra, Ambos o Sin género.';
COMMENT ON COLUMN genero.descripcion          IS 'Texto explicativo para mostrar en el detalle.';
COMMENT ON COLUMN categoria_ataque.id_categoria IS 'Identificador de la categoría.';
COMMENT ON COLUMN categoria_ataque.nombre     IS 'Físico, Especial o Estado.';
COMMENT ON COLUMN metodo_evolucion.id_metodo  IS 'Identificador del método.';
COMMENT ON COLUMN metodo_evolucion.nombre     IS 'Nombre del método (Subir de nivel, Usar objeto, ...).';
COMMENT ON COLUMN habilidad.id_habilidad      IS 'Identificador de la habilidad.';
COMMENT ON COLUMN habilidad.nombre            IS 'Nombre de la habilidad en español.';
COMMENT ON COLUMN habilidad.descripcion       IS 'Efecto de la habilidad.';
COMMENT ON COLUMN ataque.id_ataque            IS 'Identificador del ataque.';
COMMENT ON COLUMN ataque.nombre               IS 'Nombre del ataque en español.';
COMMENT ON COLUMN ataque.id_tipo              IS 'Tipo del ataque.';
COMMENT ON COLUMN ataque.id_categoria         IS 'Categoría del ataque.';
COMMENT ON COLUMN pokemon.id_pokemon          IS 'Identificador interno del Pokémon.';
COMMENT ON COLUMN pokemon.numero_nacional     IS 'Número en la Pokédex Nacional.';
COMMENT ON COLUMN pokemon.nombre              IS 'Nombre del Pokémon.';
COMMENT ON COLUMN pokemon.altura_m            IS 'Altura en metros.';
COMMENT ON COLUMN pokemon.peso_kg             IS 'Peso en kilogramos.';
COMMENT ON COLUMN pokemon.descripcion         IS 'Entrada de la Pokédex en español. NULL si la fuente no la tiene en español (899-1025).';
COMMENT ON COLUMN pokemon.url_imagen          IS 'Imagen externa (sprite de PokéAPI, 96×96) que la app muestra a 64×64. Es lo único que viene de fuera; NULL = imagen de respaldo.';
COMMENT ON COLUMN pokemon.id_genero           IS 'Género posible del Pokémon.';
COMMENT ON COLUMN pokemon.es_legendario       IS 'TRUE si es legendario.';
COMMENT ON COLUMN pokemon.es_mitico           IS 'TRUE si es mítico (excluyente con legendario).';
COMMENT ON COLUMN pokemon.fecha_creacion      IS 'Fecha de registro en la base.';
COMMENT ON COLUMN evolucion.id_pokemon_origen IS 'Pokémon que evoluciona (preevolución).';
COMMENT ON COLUMN evolucion.id_pokemon_destino IS 'Pokémon resultante. Único: cada Pokémon tiene como máximo una preevolución.';
COMMENT ON COLUMN evolucion.id_metodo         IS 'Método de evolución.';
COMMENT ON COLUMN evolucion.nivel             IS 'Nivel mínimo, si la evolución es por nivel.';
COMMENT ON COLUMN pokemon_region.id_pokemon   IS 'Pokémon.';
COMMENT ON COLUMN pokemon_region.id_region    IS 'Región en cuya Pokédex aparece.';
COMMENT ON COLUMN pokemon_tipo.id_pokemon     IS 'Pokémon.';
COMMENT ON COLUMN pokemon_tipo.id_tipo        IS 'Tipo del Pokémon.';
COMMENT ON COLUMN pokemon_tipo.slot           IS '1 = tipo principal, 2 = tipo secundario.';
COMMENT ON COLUMN pokemon_ataque.id_pokemon   IS 'Pokémon.';
COMMENT ON COLUMN pokemon_ataque.id_ataque    IS 'Ataque que aprende.';
COMMENT ON COLUMN pokemon_habilidad.id_pokemon   IS 'Pokémon.';
COMMENT ON COLUMN pokemon_habilidad.id_habilidad IS 'Habilidad que puede tener.';
COMMENT ON COLUMN pokemon_habilidad.es_oculta    IS 'TRUE si es su habilidad oculta (como máximo una).';
COMMENT ON COLUMN auditoria_borrado.id_auditoria    IS 'Identificador del registro de auditoría.';
COMMENT ON COLUMN auditoria_borrado.tabla_afectada  IS 'Tabla donde se borró el dato.';
COMMENT ON COLUMN auditoria_borrado.id_registro     IS 'id_pokemon del registro borrado.';
COMMENT ON COLUMN auditoria_borrado.numero_nacional IS 'Número nacional del Pokémon borrado.';
COMMENT ON COLUMN auditoria_borrado.nombre          IS 'Nombre del Pokémon borrado.';
COMMENT ON COLUMN auditoria_borrado.tipos           IS 'Tipos que tenía, en texto (copia histórica).';
COMMENT ON COLUMN auditoria_borrado.regiones        IS 'Regiones donde aparecía, en texto (copia histórica).';
COMMENT ON COLUMN auditoria_borrado.fecha           IS 'Fecha y hora del borrado.';

-- ---------------------------------------------------------------------
-- Permisos de la cuenta de la aplicación
-- ---------------------------------------------------------------------

GRANT USAGE ON SCHEMA public TO pokedex_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO pokedex_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO pokedex_app;
-- La auditoría solo se lee y se inserta (desde el trigger): la app no puede alterarla
REVOKE UPDATE, DELETE ON auditoria_borrado FROM pokedex_app;
-- Las vistas y tablas que se creen después (Fase 4) heredan permisos de lectura
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO pokedex_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO pokedex_app;
