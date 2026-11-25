-- =====================================================================
-- PokeDexterity · 07_demostraciones.sql
-- Demostraciones de la sección 8 del documento y de la sustentación:
-- UPDATE, DELETE, ALTER TABLE, COMMIT/ROLLBACK, trigger de auditoría,
-- borrado de una región con dependencias y respaldo antes de un DROP.
--
-- CÓMO USARLO (pgAdmin, conectado como postgres a "pokedex"):
--   Ejecutar BLOQUE POR BLOQUE: seleccionar el bloque y presionar F5.
--   Algunos bloques fallan A PROPÓSITO (se indica con "ERROR ESPERADO").
--   Al terminar, la base queda como estaba, salvo la fila nueva en
--   auditoria_borrado (que es justamente la evidencia del trigger).
-- =====================================================================


-- =====================================================================
-- BLOQUE 0 · Preparación: Pokémon de prueba "Demomon"
-- Usa el procedimiento sp_registrar_pokemon (tipos y regiones en una
-- sola operación) y le agrega dos ataques.
-- =====================================================================
CALL sp_registrar_pokemon(9999::SMALLINT, 'Demomon', 0.6, 8.5, 'Ambos', 'kanto',
                          ARRAY['electric'], ARRAY['kanto', 'johto'], NULL);

INSERT INTO pokemon_ataque (id_pokemon, id_ataque, nivel)
SELECT p.id_pokemon, a.id_ataque, v.nivel
FROM (VALUES ('Impactrueno', 1), ('Onda Trueno', 8), ('Rayo', 30), ('Trueno', 44)) AS v(ataque, nivel)
JOIN ataque a  ON a.nombre = v.ataque
JOIN pokemon p ON p.nombre = 'Demomon';

SELECT * FROM v_pokemon_resumen WHERE nombre = 'Demomon';


-- =====================================================================
-- BLOQUE 1 · Tres UPDATE con WHERE (sección 8.1)
-- =====================================================================

-- UPDATE 1: corregir el peso de un Pokémon. El trigger
-- trg_pokemon_fecha_modificacion actualiza fecha_modificacion solo.
UPDATE pokemon
SET peso_kg = 9.0
WHERE nombre = 'Demomon';

SELECT nombre, peso_kg, fecha_creacion, fecha_modificacion
FROM pokemon WHERE nombre = 'Demomon';

-- UPDATE 2: asignar el número regional de Demomon en Kanto
-- (usa el número siguiente al último de Kanto).
UPDATE pokemon_region pr
SET numero_regional = (SELECT max(numero_regional) + 1
                       FROM pokemon_region x
                       WHERE x.id_region = pr.id_region)
WHERE pr.id_pokemon = (SELECT id_pokemon FROM pokemon WHERE nombre = 'Demomon')
  AND pr.id_region  = (SELECT id_region FROM region WHERE slug = 'kanto');

SELECT r.nombre, pr.numero_regional
FROM pokemon_region pr JOIN region r USING (id_region)
WHERE pr.id_pokemon = (SELECT id_pokemon FROM pokemon WHERE nombre = 'Demomon');

-- UPDATE 3: subir 5 niveles a los ataques que Demomon aprende después del nivel 20.
UPDATE pokemon_ataque
SET nivel = nivel + 5
WHERE id_pokemon = (SELECT id_pokemon FROM pokemon WHERE nombre = 'Demomon')
  AND nivel > 20;

SELECT nivel, ataque FROM v_pokemon_ataques
WHERE id_pokemon = (SELECT id_pokemon FROM pokemon WHERE nombre = 'Demomon')
ORDER BY nivel;


-- =====================================================================
-- BLOQUE 2 · DELETE con WHERE (sección 8.1)
-- (El segundo DELETE es el del Pokémon completo, en el BLOQUE 6.)
-- =====================================================================

-- DELETE 1: quitar a Demomon los ataques que aprende después del nivel 40.
DELETE FROM pokemon_ataque
WHERE id_pokemon = (SELECT id_pokemon FROM pokemon WHERE nombre = 'Demomon')
  AND nivel > 40;

SELECT nivel, ataque FROM v_pokemon_ataques
WHERE id_pokemon = (SELECT id_pokemon FROM pokemon WHERE nombre = 'Demomon')
ORDER BY nivel;


-- =====================================================================
-- BLOQUE 3 · Tres ALTER TABLE distintos (sección 8.1)
-- En PostgreSQL el DDL es transaccional: se aplican, se comprueban y se
-- deshacen con ROLLBACK. Para dejarlos aplicados, cambiar ROLLBACK por COMMIT.
-- =====================================================================
BEGIN;

-- ALTER 1: agregar una columna con valor por defecto
ALTER TABLE pokemon ADD COLUMN color VARCHAR(20) NOT NULL DEFAULT 'Desconocido';

-- ALTER 2: agregar una restricción CHECK
ALTER TABLE ataque ADD CONSTRAINT ck_ataque_nombre_minimo CHECK (char_length(nombre) >= 2);

-- ALTER 3: renombrar una columna
ALTER TABLE habilidad RENAME COLUMN descripcion TO efecto;

-- Comprobación: la nueva columna, la restricción y el nuevo nombre
SELECT nombre, color FROM pokemon WHERE nombre = 'Demomon';
SELECT conname FROM pg_constraint WHERE conname = 'ck_ataque_nombre_minimo';
SELECT column_name FROM information_schema.columns
WHERE table_name = 'habilidad' ORDER BY ordinal_position;

ROLLBACK;

-- Después del ROLLBACK la estructura vuelve a ser la original:
SELECT column_name FROM information_schema.columns
WHERE table_name = 'habilidad' ORDER BY ordinal_position;


-- =====================================================================
-- BLOQUE 4 · COMMIT y ROLLBACK (sección 8.2)
-- =====================================================================

-- 4a. ROLLBACK: el cambio se ve dentro de la transacción y se descarta.
BEGIN;
UPDATE pokemon SET nombre = 'Demomon Modificado' WHERE nombre = 'Demomon';
SELECT nombre FROM pokemon WHERE numero_nacional = 9999;   -- Demomon Modificado
ROLLBACK;
SELECT nombre FROM pokemon WHERE numero_nacional = 9999;   -- Demomon

-- 4b. COMMIT: el cambio queda guardado.
BEGIN;
UPDATE pokemon SET altura_m = 0.7 WHERE nombre = 'Demomon';
COMMIT;
SELECT nombre, altura_m FROM pokemon WHERE nombre = 'Demomon';   -- 0.7

-- 4c. ROLLBACK automático por integridad (ERROR ESPERADO al COMMIT):
-- se crea un Pokémon SIN tipo. El trigger diferido lo detecta al COMMIT
-- y PostgreSQL revierte toda la transacción.
BEGIN;
INSERT INTO pokemon (numero_nacional, nombre, altura_m, peso_kg, id_genero, id_region_origen)
SELECT 9998, 'Sintipomon', 1.0, 1.0, g.id_genero, r.id_region
FROM genero g, region r WHERE g.nombre = 'Ambos' AND r.slug = 'kanto';
COMMIT;
-- (ejecutar aparte) No quedó nada:
SELECT count(*) AS quedo_sintipomon FROM pokemon WHERE numero_nacional = 9998;   -- 0


-- =====================================================================
-- BLOQUE 5 · Borrar una región con dependencias (sección 8.3)
-- =====================================================================

-- 5a. ERROR ESPERADO: Kanto tiene Pokémon asociados (ON DELETE RESTRICT).
DELETE FROM region WHERE slug = 'kanto';

-- 5b. Demostración específica de pokemon_region → region (RESTRICT):
-- se crea una región temporal, se asocia Demomon y se intenta borrarla.
-- ERROR ESPERADO en el DELETE; luego ROLLBACK para limpiar.
BEGIN;
INSERT INTO region (nombre, slug, generacion) VALUES ('Hisui', 'hisui', 10);
INSERT INTO pokemon_region (id_pokemon, id_region)
SELECT p.id_pokemon, r.id_region FROM pokemon p, region r
WHERE p.nombre = 'Demomon' AND r.slug = 'hisui';
DELETE FROM region WHERE slug = 'hisui';
-- ERROR: update or delete on table "region" violates foreign key constraint
--        "fk_pokemon_region_region" on table "pokemon_region"
ROLLBACK;

-- Qué depende de una región (lo mismo que muestra pgAdmin en la pestaña "Dependents"):
SELECT 'pokemon_region' AS tabla, count(*) AS filas
FROM pokemon_region WHERE id_region = (SELECT id_region FROM region WHERE slug = 'kanto')
UNION ALL
SELECT 'pokemon (región de origen)', count(*)
FROM pokemon WHERE id_region_origen = (SELECT id_region FROM region WHERE slug = 'kanto');


-- =====================================================================
-- BLOQUE 6 · DELETE 2 y trigger de auditoría (sección 8.3)
-- Se borra Demomon indicando quién lo hace. En la aplicación esto lo hace
-- el backend (o CALL sp_eliminar_pokemon(id, 'usuario')).
-- =====================================================================
BEGIN;
SELECT set_config('app.usuario', 'Demostración sustentación', true);
DELETE FROM pokemon WHERE nombre = 'Demomon';
COMMIT;

-- Registro que dejó el trigger trg_auditar_borrado_pokemon:
SELECT id_auditoria, nombre, numero_nacional, tipos, regiones, usuario_bd, usuario_app, fecha
FROM auditoria_borrado
ORDER BY fecha DESC
LIMIT 5;

-- El CASCADE borró también sus tipos, regiones y ataques:
SELECT count(*) AS filas_huerfanas
FROM pokemon_ataque pa
WHERE NOT EXISTS (SELECT 1 FROM pokemon p WHERE p.id_pokemon = pa.id_pokemon);   -- 0


-- =====================================================================
-- BLOQUE 7 · Respaldo y advertencia antes de un DROP TABLE (sección 8.3)
-- =====================================================================

-- 7a. RESPALDO COMPLETO antes de cualquier DROP (recomendado).
--   Opción pgAdmin: clic derecho en la base "pokedex" → Backup... →
--     Format: Custom · Filename: pokedex_respaldo.backup → Backup.
--   Opción terminal (carpeta bin de PostgreSQL):
--     pg_dump  -U postgres -d pokedex -F c -f pokedex_respaldo.backup
--   Restaurar:
--     pg_restore -U postgres -d pokedex --clean --if-exists pokedex_respaldo.backup

-- 7b. RESPALDO RÁPIDO de una tabla dentro de la base:
CREATE TABLE respaldo_auditoria_borrado AS TABLE auditoria_borrado;
SELECT count(*) AS filas_respaldadas FROM respaldo_auditoria_borrado;

-- 7c. ADVERTENCIA de PostgreSQL (ERROR ESPERADO): no deja borrar una tabla
-- de la que dependen otras. Con CASCADE borraría también las FK de
-- ataque y pokemon_tipo, por eso NUNCA se usa CASCADE sin respaldo.
DROP TABLE tipo;
-- ERROR: cannot drop table tipo because other objects depend on it

-- 7d. DROP dentro de una transacción: se comprueba y se revierte.
BEGIN;
DROP TABLE respaldo_auditoria_borrado;
SELECT to_regclass('respaldo_auditoria_borrado') AS existe;   -- NULL: ya no existe
ROLLBACK;
SELECT to_regclass('respaldo_auditoria_borrado') AS existe;   -- vuelve a existir

-- 7e. Limpieza: borrar la copia de respaldo de la demostración.
DROP TABLE respaldo_auditoria_borrado;
