## GameManager Autoload — Central game state and hot-reload orchestration.
extends Node

signal state_changed(new_state: GameState)
signal character_spec_updated(spec: Dictionary)
signal hot_reload_ready(new_image: Image, metadata: Dictionary)
signal hot_reload_applied
signal animation_expanded(anim_name: String, frames: Array, fps: int, loop: bool)

enum GameState {
	MENU,
	CREATING,
	PLAYING,
	MODIFYING,
}

var current_state: GameState = GameState.MENU:
	set(value):
		current_state = value
		state_changed.emit(current_state)

## Current character specification
var character_spec: Dictionary = {
	"name": "",
	"prompt": "",
	"bit_style": "32-bit",
	"speed": 200.0,
	"jump_velocity": -350.0,
	"gravity_multiplier": 1.0,
	"scale": 1.0,
	"animation_fps": 10,
}

## Pending sprite for hot-reload
var pending_image: Image = null
var pending_metadata: Dictionary = {}
var pending_params: Dictionary = {}

## Current sprite sheet image
var current_sprite_image: Image = null

## Current game perspective ("side-scroller" or "top-down")
var current_perspective: String = "side-scroller"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GeminiAPI.sprite_generated.connect(_on_sprite_generated)
	GeminiAPI.sprite_modified.connect(_on_sprite_modified)
	GeminiAPI.sprite_expanded.connect(_on_sprite_expanded)
	GeminiAPI.command_parsed.connect(_on_command_parsed)
	GeminiAPI.api_error.connect(_on_api_error)


## Request a new character sprite to be generated from a structured spec.
func request_character_generation(sprite_spec: Dictionary) -> void:
	current_state = GameState.CREATING
	character_spec["prompt"] = sprite_spec.get("character_design", "")
	character_spec["bit_style"] = sprite_spec.get("style", "32-bit")
	
	# Detect perspective for field setup
	var persp: String = sprite_spec.get("perspective", "").to_lower()
	if "top-down" in persp:
		current_perspective = "top-down"
	elif "isometric" in persp:
		current_perspective = "top-down"  # Isometric uses similar movement
	else:
		current_perspective = "side-scroller"
	
	GeminiAPI.generate_sprite(sprite_spec)


## Request modification of the current sprite during gameplay.
func request_modification(command: String) -> void:
	current_state = GameState.MODIFYING
	# First parse the command to check if it needs visual changes
	GeminiAPI.parse_command(command)


## Apply pending hot-reload changes.
func apply_hot_reload() -> void:
	# Apply pending parameter changes
	if not pending_params.is_empty():
		_apply_params(pending_params)
		pending_params = {}
	
	# Apply pending visual changes
	if pending_image:
		current_sprite_image = pending_image
		hot_reload_ready.emit(pending_image, pending_metadata)
		pending_image = null
		pending_metadata = {}
	
	hot_reload_applied.emit()
	current_state = GameState.PLAYING


func _apply_params(params: Dictionary) -> void:
	if params.has("speed_multiplier"):
		character_spec["speed"] *= params["speed_multiplier"]
	if params.has("jump_multiplier"):
		character_spec["jump_velocity"] *= params["jump_multiplier"]
	if params.has("gravity_multiplier"):
		character_spec["gravity_multiplier"] *= params["gravity_multiplier"]
	if params.has("scale_multiplier"):
		character_spec["scale"] *= params["scale_multiplier"]
	if params.has("animation_fps"):
		character_spec["animation_fps"] = params["animation_fps"]
	character_spec_updated.emit(character_spec)


func _on_sprite_generated(image: Image, metadata: Dictionary) -> void:
	current_sprite_image = image
	character_spec_updated.emit(character_spec)
	current_state = GameState.PLAYING


func _on_sprite_modified(image: Image, metadata: Dictionary) -> void:
	pending_image = image
	pending_metadata = metadata
	# State stays MODIFYING until user clicks Apply


func _on_command_parsed(params: Dictionary) -> void:
	var tool_name: String = params.get("_tool_name", "")
	
	match tool_name:
		"adjust_parameters":
			# Apply gameplay parameter changes immediately
			_apply_params(params)
			current_state = GameState.PLAYING
		
		"modify_sprite":
			# Small visual edit to existing sprite
			if current_sprite_image:
				var visual_prompt: String = params.get("visual_prompt", "")
				if not visual_prompt.is_empty():
					GeminiAPI.modify_sprite(visual_prompt, current_sprite_image)
				else:
					current_state = GameState.PLAYING
			else:
				current_state = GameState.PLAYING
		
		"regenerate_sprite":
			# Full style change — regenerate from scratch
			var new_style: String = params.get("new_style", "")
			var regen_prompt: String = params.get("regeneration_prompt", "")
			
			var spec: Dictionary = GeminiAPI._current_sprite_spec.duplicate()
			if not new_style.is_empty():
				spec["style"] = new_style
			if not regen_prompt.is_empty():
				spec["character_design"] = character_spec.get("prompt", "") + ". " + regen_prompt
			
			current_state = GameState.CREATING
			GeminiAPI.generate_sprite(spec)
		
		"expand_sprite":
			# Add or replace animation
			if current_sprite_image:
				var anim_name: String = params.get("animation_name", "custom")
				var anim_desc: String = params.get("animation_description", anim_name + " animation")
				var frame_count: int = params.get("frame_count", 4)
				var should_loop: bool = params.get("should_loop", false)
				GeminiAPI.expand_sprite(anim_name, anim_desc, frame_count, should_loop, current_sprite_image)
			else:
				current_state = GameState.PLAYING
		
		_:
			push_warning("Unknown tool name: " + tool_name)
			current_state = GameState.PLAYING


func _on_sprite_expanded(anim_name: String, frames: Array, fps: int, loop: bool) -> void:
	# Apply any pending param changes first
	if not pending_params.is_empty():
		_apply_params(pending_params)
		pending_params = {}
	
	# Forward to player via signal
	animation_expanded.emit(anim_name, frames, fps, loop)
	current_state = GameState.PLAYING


func _on_api_error(message: String) -> void:
	push_error("API Error: " + message)
	if current_state == GameState.CREATING:
		current_state = GameState.MENU
	elif current_state == GameState.MODIFYING:
		current_state = GameState.PLAYING
