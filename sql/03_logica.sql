-- =====================================================================
-- PokeDexterity · 03_logica.sql
-- Ejecutar conectado como postgres a la base "pokedex", después de
-- 02_esquema.sql. Contiene las funciones y triggers del modelo.
-- (Las vistas y el procedimiento de la Fase 4 se agregan a este archivo
--  o a uno nuevo con numeración posterior.)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Trigger 1 · Auditoría de borrado de Pokémon
-- BEFORE DELETE: se ejecuta antes de que el CASCADE borre las tablas
-- puente, así todavía se pueden leer sus tipos y regiones.
--
-- Actor registrado:
--   usuario_bd  = current_user → la cuenta JDBC (pokedex_app) si el borrado
--                 viene de la aplicación, o postgres si es desde pgAdmin.
--   usuario_app = valor de app.usuario. La aplicación lo fija con
--                 SELECT set_config('app.usuario', 'nombre', true)
--                 dentro de la misma transacción del DELETE. El tercer
--                 parámetro (true) hace que solo dure esa transacción.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_auditar_borrado_pokemon()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO auditoria_borrado
        (tabla_afectada, id_registro, numero_nacional, nombre, tipos, regiones, usuario_app)
    VALUES (
        TG_TABLE_NAME,
        OLD.id_pokemon,
        OLD.numero_nacional,
        OLD.nombre,
        (SELECT string_agg(t.nombre, ' / ' ORDER BY pt.slot)
           FROM pokemon_tipo pt
           JOIN tipo t ON t.id_tipo = pt.id_tipo
          WHERE pt.id_pokemon = OLD.id_pokemon),
        (SELECT string_agg(r.nombre, ', ' ORDER BY r.generacion)
           FROM pokemon_region pr
           JOIN region r ON r.id_region = pr.id_region
          WHERE pr.id_pokemon = OLD.id_pokemon),
        NULLIF(current_setting('app.usuario', true), '')
    );
    RETURN OLD;
END;
$$;

CREATE TRIGGER trg_auditar_borrado_pokemon
    BEFORE DELETE ON pokemon
    FOR EACH ROW
    EXECUTE FUNCTION fn_auditar_borrado_pokemon();

-- ---------------------------------------------------------------------
-- Trigger 2 · Marca de modificación
-- Cada UPDATE sobre pokemon actualiza fecha_modificacion y protege
-- fecha_creacion de cambios accidentales.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_actualizar_fecha_modificacion()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.fecha_modificacion := now();
    NEW.fecha_creacion     := OLD.fecha_creacion;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_pokemon_fecha_modificacion
    BEFORE UPDATE ON pokemon
    FOR EACH ROW
    EXECUTE FUNCTION fn_actualizar_fecha_modificacion();

-- ---------------------------------------------------------------------
-- Trigger 3 · Todo Pokémon debe tener tipo principal (slot 1)
-- Una FK no puede exigir que exista al menos una fila hija. Por eso se usa
-- un CONSTRAINT TRIGGER diferido: se revisa al hacer COMMIT, cuando ya se
-- insertaron el Pokémon y sus tipos. Si falta el slot 1, la transacción
-- completa se revierte (ROLLBACK).
-- Se dispara al crear un Pokémon y al quitar o cambiar tipos.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_tipo_principal()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_id INTEGER;
BEGIN
    IF TG_TABLE_NAME = 'pokemon' THEN
        v_id := NEW.id_pokemon;
    ELSE
        v_id := OLD.id_pokemon;
    END IF;

    -- Si el Pokémon ya no existe (se borró con CASCADE), no hay nada que validar
    IF EXISTS (SELECT 1 FROM pokemon WHERE id_pokemon = v_id)
       AND NOT EXISTS (SELECT 1 FROM pokemon_tipo
                        WHERE id_pokemon = v_id AND slot = 1) THEN
        RAISE EXCEPTION 'El Pokémon con id % no tiene tipo principal (slot 1).', v_id
            USING ERRCODE = 'check_violation',
                  HINT = 'Todo Pokémon debe tener uno o dos tipos; el primero va en el slot 1.';
    END IF;
    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER trg_pokemon_requiere_tipo
    AFTER INSERT ON pokemon
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_tipo_principal();

CREATE CONSTRAINT TRIGGER trg_pokemon_tipo_requiere_principal
    AFTER UPDATE OR DELETE ON pokemon_tipo
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_tipo_principal();
