## ChatPanel — Right panel for live modification chat during gameplay.
extends PanelContainer

@onready var message_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/MessageContainer
@onready var scroll_container: ScrollContainer = $MarginContainer/VBoxContainer/ScrollContainer
@onready var input_field: LineEdit = $MarginContainer/VBoxContainer/InputContainer/LineEdit
@onready var send_button: Button = $MarginContainer/VBoxContainer/InputContainer/SendButton
@onready var apply_button: Button = $MarginContainer/VBoxContainer/ApplyButton
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel

var _has_pending_changes: bool = false


func _ready() -> void:
	apply_button.visible = false
	status_label.text = ""
	
	send_button.pressed.connect(_on_send_pressed)
	input_field.text_submitted.connect(_on_text_submitted)
	apply_button.pressed.connect(_on_apply_pressed)
	
	GeminiAPI.generation_started.connect(_on_generation_started)
	GeminiAPI.generation_finished.connect(_on_generation_finished)
	GeminiAPI.sprite_modified.connect(_on_sprite_modified)
	GeminiAPI.sprite_expanded.connect(_on_sprite_expanded)
	GeminiAPI.api_error.connect(_on_api_error)
	GeminiAPI.command_parsed.connect(_on_command_parsed)
	GameManager.hot_reload_applied.connect(_on_hot_reload_applied)
	GameManager.state_changed.connect(_on_state_changed)


func _on_send_pressed() -> void:
	_submit_message()


func _on_text_submitted(_text: String) -> void:
	_submit_message()


func _submit_message() -> void:
	var text := input_field.text.strip_edges()
	if text.is_empty():
		return
	
	input_field.text = ""
	_add_user_message(text)
	
	# Send to GameManager for processing
	if GameManager.current_state == GameManager.GameState.PLAYING:
		GameManager.request_modification(text)
	elif GameManager.current_state == GameManager.GameState.MENU:
		_add_system_message("Generate a character first using the left panel!")


func _add_user_message(text: String) -> void:
	var msg := _create_message_label("You", text, Color("8b5cf6"))
	message_container.add_child(msg)
	_scroll_to_bottom()


func _add_system_message(text: String) -> void:
	var msg := _create_message_label("System", text, Color("06b6d4"))
	message_container.add_child(msg)
	_scroll_to_bottom()


func _create_message_label(sender: String, text: String, color: Color) -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.custom_minimum_size = Vector2(0, 0)
	
	rtl.text = "[color=#%s][b]%s:[/b][/color] %s" % [color.to_html(false), sender, text]
	
	# Styling
	rtl.add_theme_font_size_override("normal_font_size", 13)
	rtl.add_theme_color_override("default_color", Color(0.85, 0.85, 0.9))
	
	return rtl


func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value


func _on_generation_started() -> void:
	status_label.text = "✨ Generating..."
	status_label.add_theme_color_override("font_color", Color("fbbf24"))
	input_field.editable = false
	send_button.disabled = true


func _on_generation_finished() -> void:
	input_field.editable = true
	send_button.disabled = false


func _on_sprite_modified(_image: Image, _metadata: Dictionary) -> void:
	status_label.text = "✅ New version ready!"
	status_label.add_theme_color_override("font_color", Color("34d399"))
	apply_button.visible = true
	_has_pending_changes = true
	_add_system_message("New sprite ready! Click 'Apply New Version' to update.")


func _on_command_parsed(params: Dictionary) -> void:
	var tool_name: String = params.get("_tool_name", "")
	
	match tool_name:
		"adjust_parameters":
			status_label.text = "⚡ Parameters updated!"
			status_label.add_theme_color_override("font_color", Color("34d399"))
			_add_system_message("Parameters updated instantly!")
			await get_tree().create_timer(2.0).timeout
			if status_label.text == "⚡ Parameters updated!":
				status_label.text = ""
		"modify_sprite":
			_add_system_message("🎨 Modifying sprite appearance...")
		"regenerate_sprite":
			var new_style: String = params.get("new_style", "new style")
			_add_system_message("🔄 Regenerating character in %s..." % new_style)
		"expand_sprite":
			var anim_name: String = params.get("animation_name", "custom")
			_add_system_message("🎬 Generating '%s' animation..." % anim_name)


func _on_sprite_expanded(anim_name: String, frames: Array, fps: int, loop: bool) -> void:
	var key_index: int = 0
	# Find the key binding index
	var player := get_tree().root.get_node_or_null("MainUI/HSplitContainer/GameViewContainer/SubViewportContainer/SubViewport/GameWorld/Player")
	if player and player.has_method("get") and "_custom_animations" in player:
		var custom_anims: Array = player._custom_animations
		key_index = custom_anims.find(anim_name) + 1
		if key_index == 0:
			key_index = custom_anims.size() + 1
	
	status_label.text = "🎬 Animation added!"
	status_label.add_theme_color_override("font_color", Color("34d399"))
	
	var key_hint := ""
	if key_index > 0 and key_index <= 9:
		key_hint = " Press [%d] to play it!" % key_index
	
	_add_system_message("'%s' animation added (%d frames).%s" % [anim_name, frames.size(), key_hint])
	
	await get_tree().create_timer(3.0).timeout
	if status_label.text == "🎬 Animation added!":
		status_label.text = ""


func _on_apply_pressed() -> void:
	apply_button.visible = false
	_has_pending_changes = false
	status_label.text = "🔄 Applying..."
	GameManager.apply_hot_reload()


func _on_hot_reload_applied() -> void:
	status_label.text = ""
	_add_system_message("Changes applied! Keep playing!")


func _on_api_error(message: String) -> void:
	status_label.text = "❌ Error"
	status_label.add_theme_color_override("font_color", Color("ef4444"))
	_add_system_message("Error: " + message)
	input_field.editable = true
	send_button.disabled = false


func _on_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.PLAYING:
			input_field.placeholder_text = "Type changes... (e.g., 'double jump height')"
			input_field.editable = true
		GameManager.GameState.MODIFYING:
			input_field.placeholder_text = "Generating changes..."
		_:
			input_field.placeholder_text = "Generate a character first..."
