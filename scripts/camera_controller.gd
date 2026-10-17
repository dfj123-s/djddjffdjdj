extends Camera2D
class_name RtsCamera

## Pans when the cursor touches a screen edge, and keeps the view on the map
## so the tile ground always fills the window.

@export var edge_margin := 20.0
@export var pan_speed := 780.0

var map_size := Vector2(4096, 3072)


func _ready() -> void:
	make_current()
	_apply_limits()
	clamp_to_map(get_viewport_rect().size)


func _process(delta: float) -> void:
	var viewport := get_viewport()
	apply_edge_pan(viewport.get_mouse_position(), viewport.get_visible_rect().size, delta)


func set_map_size(value: Vector2) -> void:
	map_size = value
	_apply_limits()
	if is_inside_tree():
		clamp_to_map(get_viewport_rect().size)


func apply_edge_pan(mouse: Vector2, viewport_size: Vector2, delta: float) -> void:
	var direction := edge_direction(mouse, viewport_size, edge_margin)
	if direction != Vector2.ZERO:
		position += direction * pan_speed * delta
	clamp_to_map(viewport_size)


func clamp_to_map(viewport_size: Vector2) -> void:
	if viewport_size.x < 2.0 or viewport_size.y < 2.0:
		return
	var view := viewport_size / zoom
	var half := view * 0.5
	if map_size.x <= view.x:
		position.x = map_size.x * 0.5
	else:
		position.x = clampf(position.x, half.x, map_size.x - half.x)
	if map_size.y <= view.y:
		position.y = map_size.y * 0.5
	else:
		position.y = clampf(position.y, half.y, map_size.y - half.y)


static func edge_direction(mouse: Vector2, viewport_size: Vector2, margin: float) -> Vector2:
	if mouse.x < 0.0 or mouse.y < 0.0 or mouse.x > viewport_size.x or mouse.y > viewport_size.y:
		return Vector2.ZERO
	var direction := Vector2.ZERO
	if mouse.x <= margin:
		direction.x = -1.0
	elif mouse.x >= viewport_size.x - margin:
		direction.x = 1.0
	if mouse.y <= margin:
		direction.y = -1.0
	elif mouse.y >= viewport_size.y - margin:
		direction.y = 1.0
	if direction == Vector2.ZERO:
		return direction
	return direction.normalized()


func _apply_limits() -> void:
	limit_left = 0
	limit_top = 0
	limit_right = int(map_size.x)
	limit_bottom = int(map_size.y)
