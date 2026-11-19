package co.edu.unbosque.pokedexterity.repository;

import co.edu.unbosque.pokedexterity.model.EstadoConexion;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * Consultas técnicas sobre el servidor. Sirve para comprobar la conexión real
 * con PostgreSQL desde la capa de repositorio.
 */
@Repository
public class SistemaRepository {

    private final NamedParameterJdbcTemplate jdbc;

    public SistemaRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public EstadoConexion consultarEstado() {
        String sql = """
                SELECT current_database() AS base,
                       current_user       AS usuario,
                       current_setting('server_version') AS version
                """;
        return jdbc.queryForObject(sql, new MapSqlParameterSource(), (rs, n) ->
                new EstadoConexion(true,
                        rs.getString("base"),
                        rs.getString("usuario"),
                        rs.getString("version"),
                        null));
    }
}
