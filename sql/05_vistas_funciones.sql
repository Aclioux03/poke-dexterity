-- =====================================================================
-- PokeDexterity · 05_vistas_funciones.sql
-- Ejecutar conectado como postgres a la base "pokedex", después de
-- 04_datos.sql. Vistas, función y procedimientos que usa la aplicación.
-- pokedex_app recibe SELECT sobre las vistas y EXECUTE sobre las rutinas
-- por los ALTER DEFAULT PRIVILEGES de 02_esquema.sql.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Vista 1 · v_pokemon_resumen
-- Una fila por Pokémon con todo lo que muestra una tarjeta del listado:
-- tipos y regiones ya agregados. Evita repetir los mismos JOIN y
-- string_agg en cada consulta del backend.
-- Uso: listado principal y tarjetas.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_pokemon_resumen AS
SELECT p.id_pokemon,
       p.numero_nacional,
       p.nombre,
       p.url_imagen,
       g.nombre                                            AS genero,
       ro.nombre                                           AS region_origen,
       ro.slug                                             AS region_origen_slug,
       p.es_legendario,
       p.es_mitico,
       t.tipos,
       t.tipos_slug,
       t.tipo_principal_slug,
       r.regiones,
       r.regiones_slug
FROM pokemon p
JOIN genero g  ON g.id_genero  = p.id_genero
JOIN region ro ON ro.id_region = p.id_region_origen
JOIN LATERAL (
    SELECT string_agg(ti.nombre, ' / ' ORDER BY pt.slot)        AS tipos,
           string_agg(ti.slug, ' ' ORDER BY pt.slot)            AS tipos_slug,
           min(ti.slug) FILTER (WHERE pt.slot = 1)              AS tipo_principal_slug
    FROM pokemon_tipo pt
    JOIN tipo ti ON ti.id_tipo = pt.id_tipo
    WHERE pt.id_pokemon = p.id_pokemon
) t ON TRUE
LEFT JOIN LATERAL (
    SELECT string_agg(re.nombre, ', ' ORDER BY re.generacion)   AS regiones,
           string_agg(re.slug, ' ' ORDER BY re.generacion)      AS regiones_slug
    FROM pokemon_region pr
    JOIN region re ON re.id_region = pr.id_region
    WHERE pr.id_pokemon = p.id_pokemon
) r ON TRUE;

COMMENT ON VIEW v_pokemon_resumen IS
    'Una fila por Pokémon con género, región de origen, tipos y regiones agregados (tarjetas del listado).';

-- ---------------------------------------------------------------------
-- Vista 2 · v_pokemon_ataques
-- Ataques que aprende cada Pokémon con nombre, tipo, categoría, poder,
-- precisión y nivel. Uso: tabla de ataques en el detalle.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_pokemon_ataques AS
SELECT pa.id_pokemon,
       pa.nivel,
       CASE WHEN pa.nivel = 0 THEN 'Al evolucionar' ELSE pa.nivel::text END AS nivel_texto,
       a.id_ataque,
       a.nombre  AS ataque,
       t.nombre  AS tipo,
       t.slug    AS tipo_slug,
       c.nombre  AS categoria,
       a.poder,
       a.precision
FROM pokemon_ataque pa
JOIN ataque a           ON a.id_ataque    = pa.id_ataque
JOIN tipo t             ON t.id_tipo      = a.id_tipo
JOIN categoria_ataque c ON c.id_categoria = a.id_categoria;

COMMENT ON VIEW v_pokemon_ataques IS
    'Ataques por nivel de cada Pokémon con tipo, categoría, poder y precisión (detalle).';

-- ---------------------------------------------------------------------
-- Vista 3 · v_estadisticas_region
-- Resumen por región: cuántos Pokémon aparecen en su Pokédex, cuántos son
-- originarios, legendarios y míticos. Uso: encabezado o panel por región.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_estadisticas_region AS
SELECT r.id_region,
       r.nombre,
       r.slug,
       r.generacion,
       count(DISTINCT pr.id_pokemon)                                   AS pokemon_en_pokedex,
       count(DISTINCT p.id_pokemon)                                    AS pokemon_originarios,
       count(DISTINCT p.id_pokemon) FILTER (WHERE p.es_legendario)     AS legendarios,
       count(DISTINCT p.id_pokemon) FILTER (WHERE p.es_mitico)         AS miticos
FROM region r
LEFT JOIN pokemon_region pr ON pr.id_region = r.id_region
LEFT JOIN pokemon p         ON p.id_region_origen = r.id_region
GROUP BY r.id_region, r.nombre, r.slug, r.generacion;

COMMENT ON VIEW v_estadisticas_region IS 'Conteos por región (Pokédex, originarios, legendarios, míticos).';

-- ---------------------------------------------------------------------
-- Función · fn_cadena_evolutiva(id_pokemon)
-- Devuelve la cadena evolutiva completa a la que pertenece un Pokémon,
-- desde la forma base, con su etapa (1, 2, 3) y cómo se llega a cada una.
-- Técnica: WITH RECURSIVE en dos pasos (subir hasta la base, bajar a las
-- ramas). Uso: sección "Evoluciones" del detalle.
-- Ejemplo: SELECT * FROM fn_cadena_evolutiva(133);  -- Eevee y sus 8 evoluciones
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_cadena_evolutiva(p_id_pokemon INTEGER)
RETURNS TABLE (
    etapa              INTEGER,
    id_pokemon         INTEGER,
    numero_nacional    SMALLINT,
    nombre             VARCHAR,
    id_preevolucion    INTEGER,
    metodo             VARCHAR,
    nivel              SMALLINT,
    detalle            VARCHAR
)
LANGUAGE sql
STABLE
AS $$
    WITH RECURSIVE ancestros AS (           -- 1) subir hasta la forma base
        SELECT p_id_pokemon AS id
        UNION ALL
        SELECT e.id_pokemon_origen
        FROM evolucion e
        JOIN ancestros a ON e.id_pokemon_destino = a.id
    ),
    base AS (
        SELECT a.id FROM ancestros a
        WHERE NOT EXISTS (SELECT 1 FROM evolucion e WHERE e.id_pokemon_destino = a.id)
    ),
    cadena AS (                             -- 2) bajar desde la base por todas las ramas
        SELECT 1 AS etapa, b.id, NULL::INTEGER AS id_pre, NULL::SMALLINT AS id_metodo,
               NULL::SMALLINT AS nivel, NULL::VARCHAR AS detalle
        FROM base b
        UNION ALL
        SELECT c.etapa + 1, e.id_pokemon_destino, e.id_pokemon_origen, e.id_metodo, e.nivel, e.detalle
        FROM evolucion e
        JOIN cadena c ON e.id_pokemon_origen = c.id
    )
    SELECT c.etapa, p.id_pokemon, p.numero_nacional, p.nombre, c.id_pre,
           m.nombre, c.nivel, c.detalle
    FROM cadena c
    JOIN pokemon p               ON p.id_pokemon = c.id
    LEFT JOIN metodo_evolucion m ON m.id_metodo  = c.id_metodo
    ORDER BY c.etapa, p.numero_nacional;
$$;

COMMENT ON FUNCTION fn_cadena_evolutiva(INTEGER) IS
    'Cadena evolutiva completa (con ramificaciones) del Pokémon indicado. Usa WITH RECURSIVE.';

-- ---------------------------------------------------------------------
-- Procedimiento 1 · sp_registrar_pokemon
-- Crea un Pokémon con sus tipos y regiones en una sola operación. Si un
-- tipo o una región no existe, lanza un error y no queda nada a medias
-- (el CALL forma parte de la transacción de quien lo invoca).
-- Ejemplo:
--   CALL sp_registrar_pokemon(9001, 'Pokeprueba', 0.4, 6.0, 'Ambos', 'kanto',
--                             ARRAY['electric'], ARRAY['kanto','johto'], NULL);
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_registrar_pokemon(
    p_numero_nacional  SMALLINT,
    p_nombre           VARCHAR,
    p_altura_m         NUMERIC,
    p_peso_kg          NUMERIC,
    p_genero           VARCHAR,
    p_region_origen    VARCHAR,
    p_tipos            VARCHAR[],
    p_regiones         VARCHAR[],
    INOUT p_id_pokemon INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_slug VARCHAR;
    i      INTEGER;
BEGIN
    IF p_tipos IS NULL OR cardinality(p_tipos) NOT BETWEEN 1 AND 2 THEN
        RAISE EXCEPTION 'Un Pokémon debe tener uno o dos tipos (recibidos: %).', coalesce(cardinality(p_tipos), 0)
            USING ERRCODE = 'check_violation';
    END IF;

    INSERT INTO pokemon (numero_nacional, nombre, altura_m, peso_kg, id_genero, id_region_origen)
    SELECT p_numero_nacional, p_nombre, p_altura_m, p_peso_kg, g.id_genero, r.id_region
    FROM genero g, region r
    WHERE g.nombre = p_genero AND r.slug = p_region_origen
    RETURNING id_pokemon INTO p_id_pokemon;

    IF p_id_pokemon IS NULL THEN
        RAISE EXCEPTION 'Género "%" o región "%" no existen.', p_genero, p_region_origen
            USING ERRCODE = 'foreign_key_violation';
    END IF;

    FOR i IN 1 .. cardinality(p_tipos) LOOP
        INSERT INTO pokemon_tipo (id_pokemon, id_tipo, slot)
        SELECT p_id_pokemon, t.id_tipo, i FROM tipo t WHERE t.slug = p_tipos[i];
        IF NOT FOUND THEN
            RAISE EXCEPTION 'El tipo "%" no existe.', p_tipos[i] USING ERRCODE = 'foreign_key_violation';
        END IF;
    END LOOP;

    FOREACH v_slug IN ARRAY coalesce(p_regiones, ARRAY[]::VARCHAR[]) LOOP
        INSERT INTO pokemon_region (id_pokemon, id_region)
        SELECT p_id_pokemon, r.id_region FROM region r WHERE r.slug = v_slug;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'La región "%" no existe.', v_slug USING ERRCODE = 'foreign_key_violation';
        END IF;
    END LOOP;
END;
$$;

COMMENT ON PROCEDURE sp_registrar_pokemon(SMALLINT, VARCHAR, NUMERIC, NUMERIC, VARCHAR, VARCHAR, VARCHAR[], VARCHAR[], INTEGER) IS
    'Crea un Pokémon con sus tipos y regiones; si algo falla, no inserta nada.';

-- ---------------------------------------------------------------------
-- Procedimiento 2 · sp_eliminar_pokemon
-- Borra un Pokémon dejando en la auditoría quién lo hizo. Fija
-- app.usuario solo para la transacción actual y ejecuta el DELETE; el
-- trigger trg_auditar_borrado_pokemon registra los datos.
-- Ejemplo: CALL sp_eliminar_pokemon(1026, 'Jose Alejandro');
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_eliminar_pokemon(p_id_pokemon INTEGER, p_usuario VARCHAR)
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM set_config('app.usuario', coalesce(p_usuario, ''), true);
    DELETE FROM pokemon WHERE id_pokemon = p_id_pokemon;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe un Pokémon con id %.', p_id_pokemon USING ERRCODE = 'no_data_found';
    END IF;
END;
$$;

COMMENT ON PROCEDURE sp_eliminar_pokemon(INTEGER, VARCHAR) IS
    'Borra un Pokémon registrando en la auditoría el usuario de la aplicación.';
