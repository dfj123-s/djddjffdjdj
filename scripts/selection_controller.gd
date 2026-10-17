extends Node2D
class_name RtsSelection

## Left click selects the unit under the cursor. A left-button drag selects
## every unit inside the rectangle. Right click orders the selection to move.

const DRAG_THRESHOLD := 6.0
const FORMATION_GAP := 12.0

var _pressing := false
var _dragging := false
var _start_screen := Vector2.ZERO
var _current_screen := Vector2.ZERO
var _selected: Array[Unit] = []


func _ready() -> void:
	z_index = 100
	z_as_relative = false
	set_process_unhandled_input(true)


func _process(_delta: float) -> void:
	if _dragging:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_pressing = true
				_dragging = false
				_start_screen = button.position
				_current_screen = button.position
			elif _pressing:
				_current_screen = button.position
				_finish_left_gesture()
				_pressing = false
				_dragging = false
				queue_redraw()
			get_viewport().set_input_as_handled()
		elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
			_pressing = false
			_dragging = false
			queue_redraw()
			command_move(screen_to_world(button.position))
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _pressing:
		_current_screen = event.position
		if not _dragging and _start_screen.distance_to(_current_screen) >= DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			queue_redraw()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if not _dragging:
		return
	var world_rect := _world_drag_rect()
	var origin := to_local(world_rect.position)
	var end := to_local(world_rect.position + world_rect.size)
	var local_rect := Rect2(origin, end - origin).abs()
	draw_rect(local_rect, Color(0.25, 0.95, 0.35, 0.18), true)
	draw_rect(local_rect, Color(0.55, 1.0, 0.6, 0.95), false, 2.0)


func select_units(units: Array[Unit]) -> void:
	for unit in _selected:
		if is_instance_valid(unit):
			unit.set_selected(false)
	_selected.clear()
	for unit in units:
		if unit == null or unit in _selected:
			continue
		unit.set_selected(true)
		_selected.append(unit)


func command_move(world_position: Vector2) -> void:
	var units: Array[Unit] = []
	for unit in _selected:
		if is_instance_valid(unit):
			units.append(unit)
	var count := units.size()
	if count == 0:
		return
	var columns := int(ceil(sqrt(float(count))))
	var spacing := _formation_spacing(units)
	for index in count:
		var column := index % columns
		var row := int(index / float(columns))
		var offset := Vector2(
			(float(column) - float(columns - 1) * 0.5) * spacing,
			float(row) * spacing
		)
		units[index].order_move(_clamp_to_map(world_position + offset))


func units_in_world_rect(world_rect: Rect2) -> Array[Unit]:
	var found: Array[Unit] = []
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if unit != null and world_rect.intersects(unit.get_selection_rect()):
			found.append(unit)
	return found


func world_to_screen(world: Vector2) -> Vector2:
	var camera := get_viewport().get_camera_2d()
	var view := get_viewport().get_visible_rect().size
	if camera == null:
		return world
	var center := camera.get_screen_center_position()
	return (world - center) * camera.zoom + view * 0.5


func screen_to_world(screen: Vector2) -> Vector2:
	var camera := get_viewport().get_camera_2d()
	var view := get_viewport().get_visible_rect().size
	if camera == null:
		return screen
	var center := camera.get_screen_center_position()
	return center + (screen - view * 0.5) / camera.zoom


func _finish_left_gesture() -> void:
	if _dragging:
		select_units(units_in_world_rect(_world_drag_rect()))
		return
	var unit := _unit_at(screen_to_world(_current_screen))
	if unit != null:
		select_units([unit])
	else:
		select_units([])


func _world_drag_rect() -> Rect2:
	var start := screen_to_world(_start_screen)
	var current := screen_to_world(_current_screen)
	return Rect2(start, current - start).abs()


func _unit_at(world_position: Vector2) -> Unit:
	var best: Unit = null
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if unit == null or not unit.contains_point(world_position):
			continue
		if best == null or unit.global_position.y > best.global_position.y:
			best = unit
	return best


func _formation_spacing(units: Array[Unit]) -> float:
	var spacing := 48.0
	for unit in units:
		spacing = maxf(spacing, unit.get_visual_size().x + FORMATION_GAP)
	return spacing


func _clamp_to_map(world_position: Vector2) -> Vector2:
	var ground := get_tree().get_first_node_in_group("ground")
	if ground == null:
		return world_position
	var size: Vector2 = ground.world_size
	return Vector2(
		clampf(world_position.x, 24.0, size.x - 24.0),
		clampf(world_position.y, 24.0, size.y - 24.0)
	)
