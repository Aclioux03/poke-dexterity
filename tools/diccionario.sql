-- Genera las filas del diccionario de datos (docs/diccionario_datos.md) desde el catálogo de PostgreSQL.
-- Uso: psql -d pokedex -At -f tools/diccionario.sql
WITH cols AS (
  SELECT c.table_name, c.column_name, c.ordinal_position,
         CASE WHEN c.data_type IN ('character varying') THEN 'VARCHAR('||c.character_maximum_length||')'
              WHEN c.data_type='numeric' THEN 'NUMERIC('||c.numeric_precision||','||c.numeric_scale||')'
              WHEN c.data_type='timestamp with time zone' THEN 'TIMESTAMPTZ'
              ELSE upper(c.data_type) END
         || CASE WHEN c.is_identity='YES' THEN ' IDENTITY' ELSE '' END AS tipo,
         CASE WHEN c.is_nullable='YES' THEN 'Sí' ELSE 'No' END AS nulo,
         c.column_default,
         col_description((quote_ident(c.table_name))::regclass, c.ordinal_position) AS comentario
  FROM information_schema.columns c
  JOIN information_schema.tables tb ON tb.table_schema = c.table_schema AND tb.table_name = c.table_name AND tb.table_type = 'BASE TABLE'
  WHERE c.table_schema='public'),
keys AS (
  SELECT kcu.table_name, kcu.column_name,
         string_agg(DISTINCT CASE tc.constraint_type WHEN 'PRIMARY KEY' THEN 'PK' WHEN 'FOREIGN KEY' THEN 'FK' WHEN 'UNIQUE' THEN 'UK' END, ', ') AS clave
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu ON kcu.constraint_name=tc.constraint_name AND kcu.table_schema=tc.table_schema
  WHERE tc.table_schema='public' AND tc.constraint_type IN ('PRIMARY KEY','FOREIGN KEY','UNIQUE')
  GROUP BY 1,2),
fks AS (
  SELECT kcu.table_name, kcu.column_name, ccu.table_name AS ref_tabla
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu ON kcu.constraint_name=tc.constraint_name
  JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name=tc.constraint_name
  WHERE tc.constraint_type='FOREIGN KEY' AND tc.table_schema='public')
SELECT '| '||c.table_name||' | '||c.column_name||' | '||c.tipo||' | '||c.nulo||' | '||coalesce(k.clave,'')||' | '||
       coalesce(replace(c.comentario,'|','/'), '')||
       CASE WHEN f.ref_tabla IS NOT NULL THEN ' Referencia a '||f.ref_tabla||'.' ELSE '' END||
       CASE WHEN c.column_default IS NOT NULL AND c.column_default NOT LIKE 'nextval%' THEN ' Por defecto: '||replace(c.column_default,'::character varying','')||'.' ELSE '' END ||' |'
FROM cols c LEFT JOIN keys k USING(table_name,column_name) LEFT JOIN fks f USING(table_name,column_name)
ORDER BY array_position(ARRAY['region','tipo','genero','categoria_ataque','metodo_evolucion','habilidad','ataque','pokemon','evolucion','pokemon_region','pokemon_tipo','pokemon_ataque','pokemon_habilidad','auditoria_borrado']::text[], c.table_name::text), c.ordinal_position;
