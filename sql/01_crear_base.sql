-- =====================================================================
-- PokeDexterity · 01_crear_base.sql
-- Ejecutar conectado como superusuario (postgres) a la base "postgres".
-- CREATE DATABASE debe ejecutarse solo, fuera de cualquier transacción
-- o lote con otras sentencias.
--
-- Después de ejecutarlo: en pgAdmin, abrir una nueva Query Tool
-- conectada a la base "pokedex" y seguir con 02_esquema.sql.
-- =====================================================================

CREATE DATABASE pokedex
    WITH ENCODING 'UTF8'
         TEMPLATE template0;
