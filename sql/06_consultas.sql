-- =====================================================================
-- PokeDexterity · 06_consultas.sql
-- Las 12 consultas del enunciado (sección 7 del documento).
-- Solo lectura: se pueden ejecutar en cualquier orden, cuantas veces sea.
-- Los valores fijos ('kanto', 'Lanzallamas', ...) son ejemplos: en la
-- aplicación se reemplazan por parámetros con nombre (:region, :ataque, ...)
-- de NamedParameterJdbcTemplate (ver docs/guia_backend.md).
-- =====================================================================


-- ---------------------------------------------------------------------
-- Consulta 1 · JOIN de tres o más tablas
-- Pregunta: ¿cuál es el número, nombre, género y tipo principal de cada Pokémon?
-- Dónde se usa: tarjetas del listado principal.
-- Técnica: INNER JOIN de pokemon, genero, pokemon_tipo y tipo (4 tablas).
-- Justificación: cada dato vive en su tabla normalizada; el JOIN los reúne
-- sin duplicar texto. El filtro slot = 1 deja una fila por Pokémon.
-- ---------------------------------------------------------------------
SELECT p.numero_nacional,
       p.nombre,
       g.nombre AS genero,
       t.nombre AS tipo_principal
FROM pokemon p
JOIN genero g        ON g.id_genero  = p.id_genero
JOIN pokemon_tipo pt ON pt.id_pokemon = p.id_pokemon AND pt.slot = 1
JOIN tipo t          ON t.id_tipo    = pt.id_tipo
ORDER BY p.numero_nacional
LIMIT 20;


-- ---------------------------------------------------------------------
-- Consulta 2 · IN para el filtro multirregión
-- Pregunta: ¿qué Pokémon aparecen en Kanto o en Johto?
-- Dónde se usa: listado, cuando el usuario marca varias regiones.
-- Técnica: EXISTS con IN (:regiones) sobre pokemon_region.
-- Justificación: con un JOIN directo, un Pokémon presente en las dos
-- regiones saldría dos veces; EXISTS solo pregunta "¿aparece en alguna?"
-- y devuelve una sola fila por Pokémon. Si la lista está vacía, la app
-- omite la condición completa. Usa el índice ix_pokemon_region_region.
-- ---------------------------------------------------------------------
SELECT p.numero_nacional, p.nombre
FROM pokemon p
WHERE EXISTS (
    SELECT 1
    FROM pokemon_region pr
    JOIN region r ON r.id_region = pr.id_region
    WHERE pr.id_pokemon = p.id_pokemon
      AND r.slug IN ('kanto', 'johto')          -- en la app: IN (:regiones)
)
ORDER BY p.numero_nacional;


-- ---------------------------------------------------------------------
-- Consulta 3 · JOIN con ORDER BY para los ataques del detalle
-- Pregunta: ¿qué ataques aprende Charizard por nivel, con su tipo,
-- categoría, poder y precisión?
-- Dónde se usa: tabla de ataques del detalle.
-- Técnica: JOIN de 5 tablas ordenado por nivel y nombre.
-- Justificación: el orden por nivel muestra la progresión real del
-- Pokémon; los de nivel 0 (al evolucionar) quedan primero.
-- ---------------------------------------------------------------------
SELECT CASE WHEN pa.nivel = 0 THEN 'Al evolucionar' ELSE pa.nivel::text END AS nivel,
       a.nombre  AS ataque,
       t.nombre  AS tipo,
       c.nombre  AS categoria,
       a.poder,
       a.precision
FROM pokemon p
JOIN pokemon_ataque pa  ON pa.id_pokemon  = p.id_pokemon
JOIN ataque a           ON a.id_ataque    = pa.id_ataque
JOIN tipo t             ON t.id_tipo      = a.id_tipo
JOIN categoria_ataque c ON c.id_categoria = a.id_categoria
WHERE p.nombre = 'Charizard'                    -- en la app: p.id_pokemon = :id
ORDER BY pa.nivel, a.nombre;


-- ---------------------------------------------------------------------
-- Consulta 4 · Filtro por género
-- Pregunta: ¿qué Pokémon no tienen género?
-- Dónde se usa: filtro "Género" del listado.
-- Técnica: JOIN con el catálogo y WHERE sobre su nombre.
-- Justificación: el género sale del catálogo, no de texto libre; el
-- índice ix_pokemon_genero acelera el filtro.
-- ---------------------------------------------------------------------
SELECT p.numero_nacional, p.nombre, g.nombre AS genero
FROM pokemon p
JOIN genero g ON g.id_genero = p.id_genero
WHERE g.nombre = 'Sin género'                   -- en la app: p.id_genero = :genero
ORDER BY p.numero_nacional;


-- ---------------------------------------------------------------------
-- Consulta 5 · GROUP BY con HAVING
-- Pregunta: ¿qué tipos tienen más de 80 Pokémon (contando tipo principal
-- y secundario)?
-- Dónde se usa: estadísticas / ordenar el selector de tipos por popularidad.
-- Técnica: GROUP BY tipo y HAVING sobre el conteo.
-- Justificación: WHERE filtra filas antes de agrupar; HAVING filtra los
-- grupos ya contados.
-- ---------------------------------------------------------------------
SELECT t.nombre AS tipo, count(*) AS cantidad_pokemon
FROM pokemon_tipo pt
JOIN tipo t ON t.id_tipo = pt.id_tipo
GROUP BY t.nombre
HAVING count(*) > 80
ORDER BY cantidad_pokemon DESC;


-- ---------------------------------------------------------------------
-- Consulta 6 · Subconsulta en WHERE
-- Pregunta: ¿qué ataques tienen más poder que el promedio de los ataques
-- de su misma categoría?
-- Dónde se usa: resaltar ataques "fuertes" en el detalle.
-- Técnica: subconsulta correlacionada en WHERE.
-- Justificación: el promedio cambia según la categoría de cada fila, por
-- eso la subconsulta se correlaciona con a.id_categoria.
-- ---------------------------------------------------------------------
SELECT a.nombre, c.nombre AS categoria, a.poder
FROM ataque a
JOIN categoria_ataque c ON c.id_categoria = a.id_categoria
WHERE a.poder > (SELECT avg(a2.poder)
                 FROM ataque a2
                 WHERE a2.id_categoria = a.id_categoria)
ORDER BY a.poder DESC, a.nombre
LIMIT 20;


-- ---------------------------------------------------------------------
-- Consulta 7 · EXISTS / NOT EXISTS
-- Pregunta: ¿qué Pokémon aprenden Lanzallamas y NO son de tipo Fuego?
-- Dónde se usa: filtro "Ataque" del listado (la parte EXISTS).
-- Técnica: EXISTS para "aprende el ataque" y NOT EXISTS para "no tiene el tipo".
-- Justificación: EXISTS se detiene en la primera coincidencia y no
-- duplica filas; usa ix_pokemon_ataque_ataque e ix_pokemon_tipo_tipo.
-- ---------------------------------------------------------------------
SELECT p.numero_nacional, p.nombre
FROM pokemon p
WHERE EXISTS (SELECT 1
              FROM pokemon_ataque pa
              JOIN ataque a ON a.id_ataque = pa.id_ataque
              WHERE pa.id_pokemon = p.id_pokemon
                AND a.nombre = 'Lanzallamas')     -- en la app: pa.id_ataque = :ataque
  AND NOT EXISTS (SELECT 1
                  FROM pokemon_tipo pt
                  JOIN tipo t ON t.id_tipo = pt.id_tipo
                  WHERE pt.id_pokemon = p.id_pokemon
                    AND t.slug = 'fire')
ORDER BY p.numero_nacional;


-- ---------------------------------------------------------------------
-- Consulta 8 · LEFT JOIN para detectar registros faltantes
-- Pregunta: ¿qué Pokémon no evolucionan ni vienen de una evolución?
-- Dónde se usa: detalle ("Este Pokémon no tiene evoluciones") y control
-- de calidad de los datos.
-- Técnica: dos LEFT JOIN a evolucion y filtro IS NULL en ambos lados.
-- Justificación: el LEFT JOIN conserva al Pokémon aunque no tenga filas
-- relacionadas; IS NULL detecta justamente la ausencia.
-- ---------------------------------------------------------------------
SELECT p.numero_nacional, p.nombre
FROM pokemon p
LEFT JOIN evolucion como_origen  ON como_origen.id_pokemon_origen   = p.id_pokemon
LEFT JOIN evolucion como_destino ON como_destino.id_pokemon_destino = p.id_pokemon
WHERE como_origen.id_pokemon_origen IS NULL
  AND como_destino.id_pokemon_destino IS NULL
ORDER BY p.numero_nacional;


-- ---------------------------------------------------------------------
-- Consulta 9 · Agregaciones COUNT, AVG, MAX y MIN
-- Pregunta: por región de origen, ¿cuántos Pokémon hay, cuánto pesan en
-- promedio y cuál es la altura máxima y mínima?
-- Dónde se usa: panel de estadísticas por región.
-- Técnica: funciones de agregación con GROUP BY.
-- Justificación: resume 1.025 filas en una por región.
-- ---------------------------------------------------------------------
SELECT r.nombre                    AS region,
       count(*)                    AS cantidad,
       round(avg(p.peso_kg), 1)    AS peso_promedio_kg,
       max(p.altura_m)             AS altura_max_m,
       min(p.altura_m)             AS altura_min_m,
       count(*) FILTER (WHERE p.es_legendario OR p.es_mitico) AS legendarios_y_miticos
FROM pokemon p
JOIN region r ON r.id_region = p.id_region_origen
GROUP BY r.nombre, r.generacion
ORDER BY r.generacion;


-- ---------------------------------------------------------------------
-- Consulta 10 · INTERSECT (y UNION)
-- Pregunta: ¿qué Pokémon aparecen tanto en Kanto como en Johto?
-- Dónde se usa: opción "Coincidencias entre dos regiones" (operación
-- distinta del filtro multirregión, que muestra los de cualquiera).
-- Técnica: INTERSECT de dos conjuntos.
-- Justificación: expresa directamente "en las dos a la vez".
-- ---------------------------------------------------------------------
SELECT p.numero_nacional, p.nombre
FROM pokemon p
JOIN pokemon_region pr ON pr.id_pokemon = p.id_pokemon
JOIN region r          ON r.id_region   = pr.id_region
WHERE r.slug = 'kanto'                          -- en la app: :region1
INTERSECT
SELECT p.numero_nacional, p.nombre
FROM pokemon p
JOIN pokemon_region pr ON pr.id_pokemon = p.id_pokemon
JOIN region r          ON r.id_region   = pr.id_region
WHERE r.slug = 'johto'                          -- en la app: :region2
ORDER BY 1;

-- Variante con UNION: legendarios de Kanto junto con míticos de Kanto,
-- etiquetados en una sola lista.
SELECT nombre, 'Legendario' AS clase FROM pokemon
WHERE es_legendario AND id_region_origen = (SELECT id_region FROM region WHERE slug = 'kanto')
UNION
SELECT nombre, 'Mítico' FROM pokemon
WHERE es_mitico AND id_region_origen = (SELECT id_region FROM region WHERE slug = 'kanto')
ORDER BY clase, nombre;


-- ---------------------------------------------------------------------
-- Consulta 11 · CTE recursiva (WITH RECURSIVE)
-- Pregunta: ¿cuál es la cadena evolutiva completa de Charmander?
-- Dónde se usa: sección "Evoluciones" del detalle (empaquetada en la
-- función fn_cadena_evolutiva).
-- Técnica: WITH RECURSIVE sobre la tabla evolucion.
-- Justificación: la cantidad de etapas no es fija; la recursión sigue
-- las filas de evolucion hasta que no haya más.
-- ---------------------------------------------------------------------
WITH RECURSIVE cadena AS (
    SELECT p.id_pokemon, p.nombre, 1 AS etapa, NULL::SMALLINT AS nivel
    FROM pokemon p
    WHERE p.nombre = 'Charmander'               -- en la app: :id (forma base)
    UNION ALL
    SELECT d.id_pokemon, d.nombre, c.etapa + 1, e.nivel
    FROM cadena c
    JOIN evolucion e ON e.id_pokemon_origen = c.id_pokemon
    JOIN pokemon d   ON d.id_pokemon        = e.id_pokemon_destino
)
SELECT etapa, nombre, nivel AS evoluciona_al_nivel
FROM cadena
ORDER BY etapa;

-- La misma lógica desde cualquier Pokémon de la cadena (sube y baja):
SELECT * FROM fn_cadena_evolutiva((SELECT id_pokemon FROM pokemon WHERE nombre = 'Eevee'));


-- ---------------------------------------------------------------------
-- Consulta 12 · Función de ventana (RANK)
-- Pregunta: ¿cuáles son los 3 ataques más poderosos de cada tipo?
-- Dónde se usa: sección de estadísticas / ayuda al elegir el filtro de ataque.
-- Técnica: RANK() OVER (PARTITION BY tipo ORDER BY poder DESC).
-- Justificación: numera dentro de cada tipo sin colapsar filas como
-- haría GROUP BY; RANK da el mismo puesto a los empates.
-- ---------------------------------------------------------------------
SELECT tipo, puesto, ataque, poder
FROM (
    SELECT t.nombre AS tipo,
           a.nombre AS ataque,
           a.poder,
           RANK() OVER (PARTITION BY t.id_tipo ORDER BY a.poder DESC) AS puesto
    FROM ataque a
    JOIN tipo t ON t.id_tipo = a.id_tipo
    WHERE a.poder IS NOT NULL
) ranking
WHERE puesto <= 3
ORDER BY tipo, puesto, ataque;

-- Variante con ROW_NUMBER: numeración de los Pokémon dentro de cada
-- región de origen por número nacional (útil para paginar por región).
SELECT r.nombre AS region, p.nombre,
       ROW_NUMBER() OVER (PARTITION BY p.id_region_origen ORDER BY p.numero_nacional) AS n
FROM pokemon p
JOIN region r ON r.id_region = p.id_region_origen
WHERE p.es_legendario
ORDER BY r.generacion, n;
