## Player controller — CharacterBody2D platformer with hot-reload support.
class_name Player
extends CharacterBody2D

signal sprite_updated

@export var speed: float = 200.0
@export var jump_velocity: float = -350.0
@export var gravity_multiplier: float = 1.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _default_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _is_sprite_loaded: bool = false
var _facing_right: bool = true

## Tracks dynamically added animation names for key binding
var _custom_animations: Array[String] = []
var _is_playing_custom: bool = false
var _custom_anim_timer: float = 0.0


func _ready() -> void:
	GameManager.character_spec_updated.connect(_on_spec_updated)
	GameManager.hot_reload_ready.connect(_on_hot_reload_ready)
	GameManager.animation_expanded.connect(_on_animation_expanded)
	
	# Apply initial spec
	_apply_spec(GameManager.character_spec)


func _physics_process(delta: float) -> void:
	if not _is_sprite_loaded:
		return
	
	var is_topdown: bool = GameManager.current_perspective == "top-down"
	
	if is_topdown:
		_physics_topdown(delta)
	else:
		_physics_sidescroller(delta)
	
	move_and_slide()
	_update_animation()


func _physics_sidescroller(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y += _default_gravity * gravity_multiplier * delta
	
	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	
	# Horizontal movement
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		velocity.x = direction * speed
		if direction > 0 and not _facing_right:
			_facing_right = true
			animated_sprite.flip_h = false
		elif direction < 0 and _facing_right:
			_facing_right = false
			animated_sprite.flip_h = true
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 0.2)


func _physics_topdown(_delta: float) -> void:
	# 4-directional movement — no gravity
	var dir := Vector2.ZERO
	dir.x = Input.get_axis("move_left", "move_right")
	dir.y = Input.get_axis("ui_up", "ui_down")
	
	if dir.length() > 1.0:
		dir = dir.normalized()
	
	velocity = dir * speed
	
	# Track facing direction for flip
	if dir.x > 0 and not _facing_right:
		_facing_right = true
		animated_sprite.flip_h = false
	elif dir.x < 0 and _facing_right:
		_facing_right = false
		animated_sprite.flip_h = true


func _update_animation() -> void:
	if not _is_sprite_loaded:
		return
	
	# If currently playing a custom (one-shot) animation, let it finish
	if _is_playing_custom:
		if not animated_sprite.is_playing():
			_is_playing_custom = false
		else:
			return
	
	# Check for custom animation triggers (number keys 1-9)
	for i in range(_custom_animations.size()):
		var key_name := "custom_anim_%d" % (i + 1)
		if InputMap.has_action(key_name) and Input.is_action_just_pressed(key_name):
			var anim_name: String = _custom_animations[i]
			if animated_sprite.sprite_frames.has_animation(anim_name):
				animated_sprite.play(anim_name)
				var is_looping: bool = animated_sprite.sprite_frames.get_animation_loop(anim_name)
				if not is_looping:
					_is_playing_custom = true
				return
	
	# Default animation state machine
	var is_topdown: bool = GameManager.current_perspective == "top-down"
	
	if is_topdown:
		# Top-down: pick direction-based animation
		if velocity.length() > 10.0:
			var anim_name := _get_topdown_walk_anim(velocity)
			if animated_sprite.sprite_frames.has_animation(anim_name):
				animated_sprite.play(anim_name)
			elif animated_sprite.sprite_frames.has_animation("walk"):
				animated_sprite.play("walk")
		else:
			var idle_name := _get_topdown_idle_anim()
			if animated_sprite.sprite_frames.has_animation(idle_name):
				animated_sprite.play(idle_name)
			elif animated_sprite.sprite_frames.has_animation("idle"):
				animated_sprite.play("idle")
	else:
		# Side-scroller: jump / walk / idle
		if not is_on_floor():
			if animated_sprite.sprite_frames.has_animation("jump") and animated_sprite.sprite_frames.get_frame_count("jump") > 0:
				animated_sprite.play("jump")
			elif animated_sprite.sprite_frames.has_animation("idle"):
				animated_sprite.play("idle")
		elif abs(velocity.x) > 10.0:
			if animated_sprite.sprite_frames.has_animation("walk"):
				animated_sprite.play("walk")
		else:
			if animated_sprite.sprite_frames.has_animation("idle"):
				animated_sprite.play("idle")


## Track last facing direction for idle pose
var _last_direction: String = "down"

## Get the walk animation name based on velocity direction (top-down)
func _get_topdown_walk_anim(vel: Vector2) -> String:
	# Determine primary direction
	if abs(vel.x) > abs(vel.y):
		if vel.x > 0:
			_last_direction = "right"
			return "walk_right"
		else:
			_last_direction = "left"
			return "walk_left"
	else:
		if vel.y > 0:
			_last_direction = "down"
			return "walk_down"
		else:
			_last_direction = "up"
			return "walk_up"

## Get the idle animation for the last faced direction
func _get_topdown_idle_anim() -> String:
	return "idle_" + _last_direction


## Load sprite frames from a sprite sheet image.
func load_sprite_sheet(image: Image, metadata: Dictionary) -> void:
	if image == null:
		return
	
	var frame_w: int = metadata.get("frame_width", 64)
	var frame_h: int = metadata.get("frame_height", 64)
	var fps: int = metadata.get("fps", 10)
	var idle_frames: Array = metadata.get("idle_frames", [0])
	var walk_frames: Array = metadata.get("walk_frames", [1, 2, 3, 4])
	var jump_frames: Array = metadata.get("jump_frames", [5, 6])
	
	# Extract individual frames from the sprite sheet
	var frames: Array[Image] = []
	var sheet_width := image.get_width()
	var sheet_height := image.get_height()
	var cols := sheet_width / frame_w
	var rows := sheet_height / frame_h
	var total_frames := cols * rows
	
	for i in range(total_frames):
		var col := i % cols
		var row := i / cols
		var frame_rect := Rect2i(col * frame_w, row * frame_h, frame_w, frame_h)
		
		# Clamp to image bounds
		if frame_rect.position.x + frame_rect.size.x > sheet_width:
			continue
		if frame_rect.position.y + frame_rect.size.y > sheet_height:
			continue
		
		var frame_image := image.get_region(frame_rect)
		frames.append(frame_image)
	
	if frames.is_empty():
		push_error("No frames extracted from sprite sheet")
		return
	
	print("[Player] Total frames extracted: %d" % frames.size())
	
	# Create SpriteFrames resource
	var sprite_frames := SpriteFrames.new()
	
	# Clear default animation
	if sprite_frames.has_animation("default"):
		sprite_frames.remove_animation("default")
	
	var is_topdown: bool = GameManager.current_perspective == "top-down"
	
	if is_topdown and frames.size() >= 16:
		# --- Top-Down: 4 rows × 4 cols direction-based animations ---
		# Row 0 (frames 0-3): DOWN
		# Row 1 (frames 4-7): LEFT
		# Row 2 (frames 8-11): RIGHT
		# Row 3 (frames 12-15): UP
		var directions := ["down", "left", "right", "up"]
		for dir_idx in range(4):
			var base := dir_idx * 4
			
			# idle_<dir> = first frame of this row
			var idle_name: String = "idle_" + directions[dir_idx]
			sprite_frames.add_animation(idle_name)
			sprite_frames.set_animation_speed(idle_name, fps)
			sprite_frames.set_animation_loop(idle_name, true)
			if base < frames.size():
				var tex := ImageTexture.create_from_image(frames[base])
				sprite_frames.add_frame(idle_name, tex)
			
			# walk_<dir> = all 4 frames of this row
			var walk_name: String = "walk_" + directions[dir_idx]
			sprite_frames.add_animation(walk_name)
			sprite_frames.set_animation_speed(walk_name, fps)
			sprite_frames.set_animation_loop(walk_name, true)
			for f in range(4):
				var idx := base + f
				if idx < frames.size():
					var tex := ImageTexture.create_from_image(frames[idx])
					sprite_frames.add_frame(walk_name, tex)
		
		# Also add generic "idle" as alias for idle_down
		sprite_frames.add_animation("idle")
		sprite_frames.set_animation_speed("idle", fps)
		sprite_frames.set_animation_loop("idle", true)
		if frames.size() > 0:
			var tex := ImageTexture.create_from_image(frames[0])
			sprite_frames.add_frame("idle", tex)
		
		print("[Player] Created top-down animations: idle/walk × 4 directions")
	else:
		# --- Side-Scroller: idle / walk / jump ---
		# Idle
		sprite_frames.add_animation("idle")
		sprite_frames.set_animation_speed("idle", fps)
		sprite_frames.set_animation_loop("idle", true)
		for idx in idle_frames:
			if idx < frames.size():
				var tex := ImageTexture.create_from_image(frames[idx])
				sprite_frames.add_frame("idle", tex)
		
		# Walk
		sprite_frames.add_animation("walk")
		sprite_frames.set_animation_speed("walk", fps)
		sprite_frames.set_animation_loop("walk", true)
		for idx in walk_frames:
			if idx < frames.size():
				var tex := ImageTexture.create_from_image(frames[idx])
				sprite_frames.add_frame("walk", tex)
		
		# Jump (only if frames exist)
		if not jump_frames.is_empty():
			sprite_frames.add_animation("jump")
			sprite_frames.set_animation_speed("jump", fps)
			sprite_frames.set_animation_loop("jump", false)
			for idx in jump_frames:
				if idx < frames.size():
					var tex := ImageTexture.create_from_image(frames[idx])
					sprite_frames.add_frame("jump", tex)
		
		print("[Player] Created side-scroller animations: idle(%d) walk(%d) jump(%d)" % [
			idle_frames.size(), walk_frames.size(), jump_frames.size()])
	
	# Apply to AnimatedSprite2D
	animated_sprite.sprite_frames = sprite_frames
	animated_sprite.play("idle")
	
	# --- Auto-scale massive frames to fit the game world ---
	var target_height := 120.0
	var scale_factor := 1.0
	if frame_h > target_height:
		scale_factor = target_height / float(frame_h)
	
	animated_sprite.scale = Vector2(scale_factor, scale_factor)
	# Center the sprite
	animated_sprite.offset = Vector2(0, -frame_h / 2.0)
	
	# Configure scaled collision shape
	var shape := RectangleShape2D.new()
	shape.size = Vector2(frame_w * 0.6 * scale_factor, frame_h * 0.9 * scale_factor)
	collision_shape.shape = shape
	collision_shape.position = Vector2(0, -shape.size.y / 2.0)
	
	_is_sprite_loaded = true
	sprite_updated.emit()


## Hot-reload: swap sprites while preserving position.
func hot_reload(new_image: Image, metadata: Dictionary) -> void:
	var saved_pos := global_position
	var saved_vel := velocity
	
	load_sprite_sheet(new_image, metadata)
	
	global_position = saved_pos
	velocity = saved_vel


func _apply_spec(spec: Dictionary) -> void:
	speed = spec.get("speed", 200.0)
	jump_velocity = spec.get("jump_velocity", -350.0)
	gravity_multiplier = spec.get("gravity_multiplier", 1.0)
	var char_scale: float = spec.get("scale", 1.0)
	scale = Vector2(char_scale, char_scale)
	
	if animated_sprite and animated_sprite.sprite_frames:
		var fps_val: int = spec.get("animation_fps", 10)
		for anim in animated_sprite.sprite_frames.get_animation_names():
			animated_sprite.sprite_frames.set_animation_speed(anim, fps_val)


func _on_spec_updated(spec: Dictionary) -> void:
	_apply_spec(spec)


func _on_hot_reload_ready(new_image: Image, metadata: Dictionary) -> void:
	# Don't auto-apply — wait for user to click Apply
	pass


## Dynamically add a new animation to the existing SpriteFrames.
func _on_animation_expanded(anim_name: String, frame_textures: Array, fps: int, loop: bool) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	
	var sf := animated_sprite.sprite_frames
	
	# Remove existing animation with same name if any
	if sf.has_animation(anim_name):
		sf.remove_animation(anim_name)
	
	# Add new animation
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, loop)
	
	for tex in frame_textures:
		if tex is Texture2D:
			sf.add_frame(anim_name, tex)
	
	# Register custom animation for key binding (if not a built-in)
	if anim_name not in ["idle", "walk", "jump", "run"]:
		if anim_name not in _custom_animations:
			_custom_animations.append(anim_name)
			_register_custom_key(_custom_animations.size())
	
	sprite_updated.emit()


## Register a number key (1-9) as input action for custom animations.
func _register_custom_key(index: int) -> void:
	if index < 1 or index > 9:
		return
	
	var action_name := "custom_anim_%d" % index
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		var key_event := InputEventKey.new()
		# Keys 1-9 are physical keycodes 49-57
		key_event.physical_keycode = KEY_1 + (index - 1)
		InputMap.action_add_event(action_name, key_event)
