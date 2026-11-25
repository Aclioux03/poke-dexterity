# PokeDexterity

Pokédex Regional web. Proyecto final de **Bases de Datos I** · Universidad El Bosque.
Reunimos todas las regiones hasta la última generación.

**Equipo:** Jose Alejandro Prieto Colina (BD, back) · Juan Nicolás Moncada Avendaño (BD, front) · Sebastián Camilo Sánchez Rubio (documento, BD).

## Tecnologías

| Capa | Tecnología | Versión |
|---|---|---|
| Base de datos | PostgreSQL + pgAdmin | 18 |
| Backend | Java · Spring Boot (Spring MVC + Spring JDBC) | Java 21 · Spring Boot 4.1.2 |
| Acceso a datos | Driver JDBC de PostgreSQL · `NamedParameterJdbcTemplate` | gestionado por Spring Boot |
| Frontend | Thymeleaf · CSS propio · JavaScript nativo | — |
| Construcción | Maven (Maven Wrapper) | — |

Arquitectura: monolito web por capas.
`Navegador → controller → service → repository (JDBC) → PostgreSQL`, y el controlador devuelve una vista Thymeleaf.

## Estructura

```
src/main/java/co/edu/unbosque/pokedexterity/
  controller/   recibe parámetros y formularios, devuelve vistas
  service/      reglas de negocio y transacciones (@Transactional)
  repository/   SQL explícito y parametrizado, filas → objetos Java
  model/ dto/   datos del dominio y de formularios
src/main/resources/
  templates/    vistas Thymeleaf y fragmentos reutilizables
  static/       CSS, JavaScript e imágenes
sql/            scripts numerados: se ejecutan en orden desde cero
docs/           decisiones de diseño y registro de uso de IA
tools/          scripts auxiliares (generación de datos)
```

## Base de datos

Ejecutar los scripts de `sql/` en orden desde pgAdmin (Query Tool), con el usuario `postgres`:

| Orden | Script | Conectado a | Qué hace |
|---|---|---|---|
| 1 | `00_rol_aplicacion.sql` | `postgres` | Crea la cuenta `pokedex_app` (cambiar la clave localmente) |
| 2 | `01_crear_base.sql` | `postgres` | Crea la base `pokedex` (ejecutarlo solo) |
| 3 | `02_esquema.sql` | `pokedex` | 14 tablas, restricciones, índices y permisos |
| 4 | `03_logica.sql` | `pokedex` | Funciones y triggers |
| 5 | `04_datos.sql` | `pokedex` | **Inserción de todos los datos** (1.025 Pokémon, una transacción) |
| 6 | `05_vistas_funciones.sql` | `pokedex` | 3 vistas, función recursiva y 2 procedimientos |
| — | `06_consultas.sql` | `pokedex` | Las 12 consultas del enunciado (solo lectura) |
| — | `07_demostraciones.sql` | `pokedex` | Demostraciones de la sección 8, bloque por bloque |
| — | `08_verificacion.sql` | `pokedex` | Controles de la carga: todo debe salir OK |

Para empezar de cero: `DROP DATABASE pokedex;` y `DROP ROLE pokedex_app;` (conectado a `postgres`) y repetir.

`04_datos.sql` se genera con `tools/generar_datos.py` desde el dataset oficial de [PokéAPI](https://github.com/PokeAPI/pokeapi) (`data/v2/csv`).

| Documento | Contenido |
|---|---|
| `docs/guia_backend.md` | **Para backend y front:** qué SQL usar en cada pantalla |
| `docs/modelo.md` | Diagrama, relaciones, integridad, índices y normalización |
| `docs/diccionario_datos.md` | Diccionario de datos |
| `docs/decisiones.md` | Decisiones de diseño |
| `docs/reporte_datos.md` | Conteos y juego de referencia de los ataques |

## Fases

| Fase | Contenido | Estado |
|---|---|---|
| 0 | Esqueleto, conexión a PostgreSQL, README | Hecho |
| 1 | Base de datos completa: esquema, triggers, 1.025 Pokémon, vistas, función, procedimientos, 12 consultas y demostraciones | Hecho |
| 2 | Kanto y Johto · listado, búsqueda, filtros, detalle, 2 temas | Por hacer |
| 3 | Crear, editar, borrar · triggers · transacciones | Por hacer |
| 4 | Integrar en la app las consultas y la demo multirregión | Por hacer |
| 5 | Estilo final, temas regionales, móvil y accesibilidad | Por hacer |
| 6 | Prueba desde cero, capturas y documento final | Por hacer |
