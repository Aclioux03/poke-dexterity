-- =====================================================================
-- PokeDexterity · 08_verificacion.sql
-- Comprueba que la carga (04_datos.sql) quedó completa y consistente.
-- Solo lectura. Ejecutar después de 05_vistas_funciones.sql.
-- Resultado: una fila por control con OK o FALLA. Todo debe salir OK.
-- =====================================================================

WITH controles (orden, control, esperado, obtenido) AS (
    -- Totales
    SELECT 1, 'Pokémon cargados', '1025', (SELECT count(*) FROM pokemon)::text
    UNION ALL SELECT 2, 'Regiones', '9', (SELECT count(*) FROM region)::text
    UNION ALL SELECT 3, 'Tipos', '18', (SELECT count(*) FROM tipo)::text
    UNION ALL SELECT 4, 'Géneros', '4', (SELECT count(*) FROM genero)::text
    UNION ALL SELECT 5, 'Categorías de ataque', '3', (SELECT count(*) FROM categoria_ataque)::text
    UNION ALL SELECT 6, 'Ataques', '691', (SELECT count(*) FROM ataque)::text
    UNION ALL SELECT 7, 'Filas pokemon_ataque', '14934', (SELECT count(*) FROM pokemon_ataque)::text
    UNION ALL SELECT 8, 'Filas pokemon_region', '3255', (SELECT count(*) FROM pokemon_region)::text
    UNION ALL SELECT 9, 'Evoluciones', '484', (SELECT count(*) FROM evolucion)::text

    -- Completitud de cada Pokémon
    UNION ALL SELECT 10, 'Números nacionales del 1 al 1025 sin huecos', '1025',
        (SELECT count(DISTINCT numero_nacional) FROM pokemon WHERE numero_nacional BETWEEN 1 AND 1025)::text
    UNION ALL SELECT 11, 'Pokémon sin tipo principal (slot 1)', '0',
        (SELECT count(*) FROM pokemon p WHERE NOT EXISTS
            (SELECT 1 FROM pokemon_tipo t WHERE t.id_pokemon = p.id_pokemon AND t.slot = 1))::text
    UNION ALL SELECT 12, 'Pokémon con más de dos tipos', '0',
        (SELECT count(*) FROM (SELECT id_pokemon FROM pokemon_tipo GROUP BY id_pokemon HAVING count(*) > 2) x)::text
    UNION ALL SELECT 13, 'Pokémon sin región', '0',
        (SELECT count(*) FROM pokemon p WHERE NOT EXISTS
            (SELECT 1 FROM pokemon_region r WHERE r.id_pokemon = p.id_pokemon))::text
    UNION ALL SELECT 14, 'Pokémon no asociados a su región de origen', '0',
        (SELECT count(*) FROM pokemon p WHERE NOT EXISTS
            (SELECT 1 FROM pokemon_region r WHERE r.id_pokemon = p.id_pokemon AND r.id_region = p.id_region_origen))::text
    UNION ALL SELECT 15, 'Pokémon sin habilidades', '0',
        (SELECT count(*) FROM pokemon p WHERE NOT EXISTS
            (SELECT 1 FROM pokemon_habilidad h WHERE h.id_pokemon = p.id_pokemon))::text
    UNION ALL SELECT 16, 'Pokémon sin ataques', '0',
        (SELECT count(*) FROM pokemon p WHERE NOT EXISTS
            (SELECT 1 FROM pokemon_ataque a WHERE a.id_pokemon = p.id_pokemon))::text
    UNION ALL SELECT 17, 'Pokémon sin URL de imagen', '0',
        (SELECT count(*) FROM pokemon WHERE url_imagen IS NULL)::text
    -- La fuente no tiene entrada en español para Hisui (899-905) ni Paldea (906-1025):
    -- se dejan en NULL y la app muestra "Descripción no disponible".
    UNION ALL SELECT 18, 'Pokémon sin descripción (esperado: solo 899-1025)', '127',
        (SELECT count(*) FROM pokemon WHERE descripcion IS NULL)::text
    UNION ALL SELECT 19, 'Pokémon sin descripción fuera de 899-1025', '0',
        (SELECT count(*) FROM pokemon WHERE descripcion IS NULL AND numero_nacional < 899)::text
    UNION ALL SELECT 20, 'Nombres con espacios sobrantes', '0',
        (SELECT count(*) FROM pokemon WHERE nombre <> btrim(nombre))::text

    -- Coherencia de ataques
    UNION ALL SELECT 21, 'Ataques de estado con poder', '0',
        (SELECT count(*) FROM ataque a JOIN categoria_ataque c USING (id_categoria)
         WHERE c.nombre = 'Estado' AND a.poder IS NOT NULL)::text
    UNION ALL SELECT 22, 'Ataques que ningún Pokémon aprende', '0',
        (SELECT count(*) FROM ataque a WHERE NOT EXISTS
            (SELECT 1 FROM pokemon_ataque pa WHERE pa.id_ataque = a.id_ataque))::text

    -- Coherencia de evoluciones (sin ciclos: ninguna cadena pasa de 3 etapas)
    UNION ALL SELECT 23, 'Cadenas evolutivas con más de 3 etapas', '0',
        (WITH RECURSIVE c AS (
            SELECT e.id_pokemon_destino AS id, 2 AS etapa FROM evolucion e
            WHERE NOT EXISTS (SELECT 1 FROM evolucion x WHERE x.id_pokemon_destino = e.id_pokemon_origen)
            UNION ALL
            SELECT e.id_pokemon_destino, c.etapa + 1 FROM evolucion e JOIN c ON e.id_pokemon_origen = c.id
            WHERE c.etapa < 10)
         SELECT count(*) FROM c WHERE etapa > 3)::text

    -- Muestras conocidas
    UNION ALL SELECT 24, 'Tipos de Charizard', 'Fuego / Volador',
        (SELECT tipos FROM v_pokemon_resumen WHERE nombre = 'Charizard')
    UNION ALL SELECT 25, 'Tipos de Bulbasaur', 'Planta / Veneno',
        (SELECT tipos FROM v_pokemon_resumen WHERE nombre = 'Bulbasaur')
    UNION ALL SELECT 26, 'Nivel en que Charmander aprende Lanzallamas', '24',
        (SELECT nivel::text FROM v_pokemon_ataques v JOIN pokemon p USING (id_pokemon)
         WHERE p.nombre = 'Charmander' AND v.ataque = 'Lanzallamas')
    UNION ALL SELECT 27, 'Poder / precisión de Lanzallamas', '90 / 100',
        (SELECT poder || ' / ' || precision FROM ataque WHERE nombre = 'Lanzallamas')
    UNION ALL SELECT 28, 'Número de Gible en la Pokédex de Paldea', '126',
        (SELECT pr.numero_regional::text FROM pokemon_region pr
         JOIN pokemon p USING (id_pokemon) JOIN region r USING (id_region)
         WHERE p.nombre = 'Gible' AND r.slug = 'paldea')
    UNION ALL SELECT 29, 'Evoluciones directas de Eevee', '8',
        (SELECT count(*) FROM evolucion e JOIN pokemon p ON p.id_pokemon = e.id_pokemon_origen
         WHERE p.nombre = 'Eevee')::text
    UNION ALL SELECT 30, 'Género de Ditto', 'Sin género',
        (SELECT genero FROM v_pokemon_resumen WHERE nombre = 'Ditto')
    UNION ALL SELECT 31, 'Regiones en cuya Pokédex aparece Pikachu', '8',
        (SELECT count(*) FROM pokemon_region pr JOIN pokemon p USING (id_pokemon) WHERE p.nombre = 'Pikachu')::text
)
SELECT orden, control, esperado, obtenido,
       CASE WHEN obtenido IS NOT DISTINCT FROM esperado THEN 'OK' ELSE 'FALLA' END AS resultado
FROM controles
ORDER BY orden;
