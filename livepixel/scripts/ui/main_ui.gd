## MainUI — Root scene controller. Manages the 3-panel layout and
## orchestrates game world spawning and hot-reload transitions.
extends Control

@onready var creator_panel: PanelContainer = $HSplitContainer/CreatorPanel
@onready var game_container: SubViewportContainer = $HSplitContainer/GameViewContainer/SubViewportContainer
@onready var game_viewport: SubViewport = $HSplitContainer/GameViewContainer/SubViewportContainer/SubViewport
@onready var chat_panel: PanelContainer = $HSplitContainer/ChatPanel
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var title_screen: CenterContainer = $TitleScreen

var _game_world_scene: PackedScene
var _game_world: Node2D = null
var _player: Player = null


func _ready() -> void:
	# Initialize fade overlay
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.visible = false
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	GameManager.hot_reload_ready.connect(_on_hot_reload_ready)
	GeminiAPI.sprite_generated.connect(_on_first_sprite_generated)
	
	# Show title screen initially
	title_screen.visible = true


func start_game_with_sprite(image: Image, metadata: Dictionary) -> void:
	title_screen.visible = false
	
	# Create game world if not already
	if _game_world == null:
		_setup_game_world()
	
	# Load the sprite into the player
	if _player:
		_player.load_sprite_sheet(image, metadata)
		# Set spawn position based on perspective
		if GameManager.current_perspective == "top-down":
			_player.global_position = Vector2(0, 0)  # Center of field
		else:
			_player.global_position = Vector2(0, 350)  # Above ground
	
	GameManager.current_state = GameManager.GameState.PLAYING


func _setup_game_world() -> void:
	# Clean up old world if exists
	if _game_world:
		_game_world.queue_free()
		_game_world = null
		_player = null
	
	_game_world = Node2D.new()
	_game_world.name = "GameWorld"
	
	# Background color
	var bg := ColorRect.new()
	bg.name = "BackgroundColor"
	bg.color = Color("0c1445")
	bg.size = Vector2(4000, 2000)
	bg.position = Vector2(-2000, -1000)
	bg.z_index = -10
	_game_world.add_child(bg)
	
	var perspective := GameManager.current_perspective
	
	if perspective == "top-down":
		_setup_topdown_field()
	else:
		_setup_sidescroller_field()
	
	# Attach game_world.gd for visual rendering
	var world_script := load("res://scripts/game/game_world.gd")
	_game_world.set_script(world_script)
	
	# Create player
	_player = _create_player()
	_game_world.add_child(_player)
	
	# Add to game viewport
	game_viewport.add_child(_game_world)


func _setup_sidescroller_field() -> void:
	# Ground static body
	var ground_body := StaticBody2D.new()
	ground_body.name = "GroundBody"
	var ground_collision := CollisionShape2D.new()
	var ground_shape := RectangleShape2D.new()
	ground_shape.size = Vector2(6400, 200)
	ground_collision.shape = ground_shape
	ground_collision.position = Vector2(0, 500)
	ground_body.add_child(ground_collision)
	_game_world.add_child(ground_body)
	
	# Floating platforms
	var platform_positions := [
		Vector2(-200, 300), Vector2(100, 250), Vector2(350, 320),
		Vector2(-400, 200), Vector2(500, 280),
	]
	for i in range(platform_positions.size()):
		var plat_body := StaticBody2D.new()
		plat_body.name = "Platform_%d" % i
		var plat_collision := CollisionShape2D.new()
		var plat_shape := RectangleShape2D.new()
		plat_shape.size = Vector2(128, 16)
		plat_collision.shape = plat_shape
		plat_collision.position = Vector2(64, platform_positions[i].y)
		plat_body.position = Vector2(platform_positions[i].x, 0)
		plat_body.add_child(plat_collision)
		_game_world.add_child(plat_body)


func _setup_topdown_field() -> void:
	# Boundary walls for top-down view
	var wall_data := [
		{"pos": Vector2(0, -400), "size": Vector2(1200, 32)},   # Top wall
		{"pos": Vector2(0, 400), "size": Vector2(1200, 32)},    # Bottom wall
		{"pos": Vector2(-600, 0), "size": Vector2(32, 832)},    # Left wall
		{"pos": Vector2(600, 0), "size": Vector2(32, 832)},     # Right wall
	]
	for i in range(wall_data.size()):
		var wall := StaticBody2D.new()
		wall.name = "Wall_%d" % i
		wall.position = wall_data[i]["pos"]
		var coll := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = wall_data[i]["size"]
		coll.shape = shape
		wall.add_child(coll)
		_game_world.add_child(wall)
	
	# Some interior obstacles
	var obstacles := [
		{"pos": Vector2(-200, -100), "size": Vector2(96, 96)},
		{"pos": Vector2(200, 150), "size": Vector2(128, 64)},
		{"pos": Vector2(0, -250), "size": Vector2(64, 128)},
		{"pos": Vector2(350, -200), "size": Vector2(96, 96)},
		{"pos": Vector2(-300, 200), "size": Vector2(80, 80)},
	]
	for i in range(obstacles.size()):
		var obs := StaticBody2D.new()
		obs.name = "Obstacle_%d" % i
		obs.position = obstacles[i]["pos"]
		var coll := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = obstacles[i]["size"]
		coll.shape = shape
		obs.add_child(coll)
		_game_world.add_child(obs)


func _create_player() -> Player:
	var player := CharacterBody2D.new()
	player.name = "Player"
	
	# Add script
	var player_script := load("res://scripts/game/player.gd")
	player.set_script(player_script)
	
	# Add AnimatedSprite2D
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player.add_child(sprite)
	
	# Add CollisionShape2D
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32, 56)
	collision.shape = shape
	collision.position = Vector2(0, -28)
	player.add_child(collision)
	
	# Add Camera2D
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(2.0, 2.0)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_bottom = 600
	player.add_child(camera)
	
	player.position = Vector2(0, 350)
	
	return player


func _on_first_sprite_generated(image: Image, metadata: Dictionary) -> void:
	# Auto-start game with the first generated sprite
	pass  # User clicks Play button manually


func _on_hot_reload_ready(new_image: Image, metadata: Dictionary) -> void:
	# Perform fade transition then apply
	_perform_hot_reload(new_image, metadata)


func _perform_hot_reload(new_image: Image, metadata: Dictionary) -> void:
	if _player == null:
		return
	
	# Fade out
	fade_overlay.visible = true
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color", Color(0, 0, 0, 0.8), 0.3)
	await tween.finished
	
	# Swap sprite
	_player.hot_reload(new_image, metadata)
	
	# Fade in
	await get_tree().create_timer(0.2).timeout
	var tween2 := create_tween()
	tween2.tween_property(fade_overlay, "color", Color(0, 0, 0, 0), 0.3)
	await tween2.finished
	fade_overlay.visible = false
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
