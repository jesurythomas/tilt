## render_context.gd
## PORTS: Spec §5.6 / web/src/tilt-to-live/TiltRenderer.ts:23-44
class_name RenderContext
extends RefCounted
## Packs per-frame render parameters into a typed struct, replacing the 19 positional
## arguments of TypeScript TiltRenderer.render().

var viewport_size: Vector2 = Vector2.ZERO
var scale: float = 1.0
var bounds: Vector2 = Vector2.ZERO
var is_mobile: bool = false
var glow_intensity: float = 1.0
var elapsed: float = 0.0
var game_mode: Types.GameMode = Types.GameMode.CLASSIC
var control_mode: Types.ControlMode = Types.ControlMode.MOUSE
var mouse_pos: Vector2 = Vector2.ZERO
var high_contrast_halo: bool = true
var tether_line: bool = true
var show_gridlines: bool = false
