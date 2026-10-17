extends Node

## Headless-friendly checks for selection, movement, facing, the walk sheet,
## edge panning, and ground coverage. Run with:
## godot --path . -- --smoke

var _errors: Array[String] = []
var _shots := 0


func _ready() -> void:
	get_tree().create_timer(25.0).timeout.connect(_on_timeout)
	_run()


func _run() -> void:
	# Headless boots a tiny viewport. Force the real playfield size before checks.
	get_window().size = Vector2i(1280, 720)
	var camera := get_parent().get_node("Camera2D") as RtsCamera
	# Keep the automated run from sliding the view if the pointer sits in a corner.
	camera.set_process(false)
	camera.position = Vector2(2048, 1536)
	await get_tree().process_frame
	camera.clamp_to_map(get_viewport().get_visible_rect().size)
	print("VIEW ", get_viewport().get_visible_rect().size, " CAM ", camera.position)

	var selection := get_parent().get_node("Selection") as RtsSelection
	var ground: Node = get_parent().get_node("Ground")
	var units := _units()
	if units.size() != 6:
		_fail("expected 6 farmers, got %d" % units.size())
		_finish()
		return

	var homes: Dictionary = {}
	for unit in units:
		homes[unit] = unit.global_position

	_test_edges()
	_test_camera_pan(camera)
	_test_ground(ground, camera)
	_test_sheet(units[0])
	_test_body_anchor(units[0])
	_test_screen_roundtrip(selection, units[0])
	_test_box_query(selection, units)
	_test_movement(units[0])
	_test_formation(selection, units)
	_reset(units, homes, selection, camera, ground)

	await _capture("01-idle")
	selection.select_units(units)
	await _capture("02-selected")
	var rally: Vector2 = units[0].global_position + Vector2(-240, 40)
	selection.command_move(rally)
	for _i in 24:
		await get_tree().process_frame
	_expect(units[0].get_node("Walk").flip_h, "screenshot move should face screen-left")
	_expect(units[0].get_node("Walk").visible, "walk sheet should be visible while moving")
	_expect(not units[0].get_node("Idle").visible, "idle portrait hides while moving")
	await _capture("03-move-left")
	selection.command_move(units[0].global_position + Vector2(260, -20))
	for _i in 18:
		await get_tree().process_frame
	_expect(not units[0].get_node("Walk").flip_h, "screenshot move should face screen-right")
	await _capture("04-move-right")

	_reset(units, homes, selection, camera, ground)
	await _test_mouse(selection, units)
	_finish()


func _test_edges() -> void:
	var view := Vector2(1280, 720)
	var margin := 20.0
	_expect_dir(Vector2(0, 360), view, margin, Vector2.LEFT, "left edge")
	_expect_dir(Vector2(19, 400), view, margin, Vector2.LEFT, "inside left margin")
	_expect_dir(Vector2(21, 400), view, margin, Vector2.ZERO, "just off the left margin")
	_expect_dir(Vector2(1279, 360), view, margin, Vector2.RIGHT, "right edge")
	_expect_dir(Vector2(1260, 360), view, margin, Vector2.RIGHT, "inside right margin")
	_expect_dir(Vector2(640, 0), view, margin, Vector2.UP, "top edge")
	_expect_dir(Vector2(640, 719), view, margin, Vector2.DOWN, "bottom edge")
	_expect_dir(Vector2(640, 360), view, margin, Vector2.ZERO, "center")
	_expect_dir(Vector2(-4, 360), view, margin, Vector2.ZERO, "outside window")
	var corner := RtsCamera.edge_direction(Vector2(0, 0), view, margin)
	if absf(corner.length() - 1.0) > 0.001 or corner.x >= 0.0 or corner.y >= 0.0:
		_fail("top-left corner should pan diagonally, got %s" % corner)


func _expect_dir(mouse: Vector2, view: Vector2, margin: float, expected: Vector2, label: String) -> void:
	var direction := RtsCamera.edge_direction(mouse, view, margin)
	if expected == Vector2.ZERO:
		if direction != Vector2.ZERO:
			_fail("%s should not pan, got %s" % [label, direction])
		return
	if direction.dot(expected) < 0.99:
		_fail("%s expected %s, got %s" % [label, expected, direction])


func _test_camera_pan(camera: RtsCamera) -> void:
	var view := Vector2(1280, 720)
	camera.position = Vector2(2048, 1536)
	var start := camera.position
	camera.apply_edge_pan(Vector2(640, 360), view, 0.5)
	if camera.position.distance_to(start) > 0.01:
		_fail("center pointer moved the camera to %s" % camera.position)
	camera.apply_edge_pan(Vector2(0, 360), view, 0.5)
	if camera.position.x > start.x - 300.0:
		_fail("left edge should pan west, position %s" % camera.position)
	if absf(camera.position.y - start.y) > 1.0:
		_fail("pure left edge should not pan vertically")
	camera.position = Vector2(view.x * 0.5, 1536)
	var blocked := camera.position.x
	camera.apply_edge_pan(Vector2(0, 200), view, 1.0)
	if camera.position.x < blocked - 0.1:
		_fail("camera slid past the west map edge to %s" % camera.position.x)
	camera.position = Vector2(2048, 1536)
	camera.clamp_to_map(view)


func _test_ground(ground: Node, camera: RtsCamera) -> void:
	var world_size: Vector2 = ground.world_size
	var texture_size: Vector2 = ground.texture.get_size()
	if texture_size != world_size:
		_fail("tiled ground is %s, map is %s" % [texture_size, world_size])
	var view := get_viewport().get_visible_rect().size
	var center := camera.get_screen_center_position()
	var view_rect := Rect2(center - view * 0.5, view)
	if not Rect2(Vector2.ZERO, world_size).encloses(view_rect):
		_fail("ground does not cover the window %s" % view_rect)
	if camera.position.distance_to(camera.get_screen_center_position()) > 1.0:
		_fail("camera center drifted from its position")


func _test_sheet(farmer: Unit) -> void:
	var walk := farmer.get_node("Walk") as AnimatedSprite2D
	var idle := farmer.get_node("Idle") as Sprite2D
	if not str(idle.texture.resource_path).ends_with("농부.png"):
		_fail("idle sprite is %s" % idle.texture.resource_path)
	var frames := walk.sprite_frames
	if frames == null or frames.get_frame_count("walk") != 5:
		_fail("walk animation should have 5 frames")
		return
	var frame0 := frames.get_frame_texture("walk", 0) as AtlasTexture
	var frame2 := frames.get_frame_texture("walk", 2) as AtlasTexture
	if frame0 == null or frame2 == null:
		_fail("walk frames are not atlas regions of the sheet")
		return
	if not str(frame0.atlas.resource_path).ends_with("농부-sheet.png"):
		_fail("walk sheet path %s" % frame0.atlas.resource_path)
	var sheet_size := frame0.atlas.get_size()
	if frame0.region.position != Vector2.ZERO:
		_fail("first frame should be the top of the sheet")
	if frame0.region.size.x != sheet_size.x or frame0.region.size.y * 5.0 != sheet_size.y:
		_fail("sheet is not 1 column by 5 rows: frame %s sheet %s" % [frame0.region.size, sheet_size])
	if frame2.region.position.y != frame0.region.size.y * 2.0 or frame2.region.position.x != 0.0:
		_fail("third frame is not the third row: %s" % frame2.region)
	if walk.visible or not idle.visible:
		_fail("farmer should start on the idle portrait")
	if farmer.get_node("Selection").visible:
		_fail("selection ring should start hidden")


func _test_body_anchor(farmer: Unit) -> void:
	var rect := farmer.get_selection_rect()
	if not farmer.contains_point(rect.get_center()):
		_fail("body center is not clickable")
	if farmer.contains_point(rect.position + Vector2(-30, -30)):
		_fail("point well outside the body still hits")
	if absf(rect.end.y - farmer.global_position.y) > 1.5:
		_fail("feet should rest on the unit origin, rect %s origin %s" % [rect, farmer.global_position])
	if absf(rect.get_center().x - farmer.global_position.x) > 1.5:
		_fail("body is not centered on the unit origin")


func _test_screen_roundtrip(selection: RtsSelection, farmer: Unit) -> void:
	var screen := selection.world_to_screen(farmer.global_position)
	var back := selection.screen_to_world(screen)
	if farmer.global_position.distance_to(back) > 1.0:
		_fail("screen conversion roundtrip %s -> %s -> %s" % [farmer.global_position, screen, back])
	var view := get_viewport().get_visible_rect().size
	if screen.x < 0.0 or screen.y < 0.0 or screen.x > view.x or screen.y > view.y:
		_fail("farmer starts off screen at %s view %s" % [screen, view])


func _test_box_query(selection: RtsSelection, units: Array[Unit]) -> void:
	var tight := units[0].get_selection_rect().grow(1.0)
	var one := selection.units_in_world_rect(tight)
	if one.size() != 1 or one[0] != units[0]:
		_fail("tight box selected %d units" % one.size())
	var pair := units[0].get_selection_rect().merge(units[3].get_selection_rect()).grow(2.0)
	var both := selection.units_in_world_rect(pair)
	if units[0] not in both or units[3] not in both:
		_fail("drag rect missed one of the two farmers")
	var empty := selection.units_in_world_rect(Rect2(Vector2(8, 8), Vector2(32, 32)))
	if not empty.is_empty():
		_fail("empty ground returned a unit")
	selection.command_move(Vector2(400, 400))
	for unit in units:
		if unit.is_moving():
			_fail("right click with nothing selected issued a move")
			break


func _test_movement(farmer: Unit) -> void:
	farmer.set_process(false)
	var idle := farmer.get_node("Idle") as Sprite2D
	var walk := farmer.get_node("Walk") as AnimatedSprite2D
	var start := farmer.global_position
	farmer.order_move(start + Vector2(-180, 12))
	for _i in 8:
		farmer._process(1.0 / 60.0)
	if not farmer.is_moving() or farmer.global_position.x >= start.x:
		_fail("farmer did not walk left")
	if not walk.visible or idle.visible or not walk.is_playing():
		_fail("left move should play the walk sheet")
	if not walk.flip_h or not idle.flip_h:
		_fail("moving to screen-left should mirror the farmer")
	farmer.order_move(farmer.global_position + Vector2(180, 0))
	farmer._process(1.0 / 60.0)
	if walk.flip_h or idle.flip_h:
		_fail("moving to screen-right should face right")
	var facing := idle.flip_h
	farmer.order_move(farmer.global_position + Vector2(0, 80))
	for _i in 4:
		farmer._process(1.0 / 60.0)
	if idle.flip_h != facing:
		_fail("a vertical move changed facing")
	farmer.order_move(farmer.global_position + Vector2(24, 0))
	for _i in 40:
		farmer._process(1.0 / 60.0)
	if farmer.is_moving() or walk.visible or not idle.visible:
		_fail("farmer should stop on the idle portrait after arriving")
	farmer.set_process(true)


func _test_formation(selection: RtsSelection, units: Array[Unit]) -> void:
	selection.select_units(units)
	selection.command_move(Vector2(2300, 1700))
	var seen := {}
	for unit in units:
		if not unit.is_moving():
			_fail("formation left a unit behind")
			return
		seen[str(unit.get_destination())] = true
	if seen.size() < 4:
		_fail("formation collapsed units onto %d points" % seen.size())
	for unit in units:
		unit.cancel_move()
	selection.select_units([])


func _reset(units: Array[Unit], homes: Dictionary, selection: RtsSelection, camera: RtsCamera, ground: Node) -> void:
	for unit in units:
		unit.cancel_move()
		unit.global_position = homes[unit]
		unit.set_process(true)
		(unit.get_node("Idle") as Sprite2D).flip_h = false
		(unit.get_node("Walk") as AnimatedSprite2D).flip_h = false
	selection.select_units([])
	var world_size: Vector2 = ground.world_size
	camera.position = world_size * 0.5
	camera.clamp_to_map(get_viewport().get_visible_rect().size)


func _test_mouse(selection: RtsSelection, units: Array[Unit]) -> void:
	var target := units[2]
	var screen := selection.world_to_screen(target.get_selection_rect().get_center())
	_mouse_button(screen, MOUSE_BUTTON_LEFT, true)
	await get_tree().process_frame
	_mouse_button(screen, MOUSE_BUTTON_LEFT, false)
	await get_tree().process_frame
	if not target.selected:
		_fail("left click did not select the farmer under the cursor")
	var others_selected := 0
	for unit in units:
		if unit != target and unit.selected:
			others_selected += 1
	if others_selected != 0:
		_fail("left click also selected %d other units" % others_selected)

	var first: Unit = units[0]
	var second: Unit = units[4]
	var screen_a := selection.world_to_screen(first.get_selection_rect().position + Vector2(-12, -12))
	var screen_b := selection.world_to_screen(second.get_selection_rect().end + Vector2(12, 12))
	_mouse_button(screen_a, MOUSE_BUTTON_LEFT, true)
	await get_tree().process_frame
	_mouse_motion(screen_a.lerp(screen_b, 0.5))
	await get_tree().process_frame
	_mouse_motion(screen_b)
	await get_tree().process_frame
	await _capture("05-drag")
	_mouse_button(screen_b, MOUSE_BUTTON_LEFT, false)
	await get_tree().process_frame
	if not first.selected or not second.selected:
		_fail("drag release did not select both farmers in the rectangle")

	var selected_now: Array[Unit] = []
	for unit in units:
		if unit.selected:
			selected_now.append(unit)
	if selected_now.is_empty():
		_fail("nothing selected for the move order")
		return
	var rally_x := selected_now[0].global_position.x
	var rally_y := 0.0
	for unit in selected_now:
		rally_x = minf(rally_x, unit.global_position.x)
		rally_y += unit.global_position.y
	rally_y /= float(selected_now.size())
	var rally := Vector2(rally_x - 220.0, rally_y)
	_mouse_button(selection.world_to_screen(rally), MOUSE_BUTTON_RIGHT, true)
	await get_tree().process_frame
	for unit in selected_now:
		if not unit.is_moving():
			_fail("right click did not move the dragged selection")
		elif unit.get_destination().x >= unit.global_position.x:
			_fail("rally %s is not west of %s" % [unit.get_destination(), unit.global_position])
	for _i in 6:
		await get_tree().process_frame
	for unit in selected_now:
		if not (unit.get_node("Walk") as AnimatedSprite2D).flip_h:
			_fail("right-click move to screen-left did not mirror the farmer")


func _mouse_button(screen: Vector2, button: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = screen
	event.global_position = screen
	event.button_index = button
	event.pressed = pressed
	event.button_mask = button if pressed else 0
	Input.parse_input_event(event)


func _mouse_motion(screen: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = screen
	event.global_position = screen
	event.relative = Vector2(12, 8)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var viewport_texture := get_viewport().get_texture()
	if viewport_texture == null:
		return
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		print("SHOT_EMPTY ", label)
		return
	var path := "/tmp/throne-shots/%s.png" % label
	DirAccess.make_dir_recursive_absolute("/tmp/throne-shots")
	var err := image.save_png(path)
	_shots += 1
	print("SHOT ", path, " ", image.get_size(), " err", err)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_errors.append(message)
	push_error(message)


func _units() -> Array[Unit]:
	var units: Array[Unit] = []
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if unit != null:
			units.append(unit)
	return units


func _on_timeout() -> void:
	print("RTS_SMOKE_TIMEOUT")
	get_tree().quit(1)


func _finish() -> void:
	if _errors.is_empty():
		print("RTS_SMOKE_OK shots=", _shots)
		get_tree().quit(0)
	else:
		print("RTS_SMOKE_FAIL")
		for message in _errors:
			print(" - ", message)
		get_tree().quit(1)
