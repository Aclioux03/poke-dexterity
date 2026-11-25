# Guía de la base de datos para backend y front

Qué ofrece la base y qué SQL usar en cada pantalla. Todo está probado contra la base cargada con los scripts `00` a `05`.
Reglas del .txt que aplican aquí: SQL explícito con `NamedParameterJdbcTemplate`, parámetros con nombre (nunca concatenar valores del usuario) y `@Transactional` en el servicio al crear, editar o borrar.

## 1. Qué hay en la base

| Objeto | Para qué sirve en la app |
|---|---|
| `v_pokemon_resumen` (vista) | Tarjetas del listado: `id_pokemon`, `numero_nacional`, `nombre`, `url_imagen`, `genero`, `tipos` ("Planta / Veneno"), `tipos_slug` ("grass poison"), `tipo_principal_slug`, `regiones` ("Kanto, Johto"), `regiones_slug` ("kanto johto"), `es_legendario`, `es_mitico` |
| `v_pokemon_ataques` (vista) | Tabla de ataques del detalle: `nivel`, `nivel_texto` ("Al evolucionar" si es 0), `ataque`, `tipo`, `tipo_slug`, `categoria`, `poder`, `precision` |
| `v_estadisticas_region` (vista) | Conteos por región (opcional, encabezado o panel) |
| `fn_cadena_evolutiva(id)` (función) | Evoluciones del detalle: `etapa`, `id_pokemon`, `nombre`, `id_preevolucion`, `metodo`, `nivel`, `detalle` |
| `sp_registrar_pokemon(...)` (procedimiento) | Alternativa para crear Pokémon con tipos y regiones en una llamada |
| `sp_eliminar_pokemon(id, usuario)` (procedimiento) | Alternativa para borrar dejando el usuario en la auditoría |
| `auditoria_borrado` (tabla) | Historial de borrados (solo lectura para la app) |

Datos cargados: 1.025 Pokémon, 9 regiones, 18 tipos, 4 géneros, 691 ataques, 284 habilidades. En la carga inicial `id_pokemon = numero_nacional`; los Pokémon creados desde la app tendrán id 1026 en adelante.

**Slugs** (identificadores estables en minúsculas, para URL y CSS):
- Regiones: `kanto johto hoenn sinnoh unova kalos alola galar paldea` → `data-region="kanto"`.
- Tipos: `normal fire water grass electric ice fighting poison ground flying psychic bug rock ghost dragon dark steel fairy` → por ejemplo, `class="tipo tipo-fire"`.

**Imagen:** es lo único que viene de fuera. La URL está en `pokemon.url_imagen` (también en `v_pokemon_resumen`). Son los sprites de PokéAPI (96×96 px), que se muestran a **64×64**. Si la URL es NULL o la imagen no carga, se usa una imagen de respaldo propia:
```html
<img th:src="${p.urlImagen != null ? p.urlImagen : '/img/sin-imagen.png'}"
     width="64" height="64" loading="lazy" th:alt="${p.nombre}"
     onerror="this.onerror=null; this.src='/img/sin-imagen.png'">
```
`/img/sin-imagen.png` (64×64) va en `src/main/resources/static/img/`. Sin `image-rendering: pixelated`: reducir de 96 a 64 con ese modo deja bordes irregulares.

**Descripción:** puede ser NULL (Pokémon 899 a 1025, la fuente no la trae en español). Mostrar "Descripción no disponible".

## 2. Catálogos para los filtros y formularios

```sql
SELECT id_region, nombre, slug FROM region ORDER BY generacion;
SELECT id_tipo, nombre, slug   FROM tipo   ORDER BY nombre;
SELECT id_genero, nombre       FROM genero ORDER BY id_genero;
SELECT id_ataque, nombre       FROM ataque ORDER BY nombre;     -- 691: usar <datalist> o select con búsqueda
```

## 3. Listado con búsqueda y filtros (formulario GET)

Parámetros de la URL: `q` (nombre), `region` (puede repetirse), `tipo`, `genero`, `ataque`, `pagina`.
**Cada condición se agrega solo si el filtro viene con valor.** Con una lista vacía, `IN (:regiones)` genera SQL inválido, así que esa condición se omite.

```sql
SELECT v.*
FROM v_pokemon_resumen v
JOIN pokemon p ON p.id_pokemon = v.id_pokemon
WHERE 1 = 1
  -- si q:        AND lower(p.nombre) LIKE lower(:q) || '%'
  -- si regiones: AND EXISTS (SELECT 1 FROM pokemon_region pr JOIN region r ON r.id_region = pr.id_region
  --                          WHERE pr.id_pokemon = p.id_pokemon AND r.slug IN (:regiones))
  -- si tipo:     AND EXISTS (SELECT 1 FROM pokemon_tipo pt WHERE pt.id_pokemon = p.id_pokemon AND pt.id_tipo = :tipo)
  -- si genero:   AND p.id_genero = :genero
  -- si ataque:   AND EXISTS (SELECT 1 FROM pokemon_ataque pa WHERE pa.id_pokemon = p.id_pokemon AND pa.id_ataque = :ataque)
ORDER BY v.numero_nacional
LIMIT :tamano OFFSET :desde
```

```java
public List<PokemonResumen> buscar(FiltroPokemon f, int pagina, int tamano) {
    StringBuilder sql = new StringBuilder("""
        SELECT v.* FROM v_pokemon_resumen v
        JOIN pokemon p ON p.id_pokemon = v.id_pokemon
        WHERE 1 = 1
        """);
    MapSqlParameterSource params = new MapSqlParameterSource();
    if (f.q() != null && !f.q().isBlank()) {
        sql.append(" AND lower(p.nombre) LIKE lower(:q) || '%'");
        params.addValue("q", f.q().trim());
    }
    if (f.regiones() != null && !f.regiones().isEmpty()) {          // lista de slugs
        sql.append("""
             AND EXISTS (SELECT 1 FROM pokemon_region pr JOIN region r ON r.id_region = pr.id_region
                         WHERE pr.id_pokemon = p.id_pokemon AND r.slug IN (:regiones))""");
        params.addValue("regiones", f.regiones());                   // Spring expande la lista
    }
    if (f.tipo() != null) {
        sql.append(" AND EXISTS (SELECT 1 FROM pokemon_tipo pt WHERE pt.id_pokemon = p.id_pokemon AND pt.id_tipo = :tipo)");
        params.addValue("tipo", f.tipo());
    }
    if (f.genero() != null) {
        sql.append(" AND p.id_genero = :genero");
        params.addValue("genero", f.genero());
    }
    if (f.ataque() != null) {
        sql.append(" AND EXISTS (SELECT 1 FROM pokemon_ataque pa WHERE pa.id_pokemon = p.id_pokemon AND pa.id_ataque = :ataque)");
        params.addValue("ataque", f.ataque());
    }
    sql.append(" ORDER BY v.numero_nacional LIMIT :tamano OFFSET :desde");
    params.addValue("tamano", tamano).addValue("desde", (pagina - 1) * tamano);
    return jdbc.query(sql.toString(), params, (rs, n) -> new PokemonResumen(
            rs.getInt("id_pokemon"), rs.getInt("numero_nacional"), rs.getString("nombre"),
            rs.getString("tipos"), rs.getString("tipos_slug"), rs.getString("regiones"),
            rs.getString("regiones_slug"), rs.getString("genero")));
}
```
Para el total de resultados (paginación): las mismas condiciones con `SELECT count(*)` en lugar de `SELECT v.*`, sin `ORDER BY` ni `LIMIT`.

**Por qué `EXISTS` y no `JOIN`:** con varias regiones marcadas, un JOIN repetiría la tarjeta de un Pokémon presente en las dos; `EXISTS` devuelve una sola fila por Pokémon, que es lo que pide el enunciado.

**Tema visual:**
- Una sola región marcada → `data-region="<slug>"`.
- Ninguna o varias → `data-region="general"`, y se muestran los nombres de las regiones en las tarjetas (`regiones`).

## 4. Coincidencias entre dos regiones (operación distinta)

```sql
SELECT p.id_pokemon, p.numero_nacional, p.nombre
FROM pokemon p JOIN pokemon_region pr ON pr.id_pokemon = p.id_pokemon JOIN region r ON r.id_region = pr.id_region
WHERE r.slug = :region1
INTERSECT
SELECT p.id_pokemon, p.numero_nacional, p.nombre
FROM pokemon p JOIN pokemon_region pr ON pr.id_pokemon = p.id_pokemon JOIN region r ON r.id_region = pr.id_region
WHERE r.slug = :region2
ORDER BY 2
```

## 5. Detalle (`/pokemon/{id}?region=kanto`)

```sql
-- Datos base
SELECT p.id_pokemon, p.numero_nacional, p.nombre, p.altura_m, p.peso_kg, p.descripcion, p.url_imagen,
       g.nombre AS genero, g.descripcion AS genero_descripcion,
       ro.nombre AS region_origen, p.es_legendario, p.es_mitico
FROM pokemon p
JOIN genero g  ON g.id_genero  = p.id_genero
JOIN region ro ON ro.id_region = p.id_region_origen
WHERE p.id_pokemon = :id;

-- Tipos
SELECT t.nombre, t.slug, pt.slot FROM pokemon_tipo pt JOIN tipo t ON t.id_tipo = pt.id_tipo
WHERE pt.id_pokemon = :id ORDER BY pt.slot;

-- Regiones donde aparece (numero_regional puede ser NULL)
SELECT r.nombre, r.slug, pr.numero_regional FROM pokemon_region pr JOIN region r ON r.id_region = pr.id_region
WHERE pr.id_pokemon = :id ORDER BY r.generacion;

-- Habilidades
SELECT h.nombre, h.descripcion, ph.es_oculta FROM pokemon_habilidad ph JOIN habilidad h ON h.id_habilidad = ph.id_habilidad
WHERE ph.id_pokemon = :id ORDER BY ph.es_oculta, h.nombre;

-- Ataques (todos los que aprende por nivel)
SELECT nivel_texto, ataque, tipo, tipo_slug, categoria, poder, precision
FROM v_pokemon_ataques WHERE id_pokemon = :id ORDER BY nivel, ataque;

-- Evoluciones (cadena completa, con ramificaciones)
SELECT * FROM fn_cadena_evolutiva(:id);

-- ¿Conservar el tema de la región de la que vino? Solo si pertenece a ella
SELECT EXISTS (SELECT 1 FROM pokemon_region pr JOIN region r ON r.id_region = pr.id_region
               WHERE pr.id_pokemon = :id AND r.slug = :region);
```
`poder` y `precision` pueden ser NULL (ataques de estado, de poder variable o que nunca fallan): mostrar "—".

## 6. Crear y editar (`@Transactional` en el servicio)

**Crear:**
```sql
INSERT INTO pokemon (numero_nacional, nombre, altura_m, peso_kg, descripcion, url_imagen, id_genero, id_region_origen)
VALUES (:numero, :nombre, :altura, :peso, :descripcion, :urlImagen, :genero, :regionOrigen)
RETURNING id_pokemon;                                     -- jdbc.queryForObject(..., Integer.class)

INSERT INTO pokemon_tipo (id_pokemon, id_tipo, slot) VALUES (:id, :tipo1, 1);
INSERT INTO pokemon_tipo (id_pokemon, id_tipo, slot) VALUES (:id, :tipo2, 2);   -- solo si hay tipo 2
INSERT INTO pokemon_region (id_pokemon, id_region) VALUES (:id, :region);       -- una por región elegida
```

**Editar:**
```sql
UPDATE pokemon SET nombre = :nombre, numero_nacional = :numero, altura_m = :altura, peso_kg = :peso,
       descripcion = :descripcion, url_imagen = :urlImagen, id_genero = :genero, id_region_origen = :regionOrigen
WHERE id_pokemon = :id;                                   -- fecha_modificacion la pone el trigger

DELETE FROM pokemon_tipo   WHERE id_pokemon = :id;        -- reemplazar asociaciones
INSERT INTO pokemon_tipo ...                              -- (igual que al crear)
DELETE FROM pokemon_region WHERE id_pokemon = :id;
INSERT INTO pokemon_region ...
```
En la edición, `pokemon_region` pierde el `numero_regional`. Si quieren conservarlo, borren solo las regiones que se desmarcaron e inserten solo las nuevas.

**Validar en Java antes de guardar** (mensajes junto a los campos):
- Nombre y número obligatorios.
- Altura y peso mayores que 0.
- Tipo 1 obligatorio, y tipo 2 distinto del 1.
- Al menos una región.

La base vuelve a validar todo; sus errores son la última barrera:

| SQLState | Excepción de Spring | Causa | Mensaje sugerido |
|---|---|---|---|
| 23505 | `DuplicateKeyException` | `uq_pokemon_nombre` / `uq_pokemon_numero_nacional` | "Ya existe un Pokémon con ese nombre / número" |
| 23514 | `DataIntegrityViolationException` | CHECK (altura, peso…) o trigger "sin tipo principal" | "Datos inválidos: …" |
| 23503 | `DataIntegrityViolationException` | FK (tipo o región inexistente) | "Seleccione un valor válido" |

**Prueba de rollback (requisito):** si falla cualquier INSERT de tipos o regiones, `@Transactional` revierte también el INSERT del Pokémon. Para la demostración, enviar un `id_tipo` inexistente o el mismo tipo en los dos slots: el Pokémon no queda creado.

## 7. Borrar (POST, después de confirmar por nombre)

```java
@Transactional
public void eliminar(int id, String usuario) {
    jdbc.queryForObject("SELECT set_config('app.usuario', :usuario, true)",
            new MapSqlParameterSource("usuario", usuario), String.class);
    int filas = jdbc.update("DELETE FROM pokemon WHERE id_pokemon = :id", new MapSqlParameterSource("id", id));
    if (filas == 0) throw new PokemonNoEncontradoException(id);
}
```
- `set_config(..., true)` dura solo esa transacción. Por eso debe ir dentro del mismo método `@Transactional` que el DELETE.
- El trigger `trg_auditar_borrado_pokemon` guarda nombre, número, tipos, regiones, `usuario_bd = pokedex_app` y `usuario_app` = el nombre enviado.
- El CASCADE borra tipos, regiones, ataques, habilidades y evoluciones del Pokémon.
- Alternativa en una línea: `CALL sp_eliminar_pokemon(:id, :usuario)`.

**Qué significa la identidad registrada (para la demo):** la app usa una sola cuenta JDBC (`pokedex_app`), así que `usuario_bd` siempre es esa cuenta. La persona real es `usuario_app`. Como no hay login, puede ser un campo "¿Quién elimina?" en la confirmación, o un valor fijo como "Interfaz web".

```sql
-- Historial de borrados (pantalla opcional)
SELECT fecha, nombre, numero_nacional, tipos, regiones, usuario_app, usuario_bd
FROM auditoria_borrado ORDER BY fecha DESC LIMIT 50;
```

## 8. Lo que la base NO deja hacer a la app (a propósito)

- Modificar o borrar `auditoria_borrado`.
- Crear, alterar o borrar tablas.
- Borrar una región, tipo, ataque, habilidad o género que esté en uso (FK RESTRICT).
