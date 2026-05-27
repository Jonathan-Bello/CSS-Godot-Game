extends TileMapLayer
class_name TileFootstepSurface

@export var cave_source_id: int = 0
@export var city_source_id: int = 1
@export var cave_footstep_sfx: AudioStream = preload("res://assets/sfx/leaves01.ogg")
@export var city_footstep_sfx: AudioStream = preload("res://assets/sfx/step_metal.ogg")
@export var default_footstep_sfx: AudioStream = preload("res://assets/sfx/step_metal.ogg")
@export var sample_offsets: PackedVector2Array = PackedVector2Array([
	Vector2.ZERO,
	Vector2(0.0, 20.0),
	Vector2(-28.0, 16.0),
	Vector2(28.0, 16.0),
])

func _ready() -> void:
	add_to_group("footstep_surface")

func get_footstep_sfx_at_global_position(global_foot_position: Vector2) -> AudioStream:
	var local_foot_position := to_local(global_foot_position)
	for offset in sample_offsets:
		var cell := local_to_map(local_foot_position + offset)
		var source_id := get_cell_source_id(cell)
		if source_id == cave_source_id:
			return cave_footstep_sfx
		if source_id == city_source_id:
			return city_footstep_sfx
		if source_id != -1:
			return default_footstep_sfx
	return null
