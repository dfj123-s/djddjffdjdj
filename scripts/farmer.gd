extends Unit

## Farmer. Idle pose is 농부.png. While moving, 농부-sheet.png plays as a
## single column of five frames (Godot hframes = 1, vframes = 5).
## Facing left of the screen's vertical axis mirrors the sprite.

const SHEET := preload("res://assets/농부-sheet.png")
const SHEET_COLUMNS := 1
const SHEET_ROWS := 5
const WALK_FPS := 10.0

@onready var _idle: Sprite2D = $Idle
@onready var _walk: AnimatedSprite2D = $Walk


func _ready() -> void:
	_build_walk_frames()
	_cache_visual_rect()
	_idle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_walk.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	super()


func _on_move(direction: Vector2) -> void:
	_idle.visible = false
	_walk.visible = true
	if _walk.sprite_frames != null and not _walk.is_playing():
		_walk.play("walk")
	_apply_facing(direction)


func _on_idle() -> void:
	if _walk.sprite_frames != null and _walk.is_playing():
		_walk.stop()
	_walk.visible = false
	_idle.visible = true


func _build_walk_frames() -> void:
	var frame_w := int(SHEET.get_width() / float(SHEET_COLUMNS))
	var frame_h := int(SHEET.get_height() / float(SHEET_ROWS))
	if frame_w <= 0 or frame_h <= 0 or SHEET.get_height() % SHEET_ROWS != 0:
		push_error("농부-sheet.png must be a 1 column by 5 row sprite sheet")
		return
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	frames.add_animation("walk")
	frames.set_animation_loop("walk", true)
	frames.set_animation_speed("walk", WALK_FPS)
	for row in SHEET_ROWS:
		for column in SHEET_COLUMNS:
			var atlas := AtlasTexture.new()
			atlas.atlas = SHEET
			atlas.region = Rect2(column * frame_w, row * frame_h, frame_w, frame_h)
			frames.add_frame("walk", atlas)
	_walk.sprite_frames = frames
	_walk.animation = "walk"
	var idle_size := _idle.texture.get_size()
	if idle_size.x > 0.0 and idle_size.y > 0.0:
		_walk.scale = Vector2(idle_size.x / float(frame_w), idle_size.y / float(frame_h))


func _cache_visual_rect() -> void:
	var tex := _idle.texture
	if tex == null:
		return
	var image := tex.get_image()
	if image == null or image.is_empty():
		return
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return
	var tex_size := tex.get_size()
	# Put the feet on the node origin and the body on the horizontal center,
	# so a move order lands where the farmer is standing and flip stays put.
	var foot_y := float(used.position.y + used.size.y) - tex_size.y * 0.5
	var center_x := float(used.position.x) + float(used.size.x) * 0.5 - tex_size.x * 0.5
	var sprite_offset := Vector2(-center_x, -foot_y)
	_idle.position = sprite_offset
	_walk.position = sprite_offset
	var top_left := Vector2(used.position) - tex_size * 0.5 + sprite_offset
	_local_rect = Rect2(top_left, Vector2(used.size))


func _apply_facing(direction: Vector2) -> void:
	var screen_dir := _screen_direction(direction)
	if absf(screen_dir.x) < 0.02:
		return
	var face_left := screen_dir.x < 0.0
	_idle.flip_h = face_left
	_walk.flip_h = face_left


func _screen_direction(world_direction: Vector2) -> Vector2:
	# Screen-left is the left side of the view's vertical axis. A camera with
	# no rotation maps world -X onto that side; if the canvas transform does
	# not, fall back to world X so facing still follows the screen.
	var canvas := get_viewport().get_canvas_transform()
	var axis := canvas.basis_xform(Vector2.RIGHT)
	if axis.x <= 0.01:
		return world_direction
	return canvas.basis_xform(world_direction)
