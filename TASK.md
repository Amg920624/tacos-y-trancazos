# TASK — Tacos & Trancazos

Estado real del proyecto. Solo se marca DONE lo que está implementado, integrado y probado.

**Leyenda:**

- **auto:** cubierto por `tests/test_runner.gd` (192 verificaciones).
- **sim:** cubierto por `tests/sim_runner.gd` (bot que juega turnos completos).
- **visual:** revisado en las capturas de `--tour`.

## P0 — Debe funcionar

| Tarea | Estado | Verificación |
|---|---|---|
| El juego arranca (código y `.exe`) | DONE | auto, exe headless, visual |
| El jugador se mueve (taquero y bici) | DONE | auto |
| Interacciones (estaciones, venta, servir) | DONE | auto, sim |
| Los clientes compran tacos | DONE | auto, sim |
| Dinero y AURA se actualizan | DONE | auto |
| Ganar y perder (meta, quiebra, puesto destruido) | DONE | auto |
| Partida completa de 3 turnos | DONE | auto (flujo), sim (turnos) |
| El proyecto carga sin errores bloqueantes | DONE | compile_check (46 archivos) |

## P1 — Diferenciación

| Tarea | Estado | Verificación |
|---|---|---|
| Canasta: bici, mapa de 3 zonas, timbre, inventario, calor, recarga, tráfico | DONE | auto, sim, visual |
| Carnitas: cazo con fuego, cortes, charola, carne cruda finita | DONE | auto, sim, visual |
| Pastor: corte en el trompo, piñazo, combos | DONE | auto, sim, visual |
| Identidad visual de la CDMX | DONE | visual |
| Diálogos y eventos con humor | DONE | visual |
| Mejoras entre turnos (18, todas con efecto) | DONE | auto |
| Inspección municipal (avisar, salir, multa o carrera) | DONE | auto, visual |
| Mini-juego de cocina (trompo y cazo) | DONE | auto |
| Combate arcade (El Gorrón, limones, trapazo, esquivar) | DONE | auto, visual |

## P2 — Pulido

| Tarea | Estado | Notas |
|---|---|---|
| Popups de comida, dinero y AURA | DONE | |
| Música y efectos (sintetizados), botón de silencio | DONE | La música se genera en un hilo aparte; en headless se omite |
| Siete arquetipos de cliente con diálogos | DONE | |
| Crítico gastronómico (Guía Comal de Oro, ficticia) | DONE | Turno 2 o F3 |
| Transiciones de pantalla (fundido) | DONE | |
| Logros (8) | DONE | |
| Eventos: Domingo de Carnitas, salida del Metro, concierto, clienta exigente, sin tortillas | DONE | auto (parcial) |

## Entrega

| Tarea | Estado |
|---|---|
| Build de Windows (`builds/windows/TacosYTrancazos.exe`) | DONE, se ejecutó headless sin errores |
| README, PITCH, DEMO_SCRIPT, docs/ARCHITECTURE | DONE |
| Guardado versionado y Continuar partida | DONE (auto) |

## Balance (bot, sin mejoras, ventas por turno de 150 s)

| Modo | Viernes | Sábado | Domingo | Metas |
|---|---|---|---|---|
| Canasta | $774–803 | $912–1036 | $751–1260 | $300 / $400 / $450 |
| Carnitas | $859–897 | $750–946 | $539–720 | $300 / $400 / $450 |
| Pastor | $831–1336 | $598–1027 | $727–887 | $300 / $400 / $450 |

## Bugs y limitaciones conocidas

- La paleta de colores y el pixel art son procedurales; los sprites son sencillos a propósito.
- Las etiquetas de las estaciones quedan tapadas cuando el taquero está justo enfrente (el mensaje de abajo dice qué hay).
- El tráfico solo circula por las avenidas horizontales del mapa de canasta.
- Al salir, Godot reporta "ObjectDB instances leaked" en las pruebas headless: son recursos estáticos (tema y fuente) y no afectan el juego.
- No hay soporte para control (gamepad).

## Siguientes prioridades

1. Prueba con jugadores humanos para afinar el domingo de carnitas.
2. Gamepad.
3. Primera taquería futura jugable (barbacoa) reutilizando `stationary_mode.gd`.
