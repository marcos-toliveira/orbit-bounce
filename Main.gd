extends Node2D

# ==============================================================================
# ORBIT BOUNCE (PONG CIRCULAR) - EVOLUTION 5.0
# Etapa 1: Economia, Persistência, Loja de Skins Cosméticas & Rewarded Ad Loop
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. PARÂMETROS GERAIS (@export)
# ------------------------------------------------------------------------------
@export_group("Arena e Estilo")
@export var arena_radius: float = 300.0
@export var arena_line_width: float = 5.0

@export_group("Jogador (Raquete Arredondada)")
@export var paddle_base_arc_degrees: float = 54.0
@export var paddle_thickness: float = 16.0
@export var paddle_smoothness: float = 48.0
@export var keyboard_rot_speed: float = 5.2

@export_group("Bolinha & Rastro")
@export var ball_radius: float = 11.0
@export var ball_base_speed: float = 310.0
@export var ball_speed_increment: float = 1.012
@export var max_trail_points: int = 14

@export_group("Efeitos Visuais")
@export var max_screen_shake: float = 9.0

# ------------------------------------------------------------------------------
# 2. ESTRUTURAS DE DADOS
# ------------------------------------------------------------------------------
class Ball:
	var pos: Vector2
	var vel: Vector2
	var speed: float
	var trail: Array[Vector2] = []
	var color: Color = Color.WHITE
	var is_fireball: bool = false
	var fireball_timer: float = 0.0

class Particle:
	var pos: Vector2
	var vel: Vector2
	var color: Color
	var life: float
	var max_life: float
	var size: float

class SquareBlock:
	var rect: Rect2
	var hp: int = 1
	var max_hp: int = 1
	var color: Color
	var spawn_anim: float = 0.0

class CoinItem:
	var pos: Vector2
	var radius: float = 14.0
	var pulse: float = 0.0

class Bumper:
	var pos: Vector2
	var radius: float = 24.0
	var base_radius: float = 24.0
	var impulse_scale: float = 1.0
	var color: Color = Color(0.2, 0.9, 1.0)

class HelixObstacle:
	var center: Vector2
	var angle: float = 0.0
	var rot_speed: float = 0.95
	var length: float = 150.0
	var thickness: float = 16.0
	var color: Color = Color(1.0, 0.28, 0.4)

class SpecialOrb:
	var pos: Vector2
	var radius: float = 17.0
	var type: String
	var pulse_time: float = 0.0

class TurretBullet:
	var pos: Vector2
	var vel: Vector2
	var radius: float = 7.0

class TurretBoss:
	var pos: Vector2
	var radius: float = 28.0
	var hp: int = 5
	var max_hp: int = 5
	var angle: float = 0.0
	var shoot_timer: float = 0.0
	var shoot_interval: float = 2.4

# ------------------------------------------------------------------------------
# 3. DEFINIÇÃO DAS 5 FASES
# ------------------------------------------------------------------------------
const STAGE_CONFIGS = [
	{
		"stage": 1,
		"title": "FASE 1: O DESPERTAR",
		"start_score": 0,
		"target_score": 150,
		"has_turret": false,
		"palette": {
			"name": "NEON CYAN",
			"paddle": Color(0.18, 0.92, 1.0),
			"arena": Color(0.12, 0.28, 0.38, 0.7),
			"accent": Color(0.2, 0.85, 1.0)
		}
	},
	{
		"stage": 2,
		"title": "FASE 2: PODERES & FEITIÇOS",
		"start_score": 150,
		"target_score": 350,
		"has_turret": false,
		"palette": {
			"name": "SYNTH PURPLE",
			"paddle": Color(0.95, 0.25, 0.88),
			"arena": Color(0.35, 0.14, 0.35, 0.7),
			"accent": Color(0.9, 0.3, 0.9)
		}
	},
	{
		"stage": 3,
		"title": "FASE 3: TORRE DE PLASMA",
		"start_score": 350,
		"target_score": 680,
		"has_turret": true,
		"palette": {
			"name": "ELECTRIC BLUE",
			"paddle": Color(0.2, 0.75, 1.0),
			"arena": Color(0.12, 0.25, 0.45, 0.7),
			"accent": Color(0.3, 0.85, 1.0)
		}
	},
	{
		"stage": 4,
		"title": "FASE 4: CAOS TRIPLO & FOGO",
		"start_score": 680,
		"target_score": 1100,
		"has_turret": false,
		"palette": {
			"name": "EMERALD LIME",
			"paddle": Color(0.25, 0.95, 0.45),
			"arena": Color(0.14, 0.32, 0.20, 0.7),
			"accent": Color(0.3, 1.0, 0.5)
		}
	},
	{
		"stage": 5,
		"title": "FASE 5: A HÉLICE & FORTALEZA",
		"start_score": 1100,
		"target_score": 1700,
		"has_turret": true,
		"palette": {
			"name": "SOLAR AMBER",
			"paddle": Color(1.0, 0.8, 0.15),
			"arena": Color(0.38, 0.26, 0.10, 0.7),
			"accent": Color(1.0, 0.45, 0.2)
		}
	}
]

# ------------------------------------------------------------------------------
# 4. VARIÁVEIS DE ESTADO E PERSISTÊNCIA
# ------------------------------------------------------------------------------
const SAVE_PATH = "user://orbit_bounce_save.json"

enum GameState { PLAYING, GAME_OVER, CAMPAIGN_CLEAR }
var current_state: GameState = GameState.PLAYING

var arena_center: Vector2 = Vector2.ZERO
var paddle_angle: float = -PI / 2.0
var target_paddle_angle: float = -PI / 2.0
var is_dragging: bool = false

# Persistência do Jogador
var total_coins_bank: int = 0
var high_score: int = 0
var unlocked_skins: Array = ["classic"]
var equipped_skin: String = "classic"

# Modificadores da Partida
var paddle_arc_current: float = 54.0
var paddle_buff_timer: float = 0.0
var paddle_buff_type: String = "normal"
var paddle_stun_timer: float = 0.0
var revive_shield_timer: float = 0.0
var has_revived_this_run: bool = false
var has_doubled_coins_this_run: bool = false
var run_coins_collected: int = 0

# Entidades ativas
var balls: Array[Ball] = []
var particles: Array[Particle] = []
var square_blocks: Array[SquareBlock] = []
var coins_items: Array[CoinItem] = []
var bumpers: Array[Bumper] = []
var helix: HelixObstacle = null
var active_special_orbs: Array[SpecialOrb] = []
var turret: TurretBoss = null
var turret_bullets: Array[TurretBullet] = []

# Progresso & Spawner Contínuo
var current_stage_idx: int = 0
var score: int = 0
var coins: int = 0
var screen_shake: float = 0.0
var dynamic_spawn_timer: float = 0.0

# Sistema de Áudio Procedural
var audio_player: AudioStreamPlayer
var sfx_bounce: AudioStreamWAV
var sfx_brick: AudioStreamWAV
var sfx_coin: AudioStreamWAV
var sfx_powerup: AudioStreamWAV
var sfx_poison: AudioStreamWAV
var sfx_fireball: AudioStreamWAV
var sfx_turret_shot: AudioStreamWAV
var sfx_gameover: AudioStreamWAV

# Referências de UI
@onready var wave_label: Label = $HUD/TopBar/VBoxContainer/HBoxContainer/WaveLabel
@onready var score_label: Label = $HUD/TopBar/VBoxContainer/HBoxContainer/ScoreLabel
@onready var coins_label: Label = $HUD/TopBar/VBoxContainer/HBoxContainer/CoinsLabel
@onready var top_shop_button: Button = $HUD/TopBar/VBoxContainer/HBoxContainer/TopShopButton
@onready var objective_label: Label = $HUD/TopBar/VBoxContainer/ObjectiveLabel
@onready var stage_progress_bar: ProgressBar = $HUD/TopBar/VBoxContainer/StageProgressBar
@onready var wave_banner: Label = $HUD/WaveBanner

# UI Game Over & Rewarded
@onready var game_over_panel: PanelContainer = $HUD/GameOverPanel
@onready var final_score_label: Label = $HUD/GameOverPanel/MarginContainer/VBoxContainer/FinalScoreLabel
@onready var high_score_label: Label = $HUD/GameOverPanel/MarginContainer/VBoxContainer/HighScoreLabel
@onready var waves_cleared_label: Label = $HUD/GameOverPanel/MarginContainer/VBoxContainer/WavesClearedLabel
@onready var revive_button: Button = $HUD/GameOverPanel/MarginContainer/VBoxContainer/ReviveButton
@onready var double_coins_button: Button = $HUD/GameOverPanel/MarginContainer/VBoxContainer/DoubleCoinsButton
@onready var game_over_shop_button: Button = $HUD/GameOverPanel/MarginContainer/VBoxContainer/GameOverShopButton
@onready var restart_button: Button = $HUD/GameOverPanel/MarginContainer/VBoxContainer/RestartButton

# UI Loja de Skins
@onready var shop_panel: PanelContainer = $HUD/ShopPanel
@onready var shop_coins_label: Label = $HUD/ShopPanel/MarginContainer/VBoxContainer/ShopCoinsLabel
@onready var skin_classic_btn: Button = $HUD/ShopPanel/MarginContainer/VBoxContainer/SkinClassicBtn
@onready var skin_fire_btn: Button = $HUD/ShopPanel/MarginContainer/VBoxContainer/SkinFireBtn
@onready var skin_synth_btn: Button = $HUD/ShopPanel/MarginContainer/VBoxContainer/SkinSynthBtn
@onready var skin_rainbow_btn: Button = $HUD/ShopPanel/MarginContainer/VBoxContainer/SkinRainbowBtn
@onready var close_shop_button: Button = $HUD/ShopPanel/MarginContainer/VBoxContainer/CloseShopButton

# UI Vitória
@onready var victory_panel: PanelContainer = $HUD/VictoryPanel
@onready var total_score_label: Label = $HUD/VictoryPanel/MarginContainer/VBoxContainer/TotalScoreLabel
@onready var infinite_button: Button = $HUD/VictoryPanel/MarginContainer/VBoxContainer/InfiniteButton

# ------------------------------------------------------------------------------
# 5. INICIALIZAÇÃO & PERSISTÊNCIA
# ------------------------------------------------------------------------------
func _ready() -> void:
	_init_procedural_audio()
	_update_center_pos()
	get_viewport().size_changed.connect(_update_center_pos)

	_load_profile()

	# Conexões de Botões
	restart_button.pressed.connect(start_new_campaign)
	infinite_button.pressed.connect(start_infinite_mode)
	revive_button.pressed.connect(_on_revive_pressed)
	double_coins_button.pressed.connect(_on_double_coins_pressed)
	top_shop_button.pressed.connect(_open_shop)
	game_over_shop_button.pressed.connect(_open_shop)
	close_shop_button.pressed.connect(_close_shop)

	skin_classic_btn.pressed.connect(func(): _select_skin("classic", 0))
	skin_fire_btn.pressed.connect(func(): _select_skin("fire", 40))
	skin_synth_btn.pressed.connect(func(): _select_skin("synth", 70))
	skin_rainbow_btn.pressed.connect(func(): _select_skin("rainbow", 120))

	start_new_campaign()

func _update_center_pos() -> void:
	arena_center = get_viewport_rect().size / 2.0

func _save_profile() -> void:
	var data = {
		"total_coins_bank": total_coins_bank,
		"high_score": high_score,
		"unlocked_skins": unlocked_skins,
		"equipped_skin": equipped_skin
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func _load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK and typeof(json.data) == TYPE_DICTIONARY:
			var d = json.data
			total_coins_bank = int(d.get("total_coins_bank", 0))
			high_score = int(d.get("high_score", 0))
			unlocked_skins = Array(d.get("unlocked_skins", ["classic"]))
			equipped_skin = String(d.get("equipped_skin", "classic"))

# ------------------------------------------------------------------------------
# 6. SISTEMA DE SOM PROCEDURAL SINTETIZADO
# ------------------------------------------------------------------------------
func _init_procedural_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.max_polyphony = 6
	add_child(audio_player)

	sfx_bounce = _synth_tone(320.0, 580.0, 0.08, "sine")
	sfx_brick = _synth_tone(420.0, 160.0, 0.07, "square")
	sfx_coin = _synth_arpeggio([880.0, 1320.0], 0.10)
	sfx_powerup = _synth_arpeggio([523.0, 659.0, 784.0, 1046.0], 0.20)
	sfx_poison = _synth_tone(450.0, 180.0, 0.22, "saw")
	sfx_fireball = _synth_tone(180.0, 380.0, 0.25, "noise")
	sfx_turret_shot = _synth_tone(850.0, 220.0, 0.09, "saw")
	sfx_gameover = _synth_arpeggio([392.0, 349.0, 311.0, 261.0], 0.45)

func _play_sfx(stream: AudioStreamWAV) -> void:
	if stream != null:
		audio_player.stream = stream
		audio_player.play()

func _synth_tone(f_start: float, f_end: float, duration: float, wave_type: String) -> AudioStreamWAV:
	var rate: int = 22050
	var samples_count: int = int(duration * rate)
	var data = PackedByteArray()
	data.resize(samples_count)
	var phase: float = 0.0

	for i in range(samples_count):
		var t = float(i) / float(samples_count)
		var freq = lerpf(f_start, f_end, t)
		phase += (freq * TAU) / float(rate)
		var val: float = 0.0

		if wave_type == "sine":
			val = sin(phase)
		elif wave_type == "square":
			val = 0.8 if sin(phase) > 0.0 else -0.8
		elif wave_type == "saw":
			val = fmod(phase / TAU, 1.0) * 2.0 - 1.0
		elif wave_type == "noise":
			val = (sin(phase) * 0.4) + randf_range(-0.5, 0.5)

		var env: float = 1.0 - t
		val = clampf(val * env, -1.0, 1.0)
		data[i] = int((val * 0.5 + 0.5) * 255.0)

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav

func _synth_arpeggio(notes: Array, total_dur: float) -> AudioStreamWAV:
	var rate: int = 22050
	var samples_count: int = int(total_dur * rate)
	var data = PackedByteArray()
	data.resize(samples_count)
	var note_dur = total_dur / float(notes.size())

	for i in range(samples_count):
		var time = float(i) / float(rate)
		var note_idx = mini(int(time / note_dur), notes.size() - 1)
		var freq: float = notes[note_idx]
		var phase = time * freq * TAU
		var val = sin(phase)
		var env = 1.0 - fmod(time, note_dur) / note_dur
		val = clampf(val * env, -1.0, 1.0)
		data[i] = int((val * 0.5 + 0.5) * 255.0)

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav

# ------------------------------------------------------------------------------
# 7. LOJA DE SKINS & SISTEMA REWARDED (REVIVER & DOBRAR MOEDAS)
# ------------------------------------------------------------------------------
func _open_shop() -> void:
	_update_shop_ui()
	shop_panel.visible = true

func _close_shop() -> void:
	shop_panel.visible = false

func _update_shop_ui() -> void:
	shop_coins_label.text = "Saldo Total: 🪙 %d" % (total_coins_bank + coins)
	
	_configure_skin_button(skin_classic_btn, "classic", "🔵 Ciano Clássico", 0)
	_configure_skin_button(skin_fire_btn, "fire", "🔥 Fogo Solar", 40)
	_configure_skin_button(skin_synth_btn, "synth", "🌸 Synthwave Rosa", 70)
	_configure_skin_button(skin_rainbow_btn, "rainbow", "🌈 Arco-Íris Cósmico", 120)

func _configure_skin_button(btn: Button, skin_id: String, skin_title: String, cost: int) -> void:
	var is_unlocked = unlocked_skins.has(skin_id)
	var is_equipped = (equipped_skin == skin_id)

	if is_equipped:
		btn.text = "%s [EQUIPADO ✅]" % skin_title
		btn.disabled = true
	elif is_unlocked:
		btn.text = "%s [EQUIPAR]" % skin_title
		btn.disabled = false
	else:
		btn.text = "%s (🪙 %d)" % [skin_title, cost]
		btn.disabled = (total_coins_bank + coins < cost)

func _select_skin(skin_id: String, cost: int) -> void:
	var available_coins = total_coins_bank + coins

	if unlocked_skins.has(skin_id):
		equipped_skin = skin_id
		_play_sfx(sfx_powerup)
	elif available_coins >= cost:
		if coins >= cost:
			coins -= cost
		else:
			var remaining_cost = cost - coins
			coins = 0
			total_coins_bank -= remaining_cost

		unlocked_skins.append(skin_id)
		equipped_skin = skin_id
		_play_sfx(sfx_coin)
		_trigger_firework(arena_center, Color(1.0, 0.85, 0.2), 30)

	_save_profile()
	_update_shop_ui()
	_update_hud()
	queue_redraw()

func _on_revive_pressed() -> void:
	if has_revived_this_run:
		return

	has_revived_this_run = true
	game_over_panel.visible = false
	current_state = GameState.PLAYING

	# Spawna a bolinha de volta no centro com escudo protetor!
	_spawn_ball(arena_center, randf() * TAU, ball_base_speed)
	revive_shield_timer = 2.8 # 2.8 segundos de barreira protetora
	paddle_arc_current = paddle_base_arc_degrees
	paddle_buff_type = "normal"
	paddle_stun_timer = 0.0

	_play_sfx(sfx_powerup)
	_trigger_firework(arena_center, Color(0.2, 1.0, 0.5), 40)
	_show_wave_banner("REVIVIDO! ESCUDO ATIVO! 🛡️")

func _on_double_coins_pressed() -> void:
	if has_doubled_coins_this_run:
		return

	has_doubled_coins_this_run = true
	var bonus_coins = run_coins_collected
	coins += bonus_coins
	total_coins_bank += bonus_coins
	_save_profile()

	double_coins_button.text = "DOBRADO! (🪙 +%d) ✅" % bonus_coins
	double_coins_button.disabled = true
	final_score_label.text = "Pontuação: %d  |  Moedas: %d" % [score, coins]
	_play_sfx(sfx_coin)
	_trigger_firework(arena_center, Color(1.0, 0.85, 0.2), 30)

# ------------------------------------------------------------------------------
# 8. CICLO DE PARTIDA
# ------------------------------------------------------------------------------
func _get_current_palette() -> Dictionary:
	var cfg = _get_current_config()
	return cfg["palette"]

func _get_current_config() -> Dictionary:
	if current_stage_idx < STAGE_CONFIGS.size():
		return STAGE_CONFIGS[current_stage_idx]
	var loop_idx = (current_stage_idx - STAGE_CONFIGS.size()) % STAGE_CONFIGS.size()
	return STAGE_CONFIGS[loop_idx]

func start_new_campaign() -> void:
	current_state = GameState.PLAYING
	game_over_panel.visible = false
	victory_panel.visible = false
	shop_panel.visible = false
	wave_banner.visible = false

	score = 0
	coins = 0
	run_coins_collected = 0
	has_revived_this_run = false
	has_doubled_coins_this_run = false
	revive_shield_timer = 0.0

	revive_button.text = "📺 REVIVER PARTIDA (1x)"
	revive_button.disabled = false
	double_coins_button.text = "🪙 2x MOEDAS DA PARTIDA"
	double_coins_button.disabled = false

	current_stage_idx = 0
	paddle_angle = -PI / 2.0
	target_paddle_angle = paddle_angle
	screen_shake = 0.0
	dynamic_spawn_timer = 0.0
	paddle_arc_current = paddle_base_arc_degrees
	paddle_buff_timer = 0.0
	paddle_buff_type = "normal"
	paddle_stun_timer = 0.0

	particles.clear()
	_load_stage(current_stage_idx)

func start_infinite_mode() -> void:
	victory_panel.visible = false
	current_state = GameState.PLAYING
	_load_stage(current_stage_idx)

func _load_stage(stage_idx: int) -> void:
	square_blocks.clear()
	coins_items.clear()
	bumpers.clear()
	helix = null
	active_special_orbs.clear()
	balls.clear()
	turret = null
	turret_bullets.clear()
	dynamic_spawn_timer = 0.0

	var cfg = _get_current_config()
	var palette = cfg["palette"]
	var blk_size = Vector2(28, 28)

	if cfg["has_turret"]:
		turret = TurretBoss.new()
		turret.pos = arena_center
		turret.hp = 5
		turret.max_hp = 5

	match stage_idx % 5:
		0: # Fase 1
			for p in [Vector2(-60, 0), Vector2(60, 0), Vector2(0, -60), Vector2(0, 60)]:
				_create_square_block(arena_center + p - blk_size / 2.0, blk_size, palette["accent"])
			_spawn_coin(arena_center + Vector2(-35, -35))
			_spawn_coin(arena_center + Vector2(35, 35))
			_spawn_special_orb(arena_center + Vector2(0, 45), "expand")

		1: # Fase 2
			for x in [-40, 0, 40]:
				for y in [-25, 25]:
					_create_square_block(arena_center + Vector2(x, y) - blk_size / 2.0, blk_size, palette["accent"])
			_spawn_coin(arena_center + Vector2(0, -70))
			_spawn_special_orb(arena_center + Vector2(-45, 0), "fireball")
			_spawn_special_orb(arena_center + Vector2(45, 0), "poison")

		2: # Fase 3 (Torre Atiradora + Bumpers)
			_create_bumper(arena_center + Vector2(-85, 0), palette["paddle"])
			_create_bumper(arena_center + Vector2(85, 0), palette["paddle"])
			for i in range(5):
				var ang = i * (TAU / 5.0)
				var pos = arena_center + Vector2.RIGHT.rotated(ang) * 65.0 - blk_size / 2.0
				_create_square_block(pos, blk_size, palette["accent"])
			_spawn_special_orb(arena_center + Vector2(0, -50), "fireball")

		3: # Fase 4 (Multiball)
			for i in range(8):
				var ang = i * (TAU / 8.0)
				var pos = arena_center + Vector2.RIGHT.rotated(ang) * 85.0 - blk_size / 2.0
				_create_square_block(pos, blk_size, palette["accent"])
			_spawn_special_orb(arena_center, "multiball")
			_spawn_special_orb(arena_center + Vector2(-50, 0), "expand")

		4: # Fase 5 (Hélice + Torre Central)
			helix = HelixObstacle.new()
			helix.center = arena_center
			helix.color = palette["accent"]
			for i in range(6):
				var ang = i * (TAU / 6.0)
				var pos = arena_center + Vector2.RIGHT.rotated(ang) * 115.0 - blk_size / 2.0
				_create_square_block(pos, blk_size, palette["paddle"])
			_spawn_special_orb(arena_center + Vector2(-60, -60), "fireball")

	var spd = ball_base_speed + (stage_idx * 14.0)
	_spawn_ball(arena_center, randf_range(0.0, TAU), spd)

	wave_label.text = cfg["title"]
	wave_label.add_theme_color_override("font_color", palette["paddle"])
	_update_objective_and_progress()
	_show_wave_banner(cfg["title"])
	_update_hud()

func _create_square_block(top_left: Vector2, size: Vector2, col: Color) -> void:
	var b = SquareBlock.new()
	b.rect = Rect2(top_left, size)
	b.color = col
	square_blocks.append(b)

func _spawn_coin(pos: Vector2) -> void:
	var c = CoinItem.new()
	c.pos = pos
	coins_items.append(c)

func _create_bumper(pos: Vector2, col: Color) -> void:
	var bmp = Bumper.new()
	bmp.pos = pos
	bmp.color = col
	bumpers.append(bmp)

func _spawn_ball(origin: Vector2, angle: float, spd: float) -> void:
	var b = Ball.new()
	b.pos = origin
	b.speed = spd
	b.vel = Vector2.RIGHT.rotated(angle) * spd
	balls.append(b)

func _spawn_special_orb(pos: Vector2, type: String) -> void:
	var s = SpecialOrb.new()
	s.pos = pos
	s.type = type
	active_special_orbs.append(s)

func _show_wave_banner(text: String) -> void:
	wave_banner.text = text
	wave_banner.visible = true
	var tween = create_tween()
	wave_banner.modulate = Color(1, 1, 1, 0)
	tween.tween_property(wave_banner, "modulate:a", 1.0, 0.25)
	tween.tween_interval(1.1)
	tween.tween_property(wave_banner, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func(): wave_banner.visible = false)

# ------------------------------------------------------------------------------
# 9. ENTRADAS DE DADOS
# ------------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if current_state != GameState.PLAYING or shop_panel.visible:
		return

	if event is InputEventScreenTouch:
		is_dragging = event.pressed
		if event.pressed:
			_aim_at(event.position)
	elif event is InputEventScreenDrag:
		_aim_at(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_dragging = event.pressed
		if event.pressed:
			_aim_at(event.position)
	elif event is InputEventMouseMotion:
		_aim_at(event.position)

func _aim_at(screen_pos: Vector2) -> void:
	var diff = screen_pos - arena_center
	if diff.length_squared() > 100.0:
		target_paddle_angle = diff.angle()

# ------------------------------------------------------------------------------
# 10. FÍSICA E PROCESSAMENTO
# ------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if current_state != GameState.PLAYING or shop_panel.visible:
		return

	_process_modifiers(delta)
	_process_screen_shake(delta)
	_process_paddle(delta)
	_process_turret(delta)
	_process_helix(delta)
	_process_bumpers(delta)
	_process_balls(delta)
	_process_particles(delta)
	_process_special_orbs(delta)
	_process_coins_animation(delta)
	_process_dynamic_spawning(delta)

	_update_objective_and_progress()

	var cfg = _get_current_config()
	if score >= cfg["target_score"]:
		_complete_current_stage()

	queue_redraw()

func _process_modifiers(delta: float) -> void:
	if revive_shield_timer > 0.0:
		revive_shield_timer -= delta

	if paddle_buff_timer > 0.0:
		paddle_buff_timer -= delta
		if paddle_buff_timer <= 0.0:
			if paddle_buff_type == "expand" or paddle_buff_type == "poison":
				paddle_arc_current = paddle_base_arc_degrees
			paddle_buff_type = "normal"

	if paddle_stun_timer > 0.0:
		paddle_stun_timer -= delta

func _process_turret(delta: float) -> void:
	if turret == null:
		return

	turret.angle += 0.8 * delta
	turret.shoot_timer += delta

	if turret.shoot_timer >= turret.shoot_interval:
		turret.shoot_timer = 0.0
		var b = TurretBullet.new()
		b.pos = turret.pos
		b.vel = Vector2.RIGHT.rotated(turret.angle) * 190.0
		turret_bullets.append(b)
		_play_sfx(sfx_turret_shot)
		_trigger_firework(turret.pos, Color(1.0, 0.2, 0.2), 8)

	for i in range(turret_bullets.size() - 1, -1, -1):
		var tb = turret_bullets[i]
		tb.pos += tb.vel * delta

		var dist_out = tb.pos.distance_to(arena_center)
		if dist_out >= arena_radius - 14.0:
			var dir_ang = (tb.pos - arena_center).angle()
			var diff = abs(angle_difference(paddle_angle, dir_ang))
			var half_arc = deg_to_rad(paddle_arc_current / 2.0)

			if diff <= half_arc:
				paddle_arc_current = maxf(paddle_arc_current - 14.0, 14.0)
				paddle_buff_type = "hit"
				paddle_buff_timer = 0.4
				paddle_stun_timer = 0.3
				_add_shake(5.5)
				_trigger_firework(tb.pos, Color(1.0, 0.2, 0.2), 24)
				_play_sfx(sfx_poison)
				turret_bullets.remove_at(i)
				continue

		if dist_out >= arena_radius + 20.0:
			turret_bullets.remove_at(i)

func _process_dynamic_spawning(delta: float) -> void:
	dynamic_spawn_timer += delta
	if dynamic_spawn_timer >= 3.2:
		dynamic_spawn_timer = 0.0
		var palette = _get_current_palette()
		var blk_size = Vector2(28, 28)

		if square_blocks.size() < 7:
			var rand_dist = randf_range(40.0, arena_radius * 0.52)
			var rand_pos = arena_center + Vector2.RIGHT.rotated(randf() * TAU) * rand_dist - blk_size / 2.0
			_create_square_block(rand_pos, blk_size, palette["accent"])
			_trigger_firework(rand_pos + blk_size / 2.0, palette["accent"].lightened(0.3), 10)

		if coins_items.size() < 3:
			var coin_dist = randf_range(50.0, arena_radius * 0.65)
			_spawn_coin(arena_center + Vector2.RIGHT.rotated(randf() * TAU) * coin_dist)

		if active_special_orbs.size() < 2:
			var types = ["expand", "poison", "fireball"]
			var chosen = types[randi() % types.size()]
			var sp_dist = randf_range(50.0, 110.0)
			_spawn_special_orb(arena_center + Vector2.RIGHT.rotated(randf() * TAU) * sp_dist, chosen)

	for blk in square_blocks:
		if blk.spawn_anim < 1.0:
			blk.spawn_anim = clampf(blk.spawn_anim + delta * 4.0, 0.0, 1.0)

func _update_objective_and_progress() -> void:
	var cfg = _get_current_config()
	var start_s = float(cfg["start_score"])
	var target_s = float(cfg["target_score"])
	var span = maxf(target_s - start_s, 1.0)
	var current_prog = clampf(float(score) - start_s, 0.0, span)

	stage_progress_bar.max_value = span
	stage_progress_bar.value = current_prog

	var buff_indicator = ""
	if paddle_buff_type == "expand":
		buff_indicator = " [RAQUETE GIGANTE! 🟢]"
	elif paddle_buff_type == "poison":
		buff_indicator = " [VENENO MINI! 🟣]"
	elif paddle_arc_current <= 16.0:
		buff_indicator = " [RAQUETE MÍNIMA! 💀]"
	elif paddle_arc_current <= 28.0:
		buff_indicator = " [RAQUETE CRÍTICA! ⚠️]"
	elif paddle_stun_timer > 0.0:
		buff_indicator = " [ATORDOADO! ⚡]"

	objective_label.text = "Meta: %d PONTOS (%d/%d)%s" % [target_s, score, target_s, buff_indicator]

func _process_coins_animation(delta: float) -> void:
	for c in coins_items:
		c.pulse += delta * 4.0

func _process_screen_shake(delta: float) -> void:
	if screen_shake > 0.0:
		screen_shake = lerpf(screen_shake, 0.0, 12.0 * delta)
		if screen_shake < 0.2:
			screen_shake = 0.0

func _process_paddle(delta: float) -> void:
	var key_axis = Input.get_axis("ui_left", "ui_right")
	if key_axis != 0.0:
		var speed_mod = 0.4 if paddle_stun_timer > 0.0 else 1.0
		target_paddle_angle += key_axis * keyboard_rot_speed * speed_mod * delta
		target_paddle_angle = wrapf(target_paddle_angle, -PI, PI)

	var diff = angle_difference(paddle_angle, target_paddle_angle)
	var lerp_spd = paddle_smoothness * (0.3 if paddle_stun_timer > 0.0 else 1.0)
	paddle_angle += diff * clampf(lerp_spd * delta, 0.0, 1.0)
	paddle_angle = wrapf(paddle_angle, -PI, PI)

func _process_helix(delta: float) -> void:
	if helix != null:
		helix.angle += helix.rot_speed * delta
		helix.angle = wrapf(helix.angle, -PI, PI)

func _process_bumpers(delta: float) -> void:
	for bmp in bumpers:
		if bmp.impulse_scale > 1.0:
			bmp.impulse_scale = lerpf(bmp.impulse_scale, 1.0, 8.0 * delta)
			bmp.radius = bmp.base_radius * bmp.impulse_scale

func _process_balls(delta: float) -> void:
	var boundary_limit = arena_radius - ball_radius
	var palette = _get_current_palette()

	for i in range(balls.size() - 1, -1, -1):
		var b = balls[i]

		if b.is_fireball:
			b.fireball_timer -= delta
			if b.fireball_timer <= 0.0:
				b.is_fireball = false
				b.color = Color.WHITE

		b.trail.push_front(b.pos)
		if b.trail.size() > max_trail_points:
			b.trail.pop_back()

		b.pos += b.vel * delta
		var dist_center = b.pos.distance_to(arena_center)

		if dist_center >= boundary_limit:
			var outward_normal = (b.pos - arena_center).normalized()
			var impact_angle = outward_normal.angle()
			var ang_diff = abs(angle_difference(paddle_angle, impact_angle))
			var half_arc = deg_to_rad(paddle_arc_current / 2.0)

			# 1. Acertou a raquete!
			if ang_diff <= half_arc:
				var inward_normal = -outward_normal
				b.vel = b.vel.bounce(inward_normal)

				var contact_ratio = angle_difference(paddle_angle, impact_angle) / half_arc
				var tangent = Vector2(-outward_normal.y, outward_normal.x)
				b.vel = (b.vel + tangent * contact_ratio * (b.speed * 0.35)).normalized() * b.speed

				if b.vel.dot(outward_normal) > 0.0:
					b.vel = b.vel.bounce(inward_normal)

				b.speed *= ball_speed_increment
				b.vel = b.vel.normalized() * b.speed
				b.pos = arena_center + outward_normal * (boundary_limit - 1.0)

				score += 1
				_update_hud()
				_add_shake(2.5)
				_play_sfx(sfx_bounce)
				_trigger_firework(b.pos, palette["paddle"], 12)

			# 2. ESCUDO DE REVIVER ATIVO: Rebate de volta automaticamente!
			elif revive_shield_timer > 0.0:
				var inward_normal = -outward_normal
				b.vel = b.vel.bounce(inward_normal)
				b.pos = arena_center + outward_normal * (boundary_limit - 1.0)
				_add_shake(4.0)
				_play_sfx(sfx_bounce)
				_trigger_firework(b.pos, Color(0.2, 1.0, 0.5), 18)

			else:
				# Perdeu a bolinha
				_trigger_firework(b.pos, Color(1.0, 0.2, 0.3), 16)
				balls.remove_at(i)
				continue

		_check_ball_coins_pickup(b)
		_check_ball_square_blocks_collision(b)
		_check_ball_bumpers_collision(b)
		_check_ball_helix_collision(b)
		_check_ball_turret_collision(b)

	if balls.is_empty():
		_trigger_game_over()

func _check_ball_coins_pickup(b: Ball) -> void:
	for i in range(coins_items.size() - 1, -1, -1):
		var coin = coins_items[i]
		if b.pos.distance_to(coin.pos) <= ball_radius + coin.radius:
			coins += 1
			run_coins_collected += 1
			total_coins_bank += 1
			score += 15
			_play_sfx(sfx_coin)
			_trigger_firework(coin.pos, Color(1.0, 0.85, 0.15), 18)
			coins_items.remove_at(i)
			_update_hud()

func _check_ball_square_blocks_collision(b: Ball) -> void:
	for i in range(square_blocks.size() - 1, -1, -1):
		var blk = square_blocks[i]
		var blk_center = blk.rect.get_center()
		var half_sz = blk.rect.size / 2.0
		var diff = b.pos - blk_center

		var overlap_x = (half_sz.x + ball_radius) - absf(diff.x)
		var overlap_y = (half_sz.y + ball_radius) - absf(diff.y)

		if overlap_x > 0.0 and overlap_y > 0.0:
			if not b.is_fireball:
				if overlap_x < overlap_y:
					b.vel.x = -b.vel.x
					b.pos.x = blk_center.x + (half_sz.x + ball_radius + 1.0) * signf(diff.x)
				else:
					b.vel.y = -b.vel.y
					b.pos.y = blk_center.y + (half_sz.y + ball_radius + 1.0) * signf(diff.y)

			square_blocks.remove_at(i)
			score += 25
			_play_sfx(sfx_brick)
			_add_shake(3.5)
			_trigger_firework(blk_center, blk.color, 16)
			_update_hud()
			break

func _check_ball_turret_collision(b: Ball) -> void:
	if turret == null:
		return

	if b.pos.distance_to(turret.pos) <= ball_radius + turret.radius:
		var normal = (b.pos - turret.pos).normalized()
		b.vel = b.vel.bounce(normal)
		b.pos = turret.pos + normal * (turret.radius + ball_radius + 2.0)

		var dmg = 5 if b.is_fireball else 1
		turret.hp -= dmg
		_add_shake(6.0)
		_play_sfx(sfx_brick)
		_trigger_firework(turret.pos, Color(1.0, 0.4, 0.1), 22)

		if turret.hp <= 0:
			_trigger_firework(turret.pos, Color(1.0, 0.8, 0.2), 45)
			_play_sfx(sfx_powerup)
			score += 150
			coins += 10
			run_coins_collected += 10
			total_coins_bank += 10
			turret = null
			_update_hud()

func _check_ball_bumpers_collision(b: Ball) -> void:
	for bmp in bumpers:
		var dist = b.pos.distance_to(bmp.pos)
		if dist <= ball_radius + bmp.radius:
			var normal = (b.pos - bmp.pos).normalized()
			b.vel = b.vel.bounce(normal)
			b.pos = bmp.pos + normal * (bmp.radius + ball_radius + 2.0)

			bmp.impulse_scale = 1.25
			_add_shake(4.0)
			_play_sfx(sfx_bounce)
			_trigger_firework(bmp.pos + normal * bmp.radius, bmp.color, 16)
			score += 5
			_update_hud()

func _check_ball_helix_collision(b: Ball) -> void:
	if helix == null:
		return

	var rel_pos = b.pos - helix.center
	var local_pos = rel_pos.rotated(-helix.angle)
	var half_len = helix.length / 2.0
	var half_thk = helix.thickness / 2.0

	var cl_x = clampf(local_pos.x, -half_len, half_len)
	var cl_y = clampf(local_pos.y, -half_thk, half_thk)
	var local_closest = Vector2(cl_x, cl_y)
	var local_diff = local_pos - local_closest

	if local_diff.length() <= ball_radius:
		var local_normal = local_diff.normalized()
		if local_normal.is_zero_approx():
			local_normal = Vector2.UP

		var world_normal = local_normal.rotated(helix.angle)
		var surface_tangent = Vector2(-rel_pos.y, rel_pos.x) * helix.rot_speed

		b.vel = b.vel.bounce(world_normal) + surface_tangent * 0.3
		b.vel = b.vel.normalized() * b.speed
		b.pos = helix.center + (local_closest + local_normal * (ball_radius + 2.0)).rotated(helix.angle)

		_add_shake(4.5)
		_play_sfx(sfx_bounce)
		_trigger_firework(b.pos, helix.color, 16)

func _process_special_orbs(delta: float) -> void:
	for i in range(active_special_orbs.size() - 1, -1, -1):
		var orb = active_special_orbs[i]
		orb.pulse_time += delta

		for b in balls:
			if b.pos.distance_to(orb.pos) <= ball_radius + orb.radius:
				_apply_special_orb_effect(orb.type, b, orb.pos)
				active_special_orbs.remove_at(i)
				break

func _apply_special_orb_effect(type: String, b: Ball, hit_pos: Vector2) -> void:
	match type:
		"multiball":
			_spawn_ball(hit_pos, b.vel.angle() + deg_to_rad(30.0), b.speed)
			_spawn_ball(hit_pos, b.vel.angle() - deg_to_rad(30.0), b.speed)
			_play_sfx(sfx_powerup)
			_trigger_firework(hit_pos, Color(1.0, 0.85, 0.2), 30)

		"expand":
			paddle_buff_type = "expand"
			paddle_arc_current = 76.0
			paddle_buff_timer = 10.0
			_play_sfx(sfx_powerup)
			_trigger_firework(hit_pos, Color(0.2, 1.0, 0.4), 28)

		"poison":
			paddle_buff_type = "poison"
			paddle_arc_current = 36.0
			paddle_buff_timer = 8.0
			_play_sfx(sfx_poison)
			_trigger_firework(hit_pos, Color(0.8, 0.2, 0.9), 25)

		"fireball":
			b.is_fireball = true
			b.fireball_timer = 10.0
			b.color = Color(1.0, 0.4, 0.1)
			_play_sfx(sfx_fireball)
			_trigger_firework(hit_pos, Color(1.0, 0.4, 0.1), 35)

	coins += 2
	run_coins_collected += 2
	total_coins_bank += 2
	score += 30
	_add_shake(5.0)
	_update_hud()

func _complete_current_stage() -> void:
	score += 100
	coins += 5
	run_coins_collected += 5
	total_coins_bank += 5
	_play_sfx(sfx_powerup)
	_trigger_firework(arena_center, Color(0.2, 1.0, 0.6), 45)

	if current_stage_idx == 4:
		current_state = GameState.CAMPAIGN_CLEAR
		if score > high_score:
			high_score = score
		_save_profile()
		total_score_label.text = "Pontuação: %d  |  Moedas: %d" % [score, coins]
		victory_panel.visible = true
		current_stage_idx += 1
	else:
		current_stage_idx += 1
		_load_stage(current_stage_idx)

# ------------------------------------------------------------------------------
# 11. SISTEMA DE PARTÍCULAS
# ------------------------------------------------------------------------------
func _trigger_firework(origin: Vector2, col: Color, count: int) -> void:
	for i in range(count):
		var p = Particle.new()
		p.pos = origin
		var ang = randf_range(0.0, TAU)
		var spd = randf_range(80.0, 240.0)
		p.vel = Vector2.RIGHT.rotated(ang) * spd
		p.color = col.lightened(randf_range(0.0, 0.4))
		p.max_life = randf_range(0.3, 0.55)
		p.life = p.max_life
		p.size = randf_range(2.5, 4.0)
		particles.append(p)

func _process_particles(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p = particles[i]
		p.life -= delta
		if p.life <= 0.0:
			particles.remove_at(i)
			continue
		p.pos += p.vel * delta
		p.vel *= (1.0 - 2.5 * delta)

func _add_shake(amount: float) -> void:
	screen_shake = clampf(screen_shake + amount, 0.0, max_screen_shake)

# ------------------------------------------------------------------------------
# 12. RENDERIZAÇÃO GRÁFICA VIA CÓDIGO (_draw)
# ------------------------------------------------------------------------------
func _draw() -> void:
	var shake_offset = Vector2.ZERO
	if screen_shake > 0.0:
		shake_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * screen_shake

	var center = arena_center + shake_offset
	var palette = _get_current_palette()

	# 1. Fundo da Arena e Borda
	draw_circle(center, arena_radius, Color(0.06, 0.07, 0.11, 0.9))
	draw_arc(center, arena_radius, 0.0, TAU, 84, palette["arena"], arena_line_width, true)

	# 2. Escudo Protetor de Reviver (se ativo)
	if revive_shield_timer > 0.0:
		var shield_pulse = 0.5 + 0.4 * sin(Time.get_ticks_msec() * 0.015)
		var shield_col = Color(0.2, 1.0, 0.6, shield_pulse)
		draw_arc(center, arena_radius - 3.0, 0.0, TAU, 64, shield_col, 6.0, true)

	# 3. Hélice Rotativa (Fase 5)
	if helix != null:
		var h_center = helix.center + shake_offset
		var h_dir = Vector2.RIGHT.rotated(helix.angle)
		var p_start = h_center - h_dir * (helix.length / 2.0)
		var p_end = h_center + h_dir * (helix.length / 2.0)
		draw_line(p_start, p_end, helix.color, helix.thickness, true)
		draw_circle(p_start, helix.thickness / 2.0, helix.color)
		draw_circle(p_end, helix.thickness / 2.0, helix.color)
		draw_circle(h_center, helix.thickness * 0.7, Color.WHITE)

	# 4. Torre Central Atiradora (Boss)
	if turret != null:
		var t_pos = turret.pos + shake_offset
		draw_circle(t_pos, turret.radius, Color(0.85, 0.15, 0.2))
		draw_arc(t_pos, turret.radius, 0.0, TAU, 28, Color.WHITE, 2.5, true)
		var barrel_dir = Vector2.RIGHT.rotated(turret.angle)
		draw_line(t_pos, t_pos + barrel_dir * (turret.radius + 12.0), Color.WHITE, 6.0, true)
		draw_circle(t_pos, 8.0, Color.BLACK)
		for h in range(turret.max_hp):
			var hp_col = Color(0.2, 1.0, 0.4) if h < turret.hp else Color(0.3, 0.3, 0.3)
			var off_x = (h - (turret.max_hp - 1) / 2.0) * 10.0
			draw_circle(t_pos + Vector2(off_x, -turret.radius - 8.0), 3.0, hp_col)

	# 5. Projéteis da Torre
	for tb in turret_bullets:
		var tb_pos = tb.pos + shake_offset
		draw_circle(tb_pos, tb.radius, Color(1.0, 0.2, 0.2))
		draw_circle(tb_pos, tb.radius * 0.5, Color.WHITE)

	# 6. Bumpers Elásticos
	for bmp in bumpers:
		var b_pos = bmp.pos + shake_offset
		draw_circle(b_pos, bmp.radius, bmp.color.darkened(0.3))
		draw_arc(b_pos, bmp.radius, 0.0, TAU, 32, Color.WHITE, 2.5, true)
		draw_circle(b_pos, bmp.radius * 0.4, Color.WHITE)

	# 7. Moedas Coletáveis
	for c in coins_items:
		var c_pos = c.pos + shake_offset
		var scale_p = 1.0 + 0.12 * sin(c.pulse)
		draw_circle(c_pos, c.radius * scale_p, Color(1.0, 0.85, 0.2))
		draw_circle(c_pos, c.radius * 0.75 * scale_p, Color(1.0, 0.95, 0.4))
		draw_line(c_pos + Vector2(0, -5), c_pos + Vector2(0, 5), Color(0.65, 0.45, 0.0), 2.0)

	# 8. Blocos Quadradinhos
	for blk in square_blocks:
		var blk_scale = blk.spawn_anim
		var sz = blk.rect.size * blk_scale
		var top_left = blk.rect.get_center() - sz / 2.0 + shake_offset
		var r_off = Rect2(top_left, sz)
		draw_rect(r_off, blk.color)
		draw_rect(r_off, Color.WHITE.lerp(blk.color, 0.4), false, 2.0)

	# 9. Orbes Especiais
	for orb in active_special_orbs:
		var o_pos = orb.pos + shake_offset
		var pulse = 1.0 + 0.15 * sin(orb.pulse_time * 7.0)
		var base_col = Color.WHITE
		match orb.type:
			"multiball": base_col = Color(1.0, 0.85, 0.2)
			"expand": base_col = Color(0.2, 1.0, 0.4)
			"poison": base_col = Color(0.85, 0.2, 0.95)
			"fireball": base_col = Color(1.0, 0.4, 0.1)

		draw_circle(o_pos, orb.radius * pulse, base_col.darkened(0.2))
		draw_circle(o_pos, orb.radius * 0.7 * pulse, base_col)
		draw_circle(o_pos, 4.0, Color.WHITE)

	# 10. Raquete (com estados visuais de integridade)
	var half_arc = deg_to_rad(paddle_arc_current / 2.0)
	var start_ang = paddle_angle - half_arc
	var end_ang = paddle_angle + half_arc

	var p_color = palette["paddle"]
	if paddle_buff_type == "hit" or paddle_stun_timer > 0.0:
		p_color = Color(1.0, 0.2, 0.2)
	elif paddle_buff_type == "expand":
		p_color = Color(0.2, 1.0, 0.4)
	elif paddle_buff_type == "poison":
		p_color = Color(0.85, 0.2, 0.95)
	elif paddle_arc_current <= 24.0:
		p_color = Color(1.0, 0.35, 0.2)

	draw_arc(center, arena_radius, start_ang, end_ang, 44, p_color, paddle_thickness, true)
	var cap_radius = paddle_thickness / 2.0
	draw_circle(center + Vector2.RIGHT.rotated(start_ang) * arena_radius, cap_radius, p_color)
	draw_circle(center + Vector2.RIGHT.rotated(end_ang) * arena_radius, cap_radius, p_color)

	# 11. Rastro das Bolinhas (Customizado pela Skin Equipada!)
	for b in balls:
		var t_size = b.trail.size()
		for t_idx in range(t_size):
			var alpha = 1.0 - (float(t_idx) / float(t_size))
			var r_sz = ball_radius * (1.0 - (float(t_idx) / float(t_size)) * 0.6)

			var trail_col = palette["paddle"]
			if b.is_fireball or equipped_skin == "fire":
				trail_col = Color(1.0, 0.45, 0.1)
			elif equipped_skin == "synth":
				trail_col = Color(1.0, 0.2, 0.8)
			elif equipped_skin == "rainbow":
				var hue = fmod(float(t_idx) * 0.08 + float(Time.get_ticks_msec()) * 0.001, 1.0)
				trail_col = Color.from_hsv(hue, 0.9, 1.0)

			trail_col.a = alpha * 0.5
			draw_circle(b.trail[t_idx] + shake_offset, r_sz, trail_col)

		var b_col = Color(1.0, 0.4, 0.1) if b.is_fireball else b.color
		draw_circle(b.pos + shake_offset, ball_radius, b_col)
		draw_circle(b.pos + shake_offset, ball_radius * 0.5, Color.WHITE)

	# 12. Partículas
	for pt in particles:
		var alpha = pt.life / pt.max_life
		var col = pt.color
		col.a = alpha
		draw_circle(pt.pos + shake_offset, pt.size * alpha, col)

# ------------------------------------------------------------------------------
# 13. HUD E GAME OVER
# ------------------------------------------------------------------------------
func _update_hud() -> void:
	score_label.text = "PONTOS: %d" % score
	coins_label.text = "🪙 %d" % coins

func _trigger_game_over() -> void:
	current_state = GameState.GAME_OVER
	_play_sfx(sfx_gameover)

	if score > high_score:
		high_score = score
	_save_profile()

	final_score_label.text = "Pontuação: %d  |  Moedas: %d" % [score, coins]
	high_score_label.text = "🏆 RECORDE PESSOAL: %d" % high_score
	waves_cleared_label.text = "Fases Concluídas: %d" % current_stage_idx

	revive_button.disabled = has_revived_this_run
	if has_revived_this_run:
		revive_button.text = "REVIVER JÁ USADO ❌"
	else:
		revive_button.text = "📺 REVIVER PARTIDA (1x)"

	if has_doubled_coins_this_run:
		double_coins_button.text = "MOEDAS DOBRADAS ✅"
		double_coins_button.disabled = true
	else:
		double_coins_button.text = "🪙 2x MOEDAS (+%d)" % run_coins_collected
		double_coins_button.disabled = (run_coins_collected == 0)

	game_over_panel.visible = true
	queue_redraw()
