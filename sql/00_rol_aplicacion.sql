-- =====================================================================
-- PokeDexterity · 00_rol_aplicacion.sql
-- Ejecutar conectado como superusuario (postgres) a la base "postgres".
-- Crea la cuenta que usa la aplicación Spring Boot para conectarse.
-- La aplicación NO usa el superusuario: solo recibe los permisos que
-- necesita (se otorgan al final de 02_esquema.sql, en la Fase 1).
--
-- IMPORTANTE: cambiar la clave aquí y usar la misma en el archivo .env
-- local. Este script con la clave real NO se sube al repositorio;
-- en el repositorio queda con la clave de ejemplo.
-- =====================================================================

CREATE ROLE pokedex_app
    LOGIN
    PASSWORD 'cambiar_esta_clave'
    NOSUPERUSER NOCREATEDB NOCREATEROLE;
