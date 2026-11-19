package co.edu.unbosque.pokedexterity.model;

/**
 * Resultado de la verificación de conexión con PostgreSQL.
 *
 * @param conectado   true si la consulta a la base respondió
 * @param baseDatos   nombre de la base (current_database())
 * @param usuario     cuenta JDBC con la que se conectó (current_user)
 * @param version     versión del servidor PostgreSQL
 * @param error       mensaje de error si no se pudo conectar
 */
public record EstadoConexion(boolean conectado, String baseDatos, String usuario,
                             String version, String error) {

    public static EstadoConexion fallo(String error) {
        return new EstadoConexion(false, null, null, null, error);
    }
}
