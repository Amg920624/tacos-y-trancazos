# Tacos & Trancazos

> 🇺🇸 **English:** a Mexico City street-taco arcade game. **[Download the Windows game from the Releases page](../../releases/latest)**, unzip if needed, and run `TacosYTrancazos.exe`. Click **English** in the top-right corner of the main menu to switch languages. See [Playing in English](#playing-in-english) below.

**De la banqueta a la gloria.** Un arcade chilango de taquerías callejeras: cocina, vende, defiende tu puesto y vuélvete leyenda en tres turnos (viernes, sábado y domingo).

Hecho en Godot 4.7 (GDScript). Todo el arte y el audio se generan por código: no hay imágenes ni sonidos externos.

## Requisitos

- **Para jugar:** Windows 10/11 de 64 bits. Ejecuta `builds/windows/TacosYTrancazos.exe` (no requiere instalación).
- **Para abrir el código:** [Godot 4.7.x](https://godotengine.org/) (estándar, no .NET). El proyecto usa el renderer *Compatibility* (OpenGL 3.3), así que corre en gráficas integradas.

## Cómo abrir el juego

1. **Build:** doble clic en `builds/windows/TacosYTrancazos.exe`.
2. **Código fuente:** abre Godot → *Import* → elige `project.godot` → *Run* (F5).
   - Desde la terminal: `godot --path .`

## Controles

| Tecla | Acción |
|---|---|
| WASD / flechas | Moverse (o pedalear) |
| E | Usar estación · vender · servir · confirmar |
| Q | Cambiar de corte o de taco |
| ESPACIO | Esquivar / ¡pedalazo! |
| J / clic izquierdo | Trapazo · cerrar el turno en la base (canasta) |
| K / clic derecho | Limonazo · piñazo · timbre de la bici |
| ESC | Pausa (continuar, sonido, reiniciar turno, menú) |
| M | Silenciar |

Atajos de demostración (para presentar, durante el turno): **F2** lanza el evento estrella del modo (Inspector / Domingo de Carnitas / El Gorrón), **F3** manda al crítico gastronómico y **F4** salta a los últimos 3 segundos del turno.

## Modos

| Modo | Mecánica central |
|---|---|
| **Tacos de Canasta** (Portales y Narvarte, de día) | Pedaleas por un mapa de la colonia. Tocas el timbre para atraer clientes en el Metro, las oficinas y el parque, y vendes papa, frijol o chicharrón prensado. Los tacos se enfrían y tienes que recargar en la vecindad. Hay que esquivar coches, y en el Metro, si vendes sin permiso, llega un inspector (ficticio y en son de broma). |
| **Carnitas** (Iztapalapa, de día) | Cocinas tandas en el cazo de cobre sin que se queme el fuego. Picas maciza, surtida o cuerito, pones verdura y salsa según la comanda, y entregas. El inventario se acaba. El domingo llega el **Domingo de Carnitas**. |
| **Tacos al Pastor** (Doctores, de noche) | Mini-juego de corte en el trompo (perfecto, bien o fallo), piñazo con *timing*, combos de pedidos perfectos y **El Gorrón**: lo corres a limonazos sin que deje de llegar la clientela. |

**Próximamente** (ya definidos como datos en `data/recipes.json`, bloqueados en el menú): Barbacoa, Suadero y Tripa, Birria, Tacos de Guisado, y Cabeza y Lengua.

## Objetivo

- Cada día hay una **meta de ventas**. Si no llegas, pierdes la partida.
- Al cierre del día se cobran ingredientes y gastos fijos. Si la caja queda en negativo, quiebras.
- En pastor, si **El Gorrón** te deja el puesto sin aguante, pierdes el turno.
- **Ganas** si completas viernes, sábado y domingo cumpliendo las metas.
- **AURA** es tu prestigio: la ganas con pedidos perfectos, rapidez, combos, eventos superados y buenas reseñas del crítico. La pierdes con errores, clientes enojados y eventos fallidos. Los niveles de AURA aumentan la clientela y las propinas, y desbloquean mejoras.
- Entre turnos compras **mejoras** en la tiendita. Todas tienen efecto real en el juego.

## Reiniciar

- Durante el turno: **ESC → Reiniciar turno** (regresa caja y AURA al inicio del turno).
- Al final: **Jugar otra vez** o **Elegir otra taquería**.
- **Nuevo juego** en el menú principal empieza una partida limpia. **Continuar partida** retoma desde la tiendita.
- El guardado vive en `user://tacos_y_trancazos_save.json` (en Windows: `%APPDATA%\Godot\app_userdata\Tacos & Trancazos\`). Si el archivo está dañado o es de otra versión, se ignora sin romper el juego.

## Compilar el build de Windows

Necesitas las plantillas de exportación de Godot 4.7.2 instaladas (Editor → *Manage Export Templates*).

```bash
godot --headless --path . --export-release "Windows Desktop" builds/windows/TacosYTrancazos.exe
```

El preset **Windows Desktop** (`export_presets.cfg`) incluye `data/*.json`, deja fuera `tests/`, `docs/` y `scripts/dev/`, y mete el paquete dentro del `.exe`.

## Pruebas

```bash
godot --headless --path . res://tests/compile_check.tscn
godot --headless --path . res://tests/test_runner.tscn
godot --headless --path . res://tests/sim_runner.tscn
```

1. `compile_check` carga todos los scripts y escenas.
2. `test_runner` corre 192 verificaciones de juego real:
   - Ventas, inventario y pedidos equivocados.
   - Mejoras y AURA.
   - Guardado y carga, incluyendo archivos dañados.
   - Eventos, crítico, Gorrón e inspector.
   - Fin de turno, victoria, derrota y quiebra.
3. `sim_runner` pone a un bot a jugar turnos completos de cada modo, con movimiento y tiempos reales, para balancear las metas.

Herramienta de QA visual (ventana real, guarda capturas):

```bash
godot --path . -- --tour=C:/ruta/de/salida
```

## Estructura

```
scenes/            Escenas de cada pantalla y modo (raíz + script)
scripts/core/      Autoloads: GameManager, Economy, Aura, EventManager, SaveManager, AudioManager
scripts/gameplay/  DB (recipe_database), Upgrades, modos, OrderManager, bici, inspector, combate
scripts/entities/  Cliente (FSM), taquero, El Gorrón, coches
scripts/ui/        Menús, HUD, pausa, instrucciones, tiendita, resultados, final
scripts/art/       Arte procedural: pix.gd, fachadas CDMX, mapa de la colonia
data/              recipes, customers, upgrades, events, dialogue (JSON)
tests/             compile_check, test_runner, sim_runner
docs/              Notas de arquitectura
```

## Playing in English

**Tacos & Trancazos** — *From the sidewalk to glory.* Run a Mexico City taco business through three shifts (Friday, Saturday, Sunday). Hit each day's sales goal to win.

- **Download:** grab `TacosYTrancazos.exe` from the latest Release (Windows 10/11, 64-bit, no install). If Windows SmartScreen warns you, click *More info → Run anyway* (the exe is not code-signed).
- **Language:** click **English** in the top-right corner of the main menu. The choice is remembered. Street signs and taco names stay in Spanish on purpose: they are part of the setting.

| Key | Action |
|---|---|
| WASD / arrows | Move / ride |
| E | Use station · sell · serve · confirm |
| Q | Switch meat cut or taco type |
| SPACE | Dodge / pedal boost |
| J / left click | Towel smack · close the shift at your base (basket mode) |
| K / right click | Throw lime · pineapple flip · bike bell |
| ESC | Pause (resume, sound, restart shift, menu) |
| M | Mute |

**Modes**

- **Tacos de Canasta:** ride a bike around a fictional CDMX neighborhood. Ring your bell, sell potato, bean or chicharrón tacos, keep the basket warm, refill at home, dodge traffic, and avoid the comedic inspector at the Metro.
- **Carnitas:** cook batches in a copper cazo without burning them, chop the right cut, add onion-cilantro and salsa as the ticket says, and survive *Carnitas Sunday*.
- **Tacos al Pastor:** slice the vertical trompo at the perfect moment, do the pineapple flip, chain combos, and chase off *El Gorrón* (the freeloader) with limes.

**Presenter shortcuts (during a shift):** F2 triggers the mode's signature event, F3 sends the food critic, F4 jumps to the end of the shift.

## Limitaciones conocidas

- La música y los efectos son sintetizados (cumbia chiptune), no grabados.
- El mapa de canasta es compacto (3×3 cuadras) y el tráfico solo circula por las avenidas horizontales.
- El balance se ajustó con un bot. A jugadores primerizos el domingo de carnitas les puede costar trabajo.
- No hay soporte para control (gamepad), solo teclado y mouse.
- Las cinco taquerías "próximamente" existen como datos, pero todavía no tienen jugabilidad.
- Las colonias, el Metro, el inspector, la Guía Comal de Oro y El Gorrón son ficticios o están solo inspirados en la CDMX real.
