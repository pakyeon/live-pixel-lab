## GeminiAPI Autoload — Handles all Gemini REST API communication.
## Supports sprite generation (Nano Banana), sprite modification, and
## text command parsing with model routing (Flash for simple, Pro for complex).
extends Node

signal sprite_generated(image: Image, metadata: Dictionary)
signal sprite_modified(image: Image, metadata: Dictionary)
signal sprite_expanded(anim_name: String, frames: Array, fps: int, loop: bool)
signal command_parsed(params: Dictionary)
signal api_error(message: String)
signal generation_started
signal generation_finished

const GEMINI_BASE_URL := "https://generativelanguage.googleapis.com/v1beta/models/"

## Model IDs
const MODEL_IMAGE := "gemini-3.1-flash-image-preview"
const MODEL_FLASH := "gemini-3-flash-preview"
const MODEL_PRO := "gemini-3-pro-preview"

var api_key: String = ""
var _http_sprite: HTTPRequest
var _http_modify: HTTPRequest
var _http_parse: HTTPRequest
var _http_expand: HTTPRequest
var _http_refine: HTTPRequest
var _http_analyze: HTTPRequest
var is_generating: bool = false

## Stores the latest sprite spec for metadata derivation
var _current_sprite_spec: Dictionary = {}

## Retry logic for TLS handshake failures
var _retry_count: int = 0
const MAX_RETRIES := 2

## Pending expansion animation metadata
var _pending_expand_name: String = ""
var _pending_expand_fps: int = 10
var _pending_expand_loop: bool = true
var _pending_expand_frame_size: Vector2i = Vector2i(64, 64)


func _ready() -> void:
	# 1. Try environment variable
	api_key = OS.get_environment("GEMINI_API_KEY")
	
	# 2. Try parsing local .env file
	if api_key.is_empty() and FileAccess.file_exists("res://../.env"):
		var f := FileAccess.open("res://../.env", FileAccess.READ)
		while not f.eof_reached():
			var line := f.get_line().strip_edges()
			if line.begins_with("GEMINI_API_KEY="):
				api_key = line.split("=", true, 1)[1].strip_edges()
				# Remove potential quotes
				if api_key.begins_with('"') and api_key.ends_with('"'):
					api_key = api_key.substr(1, api_key.length() - 2)
				break
		f.close()
	
	# 3. Try legacy config file
	if api_key.is_empty():
		var config_path := "user://api_key.txt"
		if FileAccess.file_exists(config_path):
			var f := FileAccess.open(config_path, FileAccess.READ)
			api_key = f.get_as_text().strip_edges()
			f.close()
	
	if api_key.is_empty():
		push_warning("GeminiAPI: No API key found. Use .env file, GEMINI_API_KEY environment variable, or user://api_key.txt")
	
	# Create HTTP request nodes
	_http_sprite = HTTPRequest.new()
	_http_sprite.name = "HTTPSprite"
	_http_sprite.timeout = 30.0
	_http_sprite.use_threads = true
	add_child(_http_sprite)
	_http_sprite.request_completed.connect(_on_sprite_request_completed)
	
	_http_modify = HTTPRequest.new()
	_http_modify.name = "HTTPModify"
	_http_modify.timeout = 30.0
	_http_modify.use_threads = true
	add_child(_http_modify)
	_http_modify.request_completed.connect(_on_modify_request_completed)
	
	_http_parse = HTTPRequest.new()
	_http_parse.name = "HTTPParse"
	_http_parse.timeout = 15.0
	_http_parse.use_threads = true
	add_child(_http_parse)
	_http_parse.request_completed.connect(_on_parse_request_completed)
	
	_http_expand = HTTPRequest.new()
	_http_expand.name = "HTTPExpand"
	_http_expand.timeout = 30.0
	_http_expand.use_threads = true
	add_child(_http_expand)
	_http_expand.request_completed.connect(_on_expand_request_completed)
	
	_http_refine = HTTPRequest.new()
	_http_refine.name = "HTTPRefine"
	_http_refine.timeout = 20.0
	_http_refine.use_threads = true
	add_child(_http_refine)
	_http_refine.request_completed.connect(_on_refine_request_completed)
	
	_http_analyze = HTTPRequest.new()
	_http_analyze.name = "HTTPAnalyze"
	_http_analyze.timeout = 30.0
	_http_analyze.use_threads = true
	add_child(_http_analyze)
	_http_analyze.request_completed.connect(_on_analyze_request_completed)

## Pending state for Vision analysis pipeline
var _pending_analysis_image: Image = null
var _pending_analysis_metadata: Dictionary = {}


## Generate a new sprite from a structured spec dictionary.
## Step 1: Refine prompt via Pro LLM → Step 2: Generate image via Nano Banana 2
func generate_sprite(spec: Dictionary) -> void:
	if api_key.is_empty():
		api_error.emit("API key not set")
		return
	
	is_generating = true
	_retry_count = 0
	generation_started.emit()
	_current_sprite_spec = spec
	
	# Step 1: Ask Pro LLM to refine the prompt
	_refine_prompt_with_llm(spec)


## Step 1: Call Pro model to refine user's simple description into a detailed image prompt.
func _refine_prompt_with_llm(spec: Dictionary) -> void:
	var base_prompt := _build_sprite_prompt(spec)
	
	var meta_prompt := """You are an expert pixel art sprite sheet prompt engineer.
The user wants to generate a pixel art sprite sheet using an image generation AI.
Below is the structured specification they provided.

Your job:
1. Read the specification carefully.
2. Rewrite it as a single, highly detailed image generation prompt.
3. Add specific visual details: material textures, lighting direction, shadow style, color palette suggestions, pose details for each animation frame.
4. Keep ALL the original constraints (transparency, grid layout, frame count, resolution) intact.
5. Output ONLY the refined prompt text, nothing else. No explanations, no markdown formatting.

--- USER SPECIFICATION ---
""" + base_prompt
	
	var url := GEMINI_BASE_URL + MODEL_PRO + ":generateContent?key=" + api_key
	var body := {
		"contents": [{
			"parts": [{"text": meta_prompt}]
		}],
		"generationConfig": {
			"temperature": 0.7,
			"maxOutputTokens": 2048
		}
	}
	
	var headers := ["Content-Type: application/json"]
	var json_body := JSON.stringify(body)
	
	print("[GeminiAPI] Step 1: Sending prompt to Pro LLM for refinement...")
	
	# Delay slightly to prevent TLS handshake collision on Linux
	await get_tree().create_timer(0.5).timeout
	
	var err := _http_refine.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		print("[GeminiAPI] Pro LLM request failed, falling back to basic prompt")
		_send_sprite_request(_current_sprite_spec)


## Callback: Pro model returned the refined prompt. Now send it to image generation.
func _on_refine_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_retry_count += 1
		if _retry_count <= MAX_RETRIES:
			print("[GeminiAPI] ⚠️ Pro LLM refinement connection error (result %d), retrying %d/%d in 2s..." % [result, _retry_count, MAX_RETRIES])
			await get_tree().create_timer(2.0).timeout
			_refine_prompt_with_llm(_current_sprite_spec)
			return
		else:
			print("[GeminiAPI] ❌ Max retries reached for Pro LLM, using basic prompt")
			_send_sprite_request(_current_sprite_spec)
			return
	
	if response_code != 200:
		print("[GeminiAPI] ⚠️ Pro LLM refinement failed (HTTP: %d), using basic prompt" % response_code)
		if body.size() > 0:
			print("[GeminiAPI] Pro LLM error body: " + body.get_string_from_utf8().substr(0, 500))
		_send_sprite_request(_current_sprite_spec)
		return
	
	# Extract the refined text
	var refined_text := _extract_text_from_response(body)
	if refined_text.is_empty():
		print("[GeminiAPI] ⚠️ Empty refinement response, using basic prompt")
		_send_sprite_request(_current_sprite_spec)
		return
	
	print("[GeminiAPI] ✅ Step 1 complete — Refined prompt (%d chars):" % refined_text.length())
	print(refined_text.substr(0, 300) + "...")
	
	# Step 2: Send the refined prompt to image generation
	_send_sprite_request_with_refined_prompt(refined_text, _current_sprite_spec)


## Internal: sends the actual HTTP request for sprite generation.
func _send_sprite_request(spec: Dictionary) -> void:
	var full_prompt := _build_sprite_prompt(spec)
	var url := GEMINI_BASE_URL + MODEL_IMAGE + ":generateContent?key=" + api_key
	
	# Build request parts
	var parts: Array = [{"text": full_prompt}]
	
	# Add reference image if provided
	var ref_image: Image = spec.get("reference_image", null)
	if ref_image is Image and ref_image != null:
		var png_bytes := ref_image.save_png_to_buffer()
		var base64_ref := Marshalls.raw_to_base64(png_bytes)
		parts.append({
			"inlineData": {
				"mimeType": "image/png",
				"data": base64_ref
			}
		})
	
	var body := {
		"contents": [{
			"parts": parts
		}],
		"generationConfig": {
			"responseModalities": ["TEXT", "IMAGE"],
			"imageConfig": {
				"imageSize": "1K"
			}
		}
	}
	
	var headers := ["Content-Type: application/json"]
	var json_body := JSON.stringify(body)
	
	var err := _http_sprite.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		is_generating = false
		generation_finished.emit()
		api_error.emit("HTTP request failed: %s" % error_string(err))


## Internal: sends the refined prompt from Pro LLM to the image generation model.
func _send_sprite_request_with_refined_prompt(refined_prompt: String, spec: Dictionary) -> void:
	var url := GEMINI_BASE_URL + MODEL_IMAGE + ":generateContent?key=" + api_key
	
	# Build request parts with the refined prompt
	var parts: Array = [{"text": refined_prompt}]
	
	# Add reference image if provided
	var ref_image: Image = spec.get("reference_image", null)
	if ref_image is Image and ref_image != null:
		var png_bytes := ref_image.save_png_to_buffer()
		var base64_ref := Marshalls.raw_to_base64(png_bytes)
		parts.append({
			"inlineData": {
				"mimeType": "image/png",
				"data": base64_ref
			}
		})
	
	var body := {
		"contents": [{
			"parts": parts
		}],
		"generationConfig": {
			"responseModalities": ["TEXT", "IMAGE"],
			"imageConfig": {
				"imageSize": "1K"
			}
		}
	}
	
	var headers := ["Content-Type: application/json"]
	var json_body := JSON.stringify(body)
	
	print("[GeminiAPI] Step 2: Sending refined prompt to image model...")
	var err := _http_sprite.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		is_generating = false
		generation_finished.emit()
		api_error.emit("HTTP request failed: %s" % error_string(err))


## Modify an existing sprite based on text instructions.
func modify_sprite(prompt: String, current_image: Image) -> void:
	if api_key.is_empty():
		api_error.emit("API key not set")
		return
	
	is_generating = true
	generation_started.emit()
	
	# Encode current image to base64 PNG
	var png_bytes := current_image.save_png_to_buffer()
	var base64_image := Marshalls.raw_to_base64(png_bytes)
	
	var full_prompt := "You are a pixel art sprite editor. Modify this pixel art sprite sheet based on the following instructions. Keep the same sprite sheet layout and format. Instructions: " + prompt
	
	var url := GEMINI_BASE_URL + MODEL_IMAGE + ":generateContent?key=" + api_key
	
	var body := {
		"contents": [{
			"parts": [
				{"text": full_prompt},
				{
					"inlineData": {
						"mimeType": "image/png",
						"data": base64_image
					}
				}
			]
		}],
		"generationConfig": {
			"responseModalities": ["TEXT", "IMAGE"],
			"imageConfig": {
				"imageSize": "1K"
			}
		}
	}
	
	var headers := ["Content-Type: application/json"]
	var json_body := JSON.stringify(body)
	
	var err := _http_modify.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		is_generating = false
		generation_finished.emit()
		api_error.emit("HTTP request failed: %s" % error_string(err))


## Generate NEW animation frames for an existing character.
## Sends the current sprite as reference so the new frames match the style.
func expand_sprite(anim_name: String, anim_description: String, frame_count: int, loop: bool, current_image: Image) -> void:
	if api_key.is_empty():
		api_error.emit("API key not set")
		return
	
	is_generating = true
	generation_started.emit()
	
	# Store metadata for the callback
	_pending_expand_name = anim_name
	_pending_expand_fps = 10
	_pending_expand_loop = loop
	
	# Derive frame size from current spec
	var frame_res: String = _current_sprite_spec.get("frame_resolution", "64x64")
	var res_parts := frame_res.split("x")
	var fw := int(res_parts[0]) if res_parts.size() >= 2 else 64
	var fh := int(res_parts[1]) if res_parts.size() >= 2 else 64
	_pending_expand_frame_size = Vector2i(fw, fh)
	
	# Encode existing sprite as reference
	var png_bytes := current_image.save_png_to_buffer()
	var base64_image := Marshalls.raw_to_base64(png_bytes)
	
	var prompt := """You are a pixel art sprite sheet generator.
I have an existing character sprite sheet (provided as reference image).
Generate a NEW sprite sheet for the "%s" animation of this SAME character.

Requirements:
- Match the existing character's art style, colors, proportions, and design EXACTLY
- Create %d frames arranged in a single horizontal row
- Each frame: exactly %dx%d pixels
- Animation: %s
- Background: Fully transparent (alpha channel)
- No anti-aliasing — keep crisp pixel edges
- Character should face RIGHT
- Generate ONLY the new animation sprite sheet image, no text overlay""" % [anim_name, frame_count, fw, fh, anim_description]
	
	var url := GEMINI_BASE_URL + MODEL_IMAGE + ":generateContent?key=" + api_key
	
	var body := {
		"contents": [{
			"parts": [
				{"text": prompt},
				{
					"inlineData": {
						"mimeType": "image/png",
						"data": base64_image
					}
				}
			]
		}],
		"generationConfig": {
			"responseModalities": ["TEXT", "IMAGE"],
			"imageConfig": {
				"imageSize": "1K"
			}
		}
	}
	
	var headers := ["Content-Type: application/json"]
	var json_body := JSON.stringify(body)
	
	var err := _http_expand.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		is_generating = false
		generation_finished.emit()
		api_error.emit("HTTP request failed: %s" % error_string(err))


## Parse a natural language command using Gemini Function Calling.
## The model selects one of 4 tools based on user intent.
func parse_command(text: String, is_complex: bool = false) -> void:
	if api_key.is_empty():
		api_error.emit("API key not set")
		return
	
	var model := MODEL_PRO if is_complex else MODEL_FLASH
	var url := GEMINI_BASE_URL + model + ":generateContent?key=" + api_key
	
	# Define 4 function tools for the model to choose from
	var tools := [{
		"functionDeclarations": [
			{
				"name": "adjust_parameters",
				"description": "Adjust gameplay physics parameters like speed, jump height, gravity, character scale, or animation FPS. Use for non-visual changes that affect gameplay mechanics.",
				"parameters": {
					"type": "OBJECT",
					"properties": {
						"speed_multiplier": {"type": "NUMBER", "description": "Multiplier for walking speed (e.g. 1.5 for 50% faster, 0.5 for half speed)"},
						"jump_multiplier": {"type": "NUMBER", "description": "Multiplier for jump height (e.g. 2.0 for double jump height)"},
						"gravity_multiplier": {"type": "NUMBER", "description": "Multiplier for gravity (e.g. 0.5 for floaty, 2.0 for heavy)"},
						"scale_multiplier": {"type": "NUMBER", "description": "Multiplier for character visual size (e.g. 2.0 for double size)"},
						"animation_fps": {"type": "INTEGER", "description": "Frames per second for sprite animations (e.g. 12 for faster animation)"}
					}
				}
			},
			{
				"name": "modify_sprite",
				"description": "Make small visual edits to the existing sprite appearance. Use for tweaks like changing colors, adding accessories (cape, hat), adjusting facial features, or minor design changes that keep the same overall style and layout.",
				"parameters": {
					"type": "OBJECT",
					"properties": {
						"visual_prompt": {"type": "STRING", "description": "Detailed description of the visual modification to apply to the existing sprite"}
					},
					"required": ["visual_prompt"]
				}
			},
			{
				"name": "regenerate_sprite",
				"description": "Fully regenerate the character sprite from scratch with a new style or fundamental design change. Use for bit-depth changes (8-bit to 16-bit), art style overhauls (e.g. 'make it look like Stardew Valley'), perspective changes, or complete redesigns.",
				"parameters": {
					"type": "OBJECT",
					"properties": {
						"new_style": {"type": "STRING", "description": "The new art style to apply (e.g. '16-bit retro pixel art', '8-bit classic pixel art', 'Stardew Valley style')"},
						"regeneration_prompt": {"type": "STRING", "description": "Full description of how the character should look in the new style"}
					},
					"required": ["new_style", "regeneration_prompt"]
				}
			},
			{
				"name": "expand_sprite",
				"description": "Add a NEW animation action to the character (e.g. attack, run, dance, slide, climb) or replace an existing animation with a new version. Generates new sprite frames that match the character's existing art style.",
				"parameters": {
					"type": "OBJECT",
					"properties": {
						"animation_name": {"type": "STRING", "description": "Short name for the animation (e.g. 'attack', 'run', 'dance', 'slide', 'climb')"},
						"animation_description": {"type": "STRING", "description": "Detailed description of what the animation looks like (e.g. 'character swings a sword in a wide arc')"},
						"frame_count": {"type": "INTEGER", "description": "Number of frames for the animation (default 4)"},
						"should_loop": {"type": "BOOLEAN", "description": "Whether the animation should loop (true for run/dance, false for attack/jump)"}
					},
					"required": ["animation_name", "animation_description"]
				}
			}
		]
	}]
	
	var body := {
		"contents": [{
			"parts": [{"text": "You are a game assistant for a pixel art platformer. The user wants to modify their character or game. Determine which tool to use and call it.\n\nUser request: " + text}]
		}],
		"tools": tools,
		"toolConfig": {
			"functionCallingConfig": {
				"mode": "ANY"
			}
		}
	}
	
	var headers := ["Content-Type: application/json"]
	var json_body := JSON.stringify(body)
	
	var err := _http_parse.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		api_error.emit("HTTP request failed: %s" % error_string(err))


## Build an optimized prompt for pixel art sprite generation from structured spec.
func _build_sprite_prompt(spec: Dictionary) -> String:
	var parts: PackedStringArray = []
	parts.append("You are a pixel art sprite sheet generator. Create a character sprite sheet.")
	parts.append("")
	
	# 1. Style & Format
	var style: String = spec.get("style", "32-bit pixel art")
	parts.append("[Style & Format]")
	parts.append("- " + style + " character sprite sheet")
	parts.append("")
	
	# 2. Frame Resolution
	var frame_res: String = spec.get("frame_resolution", "64x64")
	var res_parts := frame_res.split("x")
	var fw := int(res_parts[0]) if res_parts.size() >= 2 else 64
	var fh := int(res_parts[1]) if res_parts.size() >= 2 else 64
	parts.append("[Frame Resolution]")
	parts.append("- Each frame: exactly %dx%d pixels" % [fw, fh])
	parts.append("")
	
	# 3. Perspective & Genre
	var perspective: String = spec.get("perspective", "side-scrolling platformer")
	parts.append("[Perspective & Genre]")
	parts.append("- " + perspective)
	parts.append("")
	
	# 4. Layout & Animation Structure (auto-generated from perspective)
	var persp_lower := perspective.to_lower()
	parts.append("[Sprite Sheet Layout & Animation]")
	
	if "top-down" in persp_lower:
		parts.append("- 4 rows × 4 columns grid (16 frames total)")
		parts.append("- Row 1: Walk DOWN (4 frames)")
		parts.append("- Row 2: Walk LEFT (4 frames)")
		parts.append("- Row 3: Walk RIGHT (4 frames)")
		parts.append("- Row 4: Walk UP (4 frames)")
		parts.append("- First frame of each row is the idle pose for that direction")
	elif "isometric" in persp_lower:
		parts.append("- 4 rows × 4 columns grid (16 frames total)")
		parts.append("- Row 1: Walk South-East (4 frames)")
		parts.append("- Row 2: Walk South-West (4 frames)")
		parts.append("- Row 3: Walk North-East (4 frames)")
		parts.append("- Row 4: Walk North-West (4 frames)")
		parts.append("- First frame of each row is the idle pose for that direction")
	else:
		parts.append("- 1 row × 7 columns (7 frames total, single horizontal strip)")
		parts.append("- Frame 1: Idle pose")
		parts.append("- Frames 2-5: Walk cycle (4 frames)")
		parts.append("- Frames 6-7: Jump (ascending, descending)")
		parts.append("- Character should face RIGHT")
	parts.append("")
	
	# 5. Character Design & Proportions
	var design: String = spec.get("character_design", "cute pixel character")
	parts.append("[Character Design]")
	parts.append("- " + design)
	parts.append("")
	
	# 6. Detailed Requirements
	var details: String = spec.get("details", "")
	if not details.is_empty():
		parts.append("[Detail Requirements]")
		parts.append("- " + details)
		parts.append("")
	
	# Reference image instruction
	var has_ref: bool = spec.get("reference_image", null) != null
	if has_ref:
		parts.append("[Reference Image]")
		parts.append("- Use the provided reference image as the base design for this character.")
		parts.append("- Adapt the character's silhouette, color palette, and proportions from the reference.")
		parts.append("- Apply the specified pixel art style and generate all animation frames based on this reference.")
		parts.append("")
	
	# Universal constraints
	parts.append("[Constraints & Formatting]")
	parts.append("- Background: Fully transparent (alpha channel)")
	parts.append("- No anti-aliasing — keep crisp pixel edges")
	parts.append("- No text overlay on the image")
	parts.append("- CRITICAL: Ensure the canvas is perfectly divided into the grid described above.")
	parts.append("- CRITICAL: Each frame must be exactly the same size.")
	parts.append("- CRITICAL: The character must be centered within each grid cell.")
	parts.append("- Generate ONLY the sprite sheet image")
	
	return "\n".join(parts)


## Parse layout metadata — compute frame size from actual generated image.
func _parse_layout_metadata(spec: Dictionary, image: Image = null) -> Dictionary:
	# Detect perspective
	var perspective: String = spec.get("perspective", "").to_lower()
	var layout: String = spec.get("layout", "").to_lower()
	
	var is_top_down: bool = "top-down" in perspective or "top-down" in layout
	
	# Determine expected grid layout
	var grid_cols: int
	var grid_rows: int
	
	if is_top_down:
		grid_cols = 4  # 4 directions
		grid_rows = 4  # 4 frames per direction
	else:
		grid_cols = 7  # 1 idle + 4 walk + 2 jump
		grid_rows = 1
	
	# Calculate frame size from actual image dimensions
	var fw: int = 64
	var fh: int = 64
	
	print("[GeminiAPI] _parse_layout_metadata — image is %s, type: %s" % [str(image != null), typeof(image)])
	
	if image is Image and image.get_width() > 0 and image.get_height() > 0:
		fw = image.get_width() / grid_cols
		fh = image.get_height() / grid_rows
		print("[GeminiAPI] Calculated frame size from image: %dx%d (grid %dx%d)" % [fw, fh, grid_cols, grid_rows])
	else:
		# Fallback to spec resolution if no image available
		var frame_res: String = spec.get("frame_resolution", "64x64")
		var res_parts := frame_res.split("x")
		fw = int(res_parts[0]) if res_parts.size() >= 2 else 64
		fh = int(res_parts[1]) if res_parts.size() >= 2 else 64
		print("[GeminiAPI] FALLBACK frame size: %dx%d" % [fw, fh])
	
	var frame_dict := {}
	
	if is_top_down:
		frame_dict = {
			"frame_width": fw,
			"frame_height": fh,
			"frame_count": 16,
			"idle_frames": [0, 4, 8, 12],
			"walk_frames": [1, 2, 3, 5, 6, 7, 9, 10, 11, 13, 14, 15],
			"jump_frames": [],
			"fps": 8
		}
	else:
		frame_dict = {
			"frame_width": fw,
			"frame_height": fh,
			"frame_count": 7,
			"idle_frames": [0],
			"walk_frames": [1, 2, 3, 4],
			"jump_frames": [5, 6],
			"fps": 10
		}
	
	return frame_dict


## Extract image from Gemini API response body.
func _extract_image_from_response(body: PackedByteArray) -> Image:
	var json := JSON.new()
	var parse_result := json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		push_error("Failed to parse API response JSON")
		return null
	
	var response: Dictionary = json.data
	if not response.has("candidates"):
		if response.has("error"):
			var error_msg: String = response["error"].get("message", "Unknown error")
			push_error("Gemini API error: " + error_msg)
			api_error.emit(error_msg)
		return null
	
	var candidates: Array = response["candidates"]
	if candidates.is_empty():
		return null
	
	var parts: Array = candidates[0]["content"]["parts"]
	var result_text := ""
	var result_image: Image = null
	
	for part in parts:
		if part.has("text"):
			result_text = part["text"]
		elif part.has("inlineData"):
			var inline_data: Dictionary = part["inlineData"]
			var base64_data: String = inline_data["data"]
			var raw_bytes := Marshalls.base64_to_raw(base64_data)
			
			result_image = Image.new()
			var mime: String = inline_data.get("mimeType", "image/png")
			print("[GeminiAPI] Image MIME type: %s, data size: %d bytes" % [mime, raw_bytes.size()])
			var err: int
			if "png" in mime:
				err = result_image.load_png_from_buffer(raw_bytes)
			elif "jpeg" in mime or "jpg" in mime:
				err = result_image.load_jpg_from_buffer(raw_bytes)
			elif "webp" in mime:
				err = result_image.load_webp_from_buffer(raw_bytes)
			else:
				err = result_image.load_png_from_buffer(raw_bytes)
			
			if err != OK:
				push_error("Failed to load image from response")
				result_image = null
			else:
				# Force convert to RGBA8 to ensure alpha channel exists
				# (JPEG has no alpha → background will be opaque without this)
				if result_image.get_format() != Image.FORMAT_RGBA8:
					print("[GeminiAPI] Converting image from format %d to RGBA8" % result_image.get_format())
					result_image.convert(Image.FORMAT_RGBA8)
	
	return result_image


## Extract text JSON from Gemini response.
func _extract_text_from_response(body: PackedByteArray) -> String:
	var json := JSON.new()
	var parse_result := json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		return ""
	
	var response: Dictionary = json.data
	if not response.has("candidates"):
		if response.has("error"):
			api_error.emit(response["error"].get("message", "Unknown error"))
		return ""
	
	var candidates: Array = response["candidates"]
	if candidates.is_empty():
		return ""
	
	var parts: Array = candidates[0]["content"]["parts"]
	for part in parts:
		if part.has("text"):
			return part["text"]
	return ""


func _on_sprite_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	print("[GeminiAPI] Sprite request completed — result: %d, HTTP: %d, body size: %d bytes" % [result, response_code, body.size()])
	
	# Auto-retry on TLS handshake / connection errors
	if result != HTTPRequest.RESULT_SUCCESS:
		_retry_count += 1
		if _retry_count <= MAX_RETRIES:
			print("[GeminiAPI] ⚠️ Connection error (result %d), retrying %d/%d..." % [result, _retry_count, MAX_RETRIES])
			await get_tree().create_timer(1.0).timeout
			_send_sprite_request(_current_sprite_spec)
			return
		else:
			print("[GeminiAPI] ❌ Max retries reached")
	
	is_generating = false
	generation_finished.emit()
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var error_detail := ""
		if body.size() > 0:
			error_detail = body.get_string_from_utf8().substr(0, 500)
		print("[GeminiAPI] ERROR response: " + error_detail)
		api_error.emit("Sprite generation failed (HTTP %d): %s" % [response_code, error_detail])
		return
	
	var image := _extract_image_from_response(body)
	if image:
		print("[GeminiAPI] ✅ Image extracted: %dx%d" % [image.get_width(), image.get_height()])
		
		# Stage A: Remove background
		image = _remove_background(image)
		print("[GeminiAPI] ✅ Background removal done")
		
		# Stage B: Build base math-based metadata (used as fallback)
		var base_metadata := _parse_layout_metadata(_current_sprite_spec, image)
		
		# Stage C: Flash Vision for precise frame boundary detection
		_pending_analysis_image = image
		_pending_analysis_metadata = base_metadata
		_analyze_frame_bounds(image, base_metadata)
	else:
		print("[GeminiAPI] ❌ Failed to extract image. Response body preview:")
		print(body.get_string_from_utf8().substr(0, 1000))
		api_error.emit("Failed to extract image from response")


## Stage A: Remove image background using corner-pixel chroma key.
func _remove_background(img: Image) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	var bg := _detect_bg_color(img)
	print("[GeminiAPI] BG color detected: R=%.2f G=%.2f B=%.2f" % [bg.r, bg.g, bg.b])
	var w := img.get_width()
	var h := img.get_height()
	for y in range(h):
		for x in range(w):
			var px := img.get_pixel(x, y)
			if _color_similar(px, bg, 0.15):
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return img


## Detect background color from the 4 corner pixels (averaged).
func _detect_bg_color(img: Image) -> Color:
	var w := img.get_width()
	var h := img.get_height()
	var avg := Color(0, 0, 0, 1)
	var corners := [
		img.get_pixel(0, 0),
		img.get_pixel(w - 1, 0),
		img.get_pixel(0, h - 1),
		img.get_pixel(w - 1, h - 1),
	]
	for c in corners:
		avg.r += c.r
		avg.g += c.g
		avg.b += c.b
	avg.r /= 4.0
	avg.g /= 4.0
	avg.b /= 4.0
	return avg


## Returns true if colors are within threshold on all channels.
func _color_similar(a: Color, b: Color, threshold: float) -> bool:
	return abs(a.r - b.r) < threshold and abs(a.g - b.g) < threshold and abs(a.b - b.b) < threshold


## Stage C: Send sprite sheet to Flash Vision to detect exact frame boundaries.
func _analyze_frame_bounds(img: Image, fallback_metadata: Dictionary) -> void:
	var png_bytes := img.save_png_to_buffer()
	var base64_img := Marshalls.raw_to_base64(png_bytes)
	
	var persp: String = _current_sprite_spec.get("perspective", "").to_lower()
	var is_topdown: bool = "top-down" in persp
	
	var grid_desc: String
	if is_topdown:
		grid_desc = "4 rows x 4 columns (row0=DOWN, row1=LEFT, row2=RIGHT, row3=UP)"
	else:
		grid_desc = "1 row x 7 columns (col0=idle, col1-4=walk, col5-6=jump)"
	
	var fw: int = fallback_metadata.get("frame_width", 64)
	var fh: int = fallback_metadata.get("frame_height", 64)
	
	var prompt: String = ("You are analyzing a pixel art sprite sheet image.\n"
		+ "Expected layout: " + grid_desc + "\n"
		+ "The image is " + str(img.get_width()) + "x" + str(img.get_height()) + " pixels.\n"
		+ "Estimated frame size: " + str(fw) + "x" + str(fh) + " pixels.\n\n"
		+ "Carefully identify the exact pixel boundary (x, y, w, h) of each animation frame.\n"
		+ "Each frame should contain exactly ONE character pose with transparent borders.\n"
		+ "Return ONLY valid JSON, no markdown, no explanation:\n"
		+ "{\"frames\":[{\"index\":0,\"x\":0,\"y\":0,\"w\":" + str(fw) + ",\"h\":" + str(fh) + "}],"
		+ "\"grid_cols\":4,\"grid_rows\":4}")
	
	var url := GEMINI_BASE_URL + MODEL_FLASH + ":generateContent?key=" + api_key
	var request_body := {
		"contents": [{
			"parts": [
				{"text": prompt},
				{"inlineData": {"mimeType": "image/png", "data": base64_img}}
			]
		}],
		"generationConfig": {
			"temperature": 0.1, 
			"maxOutputTokens": 2048,
			"responseMimeType": "application/json"
		}
	}
	
	print("[GeminiAPI] Stage C: Flash Vision frame analysis...")
	var err := _http_analyze.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(request_body))
	if err != OK:
		print("[GeminiAPI] ⚠️ Vision analysis HTTP error, using fallback")
		sprite_generated.emit(_pending_analysis_image, fallback_metadata)


## Callback: Flash Vision returned frame boundary JSON.
func _on_analyze_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var fb_meta := _pending_analysis_metadata
	var image := _pending_analysis_image
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("[GeminiAPI] ⚠️ Vision analysis failed (%d / HTTP %d), using math fallback" % [result, response_code])
		if body.size() > 0:
			print("[GeminiAPI] Vision error body: " + body.get_string_from_utf8().substr(0, 500))
		sprite_generated.emit(image, fb_meta)
		return
	
	# Extract JSON from response
	var raw_text := _extract_text_from_response(body)
	raw_text = raw_text.replace("```json", "").replace("```", "").strip_edges()
	
	var jobj := JSON.new()
	if jobj.parse(raw_text) != OK:
		print("[GeminiAPI] ⚠️ Vision JSON parse failed, using fallback. Raw: " + raw_text.substr(0, 200))
		sprite_generated.emit(image, fb_meta)
		return
	
	var analysis: Dictionary = jobj.data
	var frames_data: Array = analysis.get("frames", [])
	
	if frames_data.is_empty():
		print("[GeminiAPI] ⚠️ Vision returned empty frames, using fallback")
		sprite_generated.emit(image, fb_meta)
		return
	
	# Build frame_rects from Vision output
	var frame_rects: Array = []
	for fd in frames_data:
		frame_rects.append({
			"x": int(fd.get("x", 0)),
			"y": int(fd.get("y", 0)),
			"w": int(fd.get("w", fb_meta.get("frame_width", 64))),
			"h": int(fd.get("h", fb_meta.get("frame_height", 64)))
		})
	
	var enhanced_meta := fb_meta.duplicate()
	enhanced_meta["frame_rects"] = frame_rects
	if not frame_rects.is_empty():
		enhanced_meta["frame_width"] = frame_rects[0]["w"]
		enhanced_meta["frame_height"] = frame_rects[0]["h"]
	
	print("[GeminiAPI] ✅ Vision: %d frames detected" % frame_rects.size())
	sprite_generated.emit(image, enhanced_meta)


func _on_modify_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_generating = false
	generation_finished.emit()
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var error_detail := ""
		if body.size() > 0:
			error_detail = body.get_string_from_utf8().substr(0, 200)
		api_error.emit("Sprite modification failed (HTTP %d): %s" % [response_code, error_detail])
		return
	
	var image := _extract_image_from_response(body)
	if image:
		var metadata := {
			"frame_width": 64,
			"frame_height": 64,
			"frame_count": 7,
			"idle_frames": [0],
			"walk_frames": [1, 2, 3, 4],
			"jump_frames": [5, 6],
			"fps": 10
		}
		sprite_modified.emit(image, metadata)
	else:
		api_error.emit("Failed to extract modified image from response")


func _on_parse_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var error_detail := ""
		if body.size() > 0:
			error_detail = body.get_string_from_utf8().substr(0, 200)
		api_error.emit("Command parsing failed (HTTP %d): %s" % [response_code, error_detail])
		return
	
	# Parse the response body
	var response_text := body.get_string_from_utf8()
	var json := JSON.new()
	var parse_result := json.parse(response_text)
	if parse_result != OK:
		api_error.emit("Failed to parse API response")
		return
	
	var response: Dictionary = json.data
	if not response.has("candidates"):
		if response.has("error"):
			var error_msg: String = response["error"].get("message", "Unknown error")
			api_error.emit(error_msg)
		else:
			api_error.emit("No candidates in response")
		return
	
	var candidates: Array = response["candidates"]
	if candidates.is_empty():
		api_error.emit("Empty candidates in response")
		return
	
	var parts: Array = candidates[0]["content"]["parts"]
	
	# Look for functionCall in parts
	for part in parts:
		if part.has("functionCall"):
			var func_call: Dictionary = part["functionCall"]
			var func_name: String = func_call.get("name", "")
			var func_args: Dictionary = func_call.get("args", {})
			
			# Package as Dictionary with _tool_name for routing
			func_args["_tool_name"] = func_name
			command_parsed.emit(func_args)
			return
	
	# Fallback: try to extract text response (shouldn't happen with mode: ANY)
	for part in parts:
		if part.has("text"):
			push_warning("Function calling returned text instead of functionCall: " + part["text"])
	
	api_error.emit("No function call in response")


func _on_expand_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_generating = false
	generation_finished.emit()
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var error_detail := ""
		if body.size() > 0:
			error_detail = body.get_string_from_utf8().substr(0, 200)
		api_error.emit("Animation expansion failed (HTTP %d): %s" % [response_code, error_detail])
		return
	
	var image := _extract_image_from_response(body)
	if image == null:
		api_error.emit("Failed to extract expanded animation image")
		return
	
	# Split the image into individual frames
	var fw: int = _pending_expand_frame_size.x
	var fh: int = _pending_expand_frame_size.y
	var cols := image.get_width() / fw
	var rows := image.get_height() / fh
	var total := cols * rows
	
	var frame_textures: Array = []
	for i in range(total):
		var col := i % cols
		var row := i / cols
		var rect := Rect2i(col * fw, row * fh, fw, fh)
		if rect.position.x + rect.size.x > image.get_width():
			continue
		if rect.position.y + rect.size.y > image.get_height():
			continue
		var frame_img := image.get_region(rect)
		var tex := ImageTexture.create_from_image(frame_img)
		frame_textures.append(tex)
	
	if frame_textures.is_empty():
		api_error.emit("No frames extracted from expanded animation")
		return
	
	sprite_expanded.emit(_pending_expand_name, frame_textures, _pending_expand_fps, _pending_expand_loop)
