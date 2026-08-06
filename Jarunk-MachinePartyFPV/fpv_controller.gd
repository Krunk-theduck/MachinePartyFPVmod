extends Node

const SAVE_PATH := "user://fpv_mod_settings.save"
const RESCAN_IV := 0.5
const SCAN_BUDGET := 8000
const EYE_FORWARD_OFFSET := 0.16  # nudged forward again from 0.1 -- see your chest, not your neck
const EYE_UP_OFFSET := 0.07  # small further nudge up from 0.05
const MOUSE_SENSITIVITY := 0.0025
const SENS_SLIDER_TOP := 6.0
const CONTROLLER_LOOK_DEADZONE := 0.16
const CONTROLLER_LOOK_SPEED := 3.0
const COUNTDOWN_YAW_LIMIT_DEG := 80.0
const PITCH_LIMIT := 1.5533  # ~89 degrees, in radians
const HEAD_HIDE_SCALE := 0.0001  # not exactly 0 -- avoids degenerate zero-scale matrices

const LOBBY_PREVIEW_VIEWPORT_NAME := "LobbyPreviewViewport"
const LOBBY_FPV_YAW_LIMIT_DEG := 80.0  # lobby-only: you can look at most 80° left/right of the default view
const LOBBY_FPV_PITCH_LIMIT_DEG := 75.0
const LOBBY_FPV_MOUSE_SENS := 0.0025  # radians per pixel of mouse motion while held
const LOBBY_FPV_STICK_SPEED := 2.6    # radians/sec at full right-stick deflection
const LOBBY_FPV_FOV := 70.0           # the vanilla lobby cam is a 28° telephoto of the row -- widen it for first person
const LOBBY_FPV_DEFAULT_YAW_DEG := 85.0  # was -95.0; +180 to fix a confirmed flat 180° reversal (see comment above)
const LOBBY_FPV_FALLBACK_SEAT := 1    # Player1 when we can't resolve the local seat (local couch = main player)
const LOBBY_SEARCH_IV := 0.25         # how often to (re)scan for the lobby rig until one is locked on

const LOBBY_UI_HIDE_EXCLUDE_NAMES: Array[StringName] = [&"Loading", &"Reconnect", &"Playlist"]

const CROSSHAIR_RADIUS := 2.0
const CROSSHAIR_ALPHA := 0.55

const DAMAGE_FLASH_HEALTH_PROPERTY: Dictionary = {
	&"ExplodingCollarRacePlayer": "lives",
	&"KnifeAtTheOfficePlayer": "health",
	&"DuckHuntDuckPlayer": "health",
}
const DAMAGE_FLASH_COLOR := Color(0.55, 0.0, 0.0)
const DAMAGE_FLASH_PEAK_ALPHA := 0.6  # bumped up so the "bloody" hit is unmissable
const DAMAGE_FLASH_DECAY := 2.2

const DAMAGE_SHAKE_MAGNITUDE := 0.10  # world units, peak random jitter right after a hit
const DAMAGE_SHAKE_DECAY := 7.0       # faster than DAMAGE_FLASH_DECAY -- a jolt, not a wobble

const ONE_LIFE_OVERLAY_COLOR := Color(0.6, 0.0, 0.0)
const ONE_LIFE_OVERLAY_MIN_ALPHA := 0.30
const ONE_LIFE_OVERLAY_MAX_ALPHA := 0.55
const ONE_LIFE_OVERLAY_PULSE_SPEED := 2.6  # radians/sec into the sine driving the pulse
const ONE_LIFE_OVERLAY_VIGNETTE_START := 0.4
const ONE_LIFE_OVERLAY_VIGNETTE_SOFTNESS := 0.4
const ONE_LIFE_OVERLAY_SHADER_CODE := """
shader_type canvas_item;

uniform vec4 vignette_color : source_color = vec4(0.6, 0.0, 0.0, 1.0);
uniform float vignette_alpha : hint_range(0.0, 1.0) = 0.0;
uniform float vignette_start : hint_range(0.0, 1.5) = 0.4;
uniform float vignette_softness : hint_range(0.01, 2.0) = 0.4;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered) * 2.0;
	float t = clamp((dist - vignette_start) / max(vignette_softness, 0.001), 0.0, 1.0);
	float eased = t * t * (3.0 - 2.0 * t);
	COLOR = vec4(vignette_color.rgb, eased * vignette_alpha);
}
"""


const DEATH_CAM_HAT_SEARCH_RADIUS := 12.0
const HAT_GIB_SCRIPT_PATH := "res://modules/prop_manager/scripts/hat_gib_prop.gd"

const HAT_SEARCH_WINDOW := 2.5

const DEATH_BLACK_HOLD := 0.5
const DEATH_BEHAVIOR_DEFAULT: Dictionary = {"mode": &"stay"}
const DEATH_BEHAVIOR: Dictionary = {
	&"BurnRecyclePlayer":         {"mode": &"corpse", "delay": 0.9, "black_end": true},  # Recycle: anim to the 0.9s stomp, then black -> spectate
	&"ExplodingCollarRacePlayer": {"mode": &"hat",    "delay": 5.0},                     # Minefield: hat view 5s -> spectate
	&"EscalatorPitPlayer":        {"mode": &"corpse", "delay": 2.5},                     # Wrong Way: crush/shred anim -> spectate
	&"ManufactureGunPlayer":      {"mode": &"corpse", "delay": 3.0},                     # Firearm Factory: body drop 3s -> spectate
	&"DiscoDodgePlayer":          {"mode": &"corpse", "delay": 1.6},                     # Stable Footing: 1.5s fall tween -> spectate
	&"KnifeAtTheOfficePlayer":    {"mode": &"stay"},                                     # Inside Job: mutate in FPV, no spectate
	&"TrainRacePlayer":           {"mode": &"black",  "delay": 0.6},                     # Tunnel Hazard: instant vanish -> black -> spectate
	&"DuckHuntDuckPlayer":        {"mode": &"corpse", "delay": 3.0},                     # Duck Hunt: body drop 3s -> spectate
	&"GreenPeaPlayer":            {"mode": &"corpse", "delay": 3.0},                     # Table Manners: body drop 3s -> spectate
	&"DvdRoombaPlayer":           {"mode": &"black",  "delay": 0.6},                     # Lethal Rebound: instant vanish -> black -> spectate
	&"JunkPlatformPlayer":        {"mode": &"corpse", "delay": 1.6},                     # Debris Platform: fall rides down / crush -> black -> spectate
	&"SpineBreakerPlayer":        {"mode": &"corpse", "delay": 4.0},                     # Spine Breaker: ~1s kill anim + 3s floor -> spectate
	&"SmokeBreakPlayer":          {"mode": &"stay"},                                     # Smoke Break: unchanged
	&"ForkliftCertifiedVehicle":  {"mode": &"stay"},                                     # Forklift: unchanged
}

const CAMERA_TUNING_OVERRIDES: Dictionary = {
	&"SmokeBreakPlayer": {"freeze_body": true, "yaw_from_player_body": true, "offset_fixed_to_body": true, "pitch_offset_deg": -6.0, "eye_up_offset": 0.30, "eye_forward_offset": -0.05, "eye_left_offset": 0.32, "yaw_limit_deg": 50.0, "yaw_offset_deg": 90.0, "pitch_down_limit_deg": 40.0},
	&"ForkliftCertifiedVehicle": {"yaw_offset_deg": 180.0, "freeze_body": true, "follow_rig_yaw": true, "eye_up_offset": -0.15, "eye_forward_offset": 0.4, "yaw_limit_deg": 60.0},
	&"BurnRecyclePlayer": {"freeze_body": true, "yaw_limit_deg": 80.0},
	&"GreenPeaPlayer": {"eye_forward_offset": 0.28, "eye_up_offset": -0.02, "freeze_body": true, "yaw_limit_deg": 80.0},
	&"EscalatorPitPlayer": {"eye_forward_offset": 0.30, "eye_up_offset": -0.07},
}

const SMOKE_BREAK_CIGARETTE_EYE_UP := 0.24
const SMOKE_BREAK_CIGARETTE_EYE_BACK := 0.14

const DEATH_CAM_SAFETY_TIME := 60.0

const HEAD_BOB_SMOOTHING := 14.0

const HEAD_TELEPORT_SNAP_DISTANCE := 2.0

const FREE_CURSOR_CLASSES: Array[StringName] = []

const SKIP_ENTIRELY_CLASSES: Array[StringName] = [&"DuckHuntHunterPlayer", &"ChiselGauntletPlayer"]

const MOVEMENT_ROTATE_CLASSES: Array[StringName] = [
	&"ExplodingCollarRacePlayer",
	&"ManufactureGunPlayer",
	&"KnifeAtTheOfficePlayer",
	&"TrainRacePlayer",
	&"ScavangerChairsPlayer",
	&"MemorizePathPlayer",
	&"DiscoDodgePlayer",
	&"CutsceneTestPlayer02",
	&"SpineBreakerPlayer",
	&"DuckHuntDuckPlayer",
	&"DvdRoombaPlayer",
	&"JunkPlatformPlayer",
	&"CutsceneTestPlayer",
]




const DEBRIS_GRAB_RANGE_MULT := 1.5
const DEBRIS_GRAB_RANGE_CLASS: StringName = &"JunkPlatformPlayer"

var enabled: bool = false

var _yaw: float = 0.0
var _pitch: float = 0.0

var _camera: Camera3D
var _orig_camera: Camera3D

var _crosshair_layer: CanvasLayer
var _crosshair: Control

var _damage_flash_rect: ColorRect
var _death_black_rect: ColorRect
var _spectating_released: bool = false
var _damage_flash_property: String = ""
var _damage_flash_last_value: int = 0
var _damage_flash_alpha: float = 0.0

var _damage_shake_magnitude: float = 0.0

var _one_life_overlay: ColorRect
var _one_life_overlay_material: ShaderMaterial
var _one_life_pulse_time: float = 0.0

var _collar_indicator: ColorRect
var _collar_indicator_label: Label

var _smoke_break_cigarette_node: Node3D = null
var _cigarette_bar_bg: ColorRect
var _cigarette_bar_fill: ColorRect

var _debris_grab_collision: CollisionShape3D = null
var _debris_grab_original_shape: Shape3D = null
var _debris_grab_widened: bool = false

var _player: Node = null
var _visuals: Node3D = null
var _skeleton: Skeleton3D = null
var _head_bone_idx: int = -1
var _head_original_scale: Vector3 = Vector3.ONE

var _smoothed_head_pos: Vector3 = Vector3.ZERO
var _snap_head_smoothing: bool = true

var _eye_up_offset: float = EYE_UP_OFFSET
var _eye_forward_offset: float = EYE_FORWARD_OFFSET
var _eye_left_offset: float = 0.0
var _offset_fixed_to_body: bool = false
var _yaw_limit_rad: float = 0.0
var _yaw_lock_center: float = 0.0
var _pitch_down_limit_rad: float = PITCH_LIMIT

var _freeze_body: bool = false
var _follow_rig_yaw: bool = false
var _follow_yaw_base: float = 0.0
var _look_yaw_offset: float = 0.0

var _dying: bool = false
var _dying_timer: float = 0.0
var _dying_anchor: Vector3 = Vector3.ZERO  # last known good camera position; hat search center
var _dying_hat: Node3D = null  # latched-onto hat_gib once the corpse itself is gone, if any
var _dying_hat_search_active: bool = false  # currently retrying within HAT_SEARCH_WINDOW
var _dying_hat_search_time_left: float = 0.0
var _last_hat_scan_total: int = 0
var _last_hat_scan_active: int = 0
var _last_hat_scan_nearest: float = INF
var _death_mode: StringName = &"stay"
var _death_delay: float = 0.0
var _death_black_end: bool = false

var _accum: float = 0.0
var _mouse_captured_by_us: bool = false
var _mouse_blocked_logged: bool = false  # edge-detection for the mouse capture blocked/unblocked debug print
var _last_scan_in_game: bool = false

var _toggle_button: Button = null
var _fpv_sub_section: Control = null  # indented container holding the sensitivity sliders (hidden while FPV off)
var _mouse_sens_slider: HSlider = null
var _controller_sens_slider: HSlider = null
var _lobby_fpv_toggle: Button = null
var _stay_after_drop_toggle: Button = null

var _fpv_settings_button: Button = null
var _fpv_settings_popup: PopupPanel = null

var stay_after_body_drop: bool = false

var lobby_fpv_enabled: bool = false
var _lobby_cam: Camera3D = null  # the lobby SubViewport's Camera3D while we're driving it
var _lobby_cam_orig_xform: Transform3D = Transform3D.IDENTITY  # saved to restore on release
var _lobby_cam_orig_fov: float = 28.2  # saved to restore on release (vanilla lobby cam is telephoto)
var _lobby_cam_override_active: bool = false  # are we currently overriding the lobby camera
var _lobby_yaw: float = 0.0    # look offset from the character's forward facing (held-look)
var _lobby_pitch: float = 0.0
var _lobby_mouse_rel: Vector2 = Vector2.ZERO  # mouse motion accumulated in _input while looking, consumed each frame
var _lobby_character: Node3D = null
var _lobby_skeleton: Skeleton3D = null
var _lobby_head_idx: int = -1
var _lobby_head_orig_scale: Vector3 = Vector3.ONE  # lobby char's head-bone rest scale, restored on release
var _lobby_search_accum: float = 0.0
var _lobby_seat_online_pending: bool = false
var _lobby_logged_seat: int = -1  # last logged resolved Player number (log only on change, no per-frame spam)
var _lobby_looking: bool = false  # is the hold-to-look button currently down (edge-detected for UI hide + mouse capture)
var _lobby_ui_hidden: bool = false
var _lobby_hidden_nodes: Array[Node] = []  # UI CanvasItems we hid while looking, restored on release
var _lobby_pp_node: CanvasItem = null
var _lobby_pp_was_visible: bool = true

var _mouse_sensitivity_mult: float = 1.0
var _controller_sensitivity_mult: float = 1.0

var _was_active: bool = true  # edge-detection for the active->inactive debug print
var _ever_active: bool = false
var _movement_rotate_active: bool = false  # is _player's class in MOVEMENT_ROTATE_CLASSES
var _movement_rotate_logged: bool = false  # one-shot debug print per player-lock
var _movement_base_yaw: float = 0.0

var _player_class_name: StringName = &""

var _forklift_crate_manager: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 4096
	_load_settings()

	_camera = Camera3D.new()
	_camera.name = "FirstPersonCamera"
	_camera.current = false

	_create_crosshair()
	_hook_settings_ui()



func _hook_settings_ui(attempt: int = 0) -> void:
	var pause_menu := get_node_or_null("/root/PauseMenu")
	var vbox: Node = null
	if pause_menu:
		vbox = pause_menu.get_node_or_null("Settings/HBoxContainer/VBoxContainer")

	if vbox == null:
		if attempt >= 20:
			print("[fpv_mod] gave up waiting for PauseMenu settings panel")
			return
		get_tree().create_timer(0.5).timeout.connect(func(): _hook_settings_ui(attempt + 1))
		return

	var checkbox_scene: PackedScene = load("res://modules/user_interface/button/button_with_checkbox/button_with_checkbox.tscn")
	if checkbox_scene == null:
		print("[fpv_mod] could not load button_with_checkbox.tscn")
		return

	var checked_tex: Texture2D = load("res://textures/ui/chebox_button_checked.png") as Texture2D
	var unchecked_tex: Texture2D = load("res://textures/ui/chebox_button_unchecked.png") as Texture2D
	var font: FontFile = load("res://fonts/Terminal F4.ttf") as FontFile

	var fullscreen_btn: Node = vbox.get_node_or_null("FullscreenFakeButton")
	var separator: Node = vbox.get_node_or_null("HSeparator")
	var back_btn: Node = vbox.get_node_or_null("Button")

	var section_label := Label.new()
	section_label.name = "FirstPersonViewSectionLabel"
	section_label.text = "MODS"
	if font:
		section_label.add_theme_font_override("font", font)
	section_label.add_theme_font_size_override("font_size", 16)
	section_label.modulate = Color(1.0, 1.0, 1.0, 0.55)
	vbox.add_child(section_label)
	if separator:
		vbox.move_child(section_label, separator.get_index())

	if back_btn:
		_fpv_settings_button = back_btn.duplicate() as Button
	else:
		_fpv_settings_button = Button.new()
	_fpv_settings_button.name = "FirstPersonViewSettingsButton"
	_fpv_settings_button.text = "FPV Settings"
	if font:
		_fpv_settings_button.set("font_override", font)
	vbox.add_child(_fpv_settings_button)
	if separator:
		vbox.move_child(_fpv_settings_button, section_label.get_index() + 1)

	if fullscreen_btn:
		_fpv_settings_button.set("focus_neighbor_top", fullscreen_btn.get_path())
		fullscreen_btn.set("focus_neighbor_bottom", _fpv_settings_button.get_path())
	if back_btn:
		_fpv_settings_button.set("focus_neighbor_bottom", back_btn.get_path())
		back_btn.set("focus_neighbor_top", _fpv_settings_button.get_path())

	_fpv_settings_popup = PopupPanel.new()
	_fpv_settings_popup.name = "FirstPersonViewSettingsPopup"
	_fpv_settings_popup.size = Vector2i(440, 460)
	_fpv_settings_popup.visible = false  # explicit: a freshly created Window can default to visible
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	popup_style.border_color = Color(0.25, 0.85, 0.35, 1.0)
	popup_style.set_border_width_all(2)
	popup_style.set_corner_radius_all(0)
	popup_style.set_content_margin_all(0)  # margins handled by popup_margin below instead
	_fpv_settings_popup.add_theme_stylebox_override("panel", popup_style)
	get_tree().root.add_child(_fpv_settings_popup)
	_fpv_settings_button.pressed.connect(func(): _fpv_settings_popup.popup_centered())

	var popup_margin := MarginContainer.new()
	popup_margin.name = "FirstPersonViewSettingsPopupMargin"
	popup_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		popup_margin.add_theme_constant_override(side, 18)
	_fpv_settings_popup.add_child(popup_margin)

	var popup_vbox := VBoxContainer.new()
	popup_vbox.name = "FirstPersonViewSettingsPopupVBox"
	popup_vbox.add_theme_constant_override("separation", 8)
	popup_margin.add_child(popup_vbox)

	var popup_title := Label.new()
	popup_title.name = "FirstPersonViewSettingsPopupTitle"
	popup_title.text = "First Person View Settings"
	if font:
		popup_title.add_theme_font_override("font", font)
	popup_title.add_theme_font_size_override("font_size", 22)
	popup_vbox.add_child(popup_title)
	popup_vbox.add_child(HSeparator.new())

	_toggle_button = checkbox_scene.instantiate() as Button
	_toggle_button.name = "FirstPersonViewToggle"
	_toggle_button.button_text = "First Person View"
	if checked_tex:
		_toggle_button.set("checked_texture", checked_tex)
	if unchecked_tex:
		_toggle_button.set("unchecked_texture", unchecked_tex)
	if font:
		_toggle_button.set("font_override", font)
	_toggle_button.set("checked", enabled)
	popup_vbox.add_child(_toggle_button)
	if _toggle_button.has_signal("checkbox_toggled"):
		_toggle_button.connect("checkbox_toggled", func(): set_enabled(bool(_toggle_button.get("checked"))))

	var sub_section := MarginContainer.new()
	sub_section.name = "FirstPersonSubSection"
	sub_section.add_theme_constant_override("margin_left", 24)
	_fpv_sub_section = sub_section
	var sub_vbox := VBoxContainer.new()
	sub_vbox.name = "FirstPersonSubSectionVBox"
	sub_section.add_child(sub_vbox)

	if checkbox_scene:
		_lobby_fpv_toggle = checkbox_scene.instantiate() as Button
		_lobby_fpv_toggle.name = "LobbyFpvToggle"
		_lobby_fpv_toggle.button_text = "Lobby FPV"
		if checked_tex:
			_lobby_fpv_toggle.set("checked_texture", checked_tex)
		if unchecked_tex:
			_lobby_fpv_toggle.set("unchecked_texture", unchecked_tex)
		if font:
			_lobby_fpv_toggle.set("font_override", font)
		_lobby_fpv_toggle.set("checked", lobby_fpv_enabled)
		sub_vbox.add_child(_lobby_fpv_toggle)
		if _lobby_fpv_toggle.has_signal("checkbox_toggled"):
			_lobby_fpv_toggle.connect("checkbox_toggled",
				func(): set_lobby_fpv_enabled(bool(_lobby_fpv_toggle.get("checked"))))
		var lobby_hint := Label.new()
		lobby_hint.name = "LobbyFpvHint"
		lobby_hint.text = "hold Shift (keyboard) / LB (controller) to look"
		if font:
			lobby_hint.add_theme_font_override("font", font)
		lobby_hint.add_theme_font_size_override("font_size", 16)
		lobby_hint.modulate = Color(1.0, 1.0, 1.0, 0.55)
		sub_vbox.add_child(lobby_hint)

	if checkbox_scene:
		_stay_after_drop_toggle = checkbox_scene.instantiate() as Button
		_stay_after_drop_toggle.name = "StayAfterBodyDropToggle"
		_stay_after_drop_toggle.button_text = "Stay After Body Drop"
		if checked_tex:
			_stay_after_drop_toggle.set("checked_texture", checked_tex)
		if unchecked_tex:
			_stay_after_drop_toggle.set("unchecked_texture", unchecked_tex)
		if font:
			_stay_after_drop_toggle.set("font_override", font)
		_stay_after_drop_toggle.set("checked", stay_after_body_drop)
		sub_vbox.add_child(_stay_after_drop_toggle)
		if _stay_after_drop_toggle.has_signal("checkbox_toggled"):
			_stay_after_drop_toggle.connect("checkbox_toggled",
				func(): set_stay_after_body_drop(bool(_stay_after_drop_toggle.get("checked"))))
		var stay_hint := Label.new()
		stay_hint.name = "StayAfterBodyDropHint"
		stay_hint.text = "stay on your body instead of cutting to spectate"
		if font:
			stay_hint.add_theme_font_override("font", font)
		stay_hint.add_theme_font_size_override("font_size", 16)
		stay_hint.modulate = Color(1.0, 1.0, 1.0, 0.55)
		sub_vbox.add_child(stay_hint)

	_mouse_sens_slider = _add_sensitivity_slider(
		sub_vbox, font, "Mouse Sensitivity", "MouseSensitivitySlider",
		_mouse_sensitivity_mult, "_on_mouse_sens_slider_changed")
	_controller_sens_slider = _add_sensitivity_slider(
		sub_vbox, font, "Controller Sensitivity", "ControllerSensitivitySlider",
		_controller_sensitivity_mult, "_on_controller_sens_slider_changed")

	popup_vbox.add_child(sub_section)
	sub_section.visible = enabled

	popup_vbox.add_child(HSeparator.new())
	var close_btn: Button
	if back_btn:
		close_btn = back_btn.duplicate() as Button
	else:
		close_btn = Button.new()
	close_btn.name = "FirstPersonViewSettingsPopupClose"
	close_btn.text = "Close"
	if font:
		close_btn.set("font_override", font)
	close_btn.pressed.connect(func(): _fpv_settings_popup.hide())
	popup_vbox.add_child(close_btn)

	if pause_menu.has_signal("unpaused"):
		pause_menu.connect("unpaused", Callable(self, "_on_pause_closed"))
		pause_menu.connect("unpaused", func():
			if _fpv_settings_popup and is_instance_valid(_fpv_settings_popup):
				_fpv_settings_popup.hide())

	print("[fpv_mod] settings section + FPV settings popup installed")


func _add_sensitivity_slider(parent: Node, font: Variant, label_text: String,
		slider_name: String, mult: float, handler: String) -> HSlider:
	var label := Label.new()
	label.text = label_text
	if font:
		label.add_theme_font_override("font", font)
	parent.add_child(label)
	var slider := HSlider.new()
	slider.name = slider_name
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = _sens_mult_to_pos(mult)
	slider.custom_minimum_size = Vector2(0, 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.connect("value_changed", Callable(self, handler))
	parent.add_child(slider)
	return slider


func _sens_pos_to_mult(pos: float) -> float:
	return pow(SENS_SLIDER_TOP, 2.0 * clampf(pos, 0.0, 1.0) - 1.0)


func _sens_mult_to_pos(mult: float) -> float:
	if mult <= 0.0:
		return 0.5
	return clampf((log(mult) / log(SENS_SLIDER_TOP) + 1.0) * 0.5, 0.0, 1.0)


func _on_mouse_sens_slider_changed(pos: float) -> void:
	_mouse_sensitivity_mult = _sens_pos_to_mult(pos)
	_save_settings()


func _on_controller_sens_slider_changed(pos: float) -> void:
	_controller_sensitivity_mult = _sens_pos_to_mult(pos)
	_save_settings()



func set_lobby_fpv_enabled(value: bool) -> void:
	if value == lobby_fpv_enabled:
		return
	lobby_fpv_enabled = value
	if not lobby_fpv_enabled:
		_restore_lobby_camera()
	_save_settings()


func set_stay_after_body_drop(value: bool) -> void:
	if value == stay_after_body_drop:
		return
	stay_after_body_drop = value
	_save_settings()


func _process_lobby_fpv(delta: float) -> bool:
	if not lobby_fpv_enabled:
		_restore_lobby_camera()
		return false

	var gm := get_node_or_null("/root/GameManager")
	if gm == null or bool(gm.get("in_game")):
		_restore_lobby_camera()
		return false

	if not _lobby_refs_valid():
		_lobby_search_accum += delta
		if _lobby_search_accum < LOBBY_SEARCH_IV and not _lobby_cam_override_active:
			return false
		_lobby_search_accum = 0.0
		var refs := _find_lobby_refs()
		if refs.is_empty():
			_restore_lobby_camera()
			return false
		var cam: Camera3D = refs["camera"]
		if not _lobby_cam_override_active or cam != _lobby_cam:
			_restore_lobby_camera()  # in case a different camera was held before
			_lobby_cam = cam
			_lobby_cam_orig_xform = cam.transform
			_lobby_cam_orig_fov = cam.fov
			cam.fov = LOBBY_FPV_FOV
			_lobby_cam_override_active = true
			_lobby_yaw = 0.0
			_lobby_pitch = 0.0
			_lobby_mouse_rel = Vector2.ZERO
			if _mouse_captured_by_us:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_mouse_captured_by_us = false
			print("[fpv_mod] lobby FPV engaged on ", cam.get_path())
		var new_skel: Skeleton3D = refs["skeleton"]
		var new_head: int = int(refs["head_idx"])
		if new_skel != _lobby_skeleton or new_head != _lobby_head_idx:
			_restore_lobby_head()
			_lobby_head_orig_scale = new_skel.get_bone_pose_scale(new_head)
		_lobby_character = refs["character"]
		_lobby_skeleton = new_skel
		_lobby_head_idx = new_head
		if _lobby_pp_node == null or not is_instance_valid(_lobby_pp_node):
			var pp := _find_node_named(get_tree().root, "post processing", [SCAN_BUDGET])
			if pp is CanvasItem:
				_lobby_pp_node = pp
				_lobby_pp_was_visible = (pp as CanvasItem).visible
				(pp as CanvasItem).visible = false

	if _camera != null and _camera.get_parent() != null:
		_set_fpv_camera_active(false)

	if _lobby_pp_node == null or not is_instance_valid(_lobby_pp_node):
		var pp2 := _find_node_named(get_tree().root, "post processing", [SCAN_BUDGET])
		if pp2 is CanvasItem:
			_lobby_pp_node = pp2
			_lobby_pp_was_visible = (pp2 as CanvasItem).visible
	if _lobby_pp_node != null and is_instance_valid(_lobby_pp_node) and _lobby_pp_node.visible:
		_lobby_pp_node.visible = false

	var skeleton: Skeleton3D = _lobby_skeleton
	var head_idx: int = _lobby_head_idx
	var cam2: Camera3D = _lobby_cam

	var looking := _lobby_look_held()
	if looking and not _lobby_looking:
		_set_lobby_ui_hidden(true)
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif not looking and _lobby_looking:
		_set_lobby_ui_hidden(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_lobby_looking = looking

	var yaw_limit: float = deg_to_rad(LOBBY_FPV_YAW_LIMIT_DEG)
	var pitch_limit: float = deg_to_rad(LOBBY_FPV_PITCH_LIMIT_DEG)
	if looking:
		_lobby_yaw -= _lobby_mouse_rel.x * LOBBY_FPV_MOUSE_SENS
		_lobby_pitch -= _lobby_mouse_rel.y * LOBBY_FPV_MOUSE_SENS
		var stick := _lobby_stick_vector()
		_lobby_yaw -= stick.x * LOBBY_FPV_STICK_SPEED * delta
		_lobby_pitch -= stick.y * LOBBY_FPV_STICK_SPEED * delta
		_lobby_yaw = clampf(_lobby_yaw, -yaw_limit, yaw_limit)
		_lobby_pitch = clampf(_lobby_pitch, -pitch_limit, pitch_limit)
	_lobby_mouse_rel = Vector2.ZERO

	var head_xform: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(head_idx)
	skeleton.set_bone_pose_scale(head_idx, Vector3.ONE * HEAD_HIDE_SCALE)
	var view_yaw: float = skeleton.global_rotation.y + deg_to_rad(LOBBY_FPV_DEFAULT_YAW_DEG) + _lobby_yaw
	var eye_basis: Basis = Basis(Vector3.UP, view_yaw) * Basis(Vector3.RIGHT, _lobby_pitch)
	var flat_forward: Vector3 = Basis(Vector3.UP, view_yaw) * Vector3(0, 0, -1)
	var eye_pos: Vector3 = head_xform.origin \
		+ flat_forward * EYE_FORWARD_OFFSET \
		+ Vector3.UP * EYE_UP_OFFSET
	cam2.global_transform = Transform3D(eye_basis, eye_pos)
	return true


func _restore_lobby_camera() -> void:
	if not _lobby_cam_override_active:
		_lobby_character = null
		_lobby_skeleton = null
		_lobby_head_idx = -1
		return
	if _lobby_cam and is_instance_valid(_lobby_cam):
		_lobby_cam.transform = _lobby_cam_orig_xform
		_lobby_cam.fov = _lobby_cam_orig_fov
	_restore_lobby_head()  # un-shrink the character's head before we let go
	if _lobby_pp_node != null and is_instance_valid(_lobby_pp_node):
		_lobby_pp_node.visible = _lobby_pp_was_visible
	_lobby_pp_node = null
	if _lobby_looking or _lobby_ui_hidden:
		_set_lobby_ui_hidden(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_lobby_looking = false
	_lobby_cam = null
	_lobby_cam_override_active = false
	_lobby_character = null
	_lobby_skeleton = null
	_lobby_head_idx = -1
	_lobby_seat_online_pending = false
	_lobby_logged_seat = -1
	_lobby_yaw = 0.0
	_lobby_pitch = 0.0
	_lobby_mouse_rel = Vector2.ZERO


func _restore_lobby_head() -> void:
	if _lobby_skeleton != null and is_instance_valid(_lobby_skeleton) and _lobby_head_idx >= 0:
		_lobby_skeleton.set_bone_pose_scale(_lobby_head_idx, _lobby_head_orig_scale)


func _set_lobby_ui_hidden(hidden: bool) -> void:
	if hidden:
		if _lobby_ui_hidden:
			return
		_lobby_hidden_nodes.clear()
		var tree := get_tree()
		if tree == null or tree.root == null:
			return
		var disp: CanvasItem = _find_lobby_display_node(tree.root, [SCAN_BUDGET])
		if disp == null:
			return
		var cur: Node = disp
		while cur != null and cur.get_parent() != null and cur.get_parent() != tree.root:
			var parent := cur.get_parent()
			for sib in parent.get_children():
				if LOBBY_UI_HIDE_EXCLUDE_NAMES.has(StringName(sib.name)):
					continue
				if sib != cur and sib is CanvasItem and (sib as CanvasItem).visible:
					(sib as CanvasItem).visible = false
					_lobby_hidden_nodes.append(sib)
			cur = parent
		_lobby_ui_hidden = true
	else:
		if not _lobby_ui_hidden:
			return
		for n in _lobby_hidden_nodes:
			if is_instance_valid(n) and n is CanvasItem:
				(n as CanvasItem).visible = true
		_lobby_hidden_nodes.clear()
		_lobby_ui_hidden = false


func _find_lobby_display_node(root: Node, budget: Array) -> CanvasItem:
	if budget[0] <= 0:
		return null
	budget[0] -= 1
	if root is TextureRect and (root as TextureRect).texture is ViewportTexture:
		return root
	for ch in root.get_children():
		var f := _find_lobby_display_node(ch, budget)
		if f:
			return f
	return null


func _lobby_refs_valid() -> bool:
	if _lobby_seat_online_pending:
		return false
	return (_lobby_cam_override_active
		and _lobby_cam != null and is_instance_valid(_lobby_cam) and _lobby_cam.is_inside_tree()
		and _lobby_skeleton != null and is_instance_valid(_lobby_skeleton) and _lobby_skeleton.is_inside_tree()
		and _lobby_character != null and is_instance_valid(_lobby_character)
		and _lobby_head_idx >= 0)


func _lobby_look_held() -> bool:
	if Input.is_key_pressed(KEY_SHIFT):
		return true
	var dev := _look_joypad_device()
	if dev >= 0 and Input.is_joy_button_pressed(dev, JOY_BUTTON_LEFT_SHOULDER):
		return true
	return false


func _lobby_stick_vector() -> Vector2:
	var dev := _look_joypad_device()
	if dev < 0:
		return Vector2.ZERO
	var v := Vector2(
		Input.get_joy_axis(dev, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(dev, JOY_AXIS_RIGHT_Y))
	if v.length() < CONTROLLER_LOOK_DEADZONE:
		return Vector2.ZERO
	return v


func _find_lobby_refs() -> Dictionary:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return {}
	var preview: Node = _find_node_named(tree.root, LOBBY_PREVIEW_VIEWPORT_NAME, [SCAN_BUDGET])
	if preview == null:
		return {}
	var viewport := preview.get_node_or_null("LobbyViewport")
	if viewport == null:
		return {}
	var cam := viewport.get_node_or_null("Camera3D")
	var players := viewport.get_node_or_null("Players")
	if not (cam is Camera3D) or players == null:
		return {}

	var seat := _local_lobby_seat(preview)
	var order: Array[int] = [seat, LOBBY_FPV_FALLBACK_SEAT, 1, 2, 3, 4]
	for n in order:
		var pnode := players.get_node_or_null("Player" + str(n))
		if not (pnode is Node3D):
			continue
		var skel := _first_skeleton_with_head(pnode, [SCAN_BUDGET])
		if skel == null:
			continue
		var head_idx: int = (skel as Skeleton3D).find_bone("head")
		if head_idx < 0:
			continue
		return {
			"camera": cam,
			"character": pnode,
			"skeleton": skel,
			"head_idx": head_idx,
		}
	return {}


func _local_lobby_seat(preview: Node) -> int:
	_lobby_seat_online_pending = false
	var result: int = LOBBY_FPV_FALLBACK_SEAT
	var detail: String = "no seat map (local/couch) -> fallback Player1"
	if multiplayer and multiplayer.has_multiplayer_peer():
		var my_id: int = multiplayer.get_unique_id()
		var n: Node = preview
		while n != null:
			var order = n.get("player_order_by_seat")
			if typeof(order) == TYPE_DICTIONARY:
				var found: bool = false
				for key in order.keys():
					if int(order[key]) == my_id:
						result = int(key) + 1  # seat 0 -> Player1
						detail = "id " + str(my_id) + " -> seat " + str(key) + " (Player" + str(result) + ")"
						found = true
						break
				if not found:
					_lobby_seat_online_pending = true
					detail = "id " + str(my_id) + " NOT in seat map " + str(order) + " yet -- waiting (fallback Player1)"
				break
			n = n.get_parent()
	if result != _lobby_logged_seat:
		_lobby_logged_seat = result
		print("[fpv_mod] lobby FPV seat: ", detail)
	return result


func _first_skeleton_with_head(root: Node, budget: Array) -> Skeleton3D:
	if budget[0] <= 0:
		return null
	budget[0] -= 1
	if root is Skeleton3D and (root as Skeleton3D).find_bone("head") >= 0:
		return root
	for ch in root.get_children():
		var found := _first_skeleton_with_head(ch, budget)
		if found:
			return found
	return null


func _find_node_named(root: Node, target: String, budget: Array) -> Node:
	if budget[0] <= 0:
		return null
	budget[0] -= 1
	if root.name == target:
		return root
	for ch in root.get_children():
		var found := _find_node_named(ch, target, budget)
		if found:
			return found
	return null



func set_enabled(value: bool) -> void:
	if value == enabled:
		return
	enabled = value

	if _fpv_sub_section and is_instance_valid(_fpv_sub_section):
		_fpv_sub_section.visible = enabled

	if enabled:
		var vp_cam := get_viewport().get_camera_3d()
		if vp_cam and vp_cam != _camera:
			_orig_camera = vp_cam
			_sync_cull_mask_from(vp_cam)
	else:
		_deactivate()

	_save_settings()


func _deactivate() -> void:
	_restore_camera_or_fallback()
	_orig_camera = null

	if _mouse_captured_by_us:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_mouse_captured_by_us = false

	_restore_head()
	_restore_debris_grab_range()
	_debris_grab_collision = null
	_debris_grab_original_shape = null

	_player = null
	_visuals = null
	_skeleton = null
	_head_bone_idx = -1
	_damage_flash_property = ""
	_damage_flash_alpha = 0.0
	_damage_shake_magnitude = 0.0
	if _damage_flash_rect:
		_damage_flash_rect.color = Color(DAMAGE_FLASH_COLOR.r, DAMAGE_FLASH_COLOR.g, DAMAGE_FLASH_COLOR.b, 0.0)
	_hide_class_specific_hud()
	_smoke_break_cigarette_node = null
	_forklift_crate_manager = null


func _restore_head() -> void:
	if _skeleton and is_instance_valid(_skeleton) and _head_bone_idx >= 0:
		_skeleton.set_bone_pose_scale(_head_bone_idx, _head_original_scale)


func _apply_debris_grab_range() -> void:
	if _debris_grab_widened or _debris_grab_collision == null or not is_instance_valid(_debris_grab_collision):
		return
	var original := _debris_grab_collision.shape
	if original == null:
		return
	_debris_grab_original_shape = original
	var widened: Shape3D = original.duplicate() as Shape3D
	if widened is CylinderShape3D:
		var s := widened as CylinderShape3D
		s.radius *= DEBRIS_GRAB_RANGE_MULT
		s.height *= DEBRIS_GRAB_RANGE_MULT
	elif widened is SphereShape3D:
		(widened as SphereShape3D).radius *= DEBRIS_GRAB_RANGE_MULT
	elif widened is CapsuleShape3D:
		var s := widened as CapsuleShape3D
		s.radius *= DEBRIS_GRAB_RANGE_MULT
		s.height *= DEBRIS_GRAB_RANGE_MULT
	elif widened is BoxShape3D:
		(widened as BoxShape3D).size *= DEBRIS_GRAB_RANGE_MULT
	else:
		return  # unrecognized shape type -- leave vanilla's own range alone rather than guess
	_debris_grab_collision.shape = widened
	_debris_grab_widened = true


func _restore_debris_grab_range() -> void:
	if not _debris_grab_widened:
		return
	if _debris_grab_collision and is_instance_valid(_debris_grab_collision) and _debris_grab_original_shape:
		_debris_grab_collision.shape = _debris_grab_original_shape
	_debris_grab_widened = false


func _sync_cull_mask_from(source_camera: Camera3D) -> void:
	_camera.cull_mask = source_camera.cull_mask


func _create_crosshair() -> void:
	_crosshair_layer = CanvasLayer.new()
	_crosshair_layer.name = "FirstPersonViewCrosshairLayer"
	_crosshair_layer.layer = 50
	get_tree().root.add_child(_crosshair_layer)

	_crosshair = Control.new()
	_crosshair.name = "FirstPersonViewCrosshair"
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.visible = false
	_crosshair.draw.connect(_draw_crosshair)
	_crosshair.resized.connect(_crosshair.queue_redraw)
	_crosshair_layer.add_child(_crosshair)

	_damage_flash_rect = ColorRect.new()
	_damage_flash_rect.name = "FirstPersonViewDamageFlash"
	_damage_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_flash_rect.color = Color(DAMAGE_FLASH_COLOR.r, DAMAGE_FLASH_COLOR.g, DAMAGE_FLASH_COLOR.b, 0.0)
	_crosshair_layer.add_child(_damage_flash_rect)

	var vignette_shader := Shader.new()
	vignette_shader.code = ONE_LIFE_OVERLAY_SHADER_CODE
	_one_life_overlay_material = ShaderMaterial.new()
	_one_life_overlay_material.shader = vignette_shader
	_one_life_overlay_material.set_shader_parameter("vignette_color", ONE_LIFE_OVERLAY_COLOR)
	_one_life_overlay_material.set_shader_parameter("vignette_alpha", 0.0)
	_one_life_overlay_material.set_shader_parameter("vignette_start", ONE_LIFE_OVERLAY_VIGNETTE_START)
	_one_life_overlay_material.set_shader_parameter("vignette_softness", ONE_LIFE_OVERLAY_VIGNETTE_SOFTNESS)

	_one_life_overlay = ColorRect.new()
	_one_life_overlay.name = "FirstPersonViewOneLifeOverlay"
	_one_life_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_one_life_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_one_life_overlay.color = Color(1, 1, 1, 1)  # irrelevant -- the shader's fragment() writes COLOR directly
	_one_life_overlay.material = _one_life_overlay_material
	_one_life_overlay.visible = false
	_crosshair_layer.add_child(_one_life_overlay)

	_collar_indicator_label = Label.new()
	_collar_indicator_label.name = "FirstPersonViewCollarLabel"
	_collar_indicator_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collar_indicator_label.text = "COLLAR"
	_collar_indicator_label.add_theme_font_size_override("font_size", 14)
	_collar_indicator_label.modulate = Color(1.0, 1.0, 1.0, 0.7)
	_collar_indicator_label.position = Vector2(20, 16)
	_collar_indicator_label.visible = false
	_crosshair_layer.add_child(_collar_indicator_label)

	_collar_indicator = ColorRect.new()
	_collar_indicator.name = "FirstPersonViewCollarIndicator"
	_collar_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collar_indicator.position = Vector2(20, 36)
	_collar_indicator.size = Vector2(28, 28)
	_collar_indicator.color = Color(0, 1, 0, 1)
	_collar_indicator.visible = false
	_crosshair_layer.add_child(_collar_indicator)

	_cigarette_bar_bg = ColorRect.new()
	_cigarette_bar_bg.name = "FirstPersonViewCigaretteBarBg"
	_cigarette_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cigarette_bar_bg.color = Color(0.0, 0.0, 0.0, 0.5)
	_cigarette_bar_bg.anchor_left = 0.5
	_cigarette_bar_bg.anchor_right = 0.5
	_cigarette_bar_bg.anchor_top = 1.0
	_cigarette_bar_bg.anchor_bottom = 1.0
	_cigarette_bar_bg.offset_left = -80
	_cigarette_bar_bg.offset_right = 80
	_cigarette_bar_bg.offset_top = -34
	_cigarette_bar_bg.offset_bottom = -24
	_cigarette_bar_bg.visible = false
	_crosshair_layer.add_child(_cigarette_bar_bg)

	_cigarette_bar_fill = ColorRect.new()
	_cigarette_bar_fill.name = "FirstPersonViewCigaretteBarFill"
	_cigarette_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cigarette_bar_fill.color = Color(0.85, 0.7, 0.55, 0.9)  # pale cigarette-paper tan
	_cigarette_bar_fill.anchor_left = 0.5
	_cigarette_bar_fill.anchor_right = 0.5
	_cigarette_bar_fill.anchor_top = 1.0
	_cigarette_bar_fill.anchor_bottom = 1.0
	_cigarette_bar_fill.offset_left = -78
	_cigarette_bar_fill.offset_right = 78  # rescaled from the left edge each frame -- see _update_smoke_break_hud
	_cigarette_bar_fill.offset_top = -32
	_cigarette_bar_fill.offset_bottom = -26
	_cigarette_bar_fill.visible = false
	_crosshair_layer.add_child(_cigarette_bar_fill)

	_death_black_rect = ColorRect.new()
	_death_black_rect.name = "FirstPersonViewDeathBlack"
	_death_black_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_black_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_crosshair_layer.add_child(_death_black_rect)


func _draw_crosshair() -> void:
	_crosshair.draw_circle(_crosshair.size * 0.5, CROSSHAIR_RADIUS, Color(1.0, 1.0, 1.0, CROSSHAIR_ALPHA))


func _update_damage_flash(delta: float) -> void:
	if _damage_flash_property != "" and _player and is_instance_valid(_player) and _damage_flash_property in _player:
		var current: int = int(_player.get(_damage_flash_property))
		if current < _damage_flash_last_value:
			_damage_flash_alpha = DAMAGE_FLASH_PEAK_ALPHA
			_damage_shake_magnitude = DAMAGE_SHAKE_MAGNITUDE
			print("[fpv_mod] damage flash: ", _damage_flash_property, " ",
				_damage_flash_last_value, " -> ", current)
		_damage_flash_last_value = current

	if _damage_flash_alpha > 0.0:
		_damage_flash_alpha *= exp(-delta * DAMAGE_FLASH_DECAY)
		if _damage_flash_alpha < 0.01:  # snap the exponential's long tail to exactly 0
			_damage_flash_alpha = 0.0
		_damage_flash_rect.color = Color(DAMAGE_FLASH_COLOR.r, DAMAGE_FLASH_COLOR.g,
			DAMAGE_FLASH_COLOR.b, _damage_flash_alpha)

	if _damage_shake_magnitude > 0.0:
		_damage_shake_magnitude *= exp(-delta * DAMAGE_SHAKE_DECAY)
		if _damage_shake_magnitude < 0.002:
			_damage_shake_magnitude = 0.0

	_update_one_life_overlay(delta)


func _update_one_life_overlay(delta: float) -> void:
	var show: bool = (_damage_flash_property != "" and _damage_flash_last_value == 1)
	_one_life_overlay.visible = show
	if not show:
		return
	_one_life_pulse_time += delta * ONE_LIFE_OVERLAY_PULSE_SPEED
	var t: float = (sin(_one_life_pulse_time) + 1.0) * 0.5  # 0..1
	var alpha: float = lerp(ONE_LIFE_OVERLAY_MIN_ALPHA, ONE_LIFE_OVERLAY_MAX_ALPHA, t)
	_one_life_overlay_material.set_shader_parameter("vignette_alpha", alpha)


func _compute_damage_shake_offset() -> Vector3:
	if _damage_shake_magnitude <= 0.0:
		return Vector3.ZERO
	var right: Vector3 = Basis(Vector3.UP, _yaw) * Vector3.RIGHT
	return (right * (-1.0 + randf() * 2.0) + Vector3.UP * (-1.0 + randf() * 2.0)) * _damage_shake_magnitude


func _hide_class_specific_hud() -> void:
	_one_life_overlay.visible = false
	_collar_indicator.visible = false
	_collar_indicator_label.visible = false
	_cigarette_bar_bg.visible = false
	_cigarette_bar_fill.visible = false


func _update_collar_indicator() -> void:
	if _player_class_name != &"ExplodingCollarRacePlayer" or _player == null or not is_instance_valid(_player):
		_collar_indicator.visible = false
		_collar_indicator_label.visible = false
		return
	if not ("collar_light_material" in _player):
		_collar_indicator.visible = false
		_collar_indicator_label.visible = false
		return
	var mat = _player.get("collar_light_material")
	if mat == null:
		_collar_indicator.visible = false
		_collar_indicator_label.visible = false
		return
	_collar_indicator.color = (mat as StandardMaterial3D).albedo_color
	_collar_indicator.visible = true
	_collar_indicator_label.visible = true


func _update_smoke_break_hud() -> void:
	if _player_class_name != &"SmokeBreakPlayer" or _player == null or not is_instance_valid(_player) or not ("cigarette_left" in _player):
		_cigarette_bar_bg.visible = false
		_cigarette_bar_fill.visible = false
		return
	var left: float = clampf(float(_player.get("cigarette_left")), 0.0, 1.0)
	_cigarette_bar_bg.visible = true
	_cigarette_bar_fill.visible = true
	var full_width: float = 156.0  # matches offset_right(78) - offset_left(-78) in _create_crosshair
	_cigarette_bar_fill.offset_right = _cigarette_bar_fill.offset_left + full_width * left


func _set_fpv_camera_active(active: bool) -> void:
	if active:
		_camera_enter_tree()
		_camera.current = true
	elif _camera.get_parent() != null:
		_camera.current = false
		get_tree().root.remove_child(_camera)
	_crosshair.visible = active
	if not active:
		_hide_class_specific_hud()


func _camera_enter_tree() -> void:
	if _camera.get_parent() == null:
		get_tree().root.add_child(_camera)


func _restore_camera_or_fallback() -> void:
	_set_fpv_camera_active(false)
	if _orig_camera and is_instance_valid(_orig_camera):
		_orig_camera.current = true
		return
	var fallback := _find_fallback_camera()
	if fallback:
		fallback.current = true
		print("[fpv_mod] original camera was gone on restore -- fell back to ", fallback.get_path())
	else:
		print("[fpv_mod] WARNING: no camera found anywhere to restore -- view may go blank")


func _find_fallback_camera() -> Camera3D:
	var tree := get_tree()
	if tree == null:
		return null
	return _find_camera_in(tree.root, tree.root)


func _find_camera_in(n: Node, root_viewport: Window) -> Camera3D:
	if n is Camera3D and n != _camera and n.get_viewport() == root_viewport:
		return n as Camera3D
	for ch in n.get_children():
		var found := _find_camera_in(ch, root_viewport)
		if found:
			return found
	return null



func _smooth_head_pos_toward(current: Vector3, target: Vector3, delta: float) -> Vector3:
	var forward: Vector3 = Basis(Vector3.UP, _yaw) * Vector3(0, 0, -1)
	var right: Vector3 = Basis(Vector3.UP, _yaw) * Vector3(1, 0, 0)
	var d: Vector3 = target - current
	var w: float = 1.0 - exp(-delta * HEAD_BOB_SMOOTHING)
	return current + Vector3.UP * (d.y * w) + right * (d.dot(right) * w) + forward * d.dot(forward)


func _process(delta: float) -> void:
	if _process_lobby_fpv(delta):
		return

	if not enabled:
		return

	_accum += delta
	var armature_swapped := not _dying and _skeleton != null and is_instance_valid(_skeleton) and not _skeleton.is_visible_in_tree()
	if _accum >= RESCAN_IV or _player == null or not is_instance_valid(_player) or armature_swapped:
		_accum = 0.0
		_rescan_player()

	var have_rig := (_player != null and is_instance_valid(_player)
		and _skeleton != null and is_instance_valid(_skeleton) and _head_bone_idx >= 0)
	var active := have_rig and _player_is_active()

	if _dying:
		if active:
			_end_death_cam()
			_was_active = true
			_snap_head_smoothing = true
			print("[fpv_mod] reactivated during death cam -- resuming FPV")
		else:
			_process_death_cam(delta)
			return

	if not have_rig:
		if _camera.get_parent() != null:
			_set_fpv_camera_active(false)
			print("[fpv_mod] released idle camera (not in a minigame) -- handed back to the game")
		var pause_menu := get_node_or_null("/root/PauseMenu")
		var pause_active: bool = pause_menu != null and bool(pause_menu.get("active"))
		var cursor_manager := get_node_or_null("/root/CursorManager")
		var minigame_locked: bool = cursor_manager != null and bool(cursor_manager.get("locked"))
		if minigame_locked and not pause_active:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_mouse_captured_by_us = true
		elif _mouse_captured_by_us:
			_mouse_captured_by_us = false
			var gm := get_node_or_null("/root/GameManager")
			var using_controller: bool = gm != null and gm.has_method("is_using_controller") and bool(gm.call("is_using_controller"))
			if not using_controller:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	if not active:
		if _ever_active:
			_process_death_cam(delta)
			return
	else:
		if not _was_active:
			_was_active = true
			_end_death_cam()
			_snap_head_smoothing = true  # could have respawned/repositioned -- don't glide there
			print("[fpv_mod] player active again -- resuming FPV")
		_ever_active = true

	_update_mouse_capture()
	_render_head_cam(delta, active)


func _compute_eye_offset() -> Vector3:
	var oyaw: float = _yaw_lock_center if _offset_fixed_to_body else _yaw
	var forward: Vector3 = Basis(Vector3.UP, oyaw) * Vector3(0, 0, -1)
	var left: Vector3 = Basis(Vector3.UP, oyaw) * Vector3(-1, 0, 0)  # -X = left
	return forward * _eye_forward_offset + Vector3.UP * _eye_up_offset + left * _eye_left_offset


func _render_head_cam(delta: float, active: bool) -> void:
	_apply_controller_look(delta)

	if _follow_rig_yaw and _visuals and is_instance_valid(_visuals):
		_yaw = _visuals.global_rotation.y + _follow_yaw_base + _look_yaw_offset

	var head_xform: Transform3D = _skeleton.global_transform * _skeleton.get_bone_global_pose(_head_bone_idx)
	var look_basis := Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch)

	var target_head_pos: Vector3
	if _player_class_name == &"SmokeBreakPlayer" and _smoke_break_cigarette_node != null and is_instance_valid(_smoke_break_cigarette_node):
		var seat_back: Vector3 = Basis(Vector3.UP, _yaw_lock_center) * Vector3(0, 0, 1)
		target_head_pos = (_smoke_break_cigarette_node.global_position
			+ Vector3.UP * SMOKE_BREAK_CIGARETTE_EYE_UP
			+ seat_back * SMOKE_BREAK_CIGARETTE_EYE_BACK)
	else:
		target_head_pos = head_xform.origin + _compute_eye_offset()

	var grounded := not (_player is CharacterBody3D) or (_player as CharacterBody3D).is_on_floor()
	if _snap_head_smoothing or not grounded or _smoothed_head_pos.distance_to(target_head_pos) > HEAD_TELEPORT_SNAP_DISTANCE:
		_smoothed_head_pos = target_head_pos
		_snap_head_smoothing = false
	else:
		_smoothed_head_pos = _smooth_head_pos_toward(_smoothed_head_pos, target_head_pos, delta)

	_camera_enter_tree()  # must be parented before writing its global transform
	_camera.global_transform = Transform3D(look_basis, _smoothed_head_pos + _compute_damage_shake_offset())

	if active and not _freeze_body and _visuals and is_instance_valid(_visuals):
		_visuals.global_rotation.y = _yaw

	_skeleton.set_bone_pose_scale(_head_bone_idx, Vector3.ONE * HEAD_HIDE_SCALE)

	if active and _movement_rotate_active:
		_rotate_player_movement()

	if active:
		_update_damage_flash(delta)
		_update_collar_indicator()
		_update_smoke_break_hud()

	_set_fpv_camera_active(true)


func _process_death_cam(delta: float) -> void:
	if _spectating_released:
		return

	if not _dying:
		_dying = true
		_was_active = false
		_dying_timer = DEATH_CAM_SAFETY_TIME
		_dying_anchor = _smoothed_head_pos
		_dying_hat = null
		_dying_hat_search_active = true
		_dying_hat_search_time_left = HAT_SEARCH_WINDOW
		_damage_flash_alpha = 0.0
		_damage_shake_magnitude = 0.0
		_damage_flash_rect.color = Color(DAMAGE_FLASH_COLOR.r, DAMAGE_FLASH_COLOR.g, DAMAGE_FLASH_COLOR.b, 0.0)
		_hide_class_specific_hud()
		_set_death_black(0.0)
		var beh: Dictionary = DEATH_BEHAVIOR.get(_player_class_name, DEATH_BEHAVIOR_DEFAULT)
		_death_mode = StringName(beh.get("mode", &"stay"))
		_death_delay = float(beh.get("delay", 0.0))
		_death_black_end = bool(beh.get("black_end", false))
		print("[fpv_mod] death cam start: class='", _player_class_name, "' mode=", _death_mode, " delay=", _death_delay)

	_dying_timer -= delta
	_apply_controller_look(delta)  # right-stick look-around during the death cam too (self-gated)
	_update_mouse_capture()  # keep releasing to Pause etc if it opens mid-death-cam

	if _player == null or not is_instance_valid(_player):
		_spectate_release("round over")
		return

	if _player_class_name == &"ForkliftCertifiedVehicle" and _is_forklift_crate_pickup_active():
		_spectate_release("forklift: crate tie-break pickup in progress -- third person")
		return

	var elapsed: float = DEATH_CAM_SAFETY_TIME - _dying_timer

	var mode: StringName = _death_mode
	if stay_after_body_drop and mode == &"corpse":
		mode = &"stay"

	if mode == &"spectate":
		_spectate_release("spectate")
	elif mode == &"stay":
		_set_death_black(0.0)
		_death_apply_camera(_death_ride_stay(delta))
	elif mode == &"hat":
		_set_death_black(0.0)
		if _dying_hat and is_instance_valid(_dying_hat):
			if elapsed >= _death_delay:
				_spectate_release("hat window done")
			else:
				_death_apply_camera(_dying_hat.global_position)
		elif _dying_hat_search_time_left > 0.0:
			_death_apply_camera(_death_ride_stay(delta))  # still searching (rides corpse/anchor meanwhile)
		else:
			_spectate_release("hat mode: no hat found -> spectate")
	elif mode == &"black":
		if elapsed >= _death_delay:
			_spectate_release("black hold done")
		else:
			_set_death_black(1.0)
			_death_apply_camera(_dying_anchor)  # frozen behind the black
	elif mode == &"corpse":
		var corpse_visible: bool = (_skeleton and is_instance_valid(_skeleton)
			and _skeleton.is_visible_in_tree() and _head_bone_idx >= 0)
		if elapsed < _death_delay:
			if corpse_visible:
				_set_death_black(0.0)
				_death_apply_camera(_death_ride_corpse())
			else:
				_set_death_black(1.0)  # instant crush, nothing to watch -> black
				_death_apply_camera(_dying_anchor)
		elif _death_black_end and elapsed < _death_delay + DEATH_BLACK_HOLD:
			_set_death_black(1.0)  # the "machine stomps" black flash
			_death_apply_camera(_dying_anchor)
		else:
			_spectate_release("corpse window done")
	else:
		_set_death_black(0.0)
		_death_apply_camera(_death_ride_stay(delta))


func _death_ride_stay(delta: float) -> Vector3:
	if _dying_hat and is_instance_valid(_dying_hat):
		return _dying_hat.global_position
	if _dying_hat_search_time_left > 0.0:
		_dying_hat_search_time_left -= delta
		var hat := _find_nearby_hat_gib(_dying_anchor)
		if hat:
			_dying_hat = hat
			print("[fpv_mod] death cam: latched onto popped-off hat_gib '", hat.name, "'")
			return hat.global_position
		elif _dying_hat_search_time_left <= 0.0:
			print("[fpv_mod] death cam: no HatGib found within ", DEATH_CAM_HAT_SEARCH_RADIUS,
				"u of ", _dying_anchor, " (HatGib nodes seen: ", _last_hat_scan_total,
				", active: ", _last_hat_scan_active, ", nearest active: ", _last_hat_scan_nearest, ")")
			print("[fpv_mod] death cam: nearby RigidBody3D near ", _dying_anchor, ": ", _debug_nearby_rigidbodies(_dying_anchor))
	return _death_ride_corpse()


func _death_ride_corpse() -> Vector3:
	if _skeleton and is_instance_valid(_skeleton) and _skeleton.is_visible_in_tree() and _head_bone_idx >= 0:
		var head_xform: Transform3D = _skeleton.global_transform * _skeleton.get_bone_global_pose(_head_bone_idx)
		var pos: Vector3 = head_xform.origin + _compute_eye_offset()
		_dying_anchor = pos
		_skeleton.set_bone_pose_scale(_head_bone_idx, Vector3.ONE * HEAD_HIDE_SCALE)
		return pos
	return _dying_anchor


func _death_apply_camera(pos: Vector3) -> void:
	var look_basis := Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch)
	_smoothed_head_pos = pos
	_camera_enter_tree()  # must be parented before writing its global transform
	_camera.global_transform = Transform3D(look_basis, _smoothed_head_pos)
	_set_fpv_camera_active(true)


func _set_death_black(alpha: float) -> void:
	if _death_black_rect and is_instance_valid(_death_black_rect):
		_death_black_rect.color = Color(0.0, 0.0, 0.0, alpha)


func _spectate_release(reason: String) -> void:
	_set_death_black(0.0)
	_end_death_cam()
	_restore_head()
	_restore_debris_grab_range()
	_debris_grab_collision = null
	_debris_grab_original_shape = null
	_set_fpv_camera_active(false)
	var game_cam := _find_fallback_camera()
	if game_cam == null and _orig_camera != null and is_instance_valid(_orig_camera):
		game_cam = _orig_camera
	if game_cam and is_instance_valid(game_cam):
		game_cam.current = true
	else:
		print("[fpv_mod] spectate: no game camera found to hand to")
	if _mouse_captured_by_us:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_mouse_captured_by_us = false
	_spectating_released = true
	print("[fpv_mod] death cam -> third-person spectate (", reason, ")")


func _end_death_cam() -> void:
	_dying = false
	_dying_hat = null
	_dying_hat_search_active = false
	_spectating_released = false
	_set_death_black(0.0)


func _resolve_forklift_crate_manager(player_node: Node) -> Node:
	var cur: Node = player_node
	while cur != null:
		if "crate_manager" in cur:
			var cm = cur.get("crate_manager")
			if cm != null:
				return cm
		cur = cur.get_parent()
	return null


func _is_forklift_crate_pickup_active() -> bool:
	if _forklift_crate_manager == null or not is_instance_valid(_forklift_crate_manager):
		return false
	if not ("remove_indicies_after_move" in _forklift_crate_manager):
		return false
	var arr = _forklift_crate_manager.get("remove_indicies_after_move")
	return typeof(arr) == TYPE_ARRAY and not (arr as Array).is_empty()


func _find_nearby_hat_gib(center: Vector3) -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	var budget: Array = [SCAN_BUDGET]
	var result: Array = [null, DEATH_CAM_HAT_SEARCH_RADIUS, 0, 0, INF]
	_scan_for_hat_gib(tree.root, center, budget, result)
	_last_hat_scan_total = int(result[2])
	_last_hat_scan_active = int(result[3])
	_last_hat_scan_nearest = float(result[4])
	return result[0]


func _scan_for_hat_gib(n: Node, center: Vector3, budget: Array, result: Array) -> void:
	if budget[0] <= 0:
		return
	budget[0] -= 1

	if n is Node3D:
		var is_hat: bool = String(n.name).contains("HatGib")
		if not is_hat:
			var sc: Script = n.get_script()
			is_hat = sc != null and sc.resource_path.contains("hat_gib")
		if is_hat:
			result[2] = int(result[2]) + 1  # total HatGib props seen (any state)
			if bool(n.get("active")):
				result[3] = int(result[3]) + 1  # active ones
				var dist: float = (n as Node3D).global_position.distance_to(center)
				if dist < float(result[4]):
					result[4] = dist  # nearest active, even if beyond the radius
				if dist < float(result[1]):
					result[0] = n
					result[1] = dist

	for ch in n.get_children():
		_scan_for_hat_gib(ch, center, budget, result)


func _debug_nearby_rigidbodies(center: Vector3) -> String:
	var tree := get_tree()
	if tree == null:
		return "(no tree)"
	var acc: Array = ["", 0]  # [text, count]
	_collect_rigidbodies(tree.root, center, [SCAN_BUDGET], acc)
	return String(acc[0]) if int(acc[1]) > 0 else "(no RigidBody3D within 20u)"


func _collect_rigidbodies(n: Node, center: Vector3, budget: Array, acc: Array) -> void:
	if budget[0] <= 0:
		return
	budget[0] -= 1
	if int(acc[1]) < 8 and n is RigidBody3D:
		var d: float = (n as RigidBody3D).global_position.distance_to(center)
		if d < 20.0:
			var sc: Script = n.get_script()
			var scp: String = sc.resource_path if sc else "(none)"
			acc[0] = String(acc[0]) + " | '" + String(n.name) + "' active=" + str(n.get("active")) + " dist=" + str(round(d)) + " script=" + scp
			acc[1] = int(acc[1]) + 1
	for ch in n.get_children():
		_collect_rigidbodies(ch, center, budget, acc)


func _input(event: InputEvent) -> void:
	if _lobby_cam_override_active and event is InputEventMouseMotion and _lobby_look_held():
		_lobby_mouse_rel += (event as InputEventMouseMotion).relative

	if not enabled or _player == null or not is_instance_valid(_player):
		return
	if not _player_is_active() and _ever_active and not _dying:
		return
	if _dying and not stay_after_body_drop:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := MOUSE_SENSITIVITY * _mouse_sensitivity_mult
		var ylim: float = _current_yaw_limit_rad()
		if _follow_rig_yaw:
			_look_yaw_offset -= event.relative.x * sens
			if ylim > 0.0:
				_look_yaw_offset = clamp(_look_yaw_offset, -ylim, ylim)
		else:
			_yaw -= event.relative.x * sens
			if ylim > 0.0:
				_yaw = clamp(_yaw, _yaw_lock_center - ylim, _yaw_lock_center + ylim)
		_pitch = clamp(_pitch - event.relative.y * sens, -_pitch_down_limit_rad, PITCH_LIMIT)


func _current_yaw_limit_rad() -> float:
	if not _ever_active:
		var countdown: float = deg_to_rad(COUNTDOWN_YAW_LIMIT_DEG)
		if _yaw_limit_rad > 0.0:
			return min(_yaw_limit_rad, countdown)
		return countdown
	return _yaw_limit_rad


func _apply_controller_look(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if not _player_is_active() and _ever_active and not _dying:
		return
	if _dying and not stay_after_body_drop:
		return

	var device: int = _look_joypad_device()
	if device < 0:
		return
	var v := Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
	var mag: float = v.length()
	if mag < CONTROLLER_LOOK_DEADZONE:
		return
	var scaled: Vector2 = v.normalized() * ((mag - CONTROLLER_LOOK_DEADZONE) / (1.0 - CONTROLLER_LOOK_DEADZONE))
	var step: float = CONTROLLER_LOOK_SPEED * _controller_sensitivity_mult * delta
	var ylim: float = _current_yaw_limit_rad()
	if _follow_rig_yaw:
		_look_yaw_offset -= scaled.x * step
		if ylim > 0.0:
			_look_yaw_offset = clamp(_look_yaw_offset, -ylim, ylim)
	else:
		_yaw -= scaled.x * step
		if ylim > 0.0:
			_yaw = clamp(_yaw, _yaw_lock_center - ylim, _yaw_lock_center + ylim)
	_pitch = clamp(_pitch - scaled.y * step, -_pitch_down_limit_rad, PITCH_LIMIT)


func _look_joypad_device() -> int:
	var pads := Input.get_connected_joypads()
	if _player and is_instance_valid(_player) and "player_presence" in _player:
		var pp = _player.get("player_presence")
		if pp and is_instance_valid(pp) and "device_id" in pp:
			var d: int = int(pp.get("device_id"))
			if d >= 0 and d in pads:
				return d
	return int(pads[0]) if not pads.is_empty() else -1


func _player_is_active() -> bool:
	if _player == null:
		return false
	if "is_dead" in _player and bool(_player.get("is_dead")):
		return false
	if "active" in _player:
		return bool(_player.get("active"))
	return true


func _rotate_player_movement() -> void:
	if not ("movement_input" in _player):
		return
	var raw: Vector3 = _player.get("movement_input")
	if raw == Vector3.ZERO:
		return
	var rotated := raw.rotated(Vector3.UP, _yaw - _movement_base_yaw)
	_player.set("movement_input", rotated)
	if not _movement_rotate_logged:
		_movement_rotate_logged = true
		print("[fpv_mod] movement rotation active for '", _player.name,
			"': raw=", raw, " yaw=", _yaw, " rotated=", rotated)


func _player_needs_free_cursor() -> bool:
	if _player == null:
		return false
	var sc: Script = _player.get_script()
	return sc != null and FREE_CURSOR_CLASSES.has(sc.get_global_name())


func _update_mouse_capture() -> void:
	if _player_needs_free_cursor():
		if _mouse_captured_by_us:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_mouse_captured_by_us = false
		return

	var pause_menu := get_node_or_null("/root/PauseMenu")
	var cursor_manager := get_node_or_null("/root/CursorManager")

	var blocked := false
	if pause_menu and bool(pause_menu.get("active")):
		blocked = true

	if blocked != _mouse_blocked_logged:
		_mouse_blocked_logged = blocked
		print("[fpv_mod] mouse capture ", ("blocked" if blocked else "unblocked"),
			" -- pause_menu.active=", bool(pause_menu.get("active")) if pause_menu else "?",
			" cursor_manager.locked=", bool(cursor_manager.get("locked")) if cursor_manager else "?",
			" Input.mouse_mode=", Input.mouse_mode)

	if blocked:
		if _mouse_captured_by_us and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_mouse_captured_by_us = false
		return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		print("[fpv_mod] poll re-capturing mouse (was ", Input.mouse_mode, ")")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_captured_by_us = true


func _on_pause_closed() -> void:
	print("[fpv_mod] _on_pause_closed fired -- enabled=", enabled, " _player=",
		(_player.name if _player else "null"), " Input.mouse_mode=", Input.mouse_mode)
	if not enabled or _player == null:
		return
	if _player_needs_free_cursor():
		print("[fpv_mod] _on_pause_closed: skipped, player needs free cursor")
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_captured_by_us = true
	print("[fpv_mod] _on_pause_closed: set Input.mouse_mode = CAPTURED")



func _rescan_player() -> void:
	var tree := get_tree()
	var gm := get_node_or_null("/root/GameManager")
	var in_game: bool = gm != null and bool(gm.get("in_game"))
	_last_scan_in_game = in_game
	if tree == null or not (multiplayer and multiplayer.has_multiplayer_peer()) or not in_game:
		if _player != null or _dying:
			_end_death_cam()
			_restore_head()
			_restore_debris_grab_range()
			_debris_grab_collision = null
			_debris_grab_original_shape = null
			if _camera.current:
				_restore_camera_or_fallback()
			if _mouse_captured_by_us:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_mouse_captured_by_us = false
			_player = null
			_visuals = null
			_skeleton = null
			_head_bone_idx = -1
			_movement_rotate_active = false
			_ever_active = false
		return

	var my_id := multiplayer.get_unique_id()
	var assigners: Array[Node] = []
	var budget: Array = [SCAN_BUDGET]
	_find_customization_assigners(tree.root, assigners, budget)

	for assigner in assigners:
		var skeleton: Node = assigner.get_parent()
		if not (skeleton is Skeleton3D):
			continue

		if not (skeleton as Node3D).is_visible_in_tree():
			continue

		if skeleton.get_viewport() != tree.root:
			continue

		var head_idx: int = (skeleton as Skeleton3D).find_bone("head")
		if head_idx < 0:
			continue

		var player_node := _find_player_ancestor(skeleton, my_id)
		if player_node == null:
			continue

		var player_script: Script = player_node.get_script()
		if player_script and SKIP_ENTIRELY_CLASSES.has(player_script.get_global_name()):
			continue

		if not _is_in_loaded_minigame(player_node):
			continue

		if player_node == _player and skeleton == _skeleton:
			return

		var is_same_player := player_node == _player

		_restore_head()
		if not is_same_player:
			_restore_debris_grab_range()

		_player = player_node
		_skeleton = skeleton as Skeleton3D
		_head_bone_idx = head_idx
		_visuals = _direct_child_ancestor(_player, _skeleton) as Node3D
		_head_original_scale = _skeleton.get_bone_pose_scale(_head_bone_idx)
		_snap_head_smoothing = true  # new skeleton entirely -- jump to its head, don't glide there

		if is_same_player:
			print("[fpv_mod] player '", player_node.name, "' switched active armature -- now tracking ", _skeleton.get_path())
			return

		_end_death_cam()
		_was_active = true
		_ever_active = false
		_movement_rotate_active = player_script != null and MOVEMENT_ROTATE_CLASSES.has(player_script.get_global_name())
		_movement_rotate_logged = false
		_player_class_name = player_script.get_global_name() if player_script else &""

		_damage_flash_property = String(DAMAGE_FLASH_HEALTH_PROPERTY.get(_player_class_name, ""))
		_damage_flash_last_value = (int(player_node.get(_damage_flash_property))
			if _damage_flash_property != "" and _damage_flash_property in player_node else 0)
		_damage_flash_alpha = 0.0
		_damage_shake_magnitude = 0.0
		_damage_flash_rect.color = Color(DAMAGE_FLASH_COLOR.r, DAMAGE_FLASH_COLOR.g, DAMAGE_FLASH_COLOR.b, 0.0)

		_smoke_break_cigarette_node = null
		if _player_class_name == &"SmokeBreakPlayer" and "anim_handler" in player_node:
			var anim_h = player_node.get("anim_handler")
			if anim_h and is_instance_valid(anim_h) and "cig_scale_parent" in anim_h:
				_smoke_break_cigarette_node = anim_h.get("cig_scale_parent")

		_forklift_crate_manager = null
		if _player_class_name == &"ForkliftCertifiedVehicle":
			_forklift_crate_manager = _resolve_forklift_crate_manager(player_node)

		_debris_grab_collision = null
		_debris_grab_original_shape = null
		_debris_grab_widened = false
		if _player_class_name == DEBRIS_GRAB_RANGE_CLASS and "grab_area" in player_node:
			var grab_area: Node = player_node.get("grab_area")
			if grab_area:
				for ch in grab_area.get_children():
					if ch is CollisionShape3D:
						_debris_grab_collision = ch
						break
		_apply_debris_grab_range()

		var tuning: Dictionary = CAMERA_TUNING_OVERRIDES.get(
			player_script.get_global_name() if player_script else &"", {}
		)
		_eye_up_offset = float(tuning.get("eye_up_offset", EYE_UP_OFFSET))
		_eye_forward_offset = float(tuning.get("eye_forward_offset", EYE_FORWARD_OFFSET))
		_eye_left_offset = float(tuning.get("eye_left_offset", 0.0))
		_offset_fixed_to_body = bool(tuning.get("offset_fixed_to_body", false))
		_yaw_limit_rad = deg_to_rad(float(tuning.get("yaw_limit_deg", 0.0)))
		_pitch_down_limit_rad = deg_to_rad(float(tuning.get("pitch_down_limit_deg", rad_to_deg(PITCH_LIMIT))))
		_freeze_body = bool(tuning.get("freeze_body", false))
		_follow_rig_yaw = bool(tuning.get("follow_rig_yaw", false))
		_look_yaw_offset = 0.0

		if "scene_rotation" in player_node:
			_movement_base_yaw = deg_to_rad(float(player_node.get("scene_rotation")))
		else:
			_movement_base_yaw = 0.0

		if bool(tuning.get("yaw_from_player_body", false)):
			_yaw = (_player as Node3D).global_rotation.y
		elif _visuals:
			_yaw = _visuals.global_rotation.y
		else:
			_yaw = _movement_base_yaw

		_pitch = deg_to_rad(float(tuning.get("pitch_offset_deg", 0.0)))

		if _follow_rig_yaw:
			_follow_yaw_base = deg_to_rad(float(tuning.get("yaw_offset_deg", 0.0)))
		else:
			_follow_yaw_base = 0.0
			_yaw += deg_to_rad(float(tuning.get("yaw_offset_deg", 0.0)))
		_yaw_lock_center = _yaw

		var vp_cam := get_viewport().get_camera_3d()
		if vp_cam and vp_cam != _camera:
			_orig_camera = vp_cam
			_sync_cull_mask_from(vp_cam)

		print("[fpv_mod] locked onto player '", player_node.name, "' (",
			player_script.get_global_name() if player_script else "?",
			"), seeded yaw=", _yaw, " orig_camera=", _orig_camera.get_path() if _orig_camera else "<none>")
		return

	if _dying:
		return

	if _player != null and is_instance_valid(_player):
		return

	if _player != null:
		print("[fpv_mod] lost local player -- no matching CustomizationAssigner found this scan")
	_restore_head()
	_restore_debris_grab_range()
	_debris_grab_collision = null
	_debris_grab_original_shape = null
	_player = null
	_visuals = null
	_skeleton = null
	_head_bone_idx = -1
	_movement_rotate_active = false


func _find_customization_assigners(n: Node, out: Array, budget: Array) -> void:
	if budget[0] <= 0:
		return
	budget[0] -= 1

	var sc: Script = n.get_script()
	if sc and sc.get_global_name() == &"CustomizationAssigner":
		out.append(n)

	for ch in n.get_children():
		_find_customization_assigners(ch, out, budget)


func _find_player_ancestor(n: Node, my_id: int) -> Node:
	var cur := n.get_parent()
	while cur != null:
		if "player_presence" in cur:
			var pp = cur.get("player_presence")
			if pp and is_instance_valid(pp) and int(pp.get("network_id")) == my_id:
				return cur
		cur = cur.get_parent()
	return null


func _direct_child_ancestor(root: Node, node: Node) -> Node:
	var cur := node
	while cur != null and cur.get_parent() != root:
		cur = cur.get_parent()
	return cur


func _is_in_loaded_minigame(n: Node) -> bool:
	var cur := n
	while cur != null:
		if _script_is_or_extends(cur.get_script(), &"Minigame"):
			return true
		cur = cur.get_parent()
	return false


func _script_is_or_extends(sc: Script, global_name: StringName) -> bool:
	while sc != null:
		if sc.get_global_name() == global_name:
			return true
		sc = sc.get_base_script()
	return false



func _save_settings() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"enabled": enabled,
			"lobby_fpv_enabled": lobby_fpv_enabled,
			"stay_after_body_drop": stay_after_body_drop,
			"mouse_sensitivity_mult": _mouse_sensitivity_mult,
			"controller_sensitivity_mult": _controller_sensitivity_mult,
		}))


func _load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		enabled = true
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		enabled = bool(parsed.get("enabled", false))
		lobby_fpv_enabled = bool(parsed.get("lobby_fpv_enabled", false))
		stay_after_body_drop = bool(parsed.get("stay_after_body_drop", false))
		var legacy: float = float(parsed.get("sensitivity_mult", 1.0))
		_mouse_sensitivity_mult = float(parsed.get("mouse_sensitivity_mult", legacy))
		_controller_sensitivity_mult = float(parsed.get("controller_sensitivity_mult", legacy))
