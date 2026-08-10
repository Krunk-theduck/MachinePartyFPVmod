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
# Inside Job (KnifeAtTheOffice): the infected/mutated player gets a GREEN overlay (their infection),
# held the WHOLE time they're infected -- not the red one. Mid-light green, a touch above mid brightness.
const INFECTION_FLASH_COLOR := Color(0.34, 0.72, 0.42)
const INFECTION_FLASH_ALPHA := 0.45  # steady overlay opacity while infected/mutated (persistent, not a flash)

const DAMAGE_SHAKE_MAGNITUDE := 0.10  # world units, peak random jitter right after a hit
const DAMAGE_SHAKE_DECAY := 7.0       # faster than DAMAGE_FLASH_DECAY -- a jolt, not a wobble

# Smoke Break: a hands/head tremor that grows as you inhale (the game's `drag_progress` 0..1, choke at
# >1). It stays calm early and ramps up hard near the top so you feel "stop now" before you choke.
const SMOKE_SHAKE_START := 0.35       # drag_progress below this = no shake (a calm deadzone)
const SMOKE_SHAKE_MAX := 0.085        # world units, peak jitter as drag_progress approaches 1.0

const ONE_LIFE_OVERLAY_COLOR := Color(0.6, 0.0, 0.0)
const INFECTION_OVERLAY_COLOR := Color(0.14, 0.55, 0.26)  # green twin of the blood vignette (Inside Job)
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
const DUCK_ESCAPE_BLACK_HOLD := 0.8  # Duck Hunt runner escapes: hold black this long (covering the game's own fade) before cutting to spectate, so no weird angle flashes
# Fallback for an unrecognized/unresolved class: ride the body ~3s then cut to third person. This is
# a SAFETY NET so a client that fails to resolve the player's class can never get stuck riding the hat
# forever ("stay" never auto-spectates). Every game that should truly stay is listed explicitly above.
const DEATH_BEHAVIOR_DEFAULT: Dictionary = {"mode": &"corpse", "delay": 3.0}
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
	&"ForkliftCertifiedVehicle":  {"mode": &"corpse", "delay": 3.0},                     # Forklift: eliminated -> ride body 3s -> spectate
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

# Firearm Factory: the big inward-facing "fog_catcher" box (a direct child of the minigame) has no
# material, so it renders solid white -- invisible to the framed 3rd-person cam but a blank wall in
# FPV. Retexture it with the room's own "metal seawall" wall texture.
# Firearm Factory's -X side is open (no wall -> skybox in FPV). Source review: the ONLY mesh using the
# room's "brick wall1" texture is `blockout mesh` (the play-area shell); its brick surface IS the walls
# the player sees, window openings and all. We lift just that surface's +X-facing wall triangles (the
# openings are gaps in the mesh, so they come along) and mirror them 180deg about the shell centre onto
# the open -X side. Exact same brick + real windows, no clutter. Client-side, FPV-only.
const GUN_WALL_ART_ROOT := "manufacture gun artwork pass2"
const GUN_WALL_SHELL_MESH := "blockout mesh"  # its brick-wall surface holds the actual walls + windows
const GUN_WALL_CLONE_NAME := "fpv_added_wall"
const GUN_WALL_MINX := 2.5  # only copy triangles whose whole footprint is past this local x -- that's the +X wall the player faces, not the side walls (whose bodies run back to low x). We TRANSLATE (not mirror) this copy straight across to the empty -X side, so the real wall lands faithfully -- windows, brick material and all -- with no inversion.
const GUN_WALL_CLOSER := 1.6  # shift the copied wall this much toward the play area (+x)
const GUN_WALL_ENABLED := true
const GUN_WALL_PROBE := false  # flip true to log the art mesh under the FPV crosshair

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
var _smoke_timer_source: Node = null # the minigame's own timer label we mirror (kept in sync on every peer)
var _round_timer_green: bool = false  # true = Forklift (green digits/bezel), false = Smoke Break (red)
var _gun_wall_clone: Node3D = null  # group node holding our mirrored window-wall clones (empty -X side)
var _gun_wall_logged: bool = false  # one-shot diagnostic if we can't find a source wall to duplicate

var _recipe_hud: Control                             # Firearm Factory recipe HUD (top-center), custom-drawn
var _recipe_seq: PackedInt32Array = PackedInt32Array()  # ordered item ids (1..5) of the local recipe
var _recipe_index: int = -1                          # current step / done-count; steps before it are fulfilled
var _recipe_done: bool = false                       # gun fully assembled
var mod_dir: String = ""                             # set by main.gd -- where the mod (and its textures) live
const RECIPE_ANIM_FPS := 3.0                         # recipe sprite animation speed
const RECIPE_FRAME_PX := 96                          # downscale target: pixels per animation frame
const RED_STROBE_SPEED := 3.2                        # slow strobe of the red light under the pending item
# Each item's sprite SHEET: file + grid (cols x rows), frames read row-major.
const RECIPE_ITEM_SHEETS := {
	1: {"file": "gear.png", "cols": 4, "rows": 4},
	2: {"file": "pipe.png", "cols": 2, "rows": 1},
	3: {"file": "glue.png", "cols": 2, "rows": 1},
	4: {"file": "strapped.png", "cols": 2, "rows": 2},
	5: {"file": "spring.png", "cols": 4, "rows": 2},
}
var _recipe_tex: Dictionary = {}                     # item_id -> full-colour sheet (drawn while pending)
var _recipe_tex_grey: Dictionary = {}                # item_id -> greyscale sheet (drawn once fulfilled)
var _recipe_frozen: Dictionary = {}                  # slot index -> true once its anim has parked at frame 0
var _recipe_anim_time: float = 0.0
var _recipe_gun_tex: Texture2D = null                # gun.png: 2 frames (ready | reloading), drawn on the bar
var _recipe_gun_mode: bool = false                   # local player is holding the built gun -> special bar
var _recipe_gun_reloading: bool = false
var _recipe_gun_reload_frac: float = 1.0             # 0..1 reload progress

# --- Spectator system (engages only once we've released to spectate; never touches live play) ---
const SPEC_MODE_THIRD := 0
const SPEC_MODE_FPV := 1
const SPEC_MODE_FREEFLY := 2
const SPEC_FREEFLY_SPEED := 16.0    # base free-fly move speed (units/sec)
const SPEC_FREEFLY_LOOK := 0.0035   # free-fly mouse look sensitivity (rad/pixel)
const SPEC_FREEFLY_PAD_LOOK := 2.8  # free-fly controller right-stick look (rad/sec at full tilt)
const SPEC_PAD_MOVE_DEADZONE := 0.18
const SPEC_HEAD_SMOOTHING := 20.0   # FPV-spectate head follow rate (tight but de-jittered)
var _spec_engaged: bool = false     # my spectate system is active (I'm dead + spectating a live round)
var _spec_mode: int = SPEC_MODE_THIRD  # third-person is the default
var _spec_cam: Camera3D = null      # my own spectator camera (created on engage, freed on disengage)
var _spec_target: Node = null       # the player node I'm currently watching
var _spec_targets: Array = []       # living player nodes to cycle through (rebuilt periodically)
var _spec_rebuild_accum: float = 0.0
var _spec_freefly_pos: Vector3 = Vector3.ZERO
var _spec_freefly_yaw: float = 0.0
var _spec_freefly_pitch: float = 0.0
var _spec_font: Font = null
var _spec_toggle_btn: Button = null   # top-right: "Switch to FPV view" / "Switch to third person"
var _spec_freefly_btn: Button = null  # under the toggle: enable free-fly
var _spec_name_panel: Control = null  # bottom-center: spectated name + role + prev/next arrows
var _spec_name_label: Label = null
var _spec_role_label: Label = null
var _spec_prev_btn: Button = null
var _spec_next_btn: Button = null
var _spec_look_hint: Label = null     # "hold Shift / LB to look around" shown in FPV-spectate
var _spec_spawn_pos: Vector3 = Vector3.ZERO   # local player's spawn point (free-fly start)
var _spec_spawn_captured: bool = false
var _spec_grabbed_mouse: bool = false         # we captured the mouse for free-fly look
var _spec_mg: Node = null                     # the minigame we're spectating (captured at engage)
var _spec_smoothed_head: Vector3 = Vector3.ZERO  # FPV-spectate head smoothing (mirrors real FPV)
var _spec_snap_head: bool = false             # snap (don't glide) on target/mode change
var _spec_hidden_skel: Skeleton3D = null      # the spectated skeleton whose head we're hiding
var _spec_hidden_idx: int = -1
var _spec_hidden_orig_scale: Vector3 = Vector3.ONE
var _pad_edge: Dictionary = {}                # per-button held-state for controller edge detection
var _last_input_was_pad: bool = false         # live input-device detection (drives UI button hints)
var _spec_pad_ui_state: int = -1              # cached pad/mouse state the spectate labels reflect
var _spec_look_yaw: float = 0.0               # FPV-spectate self-look offset from the body's forward
var _spec_look_pitch: float = 0.0
var _spec_look_rel: Vector2 = Vector2.ZERO    # mouse motion accumulated while Shift-looking
var _spec_end_accum: float = 0.0              # hysteresis: a 1-frame blip can't end spectate/free-cam
var _spec_shared_dist: float = 12.0           # shared-camera games: base cam distance (captured once)
var _spec_shared_captured: bool = false
var _stay_fpv_active: bool = false            # inactive-but-not-dead FPV (finished/between-rounds): allow look
var _was_infected: bool = false               # edge-detect the stab to flash the infection overlay once
var _spec_hunter_ref: Node = null             # Duck Hunt hunter whose laser/scope we've locally tweaked

# --- Mod-to-mod look networking (exact FPV look-around when the spectated player also has the mod) ---
# The base game replicates body yaw + position but NOT the mod's independent head look. Mod peers
# announce themselves (harmless no-op on non-mod peers) and then stream their look to each other
# only; a spectated player without the mod simply has no data and gets the head-view fallback.
const FPV_NET_BCAST_IV := 0.05   # 20 Hz look stream
const FPV_NET_HELLO_IV := 3.0    # re-announce presence (also finds late joiners)
const FPV_NET_STALE := 0.4       # look data older than this -> fall back to head-view
var _net_time: float = 0.0
var _net_bcast_accum: float = 0.0
var _net_hello_accum: float = 0.0
var _fpv_mod_peers: Dictionary = {}   # peer_id -> true (peers confirmed running this mod)
var _fpv_looks: Dictionary = {}       # network_id -> {yaw, pitch, t} broadcast look
var _gun_probe_last: String = ""  # last art-mesh name the crosshair probe reported (log only on change)
var _gun_probe_accum: float = 0.0  # throttle timer for the crosshair probe

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
var _hud_in_depth_toggle: Button = null

var _fpv_settings_button: Button = null
var _fpv_settings_popup: PopupPanel = null

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

	# Prune mod peers when they leave, so we never stream look data into the void.
	var mp := multiplayer
	if mp != null and not mp.peer_disconnected.is_connected(_fpv_on_peer_left):
		mp.peer_disconnected.connect(_fpv_on_peer_left)



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

	# --- Firearm Factory recipe HUD (top-center, custom-drawn pixel-art items) ---
	_recipe_hud = Control.new()
	_recipe_hud.name = "FirstPersonViewRecipeHud"
	_recipe_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_recipe_hud.anchor_left = 0.5
	_recipe_hud.anchor_right = 0.5
	_recipe_hud.anchor_top = 0.0
	_recipe_hud.anchor_bottom = 0.0
	_recipe_hud.offset_left = -172
	_recipe_hud.offset_right = 172
	_recipe_hud.offset_top = 12
	_recipe_hud.offset_bottom = 92
	_recipe_hud.visible = false
	_recipe_hud.draw.connect(_draw_recipe_hud)
	_crosshair_layer.add_child(_recipe_hud)
	_load_recipe_textures()

	_death_black_rect = ColorRect.new()
	_death_black_rect.name = "FirstPersonViewDeathBlack"
	_death_black_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_black_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_crosshair_layer.add_child(_death_black_rect)

	# Spectator UI sits ABOVE the death-black rect so its buttons stay clickable during spectate.
	_create_spectate_ui()


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

	var edge: Color = Color(0.13, 0.5, 0.16, 0.9) if _round_timer_green else Color(0.5, 0.12, 0.12, 0.9)
	var screen_bg: Color = Color(0.02, 0.11, 0.03, 0.9) if _round_timer_green else Color(0.11, 0.02, 0.02, 0.9)
	var scan: Color = Color(0.2, 1.0, 0.3, 0.06) if _round_timer_green else Color(1.0, 0.2, 0.2, 0.06)

	var bezel: StyleBoxFlat = StyleBoxFlat.new()
	bezel.bg_color = Color(0.06, 0.06, 0.07, 0.82)
	bezel.set_corner_radius_all(9)
	bezel.border_color = edge
	bezel.set_border_width_all(2)
	bezel.draw(cvs, Rect2(0.0, 0.0, w, h))

	var screen: StyleBoxFlat = StyleBoxFlat.new()
	screen.bg_color = screen_bg
	screen.set_corner_radius_all(5)
	screen.draw(cvs, Rect2(5.0, 5.0, w - 10.0, h - 10.0))

	ci.draw_rect(Rect2(5.0, h * 0.5 - 1.0, w - 10.0, 2.0), scan)  # faint scanline glow


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
		var fc: Color = INFECTION_FLASH_COLOR if _player_class_name == INFECTION_FLASH_CLASS else DAMAGE_FLASH_COLOR
		_damage_flash_rect.color = Color(fc.r, fc.g, fc.b, _damage_flash_alpha)

	if _damage_shake_magnitude > 0.0:
		_damage_shake_magnitude *= exp(-delta * DAMAGE_SHAKE_DECAY)
		if _damage_shake_magnitude < 0.002:
			_damage_shake_magnitude = 0.0

	_update_one_life_overlay(delta)


func _update_infection_flash() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	# ONLY the actually-mutated player, never the syringe carrier. The game sets is_infected true both
	# when you're stabbed (infected_rpc) AND for whoever holds the syringe (set_has_item_rpc), so we
	# exclude the holder via is_holding_syringe. is_infected latches at the stab and never reverts.
	var infected: bool = ("is_infected" in _player and bool(_player.get("is_infected"))) \
		and not ("is_holding_syringe" in _player and bool(_player.get("is_holding_syringe")))
	# 1:1 with the blood overlay, just green: the flash+shake fires the instant you're stabbed (exactly
	# like taking a hit) and then decays; the ongoing green is the pulsing vignette (see the one-life
	# overlay), so we do NOT hold a flat tint here anymore.
	if infected and not _was_infected:
		_damage_flash_alpha = DAMAGE_FLASH_PEAK_ALPHA
		_damage_shake_magnitude = DAMAGE_SHAKE_MAGNITUDE
	_was_infected = infected


func _update_one_life_overlay(delta: float) -> void:
	# The pulsing vignette IS the blood overlay. Infection reuses it verbatim, only green: while you're
	# the mutated player (not the syringe carrier) it pulses green; at one life it pulses red.
	var infected: bool = _player_class_name == INFECTION_FLASH_CLASS \
		and _player != null and is_instance_valid(_player) \
		and ("is_infected" in _player and bool(_player.get("is_infected"))) \
		and not ("is_holding_syringe" in _player and bool(_player.get("is_holding_syringe")))
	var one_life: bool = _damage_flash_property != "" and _damage_flash_last_value == 1
	var show: bool = infected or one_life
	_one_life_overlay.visible = show
	if not show:
		return
	var vcol: Color = INFECTION_OVERLAY_COLOR if infected else ONE_LIFE_OVERLAY_COLOR
	_one_life_overlay_material.set_shader_parameter("vignette_color", vcol)
	_one_life_pulse_time += delta * ONE_LIFE_OVERLAY_PULSE_SPEED
	var t: float = (sin(_one_life_pulse_time) + 1.0) * 0.5  # 0..1
	var alpha: float = lerp(ONE_LIFE_OVERLAY_MIN_ALPHA, ONE_LIFE_OVERLAY_MAX_ALPHA, t)
	_one_life_overlay_material.set_shader_parameter("vignette_alpha", alpha)


func _compute_damage_shake_offset() -> Vector3:
	if _damage_shake_magnitude <= 0.0:
		return Vector3.ZERO
	var right: Vector3 = Basis(Vector3.UP, _yaw) * Vector3.RIGHT
	return (right * (-1.0 + randf() * 2.0) + Vector3.UP * (-1.0 + randf() * 2.0)) * _damage_shake_magnitude


func _compute_smoke_shake_offset() -> Vector3:
	# Smoke Break only: scale a jitter by how deep the current drag is (drag_progress 0..1). Grows
	# quadratically so it's subtle mid-drag and unmistakable right before the choke at 1.0.
	if _player_class_name != &"SmokeBreakPlayer" or _player == null or not is_instance_valid(_player):
		return Vector3.ZERO
	if not ("drag_progress" in _player):
		return Vector3.ZERO
	var dp: float = clampf(float(_player.get("drag_progress")), 0.0, 1.0)
	if dp <= SMOKE_SHAKE_START:
		return Vector3.ZERO
	var t: float = (dp - SMOKE_SHAKE_START) / (1.0 - SMOKE_SHAKE_START)  # 0..1 across the danger band
	var mag: float = t * t * SMOKE_SHAKE_MAX
	var right: Vector3 = Basis(Vector3.UP, _yaw) * Vector3.RIGHT
	return (right * (-1.0 + randf() * 2.0) + Vector3.UP * (-1.0 + randf() * 2.0)) * mag


func _is_player_class(target: StringName) -> bool:
	# True if the tracked player is `target`. Falls back to the SKELETON's owning player when the
	# cached class name is stale (can happen on a client right at a round transition), so per-class
	# behaviors (e.g. Recycle staying in FPV through ranking) hold up regardless.
	if _player_class_name == target:
		return true
	if _skeleton != null and is_instance_valid(_skeleton):
		var cur: Node = _skeleton
		while cur != null:
			var sc: Script = cur.get_script()
			if sc and sc.get_global_name() == target:
				return true
			cur = cur.get_parent()
	return false


func _hide_class_specific_hud() -> void:
	_one_life_overlay.visible = false
	_collar_belt.visible = false
	_cigarette_hud.visible = false
	_smoke_timer_panel.visible = false
	if _recipe_hud:
		_recipe_hud.visible = false


func _update_recipe_hud() -> void:
	# Firearm Factory only: read the LOCAL player's recipe off its workstation (client-safe, read-only)
	# and show it top-centre. All accesses guarded so the init window / other classes just hide the HUD.
	if _player_class_name != &"ManufactureGunPlayer" or _player == null or not is_instance_valid(_player):
		_recipe_hud.visible = false
		return
	# Once the LOCAL player has built & is holding the gun, swap the recipe bar for the special gun bar.
	if "has_gun" in _player and bool(_player.get("has_gun")):
		_recipe_gun_mode = true
		var cd: float = float(_player.get("shoot_cooldown_timer")) if "shoot_cooldown_timer" in _player else 0.0
		var maxcd: float = float(_player.get("shoot_cooldown")) if "shoot_cooldown" in _player else 3.0
		_recipe_gun_reloading = cd > 0.0
		_recipe_gun_reload_frac = clampf(1.0 - cd / maxf(maxcd, 0.01), 0.0, 1.0)
		_recipe_hud.visible = true
		_recipe_hud.queue_redraw()
		return
	_recipe_gun_mode = false
	if not ("game_instance" in _player):
		_recipe_hud.visible = false
		return
	var gi = _player.get("game_instance")
	if gi == null or not is_instance_valid(gi) or not ("workstation" in gi):
		_recipe_hud.visible = false
		return
	var ws = gi.get("workstation")
	if ws == null or not is_instance_valid(ws) or not ("item_sequence" in ws) or not ("current_item_sequence_index" in ws):
		_recipe_hud.visible = false
		return
	var seq = ws.get("item_sequence")
	if not (seq is Array) or (seq as Array).is_empty():
		_recipe_hud.visible = false
		return
	_recipe_seq = PackedInt32Array(seq as Array)
	_recipe_index = int(ws.get("current_item_sequence_index"))
	_recipe_done = ("has_gun" in ws) and bool(ws.get("has_gun"))
	_recipe_hud.visible = true
	_recipe_hud.queue_redraw()


func _draw_recipe_hud() -> void:
	# A black bar of dark-grey slots (one per recipe step). The current step shows its item as translucent
	# grey pixel art; finished steps show it in solid real colour; later steps stay hidden (revealed one
	# at a time, like the in-world holo recipe).
	var ci: Control = _recipe_hud
	if _recipe_gun_mode:
		_draw_gun_bar(ci)
		return
	var n: int = _recipe_seq.size()
	if n <= 0:
		return
	var w: float = ci.size.x
	var h: float = ci.size.y
	ci.draw_rect(Rect2(0.0, 0.0, w, h), Color(0.03, 0.03, 0.04, 0.82))
	ci.draw_rect(Rect2(0.0, 0.0, w, h), Color(0.0, 0.0, 0.0, 0.95), false, 2.0)
	var pad: float = 8.0
	var gap: float = 6.0
	var sq: float = (w - pad * 2.0 - gap * float(n - 1)) / float(n)
	var top: float = (h - sq) * 0.5
	for i in n:
		var x: float = pad + float(i) * (sq + gap)
		var r := Rect2(x, top, sq, sq)
		ci.draw_rect(r, Color(0.15, 0.15, 0.17, 1.0))            # dark-grey slot
		ci.draw_rect(r, Color(0.30, 0.30, 0.34, 1.0), false, 2.0)
		var fulfilled: bool = (i < _recipe_index) or _recipe_done
		if fulfilled:
			_draw_recipe_item(ci, i, _recipe_seq[i], r, true)
		elif i == _recipe_index:
			_draw_recipe_item(ci, i, _recipe_seq[i], r, false)
			_draw_recipe_red_bar(ci, r)  # slow strobing red light under the item you still need
		# later steps: leave the slot empty (revealed one at a time)


func _draw_recipe_red_bar(ci: Control, r: Rect2) -> void:
	var t: float = 0.5 + 0.5 * sin(_recipe_anim_time * RED_STROBE_SPEED)  # 0..1, slow
	var a: float = lerpf(0.22, 0.9, t)
	var bh: float = 5.0
	var y: float = r.position.y + r.size.y - bh - 1.0
	var x: float = r.position.x + 3.0
	var bw: float = r.size.x - 6.0
	ci.draw_rect(Rect2(x - 2.0, y - 2.0, bw + 4.0, bh + 4.0), Color(0.9, 0.1, 0.05, a * 0.35))  # glow
	ci.draw_rect(Rect2(x, y, bw, bh), Color(0.85, 0.12, 0.08, a))                                # core
	ci.draw_rect(Rect2(x, y + bh * 0.32, bw, bh * 0.32), Color(1.0, 0.55, 0.45, a))              # hot centre


func _draw_gun_bar(ci: Control) -> void:
	var w: float = ci.size.x
	var h: float = ci.size.y
	var reloading: bool = _recipe_gun_reloading
	# Black background = same as the gun sprite's own background, so the sprite blends seamlessly.
	ci.draw_rect(Rect2(0.0, 0.0, w, h), Color(0.0, 0.0, 0.0, 0.94))
	# Thin red outline (gently pulsing).
	var pulse: float = 0.68 + 0.32 * (0.5 + 0.5 * sin(_recipe_anim_time * RED_STROBE_SPEED))
	ci.draw_rect(Rect2(0.0, 0.0, w, h), Color(0.85, 0.12, 0.1, pulse), false, 2.0)
	# Gun sprite: frame 0 = plain (ready), frame 1 = red-lit (reloading). Larger now.
	if _recipe_gun_tex != null:
		var frame: int = 1 if reloading else 0
		var fw: float = float(_recipe_gun_tex.get_width()) * 0.5
		var fh: float = float(_recipe_gun_tex.get_height())
		var src := Rect2(float(frame) * fw, 0.0, fw, fh)
		var scale: float = minf((w * 0.96) / fw, (h * 0.66) / fh)
		var dw: float = fw * scale
		var dh: float = fh * scale
		ci.draw_texture_rect_region(_recipe_gun_tex, Rect2((w - dw) * 0.5, 4.0, dw, dh), src, Color(1, 1, 1, 1))
	# Status text (red theme): READY light red, RELOADING solid red.
	var label: String = "RELOADING" if reloading else "READY"
	var col: Color = Color(0.95, 0.24, 0.18) if reloading else Color(1.0, 0.5, 0.42)
	var font: Font = _spec_font if _spec_font != null else ThemeDB.fallback_font
	ci.draw_string(font, Vector2(0.0, h - 7.0), label, HORIZONTAL_ALIGNMENT_CENTER, w, 15, col)
	# Reload progress bar (red).
	if reloading:
		ci.draw_rect(Rect2(8.0, h - 4.0, w - 16.0, 2.0), Color(0.25, 0.05, 0.04, 0.9))
		ci.draw_rect(Rect2(8.0, h - 4.0, (w - 16.0) * _recipe_gun_reload_frac, 2.0), Color(0.95, 0.18, 0.12, 0.98))


func _recipe_col(c: Color, solid: bool) -> Color:
	# Fulfilled -> the item's true colour; still-needed -> a translucent grey (keeps internal shading).
	if solid:
		return Color(c.r, c.g, c.b, 1.0)
	var g: float = c.get_luminance()
	return Color(g, g, g, 0.5)


func _load_recipe_textures() -> void:
	if mod_dir == "":
		print("[fpv_mod] recipe textures: mod_dir not set -- using drawn icons")
		return
	var loaded: int = 0
	for item_id in RECIPE_ITEM_SHEETS:
		var cfg: Dictionary = RECIPE_ITEM_SHEETS[item_id]
		var img := _load_recipe_img(String(cfg["file"]), int(cfg["cols"]))
		if img != null:
			_recipe_tex[item_id] = ImageTexture.create_from_image(img)   # full colour (pending)
			_recipe_tex_grey[item_id] = _greyscale_texture(img)          # grey (fulfilled)
			loaded += 1
	var gun_img := _load_recipe_img("gun.png", 3)  # 2 frames; kept in colour, drawn on the dark gun bar
	if gun_img != null:
		_recipe_gun_tex = ImageTexture.create_from_image(gun_img)
	print("[fpv_mod] recipe sprites loaded: ", loaded, "/", RECIPE_ITEM_SHEETS.size(), " gun=", _recipe_gun_tex != null)


func _load_recipe_img(fname: String, cols: int) -> Image:
	var path: String = mod_dir.path_join("textures").path_join("recipe").path_join(fname)
	var img := Image.new()
	if img.load(path) != OK:
		return null
	var tw: int = maxi(cols, 1) * RECIPE_FRAME_PX
	var th: int = int(round(float(tw) * float(img.get_height()) / float(img.get_width())))
	img.resize(tw, maxi(th, 1), Image.INTERPOLATE_LANCZOS)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


func _greyscale_texture(src: Image) -> Texture2D:
	var data: PackedByteArray = src.get_data()  # a copy
	var i: int = 0
	var n: int = data.size()
	while i + 3 < n:
		var l: int = int(0.299 * float(data[i]) + 0.587 * float(data[i + 1]) + 0.114 * float(data[i + 2]))
		data[i] = l
		data[i + 1] = l
		data[i + 2] = l
		i += 4
	var out := Image.create_from_data(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8, data)
	return ImageTexture.create_from_image(out)


func _draw_recipe_item(ci: Control, slot: int, item_id: int, r: Rect2, fulfilled: bool) -> void:
	if _draw_recipe_sprite(ci, slot, item_id, r, fulfilled):
		return
	# Fallback (texture missing): the old drawn icons.
	var c: Vector2 = r.get_center()
	var s: float = minf(r.size.x, r.size.y) * 0.40
	match item_id:
		1: _draw_item_gear(ci, c, s, fulfilled)
		2: _draw_item_pipe(ci, c, s, fulfilled)
		3: _draw_item_glue(ci, c, s, fulfilled)
		4: _draw_item_strapped(ci, c, s, fulfilled)
		5: _draw_item_spring(ci, c, s, fulfilled)


func _draw_recipe_sprite(ci: Control, slot: int, item_id: int, r: Rect2, fulfilled: bool) -> bool:
	# Pending item = full colour; fulfilled = translucent greyscale.
	var tex: Texture2D = _recipe_tex_grey.get(item_id) if fulfilled else _recipe_tex.get(item_id)
	if tex == null or not RECIPE_ITEM_SHEETS.has(item_id):
		return false
	var cfg: Dictionary = RECIPE_ITEM_SHEETS[item_id]
	var cols: int = int(cfg["cols"])
	var rows: int = int(cfg["rows"])
	var frames: int = maxi(cols * rows, 1)
	var anim_frame: int = int(_recipe_anim_time * RECIPE_ANIM_FPS) % frames

	# Freeze-on-fulfill: a pending item loops; the instant it's fulfilled it keeps playing until the
	# animation next reaches the START frame (0), then parks there.
	var frame: int = anim_frame
	if fulfilled:
		if bool(_recipe_frozen.get(slot, false)):
			frame = 0
		elif anim_frame == 0:
			_recipe_frozen[slot] = true
			frame = 0
	else:
		_recipe_frozen.erase(slot)

	var fw: float = float(tex.get_width()) / float(cols)
	var fh: float = float(tex.get_height()) / float(rows)
	var inset: float = 1.0
	var src := Rect2(float(frame % cols) * fw + inset, float(frame / cols) * fh + inset, fw - inset * 2.0, fh - inset * 2.0)
	var tint: Color = Color(0.85, 0.86, 0.9, 0.45) if fulfilled else Color(1.0, 1.0, 1.0, 1.0)
	var scale: float = minf(r.size.x / fw, r.size.y / fh) * 1.06
	var dw: float = fw * scale
	var dh: float = fh * scale
	var cen: Vector2 = r.get_center()
	var dest := Rect2(cen.x - dw * 0.5, cen.y - dh * 0.5, dw, dh)
	ci.draw_texture_rect_region(tex, dest, src, tint)
	return true


func _draw_item_gear(ci: Control, c: Vector2, s: float, solid: bool) -> void:
	var steel: Color = _recipe_col(Color(0.72, 0.71, 0.68), solid)
	var dark: Color = _recipe_col(Color(0.44, 0.43, 0.41), solid)
	var hole: Color = _recipe_col(Color(0.20, 0.20, 0.19), solid)
	var tw: float = s * 0.36
	for k in 8:
		var ang: float = TAU * float(k) / 8.0
		var p: Vector2 = c + Vector2(cos(ang), sin(ang)) * (s * 0.92)
		ci.draw_rect(Rect2(p.x - tw * 0.5, p.y - tw * 0.5, tw, tw), steel)
	ci.draw_circle(c, s * 0.80, steel)   # body
	ci.draw_circle(c, s * 0.44, dark)    # hub
	ci.draw_circle(c, s * 0.22, hole)    # centre hole


func _draw_item_pipe(ci: Control, c: Vector2, s: float, solid: bool) -> void:
	var steel: Color = _recipe_col(Color(0.66, 0.65, 0.62), solid)
	var light: Color = _recipe_col(Color(0.83, 0.82, 0.79), solid)
	var dark: Color = _recipe_col(Color(0.30, 0.30, 0.29), solid)
	var hole: Color = _recipe_col(Color(0.12, 0.12, 0.12), solid)
	var bw: float = s * 1.7
	var bh: float = s * 0.92
	var left: float = c.x - bw * 0.5
	ci.draw_rect(Rect2(left, c.y - bh * 0.5, bw, bh), steel)
	ci.draw_circle(Vector2(left, c.y), bh * 0.5, steel)
	ci.draw_circle(Vector2(left + bw, c.y), bh * 0.5, steel)
	ci.draw_rect(Rect2(left, c.y - bh * 0.42, bw, bh * 0.16), light)   # top highlight
	ci.draw_circle(Vector2(left, c.y), bh * 0.5, dark)                 # near opening rim
	ci.draw_circle(Vector2(left, c.y), bh * 0.30, hole)               # bore


func _draw_item_glue(ci: Control, c: Vector2, s: float, solid: bool) -> void:
	var white: Color = _recipe_col(Color(0.90, 0.90, 0.88), solid)
	var red: Color = _recipe_col(Color(0.86, 0.16, 0.12), solid)
	var cyan: Color = _recipe_col(Color(0.16, 0.72, 0.84), solid)
	var bw: float = s * 1.05
	var bh: float = s * 1.7
	ci.draw_rect(Rect2(c.x - bw * 0.5, c.y - bh * 0.42, bw, bh * 0.86), white)        # bottle body
	ci.draw_rect(Rect2(c.x - bw * 0.30, c.y - bh * 0.62, bw * 0.60, bh * 0.24), cyan) # cap
	ci.draw_rect(Rect2(c.x - bw * 0.5, c.y - bh * 0.04, bw, bh * 0.40), red)          # PVA label


func _draw_item_strapped(ci: Control, c: Vector2, s: float, solid: bool) -> void:
	var steel: Color = _recipe_col(Color(0.60, 0.59, 0.56), solid)
	var dark: Color = _recipe_col(Color(0.34, 0.34, 0.32), solid)
	var strap: Color = _recipe_col(Color(0.44, 0.29, 0.18), solid)
	var pw: float = s * 0.46
	var ph: float = s * 1.7
	for k in 3:
		var px: float = c.x + (float(k) - 1.0) * (pw + s * 0.10)
		ci.draw_rect(Rect2(px - pw * 0.5, c.y - ph * 0.5, pw, ph), steel)
		ci.draw_circle(Vector2(px, c.y - ph * 0.5), pw * 0.5, steel)
		ci.draw_circle(Vector2(px, c.y - ph * 0.5), pw * 0.28, dark)
	var sw: float = s * 2.0
	ci.draw_rect(Rect2(c.x - sw * 0.5, c.y - ph * 0.30, sw, ph * 0.16), strap)
	ci.draw_rect(Rect2(c.x - sw * 0.5, c.y + ph * 0.14, sw, ph * 0.16), strap)


func _draw_item_spring(ci: Control, c: Vector2, s: float, solid: bool) -> void:
	var olive: Color = _recipe_col(Color(0.34, 0.40, 0.26), solid)
	var loops: int = 4
	var steps: int = loops * 12
	var hspan: float = s * 0.92
	var vspan: float = s * 1.5
	var pts := PackedVector2Array()
	for k in steps + 1:
		var t: float = float(k) / float(steps)
		pts.append(Vector2(c.x + sin(t * TAU * float(loops)) * hspan, c.y - vspan * 0.5 + t * vspan))
	ci.draw_polyline(pts, olive, maxf(2.0, s * 0.24), true)


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


func _update_round_timer() -> void:
	# Top-center digital round timer, mirrored from the minigame's own `timer_label` (updated on every
	# peer via a call_local RPC, so it reads identically on host and clients). Smoke Break's label is
	# already "00:SS" and shows red; Forklift's is bare seconds "SS" that we compose to "00:SS" and
	# show green. Only these two games have a round timer worth mirroring.
	var green: bool = _player_class_name == &"ForkliftCertifiedVehicle"
	if _player_class_name != &"SmokeBreakPlayer" and not green:
		_smoke_timer_panel.visible = false
		return
	_round_timer_green = green
	if _smoke_timer_source == null or not is_instance_valid(_smoke_timer_source):
		_smoke_timer_source = _find_smoke_timer_label()
	var raw: String = ""
	if _smoke_timer_source != null and is_instance_valid(_smoke_timer_source):
		raw = String(_smoke_timer_source.get("text")).strip_edges()
	if raw == "":
		_smoke_timer_panel.visible = false
		return
	_smoke_timer_label.text = ("00:%02d" % int(raw)) if green else raw
	_smoke_timer_label.add_theme_color_override("font_color",
		Color(0.2, 1.0, 0.3, 1.0) if green else Color(1.0, 0.05, 0.05, 1.0))
	_smoke_timer_label.add_theme_color_override("font_outline_color",
		Color(0.0, 0.22, 0.0, 0.9) if green else Color(0.25, 0.0, 0.0, 0.9))
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
	# The gun-game wall we add is FPV-only: hide it whenever FPV is off (e.g. died -> 3rd-person spectate),
	# so it never shows in the vanilla/spectator view.
	if _gun_wall_clone != null and is_instance_valid(_gun_wall_clone):
		_gun_wall_clone.visible = active
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
	_recipe_anim_time += delta

	# Spectator drive. Runs off the release flag (not the local rig), so it survives the dead body
	# being removed/ragdolled. Returns false when spectating is genuinely over (minigame gone or we
	# respawned) after tearing itself down -- then we fall through to normal processing this frame.
	if _spectating_released:
		if _update_spectate(delta):
			return
	elif _spec_engaged:
		_spectate_disengage()

	if _process_lobby_fpv(delta):
		return

	if not enabled:
		# FPV off -> don't leave the FPV-only gun wall sitting in a 3rd-person game.
		if _gun_wall_clone != null and is_instance_valid(_gun_wall_clone):
			_gun_wall_clone.queue_free()
		_gun_wall_clone = null
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
	_stay_fpv_active = false  # recomputed below; only the finished/between-rounds branch turns it on

	# Forklift has three distinct inactive states, handled in priority order:
	if have_rig and _player_class_name == &"ForkliftCertifiedVehicle":
		# (1) ELIMINATED this round (blood decals shown) -> ride the body ~3s then cut to 3rd person
		# and stay there, like every other death. Checked first so a death isn't swallowed by, or
		# restarted after, the crane scene.
		if not active and _ever_active and _forklift_eliminated():
			_process_death_cam(delta)  # ForkliftCertifiedVehicle is corpse/3s
			return
		# (2) The crane "take the package away" tie scene (survivors) -> FPV fully off for its duration.
		if _is_forklift_crate_pickup_active():
			_forklift_third_person_handoff()
			return
		if _forklift_third_person_active:
			_forklift_third_person_active = false
			_snap_head_smoothing = true
			_end_death_cam()  # package scene over
		# (3) A survivor set inactive between rounds (scores/crane) -> stay in FPV until reactivated.
		if not active and _ever_active:
			_update_mouse_capture()
			_render_head_cam(delta, false)
			return

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
		# FINISHED-BUT-ALIVE / between-rounds: only real death (or leaving) should spectate you. If you
		# just finished your food (green pea), your smoke, etc., or you're a Recycle survivor waiting
		# through the score/loser-pick, stay in first person AND let yourself look around.
		if _ever_active and _finished_stay_fpv():
			_stay_fpv_active = true
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
	_camera.global_transform = Transform3D(look_basis, _smoothed_head_pos + _compute_damage_shake_offset() + _compute_smoke_shake_offset())

	if active and not _freeze_body and _visuals and is_instance_valid(_visuals):
		_visuals.global_rotation.y = _yaw

	_skeleton.set_bone_pose_scale(_head_bone_idx, Vector3.ONE * HEAD_HIDE_SCALE)

	if active and _movement_rotate_active:
		_rotate_player_movement()

	if active or _stay_fpv_active:
		_update_damage_flash(delta)  # keep the infection/damage overlay alive through the transform/finish
	if active:
		_update_collar_indicator()
		_update_smoke_break_hud()
		_update_round_timer()
		_update_recipe_hud()
	# Gun-game wall: OUTSIDE the active gate so it also appears before/during the countdown. It only
	# runs here on the FPV render path, so it can't show when FPV is toggled off (see _process).
	_update_gun_wall(delta)

	_set_fpv_camera_active(true)


func _find_mesh_named(n: Node, mesh_name: String, budget: Array) -> MeshInstance3D:
	if budget[0] <= 0:
		return null
	budget[0] -= 1
	if n is MeshInstance3D and String(n.name) == mesh_name:
		return n as MeshInstance3D
	for ch in n.get_children():
		var found := _find_mesh_named(ch, mesh_name, budget)
		if found:
			return found
	return null


func _update_gun_wall(delta: float) -> void:
	# Firearm Factory only: close the open -X side. Lift the +X-facing wall triangles out of the shell's
	# brick surface (window openings are gaps in the geometry, so they come along) and mirror them 180deg
	# about the shell centre onto the -X gap. Exact brick + real windows, no clutter. Visual-only.
	if _player_class_name != &"ManufactureGunPlayer":
		return
	_probe_gun_wall(delta)  # (no-op unless GUN_WALL_PROBE)
	if not GUN_WALL_ENABLED:
		return
	if _gun_wall_clone != null and is_instance_valid(_gun_wall_clone):
		return
	var tree := get_tree()
	if tree == null:
		return
	var art := _find_node_named(tree.root, GUN_WALL_ART_ROOT, [SCAN_BUDGET])
	if art == null or not (art is Node3D):
		return
	var existing := art.get_node_or_null(NodePath(GUN_WALL_CLONE_NAME))
	if existing is Node3D:
		_gun_wall_clone = existing as Node3D
		return
	var shell := _find_mesh_named(art, GUN_WALL_SHELL_MESH, [SCAN_BUDGET])
	if shell == null or shell.mesh == null:
		if not _gun_wall_logged:
			_gun_wall_logged = true
			print("[fpv_mod] gun wall: shell '", GUN_WALL_SHELL_MESH, "' not found yet")
		return
	var mesh := shell.mesh as ArrayMesh
	if mesh == null:
		return
	# The brick-wall surface is the one whose material uses a texture named "brick".
	var bsurf := -1
	for s in mesh.get_surface_count():
		var sm := mesh.surface_get_material(s)
		if sm is BaseMaterial3D:
			var tx := (sm as BaseMaterial3D).albedo_texture
			if tx != null and String(tx.resource_path).to_lower().find("brick") >= 0:
				bsurf = s
				break
	if bsurf < 0:
		return
	# Copy the +X wall the player faces (its real geometry -- windows and all) and TRANSLATE it straight
	# across to the empty -X side. A translation (not a mirror) keeps the wall faithful: the recessed 5th
	# window stays recessed instead of inverting into a bulge, and it uses the wall's own brick material.
	var aabb := shell.get_aabb()
	var dx := aabb.size.x  # shift from the +X wall over to the -X boundary (room width)
	var arrays := mesh.surface_get_arrays(bsurf)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var have_n := norms.size() == verts.size()
	var have_uv := uvs.size() == verts.size()
	var indexed := idx.size() > 0
	var tcount: int = (idx.size() / 3) if indexed else (verts.size() / 3)
	# First pass: translated-x range of the kept +X wall, so we can reflect it about its own centre.
	var minx := INF
	var maxx := -INF
	for t in tcount:
		var j0: int = idx[t * 3] if indexed else t * 3
		var j1: int = idx[t * 3 + 1] if indexed else t * 3 + 1
		var j2: int = idx[t * 3 + 2] if indexed else t * 3 + 2
		if minf(verts[j0].x, minf(verts[j1].x, verts[j2].x)) < GUN_WALL_MINX:
			continue
		for jj in [j0, j1, j2]:
			var tx0 := verts[jj].x - dx + GUN_WALL_CLOSER
			minx = minf(minx, tx0)
			maxx = maxf(maxx, tx0)
	var cx := (minx + maxx) * 0.5
	# Second pass: copy the wall at full depth, reflected about cx so the thickness/reveals face AWAY
	# from the player. The reflection is baked into the verts (reversed winding + x-flipped normals) so
	# the face normals stay correct -- that lets the wall's OWN lit brick material light it exactly like
	# the real wall. (A node-transform reflection would flip the normals and render it pitch black.)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var kept := 0
	for t in tcount:
		var i0: int = idx[t * 3] if indexed else t * 3
		var i1: int = idx[t * 3 + 1] if indexed else t * 3 + 1
		var i2: int = idx[t * 3 + 2] if indexed else t * 3 + 2
		if minf(verts[i0].x, minf(verts[i1].x, verts[i2].x)) < GUN_WALL_MINX:
			continue
		for ii in [i0, i2, i1]:  # reversed winding (a reflection flips triangle handedness)
			if have_n:
				var n := norms[ii]
				st.set_normal(Vector3(-n.x, n.y, n.z))  # x-flipped normal to match the reflection
			if have_uv:
				st.set_uv(uvs[ii])
			var tx := verts[ii].x - dx + GUN_WALL_CLOSER
			st.add_vertex(Vector3(2.0 * cx - tx, verts[ii].y, verts[ii].z))
		kept += 1
	if kept == 0:
		if not _gun_wall_logged:
			_gun_wall_logged = true
			print("[fpv_mod] gun wall: no +X wall triangles matched (cutoff x=", GUN_WALL_MINX, ")")
		return
	var wall := MeshInstance3D.new()
	wall.name = GUN_WALL_CLONE_NAME
	wall.mesh = st.commit()
	var mat := mesh.surface_get_material(bsurf)  # the wall's OWN material -> same texture/shading/lighting as the real wall
	if mat != null:
		mat = mat.duplicate()
		if mat is BaseMaterial3D:
			(mat as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED  # visible from the play-area side
		wall.material_override = mat
	art.add_child(wall)
	wall.global_transform = shell.global_transform  # the reflection is baked into the verts, no node rotation
	_gun_wall_clone = wall
	if not _gun_wall_logged:
		_gun_wall_logged = true
		print("[fpv_mod] gun wall: copied ", kept, " tris (full depth, vert-reflected about x=", cx, ")")


func _collect_meshes(n: Node, out: Array, budget: Array) -> void:
	if budget[0] <= 0:
		return
	budget[0] -= 1
	if n is MeshInstance3D:
		out.append(n)
	for ch in n.get_children():
		_collect_meshes(ch, out, budget)


func _probe_gun_wall(delta: float) -> void:
	# Diagnostic: cast a ray straight out of the FPV camera and log the nearest art mesh it hits, so we
	# can learn the exact node name of the window wall the player is looking at (the debug overlay never
	# labels static walls). Throttled, and only logs when the target changes. Remove once identified.
	if not GUN_WALL_PROBE:
		return
	_gun_probe_accum += delta
	if _gun_probe_accum < 0.35:
		return
	_gun_probe_accum = 0.0
	var tree := get_tree()
	if tree == null or _camera == null or not is_instance_valid(_camera) or _camera.get_parent() == null:
		return
	var art := _find_node_named(tree.root, GUN_WALL_ART_ROOT, [SCAN_BUDGET])
	if art == null:
		return
	var from: Vector3 = _camera.global_position
	var dir: Vector3 = -_camera.global_transform.basis.z  # camera forward
	var meshes: Array = []
	_collect_meshes(art, meshes, [SCAN_BUDGET])
	var hits: Array = []
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi == _gun_wall_clone:
			continue
		var wa: AABB = mi.global_transform * mi.get_aabb()
		# Skip shells that enclose the camera (their AABB "hits" at 0m) and the oversized backdrop
		# (any dim > 40m) -- both have huge boxes that shadow the actual wall we're looking at.
		if wa.has_point(from):
			continue
		if wa.size.x > 40.0 or wa.size.y > 40.0 or wa.size.z > 40.0:
			continue
		var hit = wa.intersects_ray(from, dir)
		if hit != null:
			var d: float = from.distance_to(hit)
			if d > 0.25:
				hits.append([d, String(mi.name)])
	if hits.is_empty():
		return
	hits.sort_custom(func(a, b): return a[0] < b[0])
	var label := String(hits[0][1]) + " (" + str(int(hits[0][0])) + "m)"
	if hits.size() > 1:
		label += " | " + String(hits[1][1]) + " (" + str(int(hits[1][0])) + "m)"
	if label != _gun_probe_last:
		_gun_probe_last = label
		print("[fpv_mod] gun probe: ", label)


func _class_from_skeleton_owner() -> StringName:
	# Walk up from the tracked skeleton to the nearest ancestor whose script global name is a known
	# death-behavior class. The skeleton reliably belongs to the real player even if _player latched
	# onto a seat/workstation node that shares our player_presence, or if the cached class went stale.
	if _skeleton == null or not is_instance_valid(_skeleton):
		return &""
	var cur: Node = _skeleton
	while cur != null:
		var sc: Script = cur.get_script()
		if sc:
			var gn: StringName = sc.get_global_name()
			if DEATH_BEHAVIOR.has(gn):
				return gn
		cur = cur.get_parent()
	return &""


func _process_death_cam(delta: float) -> void:
	if _spectating_released:
		return  # the spectator system is driven from the top of _process once we've released

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
		# Resolve the death behavior robustly. On a CLIENT the cached _player_class_name can be wrong
		# or empty (the class/presence of a spawner-replicated node can settle a beat late, so the
		# per-game key misses and we'd fall to the default). The SKELETON always belongs to the real
		# player, so if the cached class isn't a recognized death class, re-derive it by walking up
		# from the skeleton to the nearest ancestor whose script IS a known death class.
		var cls: StringName = _player_class_name
		if not DEATH_BEHAVIOR.has(cls):
			var derived: StringName = _class_from_skeleton_owner()
			if derived != &"":
				cls = derived
				_player_class_name = cls  # correct it so the rest of the death cam + HUD use the right class
		var beh: Dictionary = DEATH_BEHAVIOR.get(cls, DEATH_BEHAVIOR_DEFAULT)
		_death_mode = StringName(beh.get("mode", &"stay"))
		_death_delay = float(beh.get("delay", 0.0))
		_death_black_end = bool(beh.get("black_end", false))
		print("[fpv_mod] death cam start: class='", cls, "' (cached='", _player_class_name,
			"' node='", (_player.name if _player and is_instance_valid(_player) else "null"), "') mode=", _death_mode, " delay=", _death_delay)

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
				# Runner reached the exit and left (the duck node is hidden, not killed). The game plays
				# its own fade-to-black here -- match it with our black for a beat so no weird angle
				# flashes, THEN turn FPV off to the spectator camera.
				if elapsed < DUCK_ESCAPE_BLACK_HOLD:
					_set_death_black(1.0)
					_death_apply_camera(_dying_anchor)
				else:
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
	_spectate_disengage()  # tear down my spectator cam/UI whenever we leave the spectate state
	_set_death_black(0.0)


# =====================================================================================
# Mod-to-mod look networking. Announce ourselves to peers; peers running the mod record each other
# and stream their exact head look (yaw+pitch) only between themselves. A non-mod peer just logs a
# harmless "unknown RPC target" for the low-rate hello and is never sent the look stream at all.
# =====================================================================================

@rpc("any_peer", "call_remote", "reliable")
func _fpv_hello() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	var was_known: bool = _fpv_mod_peers.has(sender)
	_fpv_mod_peers[sender] = true
	if not was_known:
		_fpv_hello.rpc_id(sender)  # reply so discovery is mutual immediately


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _fpv_recv_look(nid: int, yaw: float, pitch: float) -> void:
	_fpv_looks[nid] = {"yaw": yaw, "pitch": pitch, "t": _net_time}


func _fpv_on_peer_left(pid: int) -> void:
	_fpv_mod_peers.erase(pid)


func _fpv_net_broadcast(delta: float) -> void:
	if multiplayer == null or not multiplayer.has_multiplayer_peer():
		return
	# Announce periodically (finds late joiners too). Only mod peers have the node to receive it.
	_net_hello_accum += delta
	if _net_hello_accum >= FPV_NET_HELLO_IV:
		_net_hello_accum = 0.0
		_fpv_hello.rpc()
	# Stream our look to known mod peers only -- but only when we're actually in first person.
	if _fpv_mod_peers.is_empty():
		return
	if not enabled or _camera == null or not is_instance_valid(_camera) or _camera.get_parent() == null:
		return
	if _player == null or not is_instance_valid(_player) or not _player_is_active():
		return
	_net_bcast_accum += delta
	if _net_bcast_accum < FPV_NET_BCAST_IV:
		return
	_net_bcast_accum = 0.0
	var nid := multiplayer.get_unique_id()
	var rot: Vector3 = _camera.global_rotation
	for pid in _fpv_mod_peers.keys():
		_fpv_recv_look.rpc_id(int(pid), nid, rot.y, rot.x)


# =====================================================================================
# Spectator system -- engages ONLY once the mod has handed to spectate (`_spectating_released`).
# Three view modes over the living players: third-person (default), FPV (their view), and a
# no-clip free-fly cam. Fully client-side and read-only; it never touches live play. Works the
# same whether you host or join, your lobby or someone else's, because it only reads nodes the
# base game already replicates to every client.
# =====================================================================================

func _create_spectate_ui() -> void:
	_spec_font = load("res://fonts/Terminal F4.ttf") as Font

	# Top-right: toggle between third-person and the spectated player's FPV.
	_spec_toggle_btn = Button.new()
	_spec_toggle_btn.name = "FpvSpecToggle"
	_spec_toggle_btn.text = "Switch to FPV view"
	_spec_toggle_btn.anchor_left = 1.0
	_spec_toggle_btn.anchor_right = 1.0
	_spec_toggle_btn.offset_left = -262
	_spec_toggle_btn.offset_right = -18
	_spec_toggle_btn.offset_top = 18
	_spec_toggle_btn.offset_bottom = 58
	_style_native_button(_spec_toggle_btn)
	_spec_toggle_btn.visible = false
	_spec_toggle_btn.pressed.connect(_on_spec_toggle_pressed)
	_crosshair_layer.add_child(_spec_toggle_btn)

	# Directly under the toggle: enable / exit the free-fly cam.
	_spec_freefly_btn = Button.new()
	_spec_freefly_btn.name = "FpvSpecFreefly"
	_spec_freefly_btn.text = "Free-fly cam"
	_spec_freefly_btn.anchor_left = 1.0
	_spec_freefly_btn.anchor_right = 1.0
	_spec_freefly_btn.offset_left = -262
	_spec_freefly_btn.offset_right = -18
	_spec_freefly_btn.offset_top = 64
	_spec_freefly_btn.offset_bottom = 104
	_style_native_button(_spec_freefly_btn)
	_spec_freefly_btn.visible = false
	_spec_freefly_btn.pressed.connect(_on_spec_freefly_pressed)
	_crosshair_layer.add_child(_spec_freefly_btn)

	# Bottom-center: spectated player's name + role tag, flanked by cycle arrows.
	_spec_name_panel = Control.new()
	_spec_name_panel.name = "FpvSpecNamePanel"
	_spec_name_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_spec_name_panel.anchor_left = 0.5
	_spec_name_panel.anchor_right = 0.5
	_spec_name_panel.anchor_top = 1.0
	_spec_name_panel.anchor_bottom = 1.0
	_spec_name_panel.offset_left = -150
	_spec_name_panel.offset_right = 150
	_spec_name_panel.offset_top = -80
	_spec_name_panel.offset_bottom = -20
	_spec_name_panel.visible = false
	_crosshair_layer.add_child(_spec_name_panel)

	var name_bg := ColorRect.new()
	name_bg.name = "Bg"
	name_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_bg.color = Color(0.04, 0.04, 0.05, 0.78)
	_spec_name_panel.add_child(name_bg)

	_spec_prev_btn = Button.new()
	_spec_prev_btn.name = "Prev"
	_spec_prev_btn.text = "◀"  # left triangle
	_spec_prev_btn.offset_left = 5
	_spec_prev_btn.offset_right = 39
	_spec_prev_btn.offset_top = 13
	_spec_prev_btn.offset_bottom = 47
	_style_native_button(_spec_prev_btn)
	_spec_prev_btn.pressed.connect(_on_spec_prev_pressed)
	_spec_name_panel.add_child(_spec_prev_btn)

	_spec_next_btn = Button.new()
	_spec_next_btn.name = "Next"
	_spec_next_btn.text = "▶"  # right triangle
	_spec_next_btn.anchor_left = 1.0
	_spec_next_btn.anchor_right = 1.0
	_spec_next_btn.offset_left = -39
	_spec_next_btn.offset_right = -5
	_spec_next_btn.offset_top = 13
	_spec_next_btn.offset_bottom = 47
	_style_native_button(_spec_next_btn)
	_spec_next_btn.pressed.connect(_on_spec_next_pressed)
	_spec_name_panel.add_child(_spec_next_btn)

	_spec_name_label = Label.new()
	_spec_name_label.name = "SpecName"
	_spec_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spec_name_label.anchor_right = 1.0
	_spec_name_label.offset_left = 44
	_spec_name_label.offset_right = -44
	_spec_name_label.offset_top = 5
	_spec_name_label.offset_bottom = 34
	_spec_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spec_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _spec_font:
		_spec_name_label.add_theme_font_override("font", _spec_font)
	_spec_name_label.add_theme_font_size_override("font_size", 19)
	_spec_name_label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.94))
	_spec_name_panel.add_child(_spec_name_label)

	_spec_role_label = Label.new()
	_spec_role_label.name = "SpecRole"
	_spec_role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spec_role_label.anchor_right = 1.0
	_spec_role_label.offset_left = 44
	_spec_role_label.offset_right = -44
	_spec_role_label.offset_top = 33
	_spec_role_label.offset_bottom = 56
	_spec_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spec_role_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _spec_font:
		_spec_role_label.add_theme_font_override("font", _spec_font)
	_spec_role_label.add_theme_font_size_override("font_size", 12)
	_spec_role_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_spec_name_panel.add_child(_spec_role_label)

	# FPV-spectate look hint (just above the name panel).
	_spec_look_hint = Label.new()
	_spec_look_hint.name = "FpvSpecLookHint"
	_spec_look_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spec_look_hint.anchor_left = 0.5
	_spec_look_hint.anchor_right = 0.5
	_spec_look_hint.anchor_top = 1.0
	_spec_look_hint.anchor_bottom = 1.0
	_spec_look_hint.offset_left = -170
	_spec_look_hint.offset_right = 170
	_spec_look_hint.offset_top = -104
	_spec_look_hint.offset_bottom = -82
	_spec_look_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spec_look_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _spec_font:
		_spec_look_hint.add_theme_font_override("font", _spec_font)
	_spec_look_hint.add_theme_font_size_override("font_size", 13)
	_spec_look_hint.add_theme_color_override("font_color", Color(0.72, 0.72, 0.75))
	_spec_look_hint.text = "hold Shift / LB to look around"
	_spec_look_hint.visible = false
	_crosshair_layer.add_child(_spec_look_hint)


func _style_native_button(btn: Button) -> void:
	if _spec_font:
		btn.add_theme_font_override("font", _spec_font)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.92, 0.92, 0.9))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.7, 0.7))
	btn.add_theme_stylebox_override("normal", _native_stylebox(Color(0.06, 0.06, 0.08, 0.9)))
	btn.add_theme_stylebox_override("hover", _native_stylebox(Color(0.14, 0.14, 0.17, 0.95)))
	btn.add_theme_stylebox_override("pressed", _native_stylebox(Color(0.02, 0.02, 0.03, 0.95)))
	btn.add_theme_stylebox_override("focus", _native_stylebox(Color(0.06, 0.06, 0.08, 0.0)))


func _native_stylebox(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color(0.55, 0.55, 0.6, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


func _update_spectate(delta: float) -> bool:
	# Returns true while genuinely spectating (we drove the camera -> caller returns), false once it's
	# over (we've already torn down + cleared the release flag -> caller falls through to normal play).
	if not _spec_engaged:
		# Don't even engage into a Duck Hunt round that's already ending (is_spectating cleared) -- that
		# transient is what briefly flashed the buttons at round/game end.
		var mg0 := _spec_minigame()
		if mg0 != null and "is_spectating" in mg0 and "spectate_duck_players" in mg0 and not bool(mg0.get("is_spectating")):
			_spectating_released = false
			return false
		_spectate_engage()

	# Camera lost unexpectedly -> rebuild it and keep going. Never tear the whole thing down for this,
	# or it would reset the mode and kick you out of free-cam.
	if _spec_cam == null or not is_instance_valid(_spec_cam):
		_spec_cam = Camera3D.new()
		_spec_cam.name = "FpvSpectatorCamera"
		get_tree().root.add_child(_spec_cam)
		_spec_snap_head = true
	# End only when the minigame is truly gone (round/match ended) or the local player is genuinely
	# alive again -- and only once that has HELD for ~0.3s. A single-frame flag blip (some minigames
	# flicker the dead player's state between rounds) must NOT tear spectate down, or it re-engages and
	# kicks you out of free-cam. Free-cam otherwise persists until you explicitly leave it.
	var mg_gone: bool = _spec_mg == null or not is_instance_valid(_spec_mg) or not _spec_mg.is_inside_tree()
	var alive_again: bool = _player != null and is_instance_valid(_player) and _player_is_active() \
		and not ("is_alive" in _player and not bool(_player.get("is_alive")))
	# Duck Hunt: the round is over the instant the game clears is_spectating (all ducks done -> new
	# hunter/round). Spectating ends right there.
	var dh_over: bool = not mg_gone and "is_spectating" in _spec_mg and "spectate_duck_players" in _spec_mg \
		and not bool(_spec_mg.get("is_spectating"))
	if dh_over:
		# Clean, deliberate signal -> end immediately (no hysteresis) so nothing flashes.
		_spectating_released = false
		_spectate_disengage()
		return false
	if mg_gone or alive_again:
		_spec_end_accum += delta
		if _spec_end_accum >= 0.3:
			_spectating_released = false
			_spectate_disengage()
			return false
	else:
		_spec_end_accum = 0.0

	# Refresh the living-player roster periodically (players die / roles flip mid-round).
	_spec_rebuild_accum += delta
	if _spec_rebuild_accum >= 0.5:
		_spec_rebuild_accum = 0.0
		_spec_build_targets()

	# Keep a valid, still-living target (free-fly is decoupled and doesn't need one on screen).
	if _spec_target == null or not is_instance_valid(_spec_target) or not _spec_is_alive(_spec_target):
		_spec_pick_target()

	_spec_controller_input()  # gamepad: cycle / toggle FPV / enter-exit free cam

	# Third-person hands to the game's OWN spectator camera (exact vanilla view); FPV/free-fly use ours.
	if _spec_mode == SPEC_MODE_FREEFLY:
		if not _spec_cam.current:
			_spec_cam.current = true
		_spec_update_freefly(delta)
	elif _spec_mode == SPEC_MODE_FPV:
		if not _spec_cam.current:
			_spec_cam.current = true
		_spec_update_fpv(delta)
	else:
		_spec_update_third()

	_spec_clear_overlays()  # keep the damage/infection flash off the whole time we're spectating
	_spec_update_ui()
	_spec_update_mouse()
	return true


func _spec_clear_overlays() -> void:
	_damage_flash_alpha = 0.0
	_damage_shake_magnitude = 0.0
	_was_infected = false
	if _damage_flash_rect and is_instance_valid(_damage_flash_rect):
		_damage_flash_rect.color = Color(DAMAGE_FLASH_COLOR.r, DAMAGE_FLASH_COLOR.g, DAMAGE_FLASH_COLOR.b, 0.0)
	if _one_life_overlay and is_instance_valid(_one_life_overlay):
		_one_life_overlay.visible = false


func _spectate_engage() -> void:
	_spec_engaged = true
	_spec_mode = SPEC_MODE_THIRD
	_spec_grabbed_mouse = false
	_spec_snap_head = true
	_spec_rebuild_accum = 0.0
	_spec_end_accum = 0.0
	_spec_look_yaw = 0.0
	_spec_look_pitch = 0.0
	_spec_shared_captured = false
	_spec_clear_overlays()        # no leftover red/green damage flash while spectating (esp. the hunter)
	_spec_mg = _spec_minigame()   # capture the minigame node -- lifecycle no longer depends on _player
	_spec_build_targets()
	_spec_pick_target()

	_spec_cam = Camera3D.new()
	_spec_cam.name = "FpvSpectatorCamera"
	get_tree().root.add_child(_spec_cam)
	# NOT made current here -- the default third-person mode hands to the game's own camera.

	_spec_freefly_yaw = 0.0
	_spec_freefly_pitch = -0.12

	if _spec_toggle_btn:
		_spec_toggle_btn.visible = true
	if _spec_freefly_btn:
		_spec_freefly_btn.visible = true
	if _spec_name_panel:
		_spec_name_panel.visible = true
	if _spec_prev_btn:
		_spec_prev_btn.visible = true
	if _spec_next_btn:
		_spec_next_btn.visible = true
	_spec_refresh_buttons()
	print("[fpv_mod] spectate engaged (", _spec_targets.size(), " living targets)")


func _spectate_disengage() -> void:
	_spec_restore_hidden_head()  # un-hide whoever's head we hid for FPV
	if _spec_grabbed_mouse and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_spec_grabbed_mouse = false
	if _spec_cam and is_instance_valid(_spec_cam):
		_spec_cam.current = false
		if _spec_cam.get_parent() != null:
			_spec_cam.get_parent().remove_child(_spec_cam)
		_spec_cam.queue_free()
	_spec_cam = null
	_spec_target = null
	_spec_targets.clear()
	_spec_mg = null
	if _spec_toggle_btn:
		_spec_toggle_btn.visible = false
	if _spec_freefly_btn:
		_spec_freefly_btn.visible = false
	if _spec_name_panel:
		_spec_name_panel.visible = false
	if _spec_look_hint:
		_spec_look_hint.visible = false
	_spec_hunter_restore()  # undo any hunter view tweaks (laser/scope) we made
	if not _spec_engaged:
		return
	_spec_engaged = false
	print("[fpv_mod] spectate disengaged")


func _spec_minigame() -> Node:
	if _player == null or not is_instance_valid(_player):
		return null
	var cur: Node = _player
	while cur != null and is_instance_valid(cur):
		if _script_is_or_extends(cur.get_script(), &"Minigame"):
			return cur
		cur = cur.get_parent()
	return null


func _spec_mg_is(substr: String) -> bool:
	# Identify the current minigame by its script path / node name (e.g. "chisel").
	if _spec_mg == null or not is_instance_valid(_spec_mg):
		return false
	var sc: Script = _spec_mg.get_script()
	if sc != null and sc.resource_path.to_lower().contains(substr):
		return true
	return String(_spec_mg.name).to_lower().contains(substr)


func _spec_build_targets() -> void:
	var mg: Node = _spec_mg
	if mg == null or not is_instance_valid(mg):
		mg = _spec_minigame()
	if mg == null:
		return
	var skels: Array = []
	_spec_collect_head_skeletons(mg, skels, [SCAN_BUDGET])
	var seen_ids := {}
	var players: Array = []
	for sk in skels:
		var pnode := _spec_player_of_skeleton(sk as Node)
		if pnode == null:
			continue
		var pid := _spec_id_of(pnode)
		if pid == 0 or seen_ids.has(pid):
			continue
		seen_ids[pid] = true
		players.append(pnode)
	var alive: Array = []
	for p in players:
		if _spec_is_alive(p):
			alive.append(p)
	# The Duck Hunt hunter is a first-person gun rig (no "head" bone), so the skeleton walk never finds
	# it. Find the hunter NODE by class in the minigame subtree -- NOT via `mg.hunter_player`, which is
	# server-only and null on clients (that's why hunter-spectate barely worked for clients). Its aim
	# camera is always-replicated, so its view is exact on every peer.
	var hunter := _spec_find_hunter(mg)
	if hunter != null and not (hunter in alive):
		alive.append(hunter)
	alive.sort_custom(_spec_sort_by_id)
	_spec_targets = alive


func _spec_collect_head_skeletons(n: Node, out: Array, budget: Array) -> void:
	if budget[0] <= 0:
		return
	budget[0] -= 1
	if n is Skeleton3D:
		var sk := n as Skeleton3D
		if sk.find_bone("head") >= 0 and sk.is_visible_in_tree() and sk.get_viewport() == get_tree().root:
			out.append(sk)
	for c in n.get_children():
		_spec_collect_head_skeletons(c, out, budget)


func _spec_find_hunter(mg: Node) -> Node:
	# Client-safe: locate the DuckHuntHunterPlayer node by class anywhere under the minigame.
	return _spec_find_by_class(mg, "DuckHunt", "Hunter", [SCAN_BUDGET])


func _spec_find_by_class(n: Node, must_a: String, must_b: String, budget: Array) -> Node:
	if budget[0] <= 0:
		return null
	budget[0] -= 1
	var sc: Script = n.get_script()
	if sc != null:
		var cn: String = String(sc.get_global_name())
		if cn.contains(must_a) and cn.contains(must_b):
			return n
	for c in n.get_children():
		var f := _spec_find_by_class(c, must_a, must_b, budget)
		if f != null:
			return f
	return null


func _spec_player_of_skeleton(sk: Node) -> Node:
	var cur := sk.get_parent()
	while cur != null:
		if "player_presence" in cur:
			var pp = cur.get("player_presence")
			if pp != null and is_instance_valid(pp):
				return cur
		cur = cur.get_parent()
	return null


func _spec_id_of(node: Node) -> int:
	if node == null or not is_instance_valid(node) or not ("player_presence" in node):
		return 0
	var pp = node.get("player_presence")
	if pp == null or not is_instance_valid(pp) or not ("network_id" in pp):
		return 0
	return int(pp.get("network_id"))


func _spec_sort_by_id(a: Node, b: Node) -> bool:
	return _spec_id_of(a) < _spec_id_of(b)


func _spec_is_alive(p: Node) -> bool:
	# Player state is per-minigame; there is no universal flag. Check the explicit death flags
	# first, then `active` (present on nearly every player subclass and RPC-synced to all clients
	# when the round is playing), then life/health counters.
	if p == null or not is_instance_valid(p):
		return false
	if "is_dead" in p and bool(p.get("is_dead")):
		return false
	if "dead" in p and bool(p.get("dead")):
		return false
	if "is_alive" in p:
		return bool(p.get("is_alive"))
	if "alive" in p:
		return bool(p.get("alive"))
	if "active" in p:
		return bool(p.get("active"))
	if "lives" in p:
		return int(p.get("lives")) > 0
	if "health" in p:
		return float(p.get("health")) > 0.0
	return true


func _spec_pick_target() -> void:
	if _spec_targets.is_empty():
		_spec_target = null
		return
	if _spec_target != null and is_instance_valid(_spec_target) and _spec_target in _spec_targets and _spec_is_alive(_spec_target):
		return
	_spec_target = _spec_targets[0]
	_spec_snap_head = true  # new target -> jump the FPV head, don't glide across the map
	_spec_look_yaw = 0.0
	_spec_look_pitch = 0.0


func _spec_cycle(dir: int) -> void:
	_spec_build_targets()
	if _spec_targets.is_empty():
		return
	var idx := _spec_targets.find(_spec_target)
	if idx < 0:
		idx = 0
	else:
		idx = (idx + dir) % _spec_targets.size()
		if idx < 0:
			idx += _spec_targets.size()
	_spec_target = _spec_targets[idx]
	_spec_snap_head = true
	_spec_look_yaw = 0.0
	_spec_look_pitch = 0.0


func _spec_head_origin(t: Node) -> Vector3:
	var sk := _first_skeleton_with_head(t, [SCAN_BUDGET])
	if sk != null:
		var idx: int = (sk as Skeleton3D).find_bone("head")
		if idx >= 0:
			var gt: Transform3D = (sk as Skeleton3D).global_transform * (sk as Skeleton3D).get_bone_global_pose(idx)
			return gt.origin
	if t is Node3D:
		return (t as Node3D).global_position + Vector3(0, 1.6, 0)
	return Vector3.ZERO


func _spec_body_yaw(t: Node) -> float:
	var sk := _first_skeleton_with_head(t, [SCAN_BUDGET])
	if sk != null:
		var vis := _direct_child_ancestor(t, sk)
		if vis is Node3D:
			return (vis as Node3D).global_rotation.y
	if t is Node3D:
		return (t as Node3D).global_rotation.y
	return 0.0


func _spec_update_third() -> void:
	# The BASE GAME's own 3rd-person spectate camera (OG feel) -- we never build our own. We just make
	# our arrows drive WHICH player it shows, and block the base game's click-to-switch.
	_spec_restore_hidden_head()  # show their head again in 3rd person
	var t := _spec_target

	# Duck Hunt hunter: mirror their exact first-person view into our own camera (arms, gun, aim, scope).
	if t != null and is_instance_valid(t) and _spec_role_for(t) == "HUNTER" and "camera" in t:
		_spec_update_hunter(t)
		return
	_spec_hunter_restore()  # not on the hunter -> undo the laser/scope tweaks

	if _spec_cam != null and is_instance_valid(_spec_cam) and _spec_cam.current:
		_spec_cam.current = false

	# (A) Duck Hunt: it follows minigame.spectate_player. We run AFTER its _process (priority 4096), so
	# writing spectate_player to our target every frame makes the arrows control it AND overrides any
	# left/right-click switch the game just processed -- the click can no longer change who you watch.
	if _spec_drive_native_spectate(t):
		return

	# (B) Games where each player owns their spectate/gameplay camera (Inside Job top-down, burn recycle
	# seat cam, shape cutter, ...): show the selected player's OWN camera. It's a child of that player,
	# so it already frames them with the game's exact angle -- cycling just switches whose we show.
	if t != null and is_instance_valid(t) and "camera" in t:
		var tc = t.get("camera")
		if tc is Camera3D and is_instance_valid(tc):
			if not (tc as Camera3D).current:
				(tc as Camera3D).current = true
			return

	# (C) Single shared/overview camera (Wrong Way, forklift, smoke break, collar race): there is no
	# per-player cam to switch to, so we follow the chosen player OURSELVES using the base camera's LIVE
	# angle -- exactly the game's framing, just re-centred on who you picked with the arrows.
	var gcam := _find_game_camera(true)
	if gcam == null and _orig_camera != null and is_instance_valid(_orig_camera):
		gcam = _orig_camera
	if t != null and is_instance_valid(t) and t is Node3D:
		var base_basis: Basis = Basis.from_euler(Vector3(deg_to_rad(-22.0), _spec_body_yaw(t), 0.0))
		if gcam != null and is_instance_valid(gcam):
			base_basis = gcam.global_transform.basis  # the game's exact live angle (keeps any pan)
			if not _spec_shared_captured:
				_spec_shared_dist = clampf(gcam.global_position.distance_to(_spec_players_centroid()), 6.0, 45.0)
				_spec_shared_captured = true
		if not _spec_cam.current:
			_spec_cam.current = true
		var fwd: Vector3 = -base_basis.z
		var subj: Vector3 = _spec_head_origin(t)
		_spec_cam.global_transform = Transform3D(base_basis, subj - fwd * _spec_shared_dist)
		return

	# Nothing to follow -> re-assert the game's own camera.
	if gcam == null:
		gcam = _find_fallback_camera()
	if gcam != null and is_instance_valid(gcam) and not gcam.current:
		gcam.current = true


func _spec_update_hunter(t: Node) -> void:
	# Make the hunter's OWN camera current -- that's the only way the layer-16 first-person viewmodel
	# (arms + gun) renders exactly as the hunter sees it; a mirrored camera showed the aim/scope but not
	# the weapon. We drive THAT camera's fov for the scope zoom and show its reticle, then hide the laser
	# they don't see. Everything is restored on leave. Aim/laser-state are replicated, so it's exact.
	_spec_hunter_ref = t
	var hcam = t.get("camera")
	if not (hcam is Camera3D) or not is_instance_valid(hcam):
		return
	var hc := hcam as Camera3D
	var scoped := _spec_hunter_scoped(hc)
	if _spec_cam != null and is_instance_valid(_spec_cam) and _spec_cam.current:
		_spec_cam.current = false
	if not hc.current:
		hc.current = true
	hc.fov = 24.0 if scoped else 55.0
	var lp = hc.get_node_or_null("LaserParent")  # LaserParent.visible is NOT replicated -> local + safe
	if lp is Node3D:
		(lp as Node3D).visible = false
	var reticle = t.get_node_or_null("HunterCanvasLayer/Control")  # scope overlay, alpha-0 by default
	if reticle is CanvasItem:
		(reticle as CanvasItem).modulate.a = 1.0 if scoped else 0.0


func _spec_hunter_scoped(hc: Camera3D) -> bool:
	# The laser is only visible while zoomed (zoom_fov_index > 0), and LaserOrigin:visible IS replicated.
	var lo = hc.get_node_or_null("LaserParent/LaserOrigin")
	if lo is Node3D:
		return (lo as Node3D).visible
	return false


func _spec_hunter_restore() -> void:
	if _spec_hunter_ref != null and is_instance_valid(_spec_hunter_ref):
		var hcam = _spec_hunter_ref.get("camera") if "camera" in _spec_hunter_ref else null
		if hcam is Camera3D and is_instance_valid(hcam):
			(hcam as Camera3D).fov = 55.0  # undo the scope zoom on the hunter's own camera
			if (hcam as Camera3D).current:
				(hcam as Camera3D).current = false  # hand back; the new mode sets its own camera
			var lp = (hcam as Camera3D).get_node_or_null("LaserParent")
			if lp is Node3D:
				(lp as Node3D).visible = true
		var reticle = _spec_hunter_ref.get_node_or_null("HunterCanvasLayer/Control")
		if reticle is CanvasItem:
			(reticle as CanvasItem).modulate.a = 0.0
	_spec_hunter_ref = null


func _spec_players_centroid() -> Vector3:
	var acc := Vector3.ZERO
	var n := 0
	for p in _spec_targets:
		if p is Node3D and is_instance_valid(p):
			acc += (p as Node3D).global_position
			n += 1
	if n > 0:
		return acc / float(n)
	if _spec_target is Node3D and is_instance_valid(_spec_target):
		return (_spec_target as Node3D).global_position
	return Vector3.ZERO


func _spec_drive_native_spectate(t: Node) -> bool:
	# Force the game's native follow-spectate onto our chosen target (Duck Hunt). Returns true if it
	# handled the view. Only fires when the target is in the game's own spectate-able list.
	var mg: Node = _spec_mg
	if mg == null or not is_instance_valid(mg):
		return false
	if not ("spectate_duck_players" in mg and "spectate_player" in mg):
		return false
	if t == null or not is_instance_valid(t):
		return false
	var list = mg.get("spectate_duck_players")
	if not (list is Array):
		return false
	var idx: int = (list as Array).find(t)
	if idx < 0:
		return false  # not a spectate-able duck (e.g. the hunter) -> caller uses the player's own cam
	mg.set("spectator_index", idx)
	mg.set("spectate_player", t)  # overrides the click every frame; drives the follow-cam to our pick
	var bc = mg.get("backup_camera")
	if bc is Camera3D and is_instance_valid(bc) and not (bc as Camera3D).current:
		(bc as Camera3D).current = true
	return true


func _spec_update_fpv(delta: float) -> void:
	# Reuse the EXACT first-person rig on the spectated player: camera pinned to their head bone (which
	# bobs with their animation), their head hidden, the same smoothing our own FPV uses. It should feel
	# just like our FPV was theirs.
	var t := _spec_target
	if t == null or not is_instance_valid(t):
		return
	# Duck Hunt hunter: full first-person view (arms/gun/aim/scope, laser hidden). Not a head rig.
	if _spec_role_for(t) == "HUNTER" and "camera" in t:
		_spec_restore_hidden_head()
		_spec_update_hunter(t)
		return
	_spec_hunter_restore()  # not the hunter -> undo any hunter tweaks
	var sk := _first_skeleton_with_head(t, [SCAN_BUDGET])
	if sk == null:
		_spec_restore_hidden_head()
		return
	var idx: int = sk.find_bone("head")

	# Look faces the way their body faces; hold Shift (or use the right stick) to look around yourself,
	# clamped exactly like the lobby view. This is your own look -- we don't mirror their mouse.
	_spec_apply_self_look(delta)
	var yaw: float = _spec_body_yaw(t) + _spec_look_yaw
	var pitch: float = _spec_look_pitch
	var look_basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)

	# Head-bone eye position, smoothed exactly like real FPV (lateral/vertical eased, forward instant).
	var head_xform: Transform3D = sk.global_transform * sk.get_bone_global_pose(idx)
	var target_head: Vector3 = head_xform.origin + _spec_eye_offset(yaw)
	var grounded: bool = not (t is CharacterBody3D) or (t as CharacterBody3D).is_on_floor()
	if _spec_snap_head or not grounded or _spec_smoothed_head.distance_to(target_head) > HEAD_TELEPORT_SNAP_DISTANCE:
		_spec_smoothed_head = target_head
		_spec_snap_head = false
	else:
		_spec_smoothed_head = _spec_smooth_head_toward(_spec_smoothed_head, target_head, delta, yaw)
	_spec_cam.global_transform = Transform3D(look_basis, _spec_smoothed_head)

	# Hide their head so we're not looking at the inside of it (re-applied each frame; restored on exit).
	_spec_hide_head(sk, idx)


func _spec_apply_self_look(delta: float) -> void:
	# You look around from the spectated player's head yourself. Mouse look only while Shift is held;
	# controller right-stick always looks (it's free in FPV). Offsets clamped like the lobby view.
	var yaw_limit: float = deg_to_rad(LOBBY_FPV_YAW_LIMIT_DEG)
	var pitch_limit: float = deg_to_rad(LOBBY_FPV_PITCH_LIMIT_DEG)
	# Match real-FPV sensitivity (and the player's slider) so it feels native, not fast.
	if Input.is_key_pressed(KEY_SHIFT):
		var sens: float = MOUSE_SENSITIVITY * _mouse_sensitivity_mult
		_spec_look_yaw -= _spec_look_rel.x * sens
		_spec_look_pitch -= _spec_look_rel.y * sens
	var stick := _lobby_stick_vector()  # right stick, deadzoned
	if stick != Vector2.ZERO:
		var cstep: float = CONTROLLER_LOOK_SPEED * _controller_sensitivity_mult * delta
		_spec_look_yaw -= stick.x * cstep
		_spec_look_pitch -= stick.y * cstep
	_spec_look_yaw = clampf(_spec_look_yaw, -yaw_limit, yaw_limit)
	_spec_look_pitch = clampf(_spec_look_pitch, -pitch_limit, pitch_limit)
	_spec_look_rel = Vector2.ZERO


func _spec_eye_offset(yaw: float) -> Vector3:
	# Same eye offset our FPV uses (per-class magnitudes), but rotated by the SPECTATED look yaw.
	var forward: Vector3 = Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)
	var left: Vector3 = Basis(Vector3.UP, yaw) * Vector3(-1, 0, 0)
	return forward * _eye_forward_offset + Vector3.UP * _eye_up_offset + left * _eye_left_offset


func _spec_smooth_head_toward(current: Vector3, target: Vector3, delta: float, _yaw: float) -> Vector3:
	# Smooth ALL axes (unlike our own FPV, which snaps forward). The spectated head comes off a
	# network-interpolated remote body, so full smoothing removes the jitter; a tight rate keeps it
	# feeling responsive/native rather than floaty.
	var w: float = 1.0 - exp(-delta * SPEC_HEAD_SMOOTHING)
	return current.lerp(target, w)


func _spec_hide_head(sk: Skeleton3D, idx: int) -> void:
	if sk == null or not is_instance_valid(sk) or idx < 0:
		return
	if _spec_hidden_skel != sk or _spec_hidden_idx != idx:
		_spec_restore_hidden_head()  # un-hide the previous target's head first
		_spec_hidden_skel = sk
		_spec_hidden_idx = idx
		_spec_hidden_orig_scale = sk.get_bone_pose_scale(idx)
	sk.set_bone_pose_scale(idx, Vector3.ONE * HEAD_HIDE_SCALE)


func _spec_restore_hidden_head() -> void:
	if _spec_hidden_skel != null and is_instance_valid(_spec_hidden_skel) and _spec_hidden_idx >= 0:
		_spec_hidden_skel.set_bone_pose_scale(_spec_hidden_idx, _spec_hidden_orig_scale)
	_spec_hidden_skel = null
	_spec_hidden_idx = -1


func _spec_use_owned_camera(t: Node) -> bool:
	if not ("camera" in t):
		return false
	return _spec_role_for(t) == "HUNTER"


func _spec_update_freefly(delta: float) -> void:
	_spec_restore_hidden_head()  # free-fly is decoupled from the spectated player
	_spec_hunter_restore()
	var device := _spec_pad_device()

	# Look-around is a HOLD (mouse look is handled via Shift-capture in _input): on a controller, hold
	# LB and steer with the right stick. LB is otherwise unused in free cam.
	if device >= 0 and Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_SHOULDER):
		var lv := Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
		var lm: float = lv.length()
		if lm > CONTROLLER_LOOK_DEADZONE:
			var ls: Vector2 = lv.normalized() * ((lm - CONTROLLER_LOOK_DEADZONE) / (1.0 - CONTROLLER_LOOK_DEADZONE))
			_spec_freefly_yaw -= ls.x * SPEC_FREEFLY_PAD_LOOK * delta
			_spec_freefly_pitch = clamp(_spec_freefly_pitch - ls.y * SPEC_FREEFLY_PAD_LOOK * delta, -1.4, 1.4)

	var speed := SPEC_FREEFLY_SPEED
	var basis := Basis.from_euler(Vector3(_spec_freefly_pitch, _spec_freefly_yaw, 0.0))
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		dir -= basis.z
	if Input.is_key_pressed(KEY_S):
		dir += basis.z
	if Input.is_key_pressed(KEY_A):
		dir -= basis.x
	if Input.is_key_pressed(KEY_D):
		dir += basis.x
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
		dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_CTRL):
		dir -= Vector3.UP

	# Controller left-stick move + triggers up/down (L3 click = sprint).
	if device >= 0:
		var mv := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		if mv.length() > SPEC_PAD_MOVE_DEADZONE:
			dir += basis.x * mv.x + basis.z * mv.y  # stick up (-Y) -> forward (-Z)
		var rt := Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT)
		var lt := Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT)
		if rt > 0.15:
			dir += Vector3.UP * rt
		if lt > 0.15:
			dir -= Vector3.UP * lt
		if Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_STICK):
			speed *= 3.5

	if dir.length() > 0.001:
		_spec_freefly_pos += dir.normalized() * speed * delta
	_spec_cam.global_transform = Transform3D(basis, _spec_freefly_pos)


func _spec_update_mouse() -> void:
	# Looking around (free-cam AND FPV) is a HOLD: press Shift to capture the mouse and look; let go and
	# the cursor is free to click the buttons (no Alt needed). Controllers never grab the cursor.
	var pause_menu := get_node_or_null("/root/PauseMenu")
	var paused: bool = pause_menu != null and bool(pause_menu.get("active"))
	var want_capture: bool = false
	if not paused and not _last_input_was_pad and Input.is_key_pressed(KEY_SHIFT):
		if _spec_mode == SPEC_MODE_FREEFLY or _spec_mode == SPEC_MODE_FPV:
			want_capture = true
	if want_capture:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_spec_grabbed_mouse = true
	else:
		if _spec_grabbed_mouse and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_spec_grabbed_mouse = false


func _using_controller() -> bool:
	var gm := get_node_or_null("/root/GameManager")
	return gm != null and gm.has_method("is_using_controller") and bool(gm.call("is_using_controller"))


func _spec_pad_device() -> int:
	var d := _look_joypad_device()
	if d >= 0:
		return d
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return -1
	return int(pads[0])


func _pad_just_pressed(device: int, button: int) -> bool:
	var down := Input.is_joy_button_pressed(device, button)
	var was: bool = bool(_pad_edge.get(button, false))
	_pad_edge[button] = down
	return down and not was


func _spec_controller_input() -> void:
	# Controller map while spectating: LB/RB or D-pad L/R = cycle players; Y = FPV<->third;
	# X = enter/exit free cam. Free-cam movement/look is read in _spec_update_freefly.
	var device := _spec_pad_device()
	if device < 0:
		_pad_edge.clear()
		return
	var lb := _pad_just_pressed(device, JOY_BUTTON_LEFT_SHOULDER)
	var rb := _pad_just_pressed(device, JOY_BUTTON_RIGHT_SHOULDER)
	var dpl := _pad_just_pressed(device, JOY_BUTTON_DPAD_LEFT)
	var dpr := _pad_just_pressed(device, JOY_BUTTON_DPAD_RIGHT)
	var y := _pad_just_pressed(device, JOY_BUTTON_Y)
	var x := _pad_just_pressed(device, JOY_BUTTON_X)
	if _spec_mode != SPEC_MODE_FREEFLY:
		if lb or dpl:
			_spec_cycle(-1)
		if rb or dpr:
			_spec_cycle(1)
	if y:
		_on_spec_toggle_pressed()
	if x:
		_on_spec_freefly_pressed()


func _spec_update_ui() -> void:
	# Re-label the buttons the moment the input device changes (pad glyphs vs plain text).
	if _spec_pad_ui_state != int(_last_input_was_pad):
		_spec_pad_ui_state = int(_last_input_was_pad)
		_spec_refresh_buttons()

	var in_chisel := _spec_mg_is("chisel")
	var on_hunter: bool = _spec_target != null and is_instance_valid(_spec_target) and _spec_role_for(_spec_target) == "HUNTER"
	if _spec_look_hint:
		_spec_look_hint.visible = _spec_mode == SPEC_MODE_FPV and not in_chisel and not on_hunter

	# Duck Hunt hunter: no FPV toggle -- its 3rd-person view already IS its scope. Drop out of FPV if
	# we cycled onto it while in FPV. Shows back the moment you cycle to someone else.
	if on_hunter and _spec_mode == SPEC_MODE_FPV:
		_spec_mode = SPEC_MODE_THIRD
		_spec_refresh_buttons()
	if _spec_toggle_btn:
		_spec_toggle_btn.visible = not in_chisel and not on_hunter

	# Chisel Gauntlet only has a fixed per-player spectate camera -- cycling/FPV do nothing there, so
	# leave ONLY the free-cam button.
	if in_chisel:
		if _spec_name_panel:
			_spec_name_panel.visible = false
		return
	if _spec_name_panel and not _spec_name_panel.visible:
		_spec_name_panel.visible = true

	# Free-fly is its own thing -- decoupled from spectating a player. Show that, hide the cycle arrows.
	if _spec_mode == SPEC_MODE_FREEFLY:
		if _spec_prev_btn:
			_spec_prev_btn.visible = false
		if _spec_next_btn:
			_spec_next_btn.visible = false
		if _spec_name_label:
			_spec_name_label.text = "In Free Cam mode"
		if _spec_role_label:
			_spec_role_label.text = "hold Shift / LB to look around"
			_spec_role_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.75))
			_spec_role_label.visible = true
		return
	if _spec_prev_btn:
		_spec_prev_btn.visible = true
	if _spec_next_btn:
		_spec_next_btn.visible = true
	if _spec_target != null and is_instance_valid(_spec_target):
		if _spec_name_label:
			_spec_name_label.text = _spec_name_of(_spec_target)
		if _spec_role_label:
			var role := _spec_role_for(_spec_target)
			_spec_role_label.text = role
			_spec_role_label.add_theme_color_override("font_color", _spec_role_color(role))
			_spec_role_label.visible = role != ""
	else:
		if _spec_name_label:
			_spec_name_label.text = "(no players)"
		if _spec_role_label:
			_spec_role_label.text = ""


func _spec_name_of(t: Node) -> String:
	if "player_presence" in t:
		var pp = t.get("player_presence")
		if pp != null and is_instance_valid(pp) and "network_name" in pp:
			var nm := String(pp.get("network_name"))
			if nm != "":
				return nm
	return String(t.name)


func _spec_role_for(t: Node) -> String:
	if t == null or not is_instance_valid(t):
		return ""
	var sc: Script = t.get_script()
	var cn: String = ""
	if sc != null:
		cn = String(sc.get_global_name())
	if cn == "KnifeAtTheOfficePlayer":
		if "is_infected" in t and bool(t.get("is_infected")):
			return "INFECTED"
		return "SURVIVOR"
	if cn.contains("DuckHunt"):
		if cn.contains("Hunter") or ("is_hunter" in t and bool(t.get("is_hunter"))):
			return "HUNTER"
		return "RUNNER"
	if "is_infected" in t and bool(t.get("is_infected")):
		return "INFECTED"
	if "is_hunter" in t and bool(t.get("is_hunter")):
		return "HUNTER"
	return ""


func _spec_role_color(role: String) -> Color:
	match role:
		"INFECTED":
			return Color(0.35, 0.8, 0.42)
		"HUNTER":
			return Color(0.96, 0.55, 0.2)
		"SURVIVOR":
			return Color(0.5, 0.76, 1.0)
		"RUNNER":
			return Color(0.92, 0.86, 0.4)
	return Color(0.85, 0.85, 0.85)


func _spec_refresh_buttons() -> void:
	# On a controller the buttons become hints showing the pad button that triggers each action.
	var pad := _last_input_was_pad
	if _spec_toggle_btn:
		var t_base: String = "Switch to third person" if _spec_mode == SPEC_MODE_FPV else "Switch to FPV view"
		_spec_toggle_btn.text = ("[Y]  " + t_base) if pad else t_base
	if _spec_freefly_btn:
		var f_base: String = "Exit Free Cam" if _spec_mode == SPEC_MODE_FREEFLY else "Free-fly cam"
		if pad:
			_spec_freefly_btn.text = "[X]  " + f_base
		else:
			_spec_freefly_btn.text = f_base + "  (F5)"
	if _spec_prev_btn:
		_spec_prev_btn.text = "LB" if pad else "◀"
	if _spec_next_btn:
		_spec_next_btn.text = "RB" if pad else "▶"


func _on_spec_toggle_pressed() -> void:
	if not _spec_engaged:
		return
	if _spec_mode == SPEC_MODE_FPV:
		_spec_mode = SPEC_MODE_THIRD
	else:
		_spec_snap_head = true  # jump straight onto the head, don't glide in from third/free
		_spec_look_yaw = 0.0    # start facing their forward
		_spec_look_pitch = 0.0
		_spec_mode = SPEC_MODE_FPV  # from third OR free-fly, the toggle goes to FPV
	_spec_refresh_buttons()


func _on_spec_freefly_pressed() -> void:
	if not _spec_engaged:
		return
	if _spec_mode == SPEC_MODE_FREEFLY:
		_spec_mode = SPEC_MODE_THIRD  # back to normal spectating
	else:
		# Spawn AT one of the players (their head), facing the way they face -- then fly anywhere.
		var anchor: Node = _spec_target
		if anchor == null or not is_instance_valid(anchor):
			if not _spec_targets.is_empty():
				anchor = _spec_targets[0]
		if anchor != null and is_instance_valid(anchor):
			_spec_freefly_yaw = _spec_body_yaw(anchor)
			_spec_freefly_pitch = 0.0
			_spec_freefly_pos = _spec_head_origin(anchor) + Vector3(0.0, 0.3, 0.0)
		elif _spec_cam and is_instance_valid(_spec_cam):
			_spec_freefly_pos = _spec_cam.global_position
		_spec_mode = SPEC_MODE_FREEFLY
	_spec_refresh_buttons()


func _on_spec_prev_pressed() -> void:
	_spec_cycle(-1)


func _on_spec_next_pressed() -> void:
	_spec_cycle(1)


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


func _forklift_eliminated() -> bool:
	# A forklift player that was eliminated this round shows blood decals (set true only in
	# set_eliminated_rpc, call_local -> all peers). Distinguishes a real death from a survivor who is
	# merely inactive between rounds.
	if _player == null or not is_instance_valid(_player):
		return false
	if not ("blood_decals_parent" in _player):
		return false
	var bd = _player.get("blood_decals_parent")
	return bd != null and is_instance_valid(bd) and bool(bd.get("visible"))


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
	# Live input-device detection: last real input wins, so the spectate UI can show pad glyphs on a
	# controller and plain labels on mouse/keyboard, flipping the instant you switch hands.
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		_last_input_was_pad = true
	elif event is InputEventJoypadMotion and abs((event as InputEventJoypadMotion).axis_value) > 0.5:
		_last_input_was_pad = true
	elif event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey:
		_last_input_was_pad = false

	# F5 toggles the free cam on/off while spectating (keyboard shortcut).
	if _spec_engaged and event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_F5:
			_on_spec_freefly_pressed()
			return

	if _lobby_cam_override_active and event is InputEventMouseMotion and _lobby_look_held():
		_lobby_mouse_rel += (event as InputEventMouseMotion).relative

	# Free-fly look: while spectating in free-fly (mouse captured).
	if _spec_engaged and _spec_mode == SPEC_MODE_FREEFLY and _spec_grabbed_mouse and event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_spec_freefly_yaw -= mm.relative.x * SPEC_FREEFLY_LOOK
		_spec_freefly_pitch = clamp(_spec_freefly_pitch - mm.relative.y * SPEC_FREEFLY_LOOK, -1.4, 1.4)
		return
	# FPV-spectate self-look: accumulate mouse motion while Shift is held.
	if _spec_engaged and _spec_mode == SPEC_MODE_FPV and Input.is_key_pressed(KEY_SHIFT) and event is InputEventMouseMotion:
		_spec_look_rel += (event as InputEventMouseMotion).relative
		return

	if not enabled or _player == null or not is_instance_valid(_player):
		return
	if not _player_is_active() and _ever_active and not _dying and not _stay_fpv_active:
		return  # allow look-around while finished/between-rounds (stay-FPV)
	if _dying:
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
	if not _player_is_active() and _ever_active and not _dying and not _stay_fpv_active:
		return  # allow look-around while finished/between-rounds (stay-FPV)
	if _dying:
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


func _finished_stay_fpv() -> bool:
	# True when the local player is inactive but NOT dead -- they finished their task (green pea food,
	# smoke break, a build, ...) or they're a Recycle survivor between rounds. Those must stay in first
	# person with look-around, never spectate. Only real death / leaving the game spectates.
	if _player == null or not is_instance_valid(_player):
		return false
	if "is_dead" in _player and bool(_player.get("is_dead")):
		return false
	if "is_alive" in _player and not bool(_player.get("is_alive")):
		return false  # a real kill (Inside Job kill_rpc) -> spectate
	if "finished" in _player and bool(_player.get("finished")):
		return true
	if "is_finished" in _player and bool(_player.get("is_finished")):
		return true
	if _is_player_class(&"BurnRecyclePlayer"):
		return true  # survivor through the score/loser-pick (is_dead flips only on the actual crush)
	if _is_player_class(&"KnifeAtTheOfficePlayer"):
		return true  # infection sets active=false for the 5s transform, but you're still playing -- stay FPV
	return false


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
			_spec_spawn_captured = false  # left the minigame -- re-capture spawn next match
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

		# Remember where we spawned this match -- the free-fly cam starts here.
		if not _spec_spawn_captured and _player is Node3D:
			_spec_spawn_pos = (_player as Node3D).global_position + Vector3(0.0, 1.4, 0.0)
			_spec_spawn_captured = true

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
		_gun_wall_clone = null
		_gun_wall_logged = false
		_recipe_seq = PackedInt32Array()
		_recipe_index = -1
		_recipe_done = false
		_recipe_frozen.clear()
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
		hud_in_depth = bool(parsed.get("hud_in_depth", true))
		experimental_manual_relock_enabled = bool(parsed.get("experimental_manual_relock_enabled", false))
		var legacy: float = float(parsed.get("sensitivity_mult", 1.0))
		_mouse_sensitivity_mult = float(parsed.get("mouse_sensitivity_mult", legacy))
		_controller_sensitivity_mult = float(parsed.get("controller_sensitivity_mult", legacy))
