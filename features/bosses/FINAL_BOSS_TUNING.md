# Final Boss Tuning

Este jefe se ajusta desde los exports de `features/bosses/final_boss.gd`.

## Dialogo inicial

- `intro_dialog_enabled`: activa o desactiva la frase antes del combate.
- `intro_dialog_lines`: texto que dice el jefe. Por defecto empieza con `INTRUSO DETECTADO.`
- `intro_dialog_duration_per_line`: duracion de cada linea.
- `lock_player_during_intro`: deja quieto al jugador mientras habla el jefe.

## Arena y caida

- `use_manual_arena_limits`: usa limites globales exactos para que el jefe no caiga fuera de la arena.
- `manual_arena_left_x` y `manual_arena_right_x`: rango horizontal donde puede caer.
- `max_target_distance_from_home`: ancho alternativo si no usas limites manuales.
- `landing_marker_path`: marker que define la Y real del suelo. Es la forma recomendada de corregir que el jefe quede flotando.
- `use_landing_y_override` y `landing_y_override`: alternativa numerica si no quieres usar marker.

## Ataque de salto

- `pre_jump_delay`: tiempo antes de brincar.
- `offscreen_jump_height`: que tan alto sale de pantalla.
- `fall_start_height`: desde que altura reaparece.
- `jump_out_time`: velocidad del salto hacia arriba.
- `fall_time`: velocidad de la caida.
- `hidden_time_phase_1/2/3`: cuanto tarda fuera de pantalla por fase.
- `warning_time`: cuanto dura la senal roja antes de caer.
- `combo_jump_gap`: pausa entre caidas en combos.
- `stun_time_phase_1/2/3`: ventana vulnerable despues del combo.
- `crush_radius_x/y`: area de dano de la caida.
- `contact_damage`: dano al jugador si lo aplasta.

## Debilidad por lado

- `left_side_weak_color`: color requerido si el impacto llega por la izquierda.
- `right_side_weak_color`: color requerido si el impacto llega por la derecha.
- `weak_spot_damage`: dano con color correcto durante stun.
- `wrong_color_damage`: dano con color incorrecto durante stun.

## Feedback

- `landing_sfx` y `destruction_sfx`: sonidos de caida y muerte.
- `shake_duration` y `shake_strength`: temblor de cada caida.
- `defeat_shake_duration` y `defeat_shake_strength`: temblor al morir.
- `thanks_message`: mensaje final.
- `warning_marker_offset/radius_x/radius_y`: posicion y tamano de la senal de caida.

## Hurtbox

Si, el jefe debe tener hurtbox. Las balas CSS detectan enemigos por la capa 16; por eso `final_boss.tscn` incluye `Hurtbox`, un `Area2D` en capa 16. El cuerpo fisico puede seguir en otra capa, y la hurtbox se apaga cuando el jefe esta fuera de pantalla.
