# Arquitectura

## Flujo

```
main_menu → mode_selection → [modo: turno 1] → results_screen → upgrade_menu → [turno 2] → … → end_screen
```

`GameManager` es dueño del flujo:

- `start_new_run(modo)` inicia una partida.
- `finish_shift(stats)` cobra los gastos fijos, decide si cumpliste la meta, si quebraste o si ganaste, y guarda.
- `after_results()` y `start_next_shift()` avanzan a la siguiente pantalla.

Cada turno guarda una foto de caja y AURA para que **ESC → Reiniciar turno** regrese limpio.

## Autoloads

| Nombre | Archivo | Responsabilidad |
|---|---|---|
| `DB` | `scripts/gameplay/recipe_database.gd` | Carga `data/*.json` |
| `Economy` | `scripts/core/economy_manager.gd` | Caja, ventas validadas (sin negativos, NaN ni infinitos), costos por categoría |
| `Aura` | `scripts/core/aura_manager.gd` | AURA, niveles, reputación y bonos de demanda, propinas y paciencia |
| `Upgrades` | `scripts/gameplay/upgrade_manager.gd` | Mejoras como datos; `stat(nombre, modo)` suma los modificadores |
| `EventManager` | `scripts/core/event_manager.gd` | Eventos como datos (programados, aleatorios o por condición), cooldowns, recompensas y castigos |
| `AudioManager` | `scripts/core/audio_manager.gd` | Efectos sintetizados y música generada en un hilo; acepta reemplazos en `assets/audio/` |
| `SaveManager` | `scripts/core/save_manager.gd` | JSON versionado en `user://`; valida y acota los valores al cargar |
| `GameManager` | `scripts/core/game_manager.gd` | Flujo, mapa de entradas, logros, avisos (toasts) y transiciones |

## Modos

- `stationary_mode.gd` es la base compartida de carnitas y pastor:
  - Cocina, estaciones, plato y comandas.
  - Evaluación del pedido: exacto, verdura o salsa equivocada, incompleto o corte equivocado.
  - Combos, crítico, clienta exigente, falta de tortillas, HUD y pausa.
- `carnitas_mode.gd` agrega el cazo (fuego, menear y sacar), la charola por corte, la carne cruda finita y el Domingo de Carnitas.
- `pastor_mode.gd` agrega el trompo (aguja de corte y dorado), el piñazo, El Gorrón (`enemy_controller.gd`), los proyectiles (`combat_manager.gd`) y a Firulais.
- `canasta_mode.gd` agrega:
  - El mapa (`canasta_map.gd`) y la bici (`bicycle_controller.gd`).
  - El tráfico (`car.gd`) y los peatones de cada zona.
  - El timbre, la venta, el calor de la canasta, la recarga en la base y el inspector (`inspection_controller.gd`).

## Clientes

`customer_controller.gd` es una máquina de estados:

```
SPAWNING → (WANDERING) → APPROACHING → ORDERING → WAITING → RECEIVING → LEAVING
                                                     └──────→ ANGRY ─────┘
```

La usan tanto la fila del mostrador (`order_manager.gd`) como los peatones de canasta.

## Arte

- `scripts/art/pix.gd` es la librería de dibujo: tacos, personas, utensilios, vehículos, letreros y globos de diálogo.
- Todos los sprites se dibujan en `_draw()` con rectángulos y polígonos, en coordenadas de una base de 640×360.

## Añadir una taquería futura

1. Cambia la entrada en `data/recipes.json` (`future` → `modes`) con `unlocked: true`, su escena y sus recetas.
2. Crea un script que extienda `stationary_mode.gd` y sobrescriba los hooks `_mode_*` y `generate_order()`.
3. Agrega sus mejoras a `upgrades.json` y sus eventos a `events.json`, con `modes` que incluyan el nuevo id.
