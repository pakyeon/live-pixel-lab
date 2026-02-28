## GameWorld — Manages the playable field, ground, and camera.
extends Node2D

# These nodes are added dynamically by main_ui.gd, not in the scene tree.
# Use get_node_or_null() where needed instead of @onready.
var bg_color: ColorRect = null

var _field_style: String = "32-bit"

## Color palettes per bit style
const BIT_PALETTES := {
	"8-bit": {
		"sky": Color("1a1c2c"),
		"ground": Color("333c57"),
		"ground_top": Color("566c86"),
		"accent": Color("94b0c2"),
	},
	"16-bit": {
		"sky": Color("1b1b3a"),
		"ground": Color("2a4b3c"),
		"ground_top": Color("3d8b37"),
		"accent": Color("73c34d"),
	},
	"32-bit": {
		"sky": Color("0c1445"),
		"ground": Color("2d1b69"),
		"ground_top": Color("5b3cc4"),
		"accent": Color("8b5cf6"),
	},
}


func _ready() -> void:
	bg_color = get_node_or_null("BackgroundColor") as ColorRect
	_generate_ground()
	_apply_field_style("32-bit")


func _generate_ground() -> void:
	# Ground is drawn procedurally using the _draw function
	queue_redraw()


func set_field_style(style: String) -> void:
	_field_style = style
	_apply_field_style(style)


func _apply_field_style(style: String) -> void:
	var palette: Dictionary = BIT_PALETTES.get(style, BIT_PALETTES["32-bit"])
	if bg_color:
		bg_color.color = palette["sky"]
	queue_redraw()


func spawn_player_at(pos: Vector2) -> void:
	var player_node: Node2D = get_node_or_null("Player")
	if player_node:
		player_node.global_position = pos


func _draw() -> void:
	var palette: Dictionary = BIT_PALETTES.get(_field_style, BIT_PALETTES["32-bit"])
	
	if GameManager.current_perspective == "top-down":
		_draw_topdown(palette)
	else:
		_draw_sidescroller(palette)


func _draw_sidescroller(palette: Dictionary) -> void:
	var tile_size := 32
	var ground_y := 400
	var ground_rows := 10
	var ground_cols := 100
	var start_x := -ground_cols * tile_size / 2
	
	# Ground top layer
	for col in range(ground_cols):
		var x := start_x + col * tile_size
		var rect := Rect2(x, ground_y, tile_size, tile_size)
		draw_rect(rect, palette["ground_top"])
		if col % 3 == 0:
			draw_rect(Rect2(x + 4, ground_y, 8, 4), palette["accent"].darkened(0.3))
		if col % 5 == 1:
			draw_rect(Rect2(x + 16, ground_y + 2, 12, 6), palette["accent"].darkened(0.2))
	
	# Ground fill
	for row in range(1, ground_rows):
		for col in range(ground_cols):
			var x := start_x + col * tile_size
			var y := ground_y + row * tile_size
			draw_rect(Rect2(x, y, tile_size, tile_size), palette["ground"].darkened(row * 0.05))
	
	# Floating platforms
	var platforms := [
		Vector2(-200, 300), Vector2(100, 250), Vector2(350, 320),
		Vector2(-400, 200), Vector2(500, 280),
	]
	for plat_pos in platforms:
		for i in range(4):
			draw_rect(Rect2(plat_pos.x + i * tile_size, plat_pos.y, tile_size, tile_size), palette["ground_top"])
		draw_rect(Rect2(plat_pos.x, plat_pos.y - 4, 4 * tile_size, 4), palette["accent"])


func _draw_topdown(palette: Dictionary) -> void:
	var tile_size := 32
	
	# Floor tiles (checkerboard pattern)
	var floor_base: Color = Color(palette["ground"]).lightened(0.15)
	var floor_alt: Color = Color(palette["ground"]).lightened(0.1)
	for row in range(-13, 13):
		for col in range(-19, 19):
			var color: Color = floor_base if (row + col) % 2 == 0 else floor_alt
			draw_rect(Rect2(col * tile_size, row * tile_size, tile_size, tile_size), color)
	
	# Boundary walls
	draw_rect(Rect2(-600, -416, 1200, 32), palette["ground_top"])  # Top
	draw_rect(Rect2(-600, 384, 1200, 32), palette["ground_top"])   # Bottom
	draw_rect(Rect2(-616, -400, 32, 832), palette["ground_top"])    # Left
	draw_rect(Rect2(584, -400, 32, 832), palette["ground_top"])     # Right
	
	# Top edge accent
	draw_rect(Rect2(-600, -384, 1200, 4), palette["accent"])
	
	# Interior obstacles
	var obstacles := [
		{"pos": Vector2(-200, -100), "size": Vector2(96, 96)},
		{"pos": Vector2(200, 150), "size": Vector2(128, 64)},
		{"pos": Vector2(0, -250), "size": Vector2(64, 128)},
		{"pos": Vector2(350, -200), "size": Vector2(96, 96)},
		{"pos": Vector2(-300, 200), "size": Vector2(80, 80)},
	]
	for obs in obstacles:
		var pos: Vector2 = obs["pos"]
		var sz: Vector2 = obs["size"]
		draw_rect(Rect2(pos.x - sz.x/2, pos.y - sz.y/2, sz.x, sz.y), palette["ground_top"])
		# Top accent
		draw_rect(Rect2(pos.x - sz.x/2, pos.y - sz.y/2 - 4, sz.x, 4), palette["accent"])


## Get the collision areas for physics. We use Area2D static bodies for ground.
func get_ground_y() -> float:
	return 400.0
