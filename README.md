# CSS Godot Game

Repositorio del prototipo en Godot de **Citadel of Solar Souls (CSS)**, videojuego educativo 2D donde las propiedades CSS se convierten en municion, puzzles y decisiones tacticas de combate. El asistente contextual del juego se llama **Hemis**.

## URLs oficiales

- Sitio: https://css.jonathanbello.com/
- GDD: https://css.jonathanbello.com/gdd/
- Demo web: https://css.jonathanbello.com/demo/

## Repositorios relacionados

- Juego Godot: https://github.com/Jonathan-Bello/CSS-Godot-Game
- GDD web: https://github.com/Jonathan-Bello/GDD-CSS
- Backend Hemis: https://github.com/Jonathan-Bello/CSS-Game-Emis

## Estado del demo

Estado documentado: **2026-05-29**.

- `content/levels/tutorial_cave.tscn`: zona tutorial terminada para la vertical slice.
- `content/levels/citadel_main.tscn`: Ciudadela/Citadel en avance visual y jugable parcial.
- `content/levels/final_combat.tscn`: combate con jefe en avance parcial.
- Las capturas de Ciudadela y jefe deben reportarse como avance, no como zonas finalizadas.

## Logros tecnicos principales

- Integracion de arte SVG nativo dentro del pipeline de Godot.
- Parser CSS propio para convertir propiedades de estilo en configuraciones jugables de municion.
- Editor CSS embebido en WebView con preview visual y comunicacion Godot-Web.
- Sistema de Hemis como tutor contextual y evaluador de codigo CSS.
- Export web con `hemis-config.js` y `hemis-bootstrap.js`.
- Rutas y compatibilidad legacy para proyectos anteriores que usaban `Emis`.

## Estructura relevante

```text
core/
  hemis_client.gd
  hemis_game_context.gd
content/
  levels/tutorial_cave.tscn
  levels/citadel_main.tscn
  levels/final_combat.tscn
  lore/tutorial_cave_context.md
features/ui/hud/
  web_overlay_editor.html
  web_overlay_hemis_chat.html
features/world/
  hemis_dialog_trigger.gd
backend/emis-backend/
  backend Express de Hemis
```

## Hemis

El nombre canonico del asistente es **Hemis**. Se mantienen alias legacy donde son utiles para no romper exportaciones o integraciones antiguas:

- Variables web canonicas: `window.HEMIS_BACKEND_URL`, `window.HEMIS_PLAYER_API_KEY`.
- Variables web legacy: `window.EMIS_BACKEND_URL`, `window.EMIS_PLAYER_API_KEY`.
- Funcion canonica: `window.setHemisPlayerApiKey`.
- Funcion legacy: `window.setEmisPlayerApiKey`.
- Contrato canonico: `hemis_chat_v1`.

## Backend

El backend publico se configura en:

```js
window.HEMIS_BACKEND_URL = "https://css-game-emis.onrender.com";
window.EMIS_BACKEND_URL = window.HEMIS_BACKEND_URL;
```

El repositorio del backend conserva el nombre historico `CSS-Game-Emis`, pero la documentacion y producto usan **Hemis**.

## Propiedades CSS del prototipo

Las propiedades oficialmente documentadas para la evaluacion del prototipo son:

- `fill`
- `stroke`
- `opacity`
- `width`
- `height`

## Ejecutar en Godot

Abrir `project.godot` con Godot 4.x. Para validacion headless:

```sh
D:\Godot\godot_console.exe --headless --path . --quit
```

## Export web

El export HTML debe incluir:

```html
<script src="hemis-config.js"></script>
<script src="hemis-bootstrap.js"></script>
```

`export_presets.cfg` ya referencia esos archivos en `html/head_include`.
