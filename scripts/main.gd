extends Node2D

## Throne of Horror RTS prototype.
## Left click selects a unit. Drag selects every unit in the rectangle.
## Right click moves the selection. The cursor at a screen edge pans the camera.


func _ready() -> void:
	var ground := $Ground
	var camera := $Camera2D as RtsCamera
	camera.set_map_size(ground.world_size)
	camera.position = ground.world_size * 0.5
	camera.clamp_to_map(get_viewport_rect().size)
	if "--smoke" in OS.get_cmdline_user_args():
		var smoke := preload("res://scripts/rts_smoke.gd").new()
		smoke.name = "Smoke"
		add_child(smoke)
