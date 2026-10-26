# Tacos & Trancazos: pitch

**De la banqueta a la gloria.**

## La oportunidad

Los juegos de cocina arcade (estilo *Overcooked*) son populares, pero cuando aparece México suele ser con sombreros, cactus y tacos de tortilla dura. La taquería callejera de la Ciudad de México tiene su propio caos, su humor y su vocabulario, y casi no aparece en los videojuegos.

## El juego

Un arcade para un jugador en el que construyes un negocio de tacos en tres turnos (viernes, sábado y domingo). Eliges entre tres taquerías, y cada una tiene una mecánica distinta sobre la misma economía:

- **Tacos de Canasta:** movilidad. En bici por una colonia ficticia inspirada en Portales y Narvarte, tocas el timbre para atraer clientes, cuidas el calor de la canasta, esquivas taxis y peseros, y lidias con un inspector cómico si vendes sin permiso en el Metro.
- **Carnitas:** cocina y precisión. Controlas el fuego del cazo de cobre y picas maciza, surtida o cuerito con inventario finito. El domingo llega la familia entera: el **Domingo de Carnitas**.
- **Tacos al Pastor:** *timing* y acción. Cortas el trompo en el momento justo, haces el piñazo, encadenas combos y corres a **El Gorrón** a limonazos sin que la clientela deje de llegar.

## Diferenciación cultural

- La dirección de arte retrata la calle real de la CDMX: mostradores de acero inoxidable, cortinas metálicas, letreros pintados a mano, azulejo, bancos de plástico, cables de luz, tinacos, taxis rosas, peseros, el Metro y el parque.
- La comida es auténtica: tortilla de maíz chica y doble, cebolla y cilantro picados, salsa verde en molcajete y salsa roja, piña del trompo y platos de plástico con bolsa.
- Todo el texto está en español mexicano: "¡Jefe! Écheme tres de surtida", "+50 AURA — ¡SE MAMÓ!", "¡TE PASASTE DE LANZA!".
- El humor sale de situaciones absurdas y del cariño por el oficio del taquero, no de estereotipos.

## Jugabilidad central

- **Clientes con máquina de estados**, siete arquetipos con diálogos propios: godín, estudiante, taxista, repartidor, cliente de siempre, señora exigente y un crítico disfrazado.
- **Comandas** con corte, cantidad, verdura, salsa y piña. Cada pedido se evalúa por exactitud, calidad y rapidez.
- **AURA:** prestigio arcade con consecuencias reales. Sube la demanda y las propinas y desbloquea mejoras.
- **Economía:** ventas, ingredientes, gastos fijos, multas y 18 mejoras definidas como datos.
- **Eventos:**
  - Inspección municipal.
  - Salida masiva del Metro.
  - Domingo de Carnitas.
  - Salida del concierto.
  - El Gorrón.
  - Clienta exigente.
  - Falta de tortillas.
  - Crítico de la *Guía Comal de Oro* (ficticia).
- **8 logros**, entre ellos "El Rey del Trompo", "Canastero Sin Miedo", "Domingo de Gloria" y "Taquero Legendario".

## Arquitectura técnica

- **Motor:** Godot 4.7 con GDScript y el renderer Compatibility. La resolución interna es 640×360, escalada.
- **Autoloads desacoplados por señales:**
  - `GameManager`: flujo, logros y transiciones.
  - `Economy`: dinero validado.
  - `Aura`: prestigio y reputación.
  - `Upgrades`: mejoras como datos.
  - `EventManager`: eventos como datos.
  - `SaveManager`: guardado JSON versionado.
  - `AudioManager`: audio sintetizado.
- **Contenido en datos:** `data/*.json` define modos, recetas, clientes, mejoras, eventos, diálogos y cinco taquerías futuras.
- **Arte 100% procedural** dibujado por código, sin assets externos. El audio también: la música es una cumbia generada en un hilo aparte.
- **Calidad:**
  - 192 pruebas automáticas de juego real.
  - Un bot que juega turnos completos para balancear las metas.
  - Un recorrido de capturas para QA visual.
  - Un build de Windows verificado.

## Implementado en este hackatón

- Las tres taquerías se pueden jugar completas.
- Ciclo de tres días con tiendita, victoria, derrota y quiebra.
- Pausa, reinicio de turno y continuar partida.
- Crítico, combate cómico, inspector, eventos y logros.
- Música y efectos sintetizados.
- Build de Windows exportado.

## Hoja de ruta

1. Jugabilidad para las taquerías ya definidas: barbacoa (consomé y cocción lenta), suadero y tripa (choricera y punto de dorado), birria, guisados (pronóstico de demanda) y cabeza y lengua.
2. Modo historia por colonias, cada una con clientes y reglas propias.
3. Cooperativo local: un taquero corta y otro sirve.
4. Arte de pixel art hecho a mano y música grabada con músicos locales.
5. Soporte de control y versión para Steam Deck.
