package co.edu.unbosque.pokedexterity.controller;

import co.edu.unbosque.pokedexterity.service.SistemaService;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

/**
 * Fase 0: página de inicio que demuestra el flujo completo
 * Navegador → controlador → servicio → repositorio JDBC → PostgreSQL → vista Thymeleaf.
 * En la Fase 2 esta ruta pasará a mostrar el listado de Pokémon.
 */
@Controller
public class InicioController {

    private final SistemaService sistemaService;

    public InicioController(SistemaService sistemaService) {
        this.sistemaService = sistemaService;
    }

    @GetMapping("/")
    public String inicio(Model model) {
        model.addAttribute("estado", sistemaService.verificarConexion());
        return "inicio";
    }
}
