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

## Fases

| Fase | Contenido | Estado |
|---|---|---|
| 0 | Esqueleto, conexión a PostgreSQL, README | Hecho |
| 1 | Modelo de datos y esquema SQL | Por hacer |
| 2 | Kanto y Johto · listado, búsqueda, filtros, detalle, 2 temas | Por hacer |
| 3 | Crear, editar, borrar · triggers · transacciones | Por hacer |
| 4 | 9 regiones · vistas, función, 12 consultas, UPDATE/DELETE/ALTER | Por hacer |
| 5 | Estilo final, temas regionales, móvil y accesibilidad | Por hacer |
| 6 | Prueba desde cero, capturas y documento final | Por hacer |
