#!/usr/bin/env python3
"""
PokeDexterity · Generador de sql/04_datos.sql

Genera los INSERT de la Pokédex a partir del dataset CSV oficial de PokéAPI
(repositorio https://github.com/PokeAPI/pokeapi, carpeta data/v2/csv).
Ningún dato se escribe a mano: nombres, tipos, ataques, poder, precisión,
categoría, niveles, habilidades, evoluciones y números regionales salen
del dataset. Solo se traducen al español los nombres de los métodos de
evolución, porque el dataset no los trae en español.

Uso:
    git clone --depth 1 https://github.com/PokeAPI/pokeapi.git
    python tools/generar_datos.py pokeapi/data/v2/csv

Salida:
    sql/04_datos.sql          script de carga (una sola transacción)
    docs/reporte_datos.md     resumen: Pokémon por región, juego de referencia, conteos

Solo usa la biblioteca estándar de Python 3.
"""
import csv
import sys
from collections import Counter, defaultdict
from pathlib import Path

ES, EN = "7", "9"   # local_language_id en PokéAPI

# ----------------------------------------------------------------------
# Criterios acordados (docs/decisiones.md)
# ----------------------------------------------------------------------

REGIONES = [  # (nombre, slug, generación)
    ("Kanto", "kanto", 1), ("Johto", "johto", 2), ("Hoenn", "hoenn", 3),
    ("Sinnoh", "sinnoh", 4), ("Unova", "unova", 5), ("Kalos", "kalos", 6),
    ("Alola", "alola", 7), ("Galar", "galar", 8), ("Paldea", "paldea", 9),
]

# Pokédex más completa de cada región. Si está dividida, se numera de corrido
# en el orden indicado (el número continúa después del máximo de la anterior).
POKEDEX_REGION = {
    "kanto":  ["letsgo-kanto"],
    "johto":  ["updated-johto"],
    "hoenn":  ["updated-hoenn"],
    "sinnoh": ["extended-sinnoh"],
    "unova":  ["updated-unova"],
    "kalos":  ["kalos-central", "kalos-coastal", "kalos-mountain"],
    "alola":  ["updated-alola"],
    "galar":  ["galar", "isle-of-armor", "crown-tundra"],
    "paldea": ["paldea", "kitakami", "blueberry"],
}

# Se incluyen TODAS las especies de la Pokédex Nacional (generaciones 1 a 9),
# por indicación del docente. Las especies de Hisui (generación 8) quedan con
# región de origen Galar, que es la región de esa generación en el proyecto.

# Juego de referencia para los ataques por nivel: Escarlata/Púrpura; si la
# especie no está en ese juego, el juego principal más reciente donde esté.
JUEGOS_REFERENCIA = [
    ("scarlet-violet", "Escarlata/Púrpura"),
    ("brilliant-diamond-shining-pearl", "Diamante Brillante/Perla Reluciente"),
    ("sword-shield", "Espada/Escudo"),
    ("ultra-sun-ultra-moon", "Ultrasol/Ultraluna"),
]
# Para las condiciones de evolución se prefieren los juegos principales; los
# "Legends" (reglas y formas distintas, p. ej. Hisui) solo se usan si la
# evolución no existe en otro juego (Wyrdeer, Kleavor, Ursaluna, ...).
GRUPOS_EXCLUIDOS_EVOLUCION = {"legends-arceus", "legends-za", "mega-dimension", "champions"}

# Imagen: lo único externo. Se guarda la URL; la app la muestra a 64×64 px.
URL_SPRITE = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/{}.png"

GENEROS = [  # (nombre, descripción)
    ("Macho", "Solo puede ser macho"),
    ("Hembra", "Solo puede ser hembra"),
    ("Ambos", "Puede ser macho o hembra"),
    ("Sin género", "No tiene género"),
]
CATEGORIAS = {"1": "Estado", "2": "Físico", "3": "Especial"}  # move_damage_classes

METODOS_ES = {  # evolution_triggers (traducción propia: el dataset no trae español)
    "level-up": "Subir de nivel", "trade": "Intercambio", "use-item": "Usar objeto",
    "shed": "Muda", "spin": "Girar", "tower-of-darkness": "Torre de la Oscuridad",
    "tower-of-waters": "Torre del Agua", "three-critical-hits": "Tres golpes críticos",
    "take-damage": "Recibir daño", "in-battle-level-up": "Subir de nivel en combate",
    "agile-style-move": "Estilo rápido", "strong-style-move": "Estilo fuerte",
    "recoil-damage": "Daño por retroceso", "use-move": "Usar movimiento",
    "three-defeated-bisharp": "Derrotar tres Bisharp", "gimmighoul-coins": "Monedas de Gimmighoul",
    "meltan-candies": "Caramelos de Meltan (Pokémon GO)", "unclassified": "Condición especial",
}


# ----------------------------------------------------------------------
# Utilidades
# ----------------------------------------------------------------------

def leer(carpeta, nombre):
    with open(carpeta / nombre, encoding="utf-8") as f:
        return list(csv.DictReader(f))


def sql_txt(valor):
    if valor is None or valor == "":
        return "NULL"
    return "'" + str(valor).replace("'", "''") + "'"


def sql_num(valor):
    return "NULL" if valor is None or valor == "" else str(valor)


def limpiar_texto(t):
    return " ".join(t.replace("\x0c", " ").replace("\xad", "").replace("­", "").split())


def ultimo_por(filas, clave, orden, idioma=ES, campo="flavor_text"):
    """Para cada clave, el texto en español de la versión más reciente."""
    mejor = {}
    for f in filas:
        if f["language_id"] != idioma:
            continue
        k, o = f[clave], int(f[orden])
        if k not in mejor or o > mejor[k][0]:
            mejor[k] = (o, limpiar_texto(f[campo]))
    return {k: v[1] for k, v in mejor.items()}


def bloque_values(titulo, encabezado, filas, cierre):
    """Arma un INSERT ... SELECT FROM (VALUES ...) legible."""
    lineas = [f"-- {titulo} ({len(filas)} filas)", encabezado]
    lineas.append(",\n".join("    (" + ", ".join(f) + ")" for f in filas))
    lineas.append(cierre)
    return "\n".join(lineas) + "\n"


# ----------------------------------------------------------------------
# Programa principal
# ----------------------------------------------------------------------

def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    csvdir = Path(sys.argv[1])
    raiz = Path(__file__).resolve().parent.parent

    especies = leer(csvdir, "pokemon_species.csv")
    sp_id = {s["id"]: s for s in especies}
    sp_ident = {s["identifier"]: s for s in especies}
    cadenas = defaultdict(list)
    for s in especies:
        cadenas[s["evolution_chain_id"]].append(s)

    region_por_gen = {g: slug for _, slug, g in REGIONES}

    # --- 1. Selección de especies -------------------------------------
    seleccion = {s["id"]: "todas" for s in especies if int(s["generation_id"]) in region_por_gen}
    ids = sorted(seleccion, key=int)

    # --- 2. Datos base -------------------------------------------------
    pokemon_def = {p["species_id"]: p for p in leer(csvdir, "pokemon.csv") if p["is_default"] == "1"}
    nombres_es = {n["pokemon_species_id"]: n["name"] for n in leer(csvdir, "pokemon_species_names.csv")
                  if n["local_language_id"] == ES}
    descripciones = ultimo_por(
        [dict(f, language_id=f["language_id"]) for f in leer(csvdir, "pokemon_species_flavor_text.csv")],
        "species_id", "version_id")

    tipos_csv = [t for t in leer(csvdir, "types.csv") if int(t["id"]) <= 18]
    tipo_slug = {t["id"]: t["identifier"] for t in tipos_csv}
    tipo_es = {n["type_id"]: n["name"] for n in leer(csvdir, "type_names.csv") if n["local_language_id"] == ES}

    def genero_de(rate):
        rate = int(rate)
        return {-1: "Sin género", 0: "Macho", 8: "Hembra"}.get(rate, "Ambos")

    # --- 3. Pertenencia regional ----------------------------------------
    pokedex_id = {d["identifier"]: d["id"] for d in leer(csvdir, "pokedexes.csv")}
    numeros = defaultdict(lambda: defaultdict(list))  # pokedex_id -> species -> [n]
    for d in leer(csvdir, "pokemon_dex_numbers.csv"):
        numeros[d["pokedex_id"]][d["species_id"]].append(int(d["pokedex_number"]))

    pertenencia = defaultdict(dict)  # species -> {region_slug: numero}
    for reg, dexes in POKEDEX_REGION.items():
        desplazamiento = 0
        for dex in dexes:
            tabla = numeros[pokedex_id[dex]]
            for sid in ids:
                if sid in tabla and reg not in pertenencia[sid]:
                    pertenencia[sid][reg] = desplazamiento + min(tabla[sid])
            desplazamiento += max(n for lst in tabla.values() for n in lst)
    for sid in ids:  # la región de origen siempre se incluye
        origen = region_por_gen[int(sp_id[sid]["generation_id"])]
        pertenencia[sid].setdefault(origen, None)

    # --- 4. Ataques por nivel ------------------------------------------
    grupos = {g["identifier"]: g["id"] for g in leer(csvdir, "version_groups.csv")}
    grupos_inv = {v: k for k, v in grupos.items()}
    por_pokemon = defaultdict(lambda: defaultdict(list))  # pokemon_id -> vg -> [(move, nivel)]
    for m in leer(csvdir, "pokemon_moves.csv"):
        if m["pokemon_move_method_id"] == "1":
            por_pokemon[m["pokemon_id"]][m["version_group_id"]].append((m["move_id"], int(m["level"])))

    juego_ref, aprende = {}, {}
    for sid in ids:
        pid = pokemon_def[sid]["id"]
        for ident, nombre in JUEGOS_REFERENCIA:
            filas = por_pokemon[pid].get(grupos[ident])
            if filas:
                juego_ref[sid] = nombre
                minimo = {}
                for mv, nv in filas:  # si aparece dos veces, se guarda el nivel menor
                    minimo[mv] = min(nv, minimo.get(mv, 999))
                aprende[sid] = minimo
                break
        else:
            sys.exit(f"Sin ataques por nivel: {sp_id[sid]['identifier']}")

    moves = {m["id"]: m for m in leer(csvdir, "moves.csv")}
    move_es = {n["move_id"]: n["name"] for n in leer(csvdir, "move_names.csv") if n["local_language_id"] == ES}
    usados = sorted({mv for d in aprende.values() for mv in d}, key=int)
    assert len({move_es[m] for m in usados}) == len(usados), "nombres de ataque repetidos"

    def poder(m):
        if m["damage_class_id"] == "1" or m["power"] in ("", "0"):
            return None  # estado o poder variable
        return m["power"]

    def precision(m):
        return None if m["accuracy"] in ("", "0") else m["accuracy"]  # nunca falla / no aplica

    # --- 5. Habilidades -------------------------------------------------
    hab_es = {n["ability_id"]: n["name"] for n in leer(csvdir, "ability_names.csv") if n["local_language_id"] == ES}
    hab_desc = ultimo_por(leer(csvdir, "ability_flavor_text.csv"), "ability_id", "version_group_id")
    hab_pk = defaultdict(list)
    for a in leer(csvdir, "pokemon_abilities.csv"):
        hab_pk[a["pokemon_id"]].append(a)

    # --- 6. Evoluciones -------------------------------------------------
    items_es = {n["item_id"]: n["name"] for n in leer(csvdir, "item_names.csv") if n["local_language_id"] == ES}
    triggers = {t["id"]: t["identifier"] for t in leer(csvdir, "evolution_triggers.csv")}
    evo_filas, evo_legends = defaultdict(list), defaultdict(list)
    for e in leer(csvdir, "pokemon_evolution.csv"):
        if grupos_inv.get(e["version_group_id"]) in GRUPOS_EXCLUIDOS_EVOLUCION:
            evo_legends[e["evolved_species_id"]].append(e)
        else:
            evo_filas[e["evolved_species_id"]].append(e)

    def detalle_de(e):
        partes = []
        if e["trigger_item_id"]:
            partes.append(items_es.get(e["trigger_item_id"], ""))
        if e["held_item_id"]:
            partes.append("Equipado con " + items_es.get(e["held_item_id"], ""))
        if e["minimum_happiness"]:
            partes.append("Amistad alta")
        if e["minimum_affection"]:
            partes.append("Afecto alto")
        if e["time_of_day"] == "day":
            partes.append("De día")
        elif e["time_of_day"] == "night":
            partes.append("De noche")
        if e["known_move_id"]:
            partes.append("Conociendo " + move_es.get(e["known_move_id"], ""))
        if e["known_move_type_id"]:
            partes.append("Conociendo un movimiento tipo " + tipo_es.get(e["known_move_type_id"], ""))
        if e["minimum_beauty"]:
            partes.append("Belleza alta")
        if e["relative_physical_stats"] == "1":
            partes.append("Ataque mayor que Defensa")
        elif e["relative_physical_stats"] == "-1":
            partes.append("Ataque menor que Defensa")
        elif e["relative_physical_stats"] == "0":
            partes.append("Ataque igual a Defensa")
        if e["party_species_id"]:
            partes.append("Con " + nombres_es.get(e["party_species_id"], "") + " en el equipo")
        if e["party_type_id"]:
            partes.append("Con un Pokémon tipo " + tipo_es.get(e["party_type_id"], "") + " en el equipo")
        if e["trade_species_id"]:
            partes.append("A cambio de " + nombres_es.get(e["trade_species_id"], ""))
        if e["needs_overworld_rain"] == "1":
            partes.append("Mientras llueve")
        if e["turn_upside_down"] == "1":
            partes.append("Con la consola boca abajo")
        if e["location_id"]:
            partes.append("En un lugar específico")
        if e["used_move_id"]:
            partes.append("Usando " + move_es.get(e["used_move_id"], ""))
        if e["minimum_steps"]:
            partes.append(f"Tras caminar {e['minimum_steps']} pasos")
        if e["gender_id"] == "1":
            partes.append("Solo hembra")
        elif e["gender_id"] == "2":
            partes.append("Solo macho")
        return ", ".join(p for p in partes if p) or None

    evoluciones = []  # (origen, destino, metodo, nivel, detalle)
    for sid in ids:
        pre = sp_id[sid]["evolves_from_species_id"]
        if not pre or pre not in seleccion:
            continue
        filas = evo_filas.get(sid) or evo_legends.get(sid)
        if not filas:
            sys.exit(f"Sin datos de evolución: {sp_id[sid]['identifier']}")
        preferidas = [f for f in filas if f["is_default"] == "1"] or filas
        vg_max = max(int(f["version_group_id"]) for f in preferidas)
        elegidas = [f for f in preferidas if int(f["version_group_id"]) == vg_max]
        e = elegidas[0]
        detalles = []
        for f in elegidas:
            d = detalle_de(f)
            if d and d not in detalles:
                detalles.append(d)
        texto = " o ".join(detalles) or None
        if texto and len(texto) > 100:  # p. ej. Alcremie: decenas de combinaciones de confite
            texto = detalles[0] + " (u otras variantes)"
        evoluciones.append((pre, sid, METODOS_ES[triggers[e["evolution_trigger_id"]]],
                            e["minimum_level"] or None, texto))
    metodos_usados = sorted({ev[2] for ev in evoluciones})

    # --- 7. Escritura del SQL -------------------------------------------
    out = []
    out.append("""-- =====================================================================
-- PokeDexterity · 04_datos.sql   (ARCHIVO GENERADO: no editar a mano)
-- Generado con tools/generar_datos.py desde el dataset CSV de PokéAPI.
-- Ejecutar conectado como postgres a la base "pokedex", después de
-- 02_esquema.sql y 03_logica.sql.
-- Orden: catálogos → Pokémon → ataques y habilidades → tablas intermedias.
-- Todo va en una transacción: si algo falla, no queda nada a medias.
-- Las claves foráneas se resuelven por nombre o número nacional con JOIN,
-- así el script no depende de los valores IDENTITY.
-- =====================================================================

BEGIN;
""")
    out.append(bloque_values(
        "Regiones", "INSERT INTO region (nombre, slug, generacion) VALUES",
        [[sql_txt(n), sql_txt(s), str(g)] for n, s, g in REGIONES], ";"))
    out.append(bloque_values(
        "Tipos", "INSERT INTO tipo (nombre, slug) VALUES",
        [[sql_txt(tipo_es[t["id"]]), sql_txt(t["identifier"])] for t in tipos_csv], ";"))
    out.append(bloque_values(
        "Géneros", "INSERT INTO genero (nombre, descripcion) VALUES",
        [[sql_txt(n), sql_txt(d)] for n, d in GENEROS], ";"))
    out.append(bloque_values(
        "Categorías de ataque", "INSERT INTO categoria_ataque (nombre) VALUES",
        [[sql_txt(c)] for c in ("Físico", "Especial", "Estado")], ";"))
    out.append(bloque_values(
        "Métodos de evolución", "INSERT INTO metodo_evolucion (nombre) VALUES",
        [[sql_txt(m)] for m in metodos_usados], ";"))

    habs = sorted({a["ability_id"] for sid in ids for a in hab_pk[pokemon_def[sid]["id"]]}, key=int)
    assert len({hab_es[h] for h in habs}) == len(habs), "nombres de habilidad repetidos"
    out.append(bloque_values(
        "Habilidades", "INSERT INTO habilidad (nombre, descripcion) VALUES",
        [[sql_txt(hab_es[h]), sql_txt(hab_desc.get(h))] for h in habs], ";"))

    out.append(bloque_values(
        "Ataques",
        "INSERT INTO ataque (nombre, id_tipo, id_categoria, poder, precision)\n"
        "SELECT v.nombre, t.id_tipo, c.id_categoria, v.poder, v.precision\nFROM (VALUES",
        [[sql_txt(move_es[m]), sql_txt(tipo_slug[moves[m]["type_id"]]),
          sql_txt(CATEGORIAS[moves[m]["damage_class_id"]]),
          sql_num(poder(moves[m])) + "::smallint", sql_num(precision(moves[m])) + "::smallint"]
         for m in usados],
        ") AS v(nombre, tipo, categoria, poder, precision)\n"
        "JOIN tipo t             ON t.slug   = v.tipo\n"
        "JOIN categoria_ataque c ON c.nombre = v.categoria\n"
        "ORDER BY v.nombre;"))

    filas_pk = []
    for sid in ids:
        s, p = sp_id[sid], pokemon_def[sid]
        filas_pk.append([
            sid, sql_txt(nombres_es[sid]), f"{int(p['height']) / 10:.1f}", f"{int(p['weight']) / 10:.1f}",
            sql_txt(descripciones.get(sid)), sql_txt(URL_SPRITE.format(sid)), sql_txt(genero_de(s["gender_rate"])),
            sql_txt(region_por_gen[int(s["generation_id"])]),
            "TRUE" if s["is_legendary"] == "1" else "FALSE",
            "TRUE" if s["is_mythical"] == "1" else "FALSE"])
    out.append(bloque_values(
        "Pokémon",
        "INSERT INTO pokemon (numero_nacional, nombre, altura_m, peso_kg, descripcion, url_imagen,\n"
        "                     id_genero, id_region_origen, es_legendario, es_mitico)\n"
        "SELECT v.num, v.nombre, v.altura, v.peso, v.descripcion, v.imagen, g.id_genero, r.id_region, v.leg, v.mit\nFROM (VALUES",
        filas_pk,
        ") AS v(num, nombre, altura, peso, descripcion, imagen, genero, region, leg, mit)\n"
        "JOIN genero g ON g.nombre = v.genero\n"
        "JOIN region r ON r.slug   = v.region\n"
        "ORDER BY v.num;  -- así id_pokemon coincide con el número nacional en la carga inicial"))

    tipos_pk = defaultdict(list)
    for t in leer(csvdir, "pokemon_types.csv"):
        tipos_pk[t["pokemon_id"]].append(t)
    out.append(bloque_values(
        "Tipos de cada Pokémon",
        "INSERT INTO pokemon_tipo (id_pokemon, id_tipo, slot)\nSELECT p.id_pokemon, t.id_tipo, v.slot\nFROM (VALUES",
        [[sid, sql_txt(tipo_slug[t["type_id"]]), t["slot"]]
         for sid in ids for t in sorted(tipos_pk[pokemon_def[sid]["id"]], key=lambda x: x["slot"])],
        ") AS v(num, tipo, slot)\n"
        "JOIN pokemon p ON p.numero_nacional = v.num\n"
        "JOIN tipo t    ON t.slug = v.tipo;"))

    orden_reg = {slug: g for _, slug, g in REGIONES}
    out.append(bloque_values(
        "Regiones donde aparece cada Pokémon",
        "INSERT INTO pokemon_region (id_pokemon, id_region, numero_regional)\n"
        "SELECT p.id_pokemon, r.id_region, v.numero\nFROM (VALUES",
        [[sid, sql_txt(reg), sql_num(n) + "::smallint"]
         for sid in ids for reg, n in sorted(pertenencia[sid].items(), key=lambda x: orden_reg[x[0]])],
        ") AS v(num, region, numero)\n"
        "JOIN pokemon p ON p.numero_nacional = v.num\n"
        "JOIN region r  ON r.slug = v.region;"))

    out.append(bloque_values(
        "Habilidades de cada Pokémon",
        "INSERT INTO pokemon_habilidad (id_pokemon, id_habilidad, es_oculta)\n"
        "SELECT p.id_pokemon, h.id_habilidad, v.oculta\nFROM (VALUES",
        [[sid, sql_txt(hab_es[a["ability_id"]]), "TRUE" if a["is_hidden"] == "1" else "FALSE"]
         for sid in ids for a in sorted(hab_pk[pokemon_def[sid]["id"]], key=lambda x: int(x["slot"]))],
        ") AS v(num, habilidad, oculta)\n"
        "JOIN pokemon p   ON p.numero_nacional = v.num\n"
        "JOIN habilidad h ON h.nombre = v.habilidad;"))

    out.append(bloque_values(
        "Ataques que aprende cada Pokémon por nivel (0 = al evolucionar)",
        "INSERT INTO pokemon_ataque (id_pokemon, id_ataque, nivel)\n"
        "SELECT p.id_pokemon, a.id_ataque, v.nivel\nFROM (VALUES",
        [[sid, sql_txt(move_es[m]), str(n)]
         for sid in ids for m, n in sorted(aprende[sid].items(), key=lambda x: (x[1], move_es[x[0]]))],
        ") AS v(num, ataque, nivel)\n"
        "JOIN pokemon p ON p.numero_nacional = v.num\n"
        "JOIN ataque a  ON a.nombre = v.ataque;"))

    out.append(bloque_values(
        "Evoluciones",
        "INSERT INTO evolucion (id_pokemon_origen, id_pokemon_destino, id_metodo, nivel, detalle)\n"
        "SELECT po.id_pokemon, pd.id_pokemon, m.id_metodo, v.nivel, v.detalle\nFROM (VALUES",
        [[o, d, sql_txt(m), sql_num(n) + "::smallint", sql_txt(det) + "::varchar"]
         for o, d, m, n, det in evoluciones],
        ") AS v(origen, destino, metodo, nivel, detalle)\n"
        "JOIN pokemon po          ON po.numero_nacional = v.origen\n"
        "JOIN pokemon pd          ON pd.numero_nacional = v.destino\n"
        "JOIN metodo_evolucion m  ON m.nombre = v.metodo;"))

    out.append("COMMIT;\n")
    (raiz / "sql" / "04_datos.sql").write_text("\n".join(out), encoding="utf-8")

    # --- 8. Reporte -------------------------------------------------------
    rep = ["# Reporte de datos generados", "",
           "Generado por `tools/generar_datos.py` desde el dataset CSV de PokéAPI. No editar a mano.", "",
           "## Conteos", "", "| Tabla | Filas |", "|---|---|"]
    conteos = [
        ("region", len(REGIONES)), ("tipo", len(tipos_csv)), ("genero", len(GENEROS)),
        ("categoria_ataque", 3), ("metodo_evolucion", len(metodos_usados)), ("habilidad", len(habs)),
        ("ataque", len(usados)), ("pokemon", len(ids)),
        ("pokemon_tipo", sum(len(tipos_pk[pokemon_def[s]["id"]]) for s in ids)),
        ("pokemon_region", sum(len(pertenencia[s]) for s in ids)),
        ("pokemon_habilidad", sum(len(hab_pk[pokemon_def[s]["id"]]) for s in ids)),
        ("pokemon_ataque", sum(len(aprende[s]) for s in ids)), ("evolucion", len(evoluciones))]
    rep += [f"| {t} | {n} |" for t, n in conteos]
    rep += ["", "## Pokémon por región (aparecen en su Pokédex)", "", "| Región | Pokémon | Sin número regional |", "|---|---|---|"]
    for nombre, slug, _ in REGIONES:
        miembros = [s for s in ids if slug in pertenencia[s]]
        sin_num = [nombres_es[s] for s in miembros if pertenencia[s][slug] is None]
        rep.append(f"| {nombre} | {len(miembros)} | {', '.join(sin_num) or '—'} |")
    rep += ["", "## Juego de referencia de los ataques", ""]
    for juego, n in Counter(juego_ref.values()).most_common():
        lista = ", ".join(nombres_es[s] for s in ids if juego_ref[s] == juego) if juego != JUEGOS_REFERENCIA[0][1] else "resto"
        rep.append(f"- **{juego}** ({n}): {lista}")
    rep += ["", "## Pokémon por región de origen (generación)", "", "| Región | Especies |", "|---|---|"]
    for nombre, slug, g in REGIONES:
        rep.append(f"| {nombre} | {sum(1 for s in ids if int(sp_id[s]['generation_id']) == g)} |")
    (raiz / "docs" / "reporte_datos.md").write_text("\n".join(rep) + "\n", encoding="utf-8")

    print("Listo:", ", ".join(f"{t}={n}" for t, n in conteos))


if __name__ == "__main__":
    main()
