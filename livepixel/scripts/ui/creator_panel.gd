## CreatorPanel — Left panel with reference image upload and structured prompt builder.
## Supports image upload via FileDialog and structured pixel art spec fields.
extends PanelContainer

@onready var prompt_input: TextEdit = $MarginContainer/ScrollContainer/VBoxContainer/PromptInput
@onready var bit_style_button: OptionButton = $MarginContainer/ScrollContainer/VBoxContainer/StyleContainer/BitStyleButton
@onready var frame_res_button: OptionButton = $MarginContainer/ScrollContainer/VBoxContainer/FrameContainer/FrameResButton
@onready var perspective_button: OptionButton = $MarginContainer/ScrollContainer/VBoxContainer/PerspContainer/PerspectiveButton

@onready var details_input: TextEdit = $MarginContainer/ScrollContainer/VBoxContainer/DetailsInput
@onready var generate_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/GenerateButton
@onready var play_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/PlayButton
@onready var preview_texture: TextureRect = $MarginContainer/ScrollContainer/VBoxContainer/PreviewContainer/PreviewTexture
@onready var status_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/CreatorStatus
@onready var ref_image_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/RefImageContainer/RefImageButton
@onready var ref_image_preview: TextureRect = $MarginContainer/ScrollContainer/VBoxContainer/RefImageContainer/RefImagePreview
@onready var ref_clear_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/RefImageContainer/ClearRefButton
@onready var file_dialog: FileDialog = $FileDialog

var _current_image: Image = null
var _current_metadata: Dictionary = {}
var _reference_image: Image = null


func _ready() -> void:
	# Bit style options
	bit_style_button.clear()
	bit_style_button.add_item("32-bit (High)")
	bit_style_button.add_item("16-bit (Retro)")
	bit_style_button.add_item("8-bit (Classic)")
	bit_style_button.selected = 0
	
	# Frame resolution options
	frame_res_button.clear()
	frame_res_button.add_item("64x64")
	frame_res_button.add_item("32x32")
	frame_res_button.add_item("32x48")
	frame_res_button.add_item("48x48")
	frame_res_button.add_item("128x128")
	frame_res_button.selected = 0
	
	# Perspective options
	perspective_button.clear()
	perspective_button.add_item("Side-scroll Platformer")
	perspective_button.add_item("Top-down RPG")
	perspective_button.add_item("Isometric")
	perspective_button.selected = 0
	
	# Default layout

	
	play_button.visible = false
	status_label.text = ""
	ref_image_preview.visible = false
	ref_clear_button.visible = false
	
	# Connect signals
	generate_button.pressed.connect(_on_generate_pressed)
	play_button.pressed.connect(_on_play_pressed)
	ref_image_button.pressed.connect(_on_ref_image_pressed)
	ref_clear_button.pressed.connect(_on_clear_ref_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	
	GeminiAPI.sprite_generated.connect(_on_sprite_generated)
	GeminiAPI.generation_started.connect(_on_generation_started)
	GeminiAPI.generation_finished.connect(_on_generation_finished)
	GeminiAPI.api_error.connect(_on_api_error)
	
	# Default prompt
	prompt_input.text = "Yellow banana character, cute, chibi style"
	prompt_input.placeholder_text = "Describe your character's appearance..."
	
	# FileDialog setup
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.png ; PNG Images", "*.jpg ; JPEG Images", "*.jpeg ; JPEG Images", "*.webp ; WebP Images"])
	file_dialog.title = "Select Reference Image"
	file_dialog.size = Vector2i(600, 400)


func _get_bit_style() -> String:
	match bit_style_button.selected:
		0: return "32-bit pixel art"
		1: return "16-bit retro pixel art"
		2: return "8-bit classic pixel art"
		_: return "32-bit pixel art"


func _get_frame_res() -> String:
	return frame_res_button.get_item_text(frame_res_button.selected)


func _get_perspective() -> String:
	match perspective_button.selected:
		0: return "side-scrolling platformer"
		1: return "top-down RPG style"
		2: return "isometric"
		_: return "side-scrolling platformer"


## Build a structured spec dictionary from all UI fields.
func _build_spec() -> Dictionary:
	var spec := {
		"style": _get_bit_style(),
		"frame_resolution": _get_frame_res(),
		"perspective": _get_perspective(),
		"character_design": prompt_input.text.strip_edges(),
		"details": details_input.text.strip_edges(),
	}
	
	if _reference_image != null:
		spec["reference_image"] = _reference_image
	
	return spec


func _on_generate_pressed() -> void:
	var design_text := prompt_input.text.strip_edges()
	if design_text.is_empty():
		status_label.text = "Please describe your character!"
		return
	
	var spec := _build_spec()
	GameManager.request_character_generation(spec)


func _on_play_pressed() -> void:
	if _current_image == null:
		return
	
	var main_ui := get_tree().root.get_node_or_null("MainUI")
	if main_ui and main_ui.has_method("start_game_with_sprite"):
		main_ui.start_game_with_sprite(_current_image, _current_metadata)


func _on_ref_image_pressed() -> void:
	file_dialog.popup_centered()


func _on_file_selected(path: String) -> void:
	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		status_label.text = "❌ Failed to load image"
		status_label.add_theme_color_override("font_color", Color("ef4444"))
		return
	
	_reference_image = image
	
	# Show preview thumbnail
	var preview := image.duplicate()
	if preview.get_width() > 120 or preview.get_height() > 120:
		preview.resize(120, 120, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(preview)
	ref_image_preview.texture = tex
	ref_image_preview.visible = true
	ref_clear_button.visible = true
	
	status_label.text = "📷 Reference image loaded"
	status_label.add_theme_color_override("font_color", Color("06b6d4"))


func _on_clear_ref_pressed() -> void:
	_reference_image = null
	ref_image_preview.visible = false
	ref_clear_button.visible = false
	ref_image_preview.texture = null
	status_label.text = ""


func _on_generation_started() -> void:
	status_label.text = "✨ Generating sprite..."
	status_label.add_theme_color_override("font_color", Color("fbbf24"))
	generate_button.disabled = true


func _on_generation_finished() -> void:
	generate_button.disabled = false


func _on_sprite_generated(image: Image, metadata: Dictionary) -> void:
	_current_image = image
	_current_metadata = metadata
	
	# Extract the first frame for preview (instead of showing the full sheet)
	var fw: int = metadata.get("frame_width", 64)
	var fh: int = metadata.get("frame_height", 64)
	var preview_img := image.get_region(Rect2i(0, 0, fw, fh))
	
	# Scale up for visibility if the frame is small
	if preview_img.get_width() < 128:
		var scale_up := 128 / preview_img.get_width()
		preview_img.resize(preview_img.get_width() * scale_up, preview_img.get_height() * scale_up, Image.INTERPOLATE_NEAREST)
	
	var tex := ImageTexture.create_from_image(preview_img)
	preview_texture.texture = tex
	preview_texture.visible = true
	print("[CreatorPanel] Preview set: %dx%d (frame 0)" % [preview_img.get_width(), preview_img.get_height()])
	
	play_button.visible = true
	status_label.text = "✅ Sprite ready! Click Play to test."
	status_label.add_theme_color_override("font_color", Color("34d399"))


func _on_api_error(message: String) -> void:
	status_label.text = "❌ " + message.substr(0, 80)
	status_label.add_theme_color_override("font_color", Color("ef4444"))
	generate_button.disabled = false
