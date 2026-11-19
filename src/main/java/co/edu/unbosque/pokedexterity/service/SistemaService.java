package co.edu.unbosque.pokedexterity.service;

import co.edu.unbosque.pokedexterity.model.EstadoConexion;
import co.edu.unbosque.pokedexterity.repository.SistemaRepository;
import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Service;

@Service
public class SistemaService {

    private final SistemaRepository repositorio;

    public SistemaService(SistemaRepository repositorio) {
        this.repositorio = repositorio;
    }

    /** Devuelve el estado de la conexión sin lanzar excepción a la vista. */
    public EstadoConexion verificarConexion() {
        try {
            return repositorio.consultarEstado();
        } catch (DataAccessException e) {
            Throwable causa = e.getMostSpecificCause();
            return EstadoConexion.fallo(causa.getMessage());
        }
    }
}
