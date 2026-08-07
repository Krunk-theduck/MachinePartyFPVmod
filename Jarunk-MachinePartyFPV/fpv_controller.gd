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
	&"DuckHuntDuckPlayer": "health",
}
const INFECTION_FLASH_CLASS: StringName = &"KnifeAtTheOfficePlayer"  # Inside Job: no health -- flash only while is_infected && !active (the transformation window)
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

const SECRET_LEVEL_FLOOR_SCAN_IV := 1.0
const SECRET_LEVEL_SCRIPT_PATH := "res://minigames/cutscene_test/scripts/cutscene_test.gd"
const SECRET_LEVEL_FLOOR_RELATIVE_PATH := "Geometry/MeshInstance3D"
const SECRET_LEVEL_FLOOR_TEXTURE_PATH := "res://minigames/duck_hunt/models/duck hunt environment2/duck hunt environment2_dh grass ground1.png"
const SECRET_LEVEL_FLOOR_UV_SCALE := 24.0

const MANUAL_RELOCK_KEY := KEY_SHIFT
const YAW_RESEED_DELAY := 0.35  # setup_rpc's seat rotation lands a beat after we first see the skeleton -- correct once, this long after lock-on, then stop (not every rescan, or free-look during countdown gets yanked back to center)

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

var _collar_belt: Control            # custom-drawn "exploding collar" belt indicator (Minefield)
var _collar_belt_color: Color = Color(0.1, 1.0, 0.2, 1.0)  # live collar-light color (green -> red)
var _collar_belt_pulse: float = 0.0  # sine phase for the danger pulse when the light goes red

var _smoke_break_cigarette_node: Node3D = null
var _smoke_break_finish_locked: bool = false
var _smoke_break_locked_head_pos: Vector3 = Vector3.ZERO
var _cigarette_hud: Control          # custom-drawn burning cigarette (replaces the flat bar)
var _cigarette_frac: float = 1.0     # 0..1 amount of cigarette left
var _cigarette_anim_t: float = 0.0   # time accumulator driving ember flicker + smoke wisp

var _smoke_timer_panel: Control      # digital "alarm clock" style round timer, top-center
var _smoke_timer_label: Label
var _smoke_timer_font: Font = null
var _smoke_timer_source: Node = null # the minigame's own Label3D we mirror (kept in sync on every peer)

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
var _hud_in_depth_toggle: Button = null

var _fpv_settings_button: Button = null
var _fpv_settings_popup: PopupPanel = null

var stay_after_body_drop: bool = false
var hud_in_depth: bool = true  # true = new detailed belt/cigarette art; false = old simplistic box/bar. Timer shows either way.

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
var _forklift_third_person_active: bool = false  # handed the forklift's between-round cutscene back to the game's 3rd-person camera

var _secret_level_floor_node: MeshInstance3D = null
var _secret_level_floor_accum: float = 0.0

var experimental_manual_relock_enabled: bool = false
var _manual_relock_toggle: Button = null
var _relock_key_was_down: bool = false

var _yaw_reseed_pending: bool = false
var _yaw_reseed_timer: float = 0.0


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
		_hud_in_depth_toggle = checkbox_scene.instantiate() as Button
		_hud_in_depth_toggle.name = "HudInDepthToggle"
		_hud_in_depth_toggle.button_text = "In-Depth HUD Art"
		if checked_tex:
			_hud_in_depth_toggle.set("checked_texture", checked_tex)
		if unchecked_tex:
			_hud_in_depth_toggle.set("unchecked_texture", unchecked_tex)
		if font:
			_hud_in_depth_toggle.set("font_override", font)
		_hud_in_depth_toggle.set("checked", hud_in_depth)
		sub_vbox.add_child(_hud_in_depth_toggle)
		if _hud_in_depth_toggle.has_signal("checkbox_toggled"):
			_hud_in_depth_toggle.connect("checkbox_toggled",
				func(): set_hud_in_depth(bool(_hud_in_depth_toggle.get("checked"))))
		var hud_hint := Label.new()
		hud_hint.name = "HudInDepthHint"
		hud_hint.text = "on = detailed collar belt & burning cigarette; off = simplistic box & bar (timer stays either way)"
		if font:
			hud_hint.add_theme_font_override("font", font)
		hud_hint.add_theme_font_size_override("font_size", 16)
		hud_hint.modulate = Color(1.0, 1.0, 1.0, 0.55)
		sub_vbox.add_child(hud_hint)

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

	if checkbox_scene:
		_manual_relock_toggle = checkbox_scene.instantiate() as Button
		_manual_relock_toggle.name = "ManualRelockToggle"
		_manual_relock_toggle.button_text = "Experimental: Hold Shift to Re-lock View"
		if checked_tex:
			_manual_relock_toggle.set("checked_texture", checked_tex)
		if unchecked_tex:
			_manual_relock_toggle.set("unchecked_texture", unchecked_tex)
		if font:
			_manual_relock_toggle.set("font_override", font)
		_manual_relock_toggle.set("checked", experimental_manual_relock_enabled)
		sub_vbox.add_child(_manual_relock_toggle)
		if _manual_relock_toggle.has_signal("checkbox_toggled"):
			_manual_relock_toggle.connect("checkbox_toggled",
				func(): set_experimental_manual_relock_enabled(bool(_manual_relock_toggle.get("checked"))))
		var relock_hint := Label.new()
		relock_hint.name = "ManualRelockHint"
		relock_hint.text = "press Shift (keyboard) / LB (controller) to re-center your view lock in non-movement games"
		if font:
			relock_hint.add_theme_font_override("font", font)
		relock_hint.add_theme_font_size_override("font_size", 16)
		relock_hint.modulate = Color(1.0, 1.0, 1.0, 0.55)
		sub_vbox.add_child(relock_hint)

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


func set_hud_in_depth(value: bool) -> void:
	if value == hud_in_depth:
		return
	hud_in_depth = value
	if _collar_belt and is_instance_valid(_collar_belt):
		_collar_belt.queue_redraw()
	if _cigarette_hud and is_instance_valid(_cigarette_hud):
		_cigarette_hud.queue_redraw()
	_save_settings()


func set_experimental_manual_relock_enabled(value: bool) -> void:
	if value == experimental_manual_relock_enabled:
		return
	experimental_manual_relock_enabled = value
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



func _update_secret_level_floor(delta: float) -> void:
	if _secret_level_floor_node != null and is_instance_valid(_secret_level_floor_node):
		return
	_secret_level_floor_accum += delta
	if _secret_level_floor_accum < SECRET_LEVEL_FLOOR_SCAN_IV:
		return
	_secret_level_floor_accum = 0.0
	var tree := get_tree()
	if tree == null:
		return
	var level_root := _find_node_with_script(tree.root, SECRET_LEVEL_SCRIPT_PATH, [SCAN_BUDGET])
	if level_root == null:
		return
	var floor_mesh := level_root.get_node_or_null(SECRET_LEVEL_FLOOR_RELATIVE_PATH) as MeshInstance3D
	if floor_mesh == null:
		return
	floor_mesh.visible = true
	var mat := StandardMaterial3D.new()
	var tex: Texture2D = load(SECRET_LEVEL_FLOOR_TEXTURE_PATH) as Texture2D
	if tex:
		mat.albedo_texture = tex
		mat.uv1_scale = Vector3(SECRET_LEVEL_FLOOR_UV_SCALE, SECRET_LEVEL_FLOOR_UV_SCALE, 1.0)
	else:
		mat.albedo_color = Color(0.24, 0.21, 0.15)
	floor_mesh.material_override = mat
	_secret_level_floor_node = floor_mesh
	print("[fpv_mod] secret level: enabled + textured floor at ", floor_mesh.get_path())


func _find_node_with_script(n: Node, script_path: String, budget: Array) -> Node:
	if budget[0] <= 0:
		return null
	budget[0] -= 1
	var sc: Script = n.get_script()
	if sc and sc.resource_path == script_path:
		return n
	for ch in n.get_children():
		var found := _find_node_with_script(ch, script_path, budget)
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
	_smoke_break_finish_locked = false
	_forklift_crate_manager = null
	_forklift_third_person_active = false
	_yaw_reseed_pending = false


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

	# --- Minefield "exploding collar" belt indicator (top-left, custom-drawn) ---
	_collar_belt = Control.new()
	_collar_belt.name = "FirstPersonViewCollarBelt"
	_collar_belt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collar_belt.position = Vector2(18, 14)
	_collar_belt.size = Vector2(214, 62)
	_collar_belt.visible = false
	_collar_belt.draw.connect(_draw_collar_belt)
	_crosshair_layer.add_child(_collar_belt)

	# --- Smoke Break burning-cigarette meter (bottom-center, custom-drawn) ---
	_cigarette_hud = Control.new()
	_cigarette_hud.name = "FirstPersonViewCigaretteHud"
	_cigarette_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cigarette_hud.anchor_left = 0.5
	_cigarette_hud.anchor_right = 0.5
	_cigarette_hud.anchor_top = 1.0
	_cigarette_hud.anchor_bottom = 1.0
	_cigarette_hud.offset_left = -130
	_cigarette_hud.offset_right = 130
	_cigarette_hud.offset_top = -70
	_cigarette_hud.offset_bottom = -18
	_cigarette_hud.visible = false
	_cigarette_hud.draw.connect(_draw_cigarette_hud)
	_crosshair_layer.add_child(_cigarette_hud)

	# --- Smoke Break digital round timer (top-center, matches the in-world alarm-clock screen) ---
	_smoke_timer_font = load("res://fonts/alarm clock.ttf") as Font
	_smoke_timer_panel = Control.new()
	_smoke_timer_panel.name = "FirstPersonViewSmokeTimerPanel"
	_smoke_timer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_smoke_timer_panel.anchor_left = 0.5
	_smoke_timer_panel.anchor_right = 0.5
	_smoke_timer_panel.anchor_top = 0.0
	_smoke_timer_panel.anchor_bottom = 0.0
	_smoke_timer_panel.offset_left = -74
	_smoke_timer_panel.offset_right = 74
	_smoke_timer_panel.offset_top = 14
	_smoke_timer_panel.offset_bottom = 82
	_smoke_timer_panel.visible = false
	_smoke_timer_panel.draw.connect(_draw_smoke_timer_panel)
	_crosshair_layer.add_child(_smoke_timer_panel)

	_smoke_timer_label = Label.new()
	_smoke_timer_label.name = "FirstPersonViewSmokeTimerLabel"
	_smoke_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_smoke_timer_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_smoke_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_smoke_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_smoke_timer_label.text = "00:00"
	if _smoke_timer_font:
		_smoke_timer_label.add_theme_font_override("font", _smoke_timer_font)
	_smoke_timer_label.add_theme_font_size_override("font_size", 40)
	_smoke_timer_label.add_theme_color_override("font_color", Color(1.0, 0.05, 0.05, 1.0))
	_smoke_timer_label.add_theme_color_override("font_outline_color", Color(0.25, 0.0, 0.0, 0.9))
	_smoke_timer_label.add_theme_constant_override("outline_size", 5)
	_smoke_timer_panel.add_child(_smoke_timer_label)

	_death_black_rect = ColorRect.new()
	_death_black_rect.name = "FirstPersonViewDeathBlack"
	_death_black_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_black_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_crosshair_layer.add_child(_death_black_rect)


func _draw_crosshair() -> void:
	_crosshair.draw_circle(_crosshair.size * 0.5, CROSSHAIR_RADIUS, Color(1.0, 1.0, 1.0, CROSSHAIR_ALPHA))


func _draw_collar_belt() -> void:
	# A leather belt strap with a metal buckle housing the collar's warning light.
	var ci: Control = _collar_belt
	var cvs: RID = ci.get_canvas_item()
	var w: float = ci.size.x
	var h: float = ci.size.y

	if not hud_in_depth:
		_draw_collar_simple(ci)
		return

	# caption
	var font: Font = ci.get_theme_default_font()
	if font:
		ci.draw_string(font, Vector2(3.0, 13.0), "COLLAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 1.0, 1.0, 0.7))

	var strap_top: float = 22.0
	var strap_h: float = 26.0

	# leather strap
	var leather: StyleBoxFlat = StyleBoxFlat.new()
	leather.bg_color = Color(0.17, 0.10, 0.055, 0.96)
	leather.set_corner_radius_all(6)
	leather.border_color = Color(0.36, 0.23, 0.12, 1.0)
	leather.set_border_width_all(2)
	leather.draw(cvs, Rect2(0.0, strap_top, w, strap_h))

	# top sheen
	ci.draw_rect(Rect2(5.0, strap_top + 3.0, w - 10.0, 4.0), Color(0.42, 0.27, 0.15, 0.45))

	# double-row stitching
	var stitch_col: Color = Color(0.80, 0.64, 0.38, 0.85)
	var x: float = 7.0
	while x < w - 7.0:
		ci.draw_rect(Rect2(x, strap_top + 4.0, 6.0, 1.6), stitch_col)
		ci.draw_rect(Rect2(x, strap_top + strap_h - 6.0, 6.0, 1.6), stitch_col)
		x += 11.0

	# belt holes on the left
	var hole_y: float = strap_top + strap_h * 0.5
	for i in range(3):
		var hx: float = 18.0 + float(i) * 14.0
		ci.draw_circle(Vector2(hx, hole_y), 2.7, Color(0.04, 0.02, 0.01, 1.0))
		ci.draw_arc(Vector2(hx, hole_y), 2.7, 0.0, TAU, 12, Color(0.45, 0.30, 0.16, 0.7), 1.0, true)

	# buckle (metal frame) toward the right-center
	var buckle_w: float = 42.0
	var buckle_h: float = strap_h + 10.0
	var bx: float = w * 0.63 - buckle_w * 0.5
	var by: float = strap_top + (strap_h - buckle_h) * 0.5
	var buckle_rect: Rect2 = Rect2(bx, by, buckle_w, buckle_h)
	var metal: StyleBoxFlat = StyleBoxFlat.new()
	metal.bg_color = Color(0.60, 0.63, 0.70, 1.0)
	metal.set_corner_radius_all(5)
	metal.border_color = Color(0.85, 0.88, 0.94, 1.0)
	metal.set_border_width_all(2)
	metal.draw(cvs, buckle_rect)
	var recess: StyleBoxFlat = StyleBoxFlat.new()
	recess.bg_color = Color(0.11, 0.12, 0.15, 1.0)
	recess.set_corner_radius_all(4)
	recess.draw(cvs, buckle_rect.grow(-5.0))

	# warning light = live collar color, with a danger pulse when it reddens
	var base: Color = _collar_belt_color
	var danger: float = clampf(base.r - base.g, 0.0, 1.0)
	var pulse: float = 1.0
	if danger > 0.25:
		pulse = 0.6 + 0.4 * (sin(_collar_belt_pulse) * 0.5 + 0.5)
	var led: Vector2 = buckle_rect.get_center()
	ci.draw_circle(led, 12.0, Color(base.r, base.g, base.b, 0.20 * pulse))
	ci.draw_circle(led, 8.5, Color(base.r, base.g, base.b, 0.40 * pulse))
	ci.draw_circle(led, 5.5, Color(base.r, base.g, base.b, 1.0))
	ci.draw_circle(led + Vector2(-1.7, -1.9), 1.7, Color(1.0, 1.0, 1.0, 0.85))


func _draw_cigarette_hud() -> void:
	# A lit cigarette that burns down from the ember as the smoke depletes.
	var ci: Control = _cigarette_hud
	var cvs: RID = ci.get_canvas_item()
	var w: float = ci.size.x
	var h: float = ci.size.y

	if not hud_in_depth:
		_draw_cigarette_simple(ci)
		return

	var cy: float = h - 12.0
	var cig_h: float = 15.0
	var top: float = cy - cig_h * 0.5

	var left_margin: float = 8.0
	var right_margin: float = 8.0
	var filter_w: float = 46.0
	var filter_left: float = w - right_margin - filter_w
	var paper_full: float = filter_left - left_margin
	var frac: float = clampf(_cigarette_frac, 0.0, 1.0)
	var paper_len: float = paper_full * frac
	var paper_left: float = filter_left - paper_len

	# unburned paper body
	if paper_len > 1.0:
		var paper: StyleBoxFlat = StyleBoxFlat.new()
		paper.bg_color = Color(0.95, 0.94, 0.90, 0.98)
		paper.set_corner_radius_all(3)
		paper.draw(cvs, Rect2(paper_left, top, paper_len, cig_h))
		ci.draw_rect(Rect2(paper_left, top + 2.0, paper_len, 2.0), Color(1.0, 1.0, 1.0, 0.5))
		ci.draw_rect(Rect2(paper_left, top + cig_h - 3.0, paper_len, 2.0), Color(0.0, 0.0, 0.0, 0.10))

	# filter (cork) end
	var filt: StyleBoxFlat = StyleBoxFlat.new()
	filt.bg_color = Color(0.80, 0.55, 0.28, 1.0)
	filt.set_corner_radius_all(3)
	filt.draw(cvs, Rect2(filter_left, top, filter_w, cig_h))
	ci.draw_rect(Rect2(filter_left + 2.0, top + 1.0, 2.0, cig_h - 2.0), Color(0.55, 0.36, 0.16, 0.85))
	ci.draw_rect(Rect2(filter_left + 6.0, top + 1.0, 1.5, cig_h - 2.0), Color(0.55, 0.36, 0.16, 0.6))

	# ember + smoke at the burning tip
	if frac > 0.01:
		var flick: float = 0.75 + 0.25 * sin(_cigarette_anim_t * 9.0)
		var ember: Vector2 = Vector2(paper_left, cy)
		ci.draw_rect(Rect2(paper_left - 3.0, top, 3.0, cig_h), Color(0.14, 0.12, 0.11, 0.9))  # char ring
		ci.draw_circle(ember, 9.0 * flick, Color(1.0, 0.35, 0.05, 0.20))
		ci.draw_circle(ember, 6.0, Color(1.0, 0.45, 0.08, 0.55 * flick))
		ci.draw_circle(ember, 3.4, Color(1.0, 0.85, 0.35, flick))
		ci.draw_circle(ember, 1.6, Color(1.0, 1.0, 0.9, 1.0))

		var pts: PackedVector2Array = PackedVector2Array()
		var n: int = 9
		for i in range(n + 1):
			var t: float = float(i) / float(n)
			var sy: float = ember.y - 5.0 - t * (h - 8.0)
			var sx: float = ember.x + sin(_cigarette_anim_t * 3.0 + t * TAU) * (2.5 + t * 6.0)
			pts.append(Vector2(sx, sy))
		ci.draw_polyline(pts, Color(0.85, 0.85, 0.9, 0.16), 2.0, true)


func _draw_collar_simple(ci: Control) -> void:
	# The original simplistic indicator: a "COLLAR" caption above a solid-colour square.
	var font: Font = ci.get_theme_default_font()
	if font:
		ci.draw_string(font, Vector2(2.0, 14.0), "COLLAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 1.0, 1.0, 0.7))
	ci.draw_rect(Rect2(2.0, 20.0, 28.0, 28.0), _collar_belt_color)


func _draw_cigarette_simple(ci: Control) -> void:
	# The original simplistic meter: a dark bar with a tan fill that shrinks from the left.
	var w: float = ci.size.x
	var h: float = ci.size.y
	var bar_w: float = 160.0
	var bx: float = (w - bar_w) * 0.5
	var by: float = h - 18.0
	ci.draw_rect(Rect2(bx, by, bar_w, 10.0), Color(0.0, 0.0, 0.0, 0.5))
	var frac: float = clampf(_cigarette_frac, 0.0, 1.0)
	ci.draw_rect(Rect2(bx + 2.0, by + 2.0, (bar_w - 4.0) * frac, 6.0), Color(0.85, 0.7, 0.55, 0.9))


func _draw_smoke_timer_panel() -> void:
	var ci: Control = _smoke_timer_panel
	var cvs: RID = ci.get_canvas_item()
	var w: float = ci.size.x
	var h: float = ci.size.y

	var bezel: StyleBoxFlat = StyleBoxFlat.new()
	bezel.bg_color = Color(0.06, 0.06, 0.07, 0.82)
	bezel.set_corner_radius_all(9)
	bezel.border_color = Color(0.5, 0.12, 0.12, 0.9)
	bezel.set_border_width_all(2)
	bezel.draw(cvs, Rect2(0.0, 0.0, w, h))

	var screen: StyleBoxFlat = StyleBoxFlat.new()
	screen.bg_color = Color(0.11, 0.02, 0.02, 0.9)
	screen.set_corner_radius_all(5)
	screen.draw(cvs, Rect2(5.0, 5.0, w - 10.0, h - 10.0))

	ci.draw_rect(Rect2(5.0, h * 0.5 - 1.0, w - 10.0, 2.0), Color(1.0, 0.2, 0.2, 0.06))  # faint scanline glow


func _update_damage_flash(delta: float) -> void:
	if _player_class_name == INFECTION_FLASH_CLASS:
		_update_infection_flash()
	elif _damage_flash_property != "" and _player and is_instance_valid(_player) and _damage_flash_property in _player:
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


func _update_infection_flash() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var infected: bool = "is_infected" in _player and bool(_player.get("is_infected"))
	var is_active: bool = "active" in _player and bool(_player.get("active"))
	if infected and not is_active:  # is_infected flips instantly, but active only comes back after the ~5s transformation anim -- flash for exactly that window
		_damage_flash_alpha = DAMAGE_FLASH_PEAK_ALPHA


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
	_collar_belt.visible = false
	_cigarette_hud.visible = false
	_smoke_timer_panel.visible = false


func _update_collar_indicator() -> void:
	if _player_class_name != &"ExplodingCollarRacePlayer" or _player == null or not is_instance_valid(_player):
		_collar_belt.visible = false
		return
	if not ("collar_light_material" in _player):
		_collar_belt.visible = false
		return
	var mat = _player.get("collar_light_material")
	if mat == null:
		_collar_belt.visible = false
		return
	_collar_belt_color = (mat as StandardMaterial3D).albedo_color
	_collar_belt_pulse += get_process_delta_time() * 6.5
	_collar_belt.visible = true
	_collar_belt.queue_redraw()


func _update_smoke_break_hud() -> void:
	if _player_class_name != &"SmokeBreakPlayer" or _player == null or not is_instance_valid(_player) or not ("cigarette_left" in _player):
		_cigarette_hud.visible = false
		_smoke_timer_panel.visible = false
		return
	_cigarette_frac = clampf(float(_player.get("cigarette_left")), 0.0, 1.0)
	_cigarette_anim_t += get_process_delta_time()
	_cigarette_hud.visible = true
	_cigarette_hud.queue_redraw()
	_update_smoke_break_timer()


func _update_smoke_break_timer() -> void:
	# Mirror the minigame's own countdown Label3D (kept in sync on every peer via its
	# call_local tick RPC) so the HUD timer reads identically on host and clients.
	if _smoke_timer_source == null or not is_instance_valid(_smoke_timer_source):
		_smoke_timer_source = _find_smoke_timer_label()
	var txt: String = ""
	if _smoke_timer_source != null and is_instance_valid(_smoke_timer_source):
		txt = String(_smoke_timer_source.get("text"))
	if txt == "":
		_smoke_timer_panel.visible = false
		return
	_smoke_timer_label.text = txt
	_smoke_timer_panel.visible = true
	_smoke_timer_panel.queue_redraw()


func _find_smoke_timer_label() -> Node:
	var cur: Node = _player
	while cur != null:
		if "timer_label" in cur:
			var tl = cur.get("timer_label")
			if tl != null and is_instance_valid(tl):
				return tl
		cur = cur.get_parent()
	return null


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
	var game_cam := _find_game_camera()  # the minigame's own overview Camera3D -- the exact view vanilla shows
	if game_cam == null and _orig_camera != null and is_instance_valid(_orig_camera):
		game_cam = _orig_camera
	if game_cam and is_instance_valid(game_cam):
		game_cam.current = true
		return
	var fallback := _find_fallback_camera()
	if fallback:
		fallback.current = true
		print("[fpv_mod] original camera was gone on restore -- fell back to ", fallback.get_path())
	else:
		print("[fpv_mod] WARNING: no camera found anywhere to restore -- view may go blank")


func _find_game_camera(prefer_spectator: bool = false) -> Camera3D:
	# Walk from the local player up to its Minigame node and return the Camera3D it owns (exported as
	# `camera` in most games, `camera_3d` in exploding_collar_race/escalator_pit). These minigames
	# never switch cameras on death, so this is the exact 3rd-person view the game shows a dead player
	# -- explicitly re-asserting it avoids Godot's unreliable current-camera fallback landing on a
	# wrong node (the "weird angle" on the spectate hand-off).
	# prefer_spectator (death only): Duck Hunt's gameplay camera is a per-player first-person-ish cam,
	# and the minigame owns a separate wide `backup_camera` for spectating -- prefer that on death, but
	# NOT on a normal camera restore (toggling FPV off while alive should keep the gameplay view).
	var props: Array = ["camera", "camera_3d"]
	if prefer_spectator:
		props = ["backup_camera", "spectate_camera", "camera", "camera_3d"]
	var cur: Node = _player
	while cur != null and is_instance_valid(cur):
		if _script_is_or_extends(cur.get_script(), &"Minigame"):
			# Read the camera only off the Minigame node itself, never an intermediate player node
			# (some first-person games hang a per-player camera off the player -- not what we want).
			for prop in props:
				if prop in cur:
					var cam = cur.get(prop)
					if cam is Camera3D and is_instance_valid(cam) and cam != _camera:
						return cam as Camera3D
			return null  # this minigame exports no matching camera -> caller falls back to _orig_camera
		cur = cur.get_parent()
	return null


func _find_fallback_camera() -> Camera3D:
	var tree := get_tree()
	if tree == null:
		return null
	var current_cam := _find_camera_in(tree.root, tree.root, true)  # prefer a camera the game marked current -- a bare DFS can land on an unused per-player rig camera first
	if current_cam:
		return current_cam
	return _find_camera_in(tree.root, tree.root, false)


func _find_camera_in(n: Node, root_viewport: Window, require_current: bool) -> Camera3D:
	if n is Camera3D and n != _camera and n.get_viewport() == root_viewport:
		if not require_current or (n as Camera3D).current:
			return n as Camera3D
	for ch in n.get_children():
		var found := _find_camera_in(ch, root_viewport, require_current)
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
	_update_secret_level_floor(delta)

	if _process_lobby_fpv(delta):
		return

	if not enabled:
		return

	_accum += delta
	var armature_swapped := not _dying and _skeleton != null and is_instance_valid(_skeleton) and not _skeleton.is_visible_in_tree()
	if _accum >= RESCAN_IV or _player == null or not is_instance_valid(_player) or armature_swapped:
		_accum = 0.0
		_rescan_player()

	if _yaw_reseed_pending:
		_yaw_reseed_timer += delta
		if _ever_active or _yaw_reseed_timer >= YAW_RESEED_DELAY:
			_yaw_reseed_pending = false
			if not _ever_active and _player != null and is_instance_valid(_player):
				_seed_yaw(CAMERA_TUNING_OVERRIDES.get(_player_class_name, {}))

	var have_rig := (_player != null and is_instance_valid(_player)
		and _skeleton != null and is_instance_valid(_skeleton) and _head_bone_idx >= 0)
	var active := have_rig and _player_is_active()

	# Forklift: the ONLY time the forklift leaves first person is the crane "take the package away"
	# tie scene -- the between-round crate removal (crate_manager.remove_indicies_after_move is
	# non-empty on every peer). Turn FPV fully off for it, then resume. A normal kill/elimination
	# is NOT this scene, so it falls through and stays in FPV (death-cam "stay") like every other game.
	if have_rig and _player_class_name == &"ForkliftCertifiedVehicle":
		if _is_forklift_crate_pickup_active():
			_forklift_third_person_handoff()
			return
		elif _forklift_third_person_active:
			_forklift_third_person_active = false
			_snap_head_smoothing = true
			_end_death_cam()  # package scene over -- back into the normal FPV / death-cam flow

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
		# Recycle: survivors are set inactive at round end while the round's loser is crushed. That is
		# NOT death for them -- keep them in first person until their OWN is_dead flips. Isolated to
		# Recycle; leaves every other minigame's death cam untouched.
		if (_player_class_name == &"BurnRecyclePlayer" and _ever_active
				and not ("is_dead" in _player and bool(_player.get("is_dead")))):
			_update_mouse_capture()
			_render_head_cam(delta, false)
			return
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

	if active:
		_update_manual_relock()

	if _follow_rig_yaw and _visuals and is_instance_valid(_visuals):
		_yaw = _visuals.global_rotation.y + _follow_yaw_base + _look_yaw_offset

	var head_xform: Transform3D = _skeleton.global_transform * _skeleton.get_bone_global_pose(_head_bone_idx)
	var look_basis := Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch)

	var target_head_pos: Vector3
	if _player_class_name == &"SmokeBreakPlayer" and _smoke_break_cigarette_node != null and is_instance_valid(_smoke_break_cigarette_node):
		var cig_finished: bool = "finished" in _player and bool(_player.get("finished"))
		if cig_finished:
			if not _smoke_break_finish_locked:
				_smoke_break_finish_locked = true
				_smoke_break_locked_head_pos = _smoothed_head_pos  # freeze here -- cig_scale_parent keeps drifting into the torso through the crossed-hands finish anim
			target_head_pos = _smoke_break_locked_head_pos
		else:
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

	# (Forklift no longer reaches the death cam -- its between-round inactivity is intercepted in
	# _process and handed to 3rd person via _forklift_third_person_handoff.)

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
			elif _player_class_name == &"DuckHuntDuckPlayer":
				# Runner reached the exit and left (the duck node is hidden, not killed) -- there's no
				# corpse to watch, so turn FPV off straight to the game's spectator camera, like Minefield.
				_spectate_release("duck reached exit -> spectate")
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
	# Explicitly re-assert the game's own spectator/overview camera. These games never switch cameras
	# on death, so this is the exact vanilla 3rd-person view; don't trust Godot's current-camera
	# fallback. prefer_spectator picks Duck Hunt's wide `backup_camera` over its per-player duck cam.
	var game_cam := _find_game_camera(true)
	if game_cam == null and _orig_camera != null and is_instance_valid(_orig_camera):
		game_cam = _orig_camera  # cached at lock = the same minigame camera
	if game_cam == null:
		game_cam = _find_fallback_camera()
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


func _forklift_third_person_handoff() -> void:
	# Release first person to the game's own camera for the whole between-round window and leave it
	# there (don't re-assert FPV each frame), so the crane cutscene plays in normal 3rd person.
	if _forklift_third_person_active:
		return
	_forklift_third_person_active = true
	_was_active = false
	_end_death_cam()
	_restore_camera_or_fallback()  # forklift never swaps cameras, so this is the normal 3rd-person view
	if _mouse_captured_by_us:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_mouse_captured_by_us = false
	print("[fpv_mod] forklift inactive (round transition / crate cutscene) -- handed to 3rd person")


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



func _seed_yaw(tuning: Dictionary) -> void:
	if "scene_rotation" in _player:
		_movement_base_yaw = deg_to_rad(float(_player.get("scene_rotation")))
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
	_look_yaw_offset = 0.0


func _update_manual_relock() -> void:
	if not experimental_manual_relock_enabled or _movement_rotate_active:
		_relock_key_was_down = false
		return
	if _player == null or not is_instance_valid(_player):
		_relock_key_was_down = false
		return

	var down := Input.is_key_pressed(MANUAL_RELOCK_KEY)
	if not down:
		var dev := _look_joypad_device()
		if dev >= 0 and Input.is_joy_button_pressed(dev, JOY_BUTTON_LEFT_SHOULDER):
			down = true

	if down and not _relock_key_was_down:
		_seed_yaw(CAMERA_TUNING_OVERRIDES.get(_player_class_name, {}))
		print("[fpv_mod] manual re-lock: view re-centered for '", _player_class_name, "'")
	_relock_key_was_down = down


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
		_smoke_break_finish_locked = false
		_smoke_timer_source = null
		if _player_class_name == &"SmokeBreakPlayer" and "anim_handler" in player_node:
			var anim_h = player_node.get("anim_handler")
			if anim_h and is_instance_valid(anim_h) and "cig_scale_parent" in anim_h:
				_smoke_break_cigarette_node = anim_h.get("cig_scale_parent")

		_forklift_crate_manager = null
		_forklift_third_person_active = false
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

		_seed_yaw(tuning)
		_yaw_reseed_pending = true
		_yaw_reseed_timer = 0.0

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
			"hud_in_depth": hud_in_depth,
			"experimental_manual_relock_enabled": experimental_manual_relock_enabled,
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
		hud_in_depth = bool(parsed.get("hud_in_depth", true))
		experimental_manual_relock_enabled = bool(parsed.get("experimental_manual_relock_enabled", false))
		var legacy: float = float(parsed.get("sensitivity_mult", 1.0))
		_mouse_sensitivity_mult = float(parsed.get("mouse_sensitivity_mult", legacy))
		_controller_sensitivity_mult = float(parsed.get("controller_sensitivity_mult", legacy))
