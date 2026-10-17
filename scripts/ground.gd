extends Sprite2D

## Repeats Tile.png across the whole map. The camera stays inside this rect,
## so the ground covers every pixel of the window.

@export var world_size := Vector2(4096, 3072)

const TILE := preload("res://assets/Tile.png")


func _ready() -> void:
	add_to_group("ground")
	var image := TILE.get_image()
	if image == null or image.is_empty():
		push_error("Tile.png could not be read")
		return
	var tile_w := image.get_width()
	var tile_h := image.get_height()
	var world_w := int(world_size.x)
	var world_h := int(world_size.y)
	var tiled := Image.create(world_w, world_h, false, image.get_format())
	for y in range(0, world_h, tile_h):
		for x in range(0, world_w, tile_w):
			tiled.blit_rect(image, Rect2i(0, 0, tile_w, tile_h), Vector2i(x, y))
	var tiled_texture := ImageTexture.create_from_image(tiled)
	texture = tiled_texture
	centered = false
	position = Vector2.ZERO
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
