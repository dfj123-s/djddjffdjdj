extends Node2D
class_name Unit

## Shared RTS unit behaviour: selection ring, point test, and right-click movement.
## Concrete units (the farmer, later soldiers, and so on) inherit this and only
## replace the visuals.

const SELECTION_TEXTURE := preload("res://assets/selectsomeunit.png")
const ARRIVE_DISTANCE := 3.0

@export var move_speed := 200.0

var selected := false

var _destination := Vector2.ZERO
var _has_destination := false
var _selection: Sprite2D
var _local_rect := Rect2(Vector2(-32, -64), Vector2(64, 64))


func _ready() -> void:
	add_to_group("units")
	_build_selection()


func _process(delta: float) -> void:
	if not _has_destination:
		_on_idle()
		return
	var offset := _destination - global_position
	var distance := offset.length()
	if distance <= ARRIVE_DISTANCE:
		global_position = _destination
		_has_destination = false
		_on_idle()
		return
	var direction := offset / distance
	var step := move_speed * delta
	if step >= distance:
		global_position = _destination
		_has_destination = false
		_on_idle()
		return
	global_position += direction * step
	_on_move(direction)


func order_move(world_position: Vector2) -> void:
	_destination = world_position
	_has_destination = true


func cancel_move() -> void:
	_has_destination = false
	_on_idle()


func is_moving() -> bool:
	return _has_destination


func get_destination() -> Vector2:
	return _destination


func set_selected(value: bool) -> void:
	selected = value
	if _selection != null:
		_selection.visible = value


func get_visual_size() -> Vector2:
	return _local_rect.size


func get_selection_rect() -> Rect2:
	return Rect2(global_position + _local_rect.position, _local_rect.size)


func contains_point(world_position: Vector2) -> bool:
	return get_selection_rect().grow(6.0).has_point(world_position)


func _on_move(_direction: Vector2) -> void:
	pass


func _on_idle() -> void:
	pass


func _build_selection() -> void:
	_selection = Sprite2D.new()
	_selection.name = "Selection"
	_selection.texture = SELECTION_TEXTURE
	_selection.centered = true
	_selection.visible = false
	# Keep this at the unit's own Z. A negative Z falls behind the opaque ground
	# tile, which would hide the ring completely.
	_selection.z_index = 0
	_selection.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var visual := _local_rect.size
	if visual.x < 1.0 or visual.y < 1.0:
		visual = Vector2(64, 64)
	var tex_size := SELECTION_TEXTURE.get_size()
	# The ring artwork fills its texture, so this lands just outside the body.
	var diameter := maxf(visual.x, visual.y) * 1.35
	var uniform := diameter / maxf(tex_size.x, tex_size.y)
	_selection.scale = Vector2(uniform, uniform)
	_selection.position = _local_rect.get_center()
	add_child(_selection)
	# Draw the ring before the body sprites so it sits around the unit, not on top.
	move_child(_selection, 0)
