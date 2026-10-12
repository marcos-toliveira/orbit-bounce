extends Node2D

# ==============================================================================
# ORBIT BOUNCE (PONG CIRCULAR) - EVOLUTION 7.0
# Clareza de Objetivos, Briefing de Fases, Duração Calibrada & Celebrações
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

class FloatingScore:
	var pos: Vector2
	var text: String
	var color: Color
	var life: float = 0.0
	var max_life: float = 0.85
	var font_size: int = 24

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
# 3. DEFINIÇÃO DAS 5 FASES DA CAMPANHA (METAS CALIBRADAS & MISSÕES CLARAS)
# ------------------------------------------------------------------------------
const STAGE_CONFIGS = [
	{
		"stage": 1,
		"title": "FASE 1: O DESPERTAR",
		"mission_title": "🎯 MISSÃO: O DESPERTAR",
		"mission_desc": "Alcance 400 Pontos rebatendo a bolinha na raquete, quebrando os blocos centrais e coletando moedas orbitais!",
		"mission_tip": "💡 Dica: A bolinha acelera suavemente a cada rebatida. Mantenha a raquete ágil!",
		"target_score": 400,
		"star_1": 400,
		"star_2": 540,
		"star_3": 700,
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
		"mission_title": "🔥 MISSÃO: PODERES & FEITIÇOS",
		"mission_desc": "Alcance 700 Pontos! Use a Bola de Fogo 🔥 para pulverizar blocos e fuja da Gosma Roxa 🟣 que encolhe sua raquete!",
		"mission_tip": "💡 Dica: O Bichinho Verde 🟢 expande sua raquete para 76°, facilitando as defesas.",
		"target_score": 700,
		"star_1": 700,
		"star_2": 950,
		"star_3": 1250,
		"has_turret": false,
		"palette": {
			"name": "PURPLE NEON",
			"paddle": Color(0.85, 0.25, 1.0),
			"arena": Color(0.28, 0.12, 0.38, 0.7),
			"accent": Color(0.9, 0.4, 1.0)
		}
	},
	{
		"stage": 3,
		"title": "FASE 3: PINBALL & BUMPERS",
		"mission_title": "💥 MISSÃO: PINBALL & BUMPERS",
		"mission_desc": "Alcance 1000 Pontos! Enfrente a Torre Central atiradora 💥 e use o impulso veloz dos Bumpers elásticos azuis!",
		"mission_tip": "💡 Dica: Acerte a Torre com a bolinha para causar dano (+50 pts) e destruí-la (+150 pts)!",
		"target_score": 1000,
		"star_1": 1000,
		"star_2": 1350,
		"star_3": 1750,
		"has_turret": true,
		"palette": {
			"name": "ELECTRIC BLUE",
			"paddle": Color(0.2, 0.55, 1.0),
			"arena": Color(0.10, 0.18, 0.42, 0.7),
			"accent": Color(0.35, 0.75, 1.0)
		}
	},
	{
		"stage": 4,
		"title": "FASE 4: CAOS TRIPLO & FOGO",
		"mission_title": "🟡 MISSÃO: CAOS TRIPLO & FOGO",
		"mission_desc": "Alcance 1400 Pontos no Caos Triplo! Colete o Multiball 🟡 para controlar 3 bolinhas simultâneas e multiplicar sua pontuação!",
		"mission_tip": "💡 Dica: Enquanto pelo menos 1 bolinha estiver viva, você continua pontuando a toda velocidade!",
		"target_score": 1400,
		"star_1": 1400,
		"star_2": 1900,
		"star_3": 2500,
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
		"mission_title": "⚡ MISSÃO: A HÉLICE & FORTALEZA",
		"mission_desc": "Alcance 1900 Pontos! Supere a Lâmina da Hélice giratória ⚡ e derrote a Fortaleza Central armada no grande confronto final!",
		"mission_tip": "💡 Dica: A Hélice transfere momento angular. Pegue a Bola de Fogo 🔥 para destruir a Torre em 1 golpe!",
		"target_score": 1900,
		"star_1": 1900,
		"star_2": 2500,
		"star_3": 3200,
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
const MAX_LIVES = 5
const LIFE_RECHARGE_SECONDS = 180 # 3 minutos para recarregar 1 vida

enum GameState { MAP, BRIEFING, PLAYING, STAGE_CLEAR, GAME_OVER, VICTORY }
var current_state: GameState = GameState.MAP

var arena_center: Vector2 = Vector2.ZERO
var paddle_angle: float = -PI / 2.0
var target_paddle_angle: float = -PI / 2.0
var is_dragging: bool = false

# Dados Persistentes do Jogador
var total_coins_bank: int = 0
var high_score: int = 0
var lives: int = 5
var last_life_timestamp: int = 0
var unlocked_stage: int = 0
var stage_high_scores: Dictionary = {}
var stage_stars: Dictionary = {}
var unlocked_skins: Array = ["classic"]
var equipped_skin: String = "classic"

# Estado da Rodada Atual
var current_stage_idx: int = 0
var target_briefing_stage_idx: int = 0
var score: int = 0
var coins: int = 0
var run_coins_collected: int = 0
var screen_shake: float = 0.0
var dynamic_spawn_timer: float = 0.0
var is_stage_completing: bool = false

var paddle_arc_current: float = 54.0
var paddle_buff_timer: float = 0.0
var paddle_buff_type: String = "normal"
var paddle_stun_timer: float = 0.0
var revive_shield_timer: float = 0.0
var has_revived_this_run: bool = false
var has_doubled_coins_this_run: bool = false

# Entidades ativas
var balls: Array[Ball] = []
var particles: Array[Particle] = []
var floating_scores: Array[FloatingScore] = []
var square_blocks: Array[SquareBlock] = []
var coins_items: Array[CoinItem] = []
var bumpers: Array[Bumper] = []
var helix: HelixObstacle = null
var active_special_orbs: Array[SpecialOrb] = []
var turret: TurretBoss = null
var turret_bullets: Array[TurretBullet] = []

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

# Referências de UI (HUD do Jogo)
@onready var dimmer_overlay: ColorRect = $HUD/DimmerOverlay
@onready var game_hud: Control = $HUD/GameHUD
@onready var lives_label: Label = $HUD/GameHUD/TopBar/HBoxContainer/LivesLabel
@onready var stage_name_label: Label = $HUD/GameHUD/TopBar/HBoxContainer/StageNameLabel
@onready var coins_label: Label = $HUD/GameHUD/TopBar/HBoxContainer/CoinsLabel
@onready var map_button: Button = $HUD/GameHUD/TopBar/HBoxContainer/MapButton

@onready var big_score_label: Label = $HUD/GameHUD/CenterScoreHUD/BigScoreLabel
@onready var stage_progress_bar: ProgressBar = $HUD/GameHUD/CenterScoreHUD/StageProgressBar
@onready var objective_label: Label = $HUD/GameHUD/CenterScoreHUD/ObjectiveLabel
@onready var wave_banner: Label = $HUD/WaveBanner

# UI Briefing de Fase (Apresentação Clara do Objetivo)
@onready var stage_briefing_panel: PanelContainer = $HUD/StageBriefingPanel
@onready var briefing_title: Label = $HUD/StageBriefingPanel/MarginContainer/VBoxContainer/BriefingTitle
@onready var briefing_subtitle: Label = $HUD/StageBriefingPanel/MarginContainer/VBoxContainer/BriefingSubtitle
@onready var briefing_desc: Label = $HUD/StageBriefingPanel/MarginContainer/VBoxContainer/BriefingDesc
@onready var briefing_target: Label = $HUD/StageBriefingPanel/MarginContainer/VBoxContainer/BriefingTarget
@onready var briefing_stars: Label = $HUD/StageBriefingPanel/MarginContainer/VBoxContainer/BriefingStars
@onready var briefing_tip: Label = $HUD/StageBriefingPanel/MarginContainer/VBoxContainer/BriefingTip
@onready var start_stage_button: Button = $HUD/StageBriefingPanel/MarginContainer/VBoxContainer/StartStageButton
@onready var briefing_map_button: Button = $HUD/StageBriefingPanel/MarginContainer/VBoxContainer/BriefingMapButton

# UI Mapa de Fases
@onready var level_map_panel: PanelContainer = $HUD/LevelMapPanel
@onready var map_lives_label: Label = $HUD/LevelMapPanel/MarginContainer/VBoxContainer/SubBar/MapLivesLabel
@onready var map_coins_label: Label = $HUD/LevelMapPanel/MarginContainer/VBoxContainer/SubBar/MapCoinsLabel
@onready var map_buy_lives_btn: Button = $HUD/LevelMapPanel/MarginContainer/VBoxContainer/SubBar/MapBuyLivesBtn
@onready var map_shop_btn: Button = $HUD/LevelMapPanel/MarginContainer/VBoxContainer/SubBar/MapShopBtn
@onready var stage_cards_container: VBoxContainer = $HUD/LevelMapPanel/MarginContainer/VBoxContainer/ScrollContainer/StageCardsContainer
@onready var close_map_button: Button = $HUD/LevelMapPanel/MarginContainer/VBoxContainer/CloseMapButton

# UI Game Over
@onready var game_over_panel: PanelContainer = $HUD/GameOverPanel
@onready var big_final_score_label: Label = $HUD/GameOverPanel/MarginContainer/VBoxContainer/BigFinalScoreLabel
@onready var stage_record_label: Label = $HUD/GameOverPanel/MarginContainer/VBoxContainer/StageRecordLabel
@onready var coins_saved_label: Label = $HUD/GameOverPanel/MarginContainer/VBoxContainer/CoinsSavedLabel
@onready var lives_status_label: Label = $HUD/GameOverPanel/MarginContainer/VBoxContainer/LivesStatusLabel
@onready var revive_button: Button = $HUD/GameOverPanel/MarginContainer/VBoxContainer/ReviveButton
@onready var double_coins_button: Button = $HUD/GameOverPanel/MarginContainer/VBoxContainer/DoubleCoinsButton
@onready var retry_stage_button: Button = $HUD/GameOverPanel/MarginContainer/VBoxContainer/RetryStageButton
@onready var game_over_map_button: Button = $HUD/GameOverPanel/MarginContainer/VBoxContainer/GameOverMapButton
@onready var game_over_shop_button: Button = $HUD/GameOverPanel/MarginContainer/VBoxContainer/GameOverShopButton

# UI Fase Concluída (Stage Clear)
@onready var stage_clear_panel: PanelContainer = $HUD/StageClearPanel
@onready var stage_stars_label: Label = $HUD/StageClearPanel/MarginContainer/VBoxContainer/StageStarsLabel
@onready var stage_clear_score_label: Label = $HUD/StageClearPanel/MarginContainer/VBoxContainer/StageClearScoreLabel
@onready var stage_clear_bonus_label: Label = $HUD/StageClearPanel/MarginContainer/VBoxContainer/StageClearBonusLabel
@onready var stage_clear_unlock_label: Label = $HUD/StageClearPanel/MarginContainer/VBoxContainer/StageClearUnlockLabel
@onready var next_stage_button: Button = $HUD/StageClearPanel/MarginContainer/VBoxContainer/NextStageButton
@onready var stage_clear_map_button: Button = $HUD/StageClearPanel/MarginContainer/VBoxContainer/StageClearMapButton

# UI Loja
@onready var shop_panel: PanelContainer = $HUD/ShopPanel
@onready var shop_coins_label: Label = $HUD/ShopPanel/MarginContainer/VBoxContainer/ShopCoinsLabel
@onready var buy_lives_btn: Button = $HUD/ShopPanel/MarginContainer/VBoxContainer/BuyLivesBtn
@onready var free_life_ad_btn: Button = $HUD/ShopPanel/MarginContainer/VBoxContainer/FreeLifeAdBtn
@onready var skin_classic_btn: Button = $HUD/ShopPanel/MarginContainer/VBoxContainer/SkinClassicBtn
@onready var skin_fire_btn: Button = $HUD/ShopPanel/MarginContainer/VBoxContainer/SkinFireBtn
@onready var skin_synth_btn: Button = $HUD/ShopPanel/MarginContainer/VBoxContainer/SkinSynthBtn
@onready var skin_rainbow_btn: Button = $HUD/ShopPanel/MarginContainer/VBoxContainer/SkinRainbowBtn
@onready var close_shop_button: Button = $HUD/ShopPanel/MarginContainer/VBoxContainer/CloseShopButton

# UI Vitória na Campanha
@onready var victory_panel: PanelContainer = $HUD/VictoryPanel
@onready var total_score_label: Label = $HUD/VictoryPanel/MarginContainer/VBoxContainer/TotalScoreLabel
@onready var victory_map_button: Button = $HUD/VictoryPanel/MarginContainer/VBoxContainer/VictoryMapButton
@onready var infinite_button: Button = $HUD/VictoryPanel/MarginContainer/VBoxContainer/InfiniteButton

# ------------------------------------------------------------------------------
# 5. INICIALIZAÇÃO & PERSISTÊNCIA
# ------------------------------------------------------------------------------
func _ready() -> void:
	_init_procedural_audio()
	_update_center_pos()
	get_viewport().size_changed.connect(_update_center_pos)

	_apply_modal_styles()
	_load_profile()
	_check_lives_recharge()

	# Conexões de Botões
	map_button.pressed.connect(_open_map)
	close_map_button.pressed.connect(_close_map)
	map_buy_lives_btn.pressed.connect(_open_shop)
	map_shop_btn.pressed.connect(_open_shop)

	start_stage_button.pressed.connect(_on_start_challenge_pressed)
	briefing_map_button.pressed.connect(_open_map)

	retry_stage_button.pressed.connect(_on_retry_pressed)
	revive_button.pressed.connect(_on_revive_pressed)
	double_coins_button.pressed.connect(_on_double_coins_pressed)
	game_over_map_button.pressed.connect(_open_map)
	game_over_shop_button.pressed.connect(_open_shop)

	next_stage_button.pressed.connect(_on_next_stage_pressed)
	stage_clear_map_button.pressed.connect(_open_map)

	victory_map_button.pressed.connect(_open_map)
	infinite_button.pressed.connect(start_infinite_mode)

	close_shop_button.pressed.connect(_close_shop)
	buy_lives_btn.pressed.connect(_buy_lives_with_coins)
	free_life_ad_btn.pressed.connect(_gain_free_life)

	skin_classic_btn.pressed.connect(func(): _select_skin("classic", 0))
	skin_fire_btn.pressed.connect(func(): _select_skin("fire", 40))
	skin_synth_btn.pressed.connect(func(): _select_skin("synth", 70))
	skin_rainbow_btn.pressed.connect(func(): _select_skin("rainbow", 120))

	# Abre o Mapa de Fases ao iniciar
	_open_map()

func _update_center_pos() -> void:
	arena_center = get_viewport_rect().size / 2.0

func _apply_modal_styles() -> void:
	_style_panel(stage_briefing_panel, Color(0.2, 0.95, 1.0, 1.0))
	_style_panel(level_map_panel, Color(0.18, 0.75, 1.0, 1.0))
	_style_panel(game_over_panel, Color(1.0, 0.35, 0.45, 1.0))
	_style_panel(stage_clear_panel, Color(0.2, 1.0, 0.55, 1.0))
	_style_panel(shop_panel, Color(1.0, 0.85, 0.25, 1.0))
	_style_panel(victory_panel, Color(1.0, 0.8, 0.2, 1.0))

func _style_panel(panel: PanelContainer, border_col: Color) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, 0.98) # Fundo sólido super escuro anti-vazamento
	sb.border_color = border_col
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 22
	sb.content_margin_top = 22
	sb.content_margin_right = 22
	sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", sb)

func _update_dimmer() -> void:
	var any_modal = stage_briefing_panel.visible or level_map_panel.visible or game_over_panel.visible or stage_clear_panel.visible or shop_panel.visible or victory_panel.visible
	dimmer_overlay.visible = any_modal
	dimmer_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if any_modal else Control.MOUSE_FILTER_IGNORE

# ------------------------------------------------------------------------------
# 6. SISTEMA DE VIDAS (CANDY CRUSH STYLE) & TIMER
# ------------------------------------------------------------------------------
func _check_lives_recharge() -> void:
	var now = int(Time.get_unix_time_from_system())
	if lives >= MAX_LIVES:
		last_life_timestamp = now
		return

	if last_life_timestamp <= 0:
		last_life_timestamp = now

	var elapsed = now - last_life_timestamp
	if elapsed >= LIFE_RECHARGE_SECONDS:
		var gained = int(elapsed / LIFE_RECHARGE_SECONDS)
		lives = mini(lives + gained, MAX_LIVES)
		if lives >= MAX_LIVES:
			last_life_timestamp = now
		else:
			last_life_timestamp = now - (elapsed % LIFE_RECHARGE_SECONDS)
		_save_profile()

func _get_lives_text() -> String:
	_check_lives_recharge()
	if lives >= MAX_LIVES:
		return "❤️ %d/%d (CHEIO)" % [lives, MAX_LIVES]

	var now = int(Time.get_unix_time_from_system())
	var elapsed = now - last_life_timestamp
	var rem = maxi(0, LIFE_RECHARGE_SECONDS - elapsed)
	var mins = int(rem / 60)
	var secs = int(rem % 60)
	return "❤️ %d/%d (+1 em %02d:%02d)" % [lives, MAX_LIVES, mins, secs]

func _buy_lives_with_coins() -> void:
	var cost = 30
	var total_avail = total_coins_bank + coins
	if total_avail >= cost:
		if coins >= cost:
			coins -= cost
		else:
			var rem = cost - coins
			coins = 0
			total_coins_bank -= rem

		lives = MAX_LIVES
		last_life_timestamp = int(Time.get_unix_time_from_system())
		_save_profile()
		_play_sfx(sfx_powerup)
		_trigger_firework(arena_center, Color(1.0, 0.35, 0.45), 30)
		_spawn_floating_text(arena_center, "+5 VIDAS! ❤️", Color(1.0, 0.35, 0.45), 30)
		_update_hud()
		_update_shop_ui()
		_update_map_ui()
	else:
		_play_sfx(sfx_poison)
		_spawn_floating_text(arena_center, "Moedas insuficientes!", Color.RED, 22)

func _gain_free_life() -> void:
	lives = mini(lives + 1, MAX_LIVES)
	last_life_timestamp = int(Time.get_unix_time_from_system())
	_save_profile()
	_play_sfx(sfx_powerup)
	_spawn_floating_text(arena_center, "+1 VIDA GRÁTIS! ❤️", Color(0.2, 1.0, 0.5), 26)
	_update_hud()
	_update_shop_ui()
	_update_map_ui()

# ------------------------------------------------------------------------------
# 7. PERSISTÊNCIA EM DISCO
# ------------------------------------------------------------------------------
func _save_profile() -> void:
	var data = {
		"total_coins_bank": total_coins_bank,
		"high_score": high_score,
		"lives": lives,
		"last_life_timestamp": last_life_timestamp,
		"unlocked_stage": unlocked_stage,
		"stage_high_scores": stage_high_scores,
		"stage_stars": stage_stars,
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
			lives = int(d.get("lives", 5))
			last_life_timestamp = int(d.get("last_life_timestamp", 0))
			unlocked_stage = int(d.get("unlocked_stage", 0))
			stage_high_scores = d.get("stage_high_scores", {})
			stage_stars = d.get("stage_stars", {})
			unlocked_skins = Array(d.get("unlocked_skins", ["classic"]))
			equipped_skin = String(d.get("equipped_skin", "classic"))

# ------------------------------------------------------------------------------
# 8. SÍNTESE DE ÁUDIO 8-BIT PROCEDURAL
# ------------------------------------------------------------------------------
func _init_procedural_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)

	sfx_bounce = _generate_tone(220.0, 360.0, 0.08, "sine")
	sfx_brick = _generate_tone(180.0, 110.0, 0.12, "square")
	sfx_coin = _generate_tone(580.0, 880.0, 0.15, "triangle")
	sfx_powerup = _generate_tone(320.0, 680.0, 0.28, "square")
	sfx_poison = _generate_tone(260.0, 120.0, 0.32, "sawtooth")
	sfx_fireball = _generate_tone(140.0, 420.0, 0.22, "noise")
	sfx_turret_shot = _generate_tone(440.0, 180.0, 0.14, "square")
	sfx_gameover = _generate_tone(320.0, 90.0, 0.55, "sawtooth")

func _play_sfx(stream: AudioStreamWAV) -> void:
	if stream != null and audio_player != null:
		audio_player.stream = stream
		audio_player.play()

func _generate_tone(freq_start: float, freq_end: float, duration: float, wave_type: String) -> AudioStreamWAV:
	var rate = 22050
	var sample_count = int(duration * rate)
	var data = PackedByteArray()
	data.resize(sample_count)

	var phase = 0.0
	for i in range(sample_count):
		var t = float(i) / float(sample_count)
		var cur_freq = lerpf(freq_start, freq_end, t)
		phase += TAU * cur_freq / float(rate)
		if phase > TAU:
			phase -= TAU

		var val = 0.0
		match wave_type:
			"sine": val = sin(phase)
			"square": val = 1.0 if sin(phase) >= 0.0 else -1.0
			"triangle": val = 2.0 * abs(2.0 * (phase / TAU - floor(phase / TAU + 0.5))) - 1.0
			"sawtooth": val = 2.0 * (phase / TAU - floor(phase / TAU + 0.5))
			"noise": val = randf_range(-1.0, 1.0)

		var env = 1.0 - t
		val = clampf(val * env, -1.0, 1.0)
		data[i] = int((val * 0.5 + 0.5) * 255.0)

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav

# ------------------------------------------------------------------------------
# 9. SISTEMA DE MAPA DE FASES E BRIEFING DE OBJETIVO
# ------------------------------------------------------------------------------
func _open_map() -> void:
	current_state = GameState.MAP
	_hide_all_modals()
	_update_map_ui()
	level_map_panel.visible = true
	_update_dimmer()

func _close_map() -> void:
	level_map_panel.visible = false
	_update_dimmer()
	if current_state == GameState.MAP:
		_show_stage_briefing(current_stage_idx)

func _update_map_ui() -> void:
	map_lives_label.text = _get_lives_text()
	map_coins_label.text = "🪙 %d" % (total_coins_bank + coins)

	# Limpa cartões anteriores
	for child in stage_cards_container.get_children():
		child.queue_free()

	# Gera cartões para as 5 fases da campanha
	for idx in range(STAGE_CONFIGS.size()):
		var cfg = STAGE_CONFIGS[idx]
		var card = _create_stage_card(idx, cfg["title"], cfg["target_score"])
		stage_cards_container.add_child(card)

	# Cartão do Modo Infinito
	var infinite_card = _create_infinite_card()
	stage_cards_container.add_child(infinite_card)

func _create_stage_card(stage_idx: int, title: String, target: int) -> PanelContainer:
	var card = PanelContainer.new()
	var is_unlocked = (stage_idx <= unlocked_stage)
	var stage_key = str(stage_idx)
	var best_score = stage_high_scores.get(stage_key, 0)
	var stars_count = stage_stars.get(stage_key, 0)

	var border_col = Color(0.2, 0.8, 1.0) if is_unlocked else Color(0.25, 0.28, 0.35)
	var bg_col = Color(0.09, 0.12, 0.18, 0.95) if is_unlocked else Color(0.05, 0.06, 0.08, 0.95)

	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 16
	sb.content_margin_top = 14
	sb.content_margin_right = 16
	sb.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", sb)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var hbox_top = HBoxContainer.new()
	vbox.add_child(hbox_top)

	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.3, 0.92, 1.0) if is_unlocked else Color(0.5, 0.55, 0.65))
	hbox_top.add_child(title_lbl)

	var stars_str = "☆☆☆"
	if stars_count == 1: stars_str = "⭐☆☆"
	elif stars_count == 2: stars_str = "⭐⭐☆"
	elif stars_count >= 3: stars_str = "⭐⭐⭐"

	var stars_lbl = Label.new()
	stars_lbl.text = stars_str if is_unlocked else "🔒"
	stars_lbl.add_theme_font_size_override("font_size", 18)
	stars_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	hbox_top.add_child(stars_lbl)

	var hbox_sub = HBoxContainer.new()
	vbox.add_child(hbox_sub)

	var info_lbl = Label.new()
	info_lbl.text = "Meta: %d pts  |  Recorde: %d pts" % [target, best_score] if is_unlocked else "Bloqueada. Vença a fase anterior!"
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_lbl.add_theme_font_size_override("font_size", 14)
	info_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9) if is_unlocked else Color(0.4, 0.45, 0.5))
	hbox_sub.add_child(info_lbl)

	var play_btn = Button.new()
	play_btn.custom_minimum_size = Vector2(100, 38)
	play_btn.add_theme_font_size_override("font_size", 15)
	if is_unlocked:
		play_btn.text = "JOGAR ▶"
		play_btn.pressed.connect(func(): _select_stage_from_map(stage_idx))
	else:
		play_btn.text = "🔒"
		play_btn.disabled = true
	hbox_sub.add_child(play_btn)

	return card

func _create_infinite_card() -> PanelContainer:
	var card = PanelContainer.new()
	var is_unlocked = (unlocked_stage >= 4)
	var best_score = stage_high_scores.get("infinite", 0)

	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.10, 0.18, 0.95) if is_unlocked else Color(0.05, 0.05, 0.07, 0.95)
	sb.border_color = Color(1.0, 0.8, 0.2) if is_unlocked else Color(0.25, 0.25, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 16
	sb.content_margin_top = 14
	sb.content_margin_right = 16
	sb.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", sb)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)

	var title_lbl = Label.new()
	title_lbl.text = "MODO INFINITO ♾️"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25) if is_unlocked else Color(0.5, 0.5, 0.5))
	hbox.add_child(title_lbl)

	var info_lbl = Label.new()
	info_lbl.text = "Sobrevivência Máxima | Recorde: %d pts" % best_score if is_unlocked else "Complete a Fase 5 para liberar!"
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_lbl.add_theme_font_size_override("font_size", 14)
	info_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9) if is_unlocked else Color(0.4, 0.45, 0.5))
	vbox.add_child(info_lbl)

	var play_btn = Button.new()
	play_btn.custom_minimum_size = Vector2(0, 40)
	play_btn.add_theme_font_size_override("font_size", 16)
	if is_unlocked:
		play_btn.text = "JOGAR MODO INFINITO ♾️"
		play_btn.pressed.connect(start_infinite_mode)
	else:
		play_btn.text = "BLOQUEADO 🔒 (Vença a Fase 5)"
		play_btn.disabled = true
	vbox.add_child(play_btn)

	return card

func _select_stage_from_map(stage_idx: int) -> void:
	if lives <= 0:
		_open_shop()
		_spawn_floating_text(arena_center, "Sem vidas! Recarregue na Loja ❤️", Color(1.0, 0.3, 0.4), 24)
		return

	level_map_panel.visible = false
	_show_stage_briefing(stage_idx)

# Briefing explicativo antes de a bolinha começar a voar!
func _show_stage_briefing(stage_idx: int) -> void:
	target_briefing_stage_idx = stage_idx
	current_state = GameState.BRIEFING
	_hide_all_modals()

	if stage_idx < STAGE_CONFIGS.size():
		var cfg = STAGE_CONFIGS[stage_idx]
		briefing_title.text = cfg["title"]
		briefing_subtitle.text = cfg["mission_title"]
		briefing_desc.text = cfg["mission_desc"]
		briefing_target.text = "🎯 META: %d PONTOS" % cfg["target_score"]
		briefing_stars.text = "⭐ %d pts  |  ⭐⭐ %d pts  |  ⭐⭐⭐ %d pts" % [cfg["star_1"], cfg["star_2"], cfg["star_3"]]
		briefing_tip.text = cfg["mission_tip"]
	else:
		briefing_title.text = "MODO INFINITO ♾️"
		briefing_subtitle.text = "SOBREVIVÊNCIA MÁXIMA"
		briefing_desc.text = "Sobreviva o máximo que puder, desvie de projéteis e acumule a maior pontuação possível!"
		briefing_target.text = "RECORDE ATUAL: %d PONTOS" % high_score
		briefing_stars.text = "Supere seus limites a cada partida!"
		briefing_tip.text = "💡 A velocidade aumenta progressivamente. Concentre-se nos desvios!"

	stage_briefing_panel.visible = true
	_update_dimmer()

func _on_start_challenge_pressed() -> void:
	stage_briefing_panel.visible = false
	_update_dimmer()
	_start_stage(target_briefing_stage_idx)

# ------------------------------------------------------------------------------
# 10. LOJA DE SKINS & SISTEMA REWARDED
# ------------------------------------------------------------------------------
func _open_shop() -> void:
	_update_shop_ui()
	shop_panel.visible = true
	_update_dimmer()

func _close_shop() -> void:
	shop_panel.visible = false
	_update_dimmer()
	if current_state == GameState.MAP:
		_update_map_ui()

func _update_shop_ui() -> void:
	shop_coins_label.text = "Saldo Total: 🪙 %d  |  %s" % [total_coins_bank + coins, _get_lives_text()]

	var total_avail = total_coins_bank + coins
	buy_lives_btn.text = "❤️ Recarregar +5 Vidas (30 Moedas)"
	buy_lives_btn.disabled = (total_avail < 30 or lives >= MAX_LIVES)

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
	_update_dimmer()
	current_state = GameState.PLAYING

	_spawn_ball(arena_center, randf() * TAU, ball_base_speed)
	revive_shield_timer = 2.8
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
	coins_saved_label.text = "🪙 Moedas no Banco: %d (+%d dobradas!)" % [total_coins_bank + coins, bonus_coins]
	_play_sfx(sfx_coin)
	_trigger_firework(arena_center, Color(1.0, 0.85, 0.2), 30)

# ------------------------------------------------------------------------------
# 11. CONTROLE DE FASES E INÍCIO DE PARTIDA
# ------------------------------------------------------------------------------
func _start_stage(stage_idx: int) -> void:
	_hide_all_modals()
	current_state = GameState.PLAYING
	is_stage_completing = false

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

	current_stage_idx = stage_idx
	paddle_angle = -PI / 2.0
	target_paddle_angle = paddle_angle
	screen_shake = 0.0
	dynamic_spawn_timer = 0.0
	paddle_arc_current = paddle_base_arc_degrees
	paddle_buff_timer = 0.0
	paddle_buff_type = "normal"
	paddle_stun_timer = 0.0

	particles.clear()
	floating_scores.clear()
	_load_stage(current_stage_idx)

func start_infinite_mode() -> void:
	_hide_all_modals()
	_show_stage_briefing(99)

func _hide_all_modals() -> void:
	stage_briefing_panel.visible = false
	level_map_panel.visible = false
	game_over_panel.visible = false
	stage_clear_panel.visible = false
	shop_panel.visible = false
	victory_panel.visible = false
	_update_dimmer()

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
	is_stage_completing = false

	var cfg = _get_current_config()
	var palette = cfg["palette"]
	var blk_size = Vector2(28, 28)

	if cfg["has_turret"]:
		turret = TurretBoss.new()
		turret.pos = arena_center
		turret.hp = 5
		turret.max_hp = 5

	var layout_idx = stage_idx if stage_idx < 5 else (stage_idx % 5)

	match layout_idx:
		0: # Fase 1: O Despertar
			for p in [Vector2(-60, 0), Vector2(60, 0), Vector2(0, -60), Vector2(0, 60)]:
				_create_square_block(arena_center + p - blk_size / 2.0, blk_size, palette["accent"])
			_spawn_coin(arena_center + Vector2(-35, -35))
			_spawn_coin(arena_center + Vector2(35, 35))
			_spawn_special_orb(arena_center + Vector2(0, 45), "expand")

		1: # Fase 2: Poderes & Feitiços
			for x in [-40, 0, 40]:
				for y in [-25, 25]:
					_create_square_block(arena_center + Vector2(x, y) - blk_size / 2.0, blk_size, palette["accent"])
			_spawn_coin(arena_center + Vector2(0, -70))
			_spawn_special_orb(arena_center + Vector2(-45, 0), "fireball")
			_spawn_special_orb(arena_center + Vector2(45, 0), "poison")

		2: # Fase 3: Pinball & Bumpers
			_create_bumper(arena_center + Vector2(-85, 0), palette["paddle"])
			_create_bumper(arena_center + Vector2(85, 0), palette["paddle"])
			for i in range(5):
				var ang = i * (TAU / 5.0)
				var pos = arena_center + Vector2.RIGHT.rotated(ang) * 65.0 - blk_size / 2.0
				_create_square_block(pos, blk_size, palette["accent"])
			_spawn_special_orb(arena_center + Vector2(0, -50), "fireball")

		3: # Fase 4: Multiball & Fogo
			for i in range(8):
				var ang = i * (TAU / 8.0)
				var pos = arena_center + Vector2.RIGHT.rotated(ang) * 85.0 - blk_size / 2.0
				_create_square_block(pos, blk_size, palette["accent"])
			_spawn_special_orb(arena_center, "multiball")
			_spawn_special_orb(arena_center + Vector2(-50, 0), "expand")

		4: # Fase 5: Hélice & Torre Boss
			helix = HelixObstacle.new()
			helix.center = arena_center
			helix.color = palette["accent"]
			for i in range(6):
				var ang = i * (TAU / 6.0)
				var pos = arena_center + Vector2.RIGHT.rotated(ang) * 115.0 - blk_size / 2.0
				_create_square_block(pos, blk_size, palette["paddle"])
			_spawn_special_orb(arena_center + Vector2(-60, -60), "fireball")

	var spd = ball_base_speed + (mini(stage_idx, 5) * 14.0)
	_spawn_ball(arena_center, randf_range(0.0, TAU), spd)

	stage_name_label.text = cfg["title"]
	stage_name_label.add_theme_color_override("font_color", palette["paddle"])
	_update_objective_and_progress()

	var goal_banner = "🎯 META: %d PONTOS!" % cfg["target_score"] if stage_idx < STAGE_CONFIGS.size() else "MODO INFINITO!"
	_show_wave_banner(goal_banner)
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

func _spawn_floating_text(pos: Vector2, text: String, col: Color, sz: int = 24) -> void:
	var ft = FloatingScore.new()
	ft.pos = pos
	ft.text = text
	ft.color = col
	ft.font_size = sz
	floating_scores.append(ft)

func _show_wave_banner(text: String) -> void:
	wave_banner.text = text
	wave_banner.visible = true
	var tween = create_tween()
	wave_banner.modulate = Color(1, 1, 1, 0)
	tween.tween_property(wave_banner, "modulate:a", 1.0, 0.25)
	tween.tween_interval(1.4)
	tween.tween_property(wave_banner, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func(): wave_banner.visible = false)

# ------------------------------------------------------------------------------
# 12. ENTRADAS DE DADOS
# ------------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if current_state != GameState.PLAYING or dimmer_overlay.visible:
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
# 13. FÍSICA E PROCESSAMENTO (_process)
# ------------------------------------------------------------------------------
func _process(delta: float) -> void:
	_check_lives_recharge()

	# Atualiza floating texts
	var ft_i = floating_scores.size() - 1
	while ft_i >= 0:
		var ft = floating_scores[ft_i]
		ft.pos.y -= 55.0 * delta
		ft.life += delta
		if ft.life >= ft.max_life:
			floating_scores.remove_at(ft_i)
		ft_i -= 1

	if current_state != GameState.PLAYING:
		queue_redraw()
		return

	# Tremor de tela
	if screen_shake > 0.0:
		screen_shake = maxf(screen_shake - delta * 18.0, 0.0)

	# Escudo protetor de reviver
	if revive_shield_timer > 0.0:
		revive_shield_timer = maxf(revive_shield_timer - delta, 0.0)

	# Duração dos Buffs/Debuffs da raquete
	if paddle_buff_timer > 0.0:
		paddle_buff_timer -= delta
		if paddle_buff_timer <= 0.0:
			paddle_buff_type = "normal"
			paddle_arc_current = paddle_base_arc_degrees

	if paddle_stun_timer > 0.0:
		paddle_stun_timer = maxf(paddle_stun_timer - delta, 0.0)

	# Atualização do Boss da Torre
	if turret != null:
		turret.angle += delta * 1.6
		turret.shoot_timer += delta
		if turret.shoot_timer >= turret.shoot_interval:
			turret.shoot_timer = 0.0
			_shoot_turret_bullet()

	# Atualização dos projéteis da torre
	_process_turret_bullets(delta)

	# Hélice rotativa
	if helix != null:
		helix.angle += helix.rot_speed * delta

	# Movimento suave da raquete
	var diff = wrapf(target_paddle_angle - paddle_angle, -PI, PI)
	paddle_angle += diff * clampf(paddle_smoothness * delta, 0.0, 1.0)
	paddle_angle = wrapf(paddle_angle, -PI, PI)

	# Atualização das partículas
	var p_idx = particles.size() - 1
	while p_idx >= 0:
		var pt = particles[p_idx]
		pt.pos += pt.vel * delta
		pt.life -= delta
		if pt.life <= 0.0:
			particles.remove_at(p_idx)
		p_idx -= 1

	# Spawner orgânico contínuo
	dynamic_spawn_timer += delta
	if dynamic_spawn_timer >= 3.2:
		dynamic_spawn_timer = 0.0
		_spawn_dynamic_content()

	# Físicas das bolinhas
	var ball_idx = balls.size() - 1
	while ball_idx >= 0:
		var b = balls[ball_idx]
		b.pos += b.vel * delta

		if b.is_fireball:
			b.fireball_timer -= delta
			if b.fireball_timer <= 0.0:
				b.is_fireball = false

		b.trail.insert(0, b.pos)
		if b.trail.size() > max_trail_points:
			b.trail.pop_back()

		_check_ball_paddle_collision(b)
		_check_ball_coins_collision(b)
		_check_ball_blocks_collision(b)
		_check_ball_bumpers_collision(b)
		_check_ball_helix_collision(b)
		_check_ball_special_orbs_collision(b)
		_check_ball_turret_collision(b)

		# Morte da bolinha (fora dos limites)
		var dist = b.pos.distance_to(arena_center)
		if dist > arena_radius + ball_radius + 40.0:
			balls.remove_at(ball_idx)
			_trigger_firework(b.pos, Color.RED, 18)
			_add_shake(6.0)

		ball_idx -= 1

	# Game Over se acabarem todas as bolinhas (apenas se não estiver completando a fase)
	if balls.is_empty() and not is_stage_completing:
		_trigger_game_over()

	queue_redraw()

func _shoot_turret_bullet() -> void:
	if turret == null:
		return
	var b = TurretBullet.new()
	b.pos = turret.pos
	var shoot_dir = Vector2.RIGHT.rotated(turret.angle)
	b.vel = shoot_dir * 185.0
	turret_bullets.append(b)
	_play_sfx(sfx_turret_shot)

func _process_turret_bullets(delta: float) -> void:
	var tb_idx = turret_bullets.size() - 1
	while tb_idx >= 0:
		var tb = turret_bullets[tb_idx]
		tb.pos += tb.vel * delta

		var dist = tb.pos.distance_to(arena_center)
		# Colisão com o escudo da raquete
		if absf(dist - arena_radius) <= tb.radius + paddle_thickness / 2.0:
			var ang_to_bullet = (tb.pos - arena_center).angle()
			var ang_diff = absf(wrapf(ang_to_bullet - paddle_angle, -PI, PI))
			var half_arc = deg_to_rad(paddle_arc_current / 2.0)

			if ang_diff <= half_arc:
				# Tiro acertou a raquete do jogador!
				turret_bullets.remove_at(tb_idx)
				_add_shake(6.0)
				_play_sfx(sfx_brick)
				_trigger_firework(tb.pos, Color(1.0, 0.2, 0.2), 20)

				# Encolhimento progressivo sem Game Over direto
				paddle_arc_current = maxf(paddle_arc_current - 14.0, 14.0)
				paddle_stun_timer = 0.4
				_spawn_floating_text(tb.pos, "-LARGURA!", Color(1.0, 0.3, 0.3), 20)
				tb_idx -= 1
				continue

		if dist > arena_radius + 60.0:
			turret_bullets.remove_at(tb_idx)

		tb_idx -= 1

func _spawn_dynamic_content() -> void:
	var cfg = _get_current_config()
	var palette = cfg["palette"]
	var blk_size = Vector2(28, 28)

	if square_blocks.size() < 5:
		var ang = randf() * TAU
		var dist = randf_range(50.0, arena_radius * 0.55)
		var pos = arena_center + Vector2.RIGHT.rotated(ang) * dist - blk_size / 2.0
		_create_square_block(pos, blk_size, palette["accent"])

	if coins_items.size() < 4:
		var c_ang = randf() * TAU
		var c_dist = randf_range(40.0, arena_radius * 0.65)
		_spawn_coin(arena_center + Vector2.RIGHT.rotated(c_ang) * c_dist)

# ------------------------------------------------------------------------------
# 14. COLISÕES E PONTUAÇÃO
# ------------------------------------------------------------------------------
func _check_ball_paddle_collision(b: Ball) -> void:
	var dist = b.pos.distance_to(arena_center)
	var boundary_limit = arena_radius - ball_radius

	# Escudo de reviver ativo
	if revive_shield_timer > 0.0 and dist >= boundary_limit - 4.0:
		var normal = (arena_center - b.pos).normalized()
		b.vel = b.vel.bounce(normal)
		b.pos = arena_center - normal * (boundary_limit - 6.0)
		_play_sfx(sfx_bounce)
		_trigger_firework(b.pos, Color(0.2, 1.0, 0.6), 14)
		_spawn_floating_text(b.pos, "ESCUDO! 🛡️", Color(0.2, 1.0, 0.6), 22)
		return

	if dist >= boundary_limit - 6.0 and dist <= boundary_limit + 14.0:
		var ang_to_ball = (b.pos - arena_center).angle()
		var ang_diff = absf(wrapf(ang_to_ball - paddle_angle, -PI, PI))
		var half_arc = deg_to_rad(paddle_arc_current / 2.0)

		if ang_diff <= half_arc:
			var outward_normal = (b.pos - arena_center).normalized()
			if b.vel.dot(outward_normal) > 0.0:
				var paddle_tangent = Vector2(-outward_normal.y, outward_normal.x)
				var hit_factor = (ang_to_ball - paddle_angle) / half_arc
				var bounce_dir = -outward_normal + paddle_tangent * (hit_factor * 0.45)
				b.vel = bounce_dir.normalized() * b.speed

				b.speed *= ball_speed_increment
				b.vel = b.vel.normalized() * b.speed
				b.pos = arena_center + outward_normal * (boundary_limit - 1.0)

				score += 1
				_spawn_floating_text(b.pos, "+1", Color(0.2, 0.95, 1.0), 18)
				_update_hud()
				_add_shake(2.0)
				_play_sfx(sfx_bounce)
				_trigger_firework(b.pos, _get_current_config()["palette"]["paddle"], 10)
				_check_stage_goal()

func _check_ball_coins_collision(b: Ball) -> void:
	for i in range(coins_items.size() - 1, -1, -1):
		var coin = coins_items[i]
		if b.pos.distance_to(coin.pos) <= ball_radius + coin.radius:
			coins += 1
			run_coins_collected += 1
			total_coins_bank += 1
			score += 15
			_spawn_floating_text(coin.pos, "+15 🪙", Color(1.0, 0.85, 0.2), 24)
			_play_sfx(sfx_coin)
			_trigger_firework(coin.pos, Color(1.0, 0.85, 0.15), 18)
			coins_items.remove_at(i)
			_update_hud()
			_check_stage_goal()

func _check_ball_blocks_collision(b: Ball) -> void:
	for i in range(square_blocks.size() - 1, -1, -1):
		var blk = square_blocks[i]
		var blk_center = blk.rect.position + blk.rect.size / 2.0
		var half_sz = blk.rect.size / 2.0

		var diff = b.pos - blk_center
		var clamped_diff = Vector2(
			clampf(diff.x, -half_sz.x, half_sz.x),
			clampf(diff.y, -half_sz.y, half_sz.y)
		)
		var closest = blk_center + clamped_diff

		if b.pos.distance_to(closest) <= ball_radius:
			if not b.is_fireball:
				var overlap = ball_radius - b.pos.distance_to(closest)
				if absf(diff.x) > absf(diff.y):
					b.vel.x = -b.vel.x
					b.pos.x = blk_center.x + (half_sz.x + ball_radius + 1.0) * signf(diff.x)
				else:
					b.vel.y = -b.vel.y
					b.pos.y = blk_center.y + (half_sz.y + ball_radius + 1.0) * signf(diff.y)

			square_blocks.remove_at(i)
			score += 25
			_spawn_floating_text(blk_center, "+25", blk.color, 24)
			_play_sfx(sfx_brick)
			_add_shake(3.0)
			_trigger_firework(blk_center, blk.color, 16)
			_update_hud()
			_check_stage_goal()
			break

func _check_ball_turret_collision(b: Ball) -> void:
	if turret == null:
		return
	if b.pos.distance_to(turret.pos) <= ball_radius + turret.radius:
		var dmg = 5 if b.is_fireball else 1
		turret.hp -= dmg
		b.vel = (b.pos - turret.pos).normalized() * b.speed
		_play_sfx(sfx_brick)
		_trigger_firework(turret.pos, Color(1.0, 0.4, 0.1), 22)
		_spawn_floating_text(turret.pos, "+50 💥", Color(1.0, 0.4, 0.1), 26)
		score += 50
		_update_hud()

		if turret.hp <= 0:
			_trigger_firework(turret.pos, Color(1.0, 0.8, 0.2), 45)
			_play_sfx(sfx_powerup)
			score += 150
			coins += 10
			run_coins_collected += 10
			total_coins_bank += 10
			_spawn_floating_text(turret.pos, "TORRE DESTRUÍDA! +150 🏆", Color(1.0, 0.85, 0.2), 28)
			turret = null
			_update_hud()
			_check_stage_goal()

func _check_ball_bumpers_collision(b: Ball) -> void:
	for bmp in bumpers:
		if b.pos.distance_to(bmp.pos) <= ball_radius + bmp.radius:
			var normal = (b.pos - bmp.pos).normalized()
			b.vel = normal * (b.speed * 1.15)
			b.pos = bmp.pos + normal * (bmp.radius + ball_radius + 1.0)

			_add_shake(3.5)
			_play_sfx(sfx_bounce)
			_trigger_firework(bmp.pos + normal * bmp.radius, bmp.color, 14)
			score += 5
			_spawn_floating_text(bmp.pos, "+5", bmp.color, 20)
			_update_hud()
			_check_stage_goal()

func _check_ball_helix_collision(b: Ball) -> void:
	if helix == null:
		return
	var h_dir = Vector2.RIGHT.rotated(helix.angle)
	var p_start = helix.center - h_dir * (helix.length / 2.0)
	var p_end = helix.center + h_dir * (helix.length / 2.0)

	var seg = p_end - p_start
	var t = clampf((b.pos - p_start).dot(seg) / seg.length_squared(), 0.0, 1.0)
	var closest = p_start + seg * t

	if b.pos.distance_to(closest) <= ball_radius + helix.thickness / 2.0:
		var n = (b.pos - closest).normalized()
		b.vel = n * b.speed
		b.pos = closest + n * (ball_radius + helix.thickness / 2.0 + 1.0)
		_play_sfx(sfx_bounce)
		_add_shake(4.0)
		score += 5
		_spawn_floating_text(closest, "+5", helix.color, 20)
		_update_hud()
		_check_stage_goal()

func _check_ball_special_orbs_collision(b: Ball) -> void:
	for i in range(active_special_orbs.size() - 1, -1, -1):
		var orb = active_special_orbs[i]
		if b.pos.distance_to(orb.pos) <= ball_radius + orb.radius:
			_apply_special_power(orb.type, orb.pos)
			active_special_orbs.remove_at(i)
			break

func _apply_special_power(type: String, hit_pos: Vector2) -> void:
	match type:
		"multiball":
			_play_sfx(sfx_powerup)
			_spawn_floating_text(hit_pos, "MULTIBALL! 🟡", Color(1.0, 0.85, 0.2), 26)
			if not balls.is_empty():
				var ref = balls[0]
				for ang_off in [-0.4, 0.4]:
					_spawn_ball(ref.pos, ref.vel.angle() + ang_off, ref.speed)
			_trigger_firework(hit_pos, Color(1.0, 0.85, 0.2), 30)

		"expand":
			_play_sfx(sfx_powerup)
			paddle_arc_current = 76.0
			paddle_buff_timer = 9.0
			paddle_buff_type = "expand"
			_spawn_floating_text(hit_pos, "RAQUETE GIGANTE! 🟢", Color(0.2, 1.0, 0.4), 26)
			_trigger_firework(hit_pos, Color(0.2, 1.0, 0.4), 30)

		"poison":
			_play_sfx(sfx_poison)
			paddle_arc_current = 36.0
			paddle_buff_timer = 7.0
			paddle_buff_type = "poison"
			_spawn_floating_text(hit_pos, "ENCOLHEU! 🟣", Color(0.85, 0.2, 0.95), 24)
			_trigger_firework(hit_pos, Color(0.85, 0.2, 0.95), 30)

		"fireball":
			_play_sfx(sfx_fireball)
			_spawn_floating_text(hit_pos, "BOLA DE FOGO! 🔥", Color(1.0, 0.4, 0.1), 28)
			for bl in balls:
				bl.is_fireball = true
				bl.fireball_timer = 7.5
			_trigger_firework(hit_pos, Color(1.0, 0.4, 0.1), 35)

	coins += 2
	run_coins_collected += 2
	total_coins_bank += 2
	score += 30
	_add_shake(4.0)
	_update_hud()
	_check_stage_goal()

# ------------------------------------------------------------------------------
# 15. PROGRESSÃO DE FASE & TRANSIÇÃO COMEMORATIVA
# ------------------------------------------------------------------------------
func _check_stage_goal() -> void:
	if current_stage_idx >= STAGE_CONFIGS.size() or is_stage_completing:
		return # Modo infinito não tem meta fixa

	var target = STAGE_CONFIGS[current_stage_idx]["target_score"]
	if score >= target:
		is_stage_completing = true
		_play_sfx(sfx_powerup)
		_show_wave_banner("🎯 OBJETIVO CONCLUÍDO!")
		_trigger_firework(arena_center, Color(0.2, 1.0, 0.6), 55)
		_spawn_floating_text(arena_center, "FASE COMPLETA! 🏆", Color(1.0, 0.85, 0.2), 32)

		# Desacelera as bolinhas para celebrar
		for b in balls:
			b.vel *= 0.35

		# Transição suave para o painel de vitória
		var tween = create_tween()
		tween.tween_interval(0.85)
		tween.tween_callback(_complete_current_stage)

func _complete_current_stage() -> void:
	current_state = GameState.STAGE_CLEAR

	score += 100
	coins += 10
	run_coins_collected += 10
	total_coins_bank += 10

	var cfg = STAGE_CONFIGS[current_stage_idx]
	var target = cfg["target_score"]
	var stage_key = str(current_stage_idx)

	# Atualiza recorde da fase
	var prev_record = stage_high_scores.get(stage_key, 0)
	if score > prev_record:
		stage_high_scores[stage_key] = score

	# Calcula estrelas com base nos limiares da fase
	var stars = 1
	if score >= cfg["star_3"]:
		stars = 3
	elif score >= cfg["star_2"]:
		stars = 2
	stage_stars[stage_key] = maxi(stage_stars.get(stage_key, 0), stars)

	# Desbloqueia próxima fase
	if current_stage_idx == unlocked_stage and unlocked_stage < STAGE_CONFIGS.size() - 1:
		unlocked_stage += 1

	if score > high_score:
		high_score = score
	_save_profile()

	# Configura o painel comemorativo
	var stars_text = "⭐⭐⭐" if stars == 3 else ("⭐⭐☆" if stars == 2 else "⭐☆☆")
	stage_stars_label.text = stars_text
	stage_clear_score_label.text = "Pontuação: %d PONTOS" % score
	stage_clear_bonus_label.text = "Bônus Conquistado: +100 Pontos | +10 Moedas"

	if current_stage_idx >= STAGE_CONFIGS.size() - 1:
		stage_clear_unlock_label.text = "🏆 MODO INFINITO DESBLOQUEADO!"
		next_stage_button.text = "MODO INFINITO ♾️"
	else:
		stage_clear_unlock_label.text = "🔓 Fase %d Liberada no Mapa!" % (current_stage_idx + 2)
		next_stage_button.text = "PRÓXIMA FASE ➡️"

	stage_clear_panel.visible = true
	_update_dimmer()

func _on_next_stage_pressed() -> void:
	stage_clear_panel.visible = false
	_update_dimmer()
	if current_stage_idx < STAGE_CONFIGS.size() - 1:
		_show_stage_briefing(current_stage_idx + 1)
	else:
		start_infinite_mode()

# ------------------------------------------------------------------------------
# 16. SISTEMA DE PARTÍCULAS E SCREEN SHAKE
# ------------------------------------------------------------------------------
func _trigger_firework(origin: Vector2, col: Color, count: int) -> void:
	for i in range(count):
		var p = Particle.new()
		p.pos = origin
		var ang = randf() * TAU
		var spd = randf_range(60.0, 240.0)
		p.vel = Vector2.RIGHT.rotated(ang) * spd
		p.color = col
		p.life = randf_range(0.25, 0.65)
		p.max_life = p.life
		p.size = randf_range(3.0, 6.0)
		particles.append(p)

func _add_shake(amount: float) -> void:
	screen_shake = clampf(screen_shake + amount, 0.0, max_screen_shake)

# ------------------------------------------------------------------------------
# 17. RENDERIZAÇÃO GRÁFICA VIA CÓDIGO (_draw)
# ------------------------------------------------------------------------------
func _draw() -> void:
	var shake_offset = Vector2.ZERO
	if screen_shake > 0.0:
		shake_offset = Vector2(randf_range(-screen_shake, screen_shake), randf_range(-screen_shake, screen_shake))

	var center = arena_center + shake_offset
	var cfg = _get_current_config()
	var palette = cfg["palette"]

	# 1. Arena Circular Base
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
		draw_circle(c_pos, c.radius * scale_p, Color(0.9, 0.75, 0.1))
		draw_circle(c_pos, c.radius * 0.75 * scale_p, Color(1.0, 0.95, 0.4))
		draw_line(c_pos + Vector2(0, -5), c_pos + Vector2(0, 5), Color(0.65, 0.45, 0.0), 2.0)

	# 8. Blocos Quadradinhos
	for blk in square_blocks:
		var blk_scale = blk.spawn_anim
		var sz = blk.rect.size * blk_scale
		var r_off = Rect2(blk.rect.position + shake_offset + (blk.rect.size - sz) / 2.0, sz)
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

	# 10. Raquete (Estados visuais de integridade)
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

	# 11. Rastro das Bolinhas (Customizado pela Skin)
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

	# 13. Textos Flutuantes de Pontuação (Score Popups)
	var default_font = ThemeDB.fallback_font
	for ft in floating_scores:
		var alpha = clampf(1.0 - (ft.life / ft.max_life), 0.0, 1.0)
		var ft_col = ft.color
		ft_col.a = alpha
		draw_string(default_font, ft.pos + shake_offset, ft.text, HORIZONTAL_ALIGNMENT_CENTER, -1, ft.font_size, ft_col)

# ------------------------------------------------------------------------------
# 18. HUD E GAME OVER
# ------------------------------------------------------------------------------
func _update_hud() -> void:
	lives_label.text = _get_lives_text()
	coins_label.text = "🪙 %d" % (total_coins_bank + coins)
	big_score_label.text = str(score)
	_update_objective_and_progress()

func _update_objective_and_progress() -> void:
	var cfg = _get_current_config()
	var target = cfg["target_score"]

	if current_stage_idx >= STAGE_CONFIGS.size():
		objective_label.text = "♾️ MODO INFINITO | RECORDE: %d" % high_score
		stage_progress_bar.max_value = 1000
		stage_progress_bar.value = score % 1000
		objective_label.add_theme_color_override("font_color", Color(0.9, 0.4, 1.0))
	else:
		stage_progress_bar.max_value = target
		stage_progress_bar.value = score

		var remaining = target - score
		if remaining <= 0:
			objective_label.text = "🎉 OBJETIVO CONCLUÍDO! (%d/%d)" % [score, target]
			objective_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.55))
		elif remaining <= int(target * 0.15) or remaining <= 80:
			# Reta Final! Alerta dourado de alta empolgação
			objective_label.text = "⚡ RETA FINAL! FALTAM %d PTS! (%d/%d)" % [remaining, score, target]
			objective_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			var pct = int(float(score) / float(target) * 100.0)
			objective_label.text = "🎯 META: %d PTS (%d/%d - %d%%)" % [target, score, target, pct]
			objective_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 0.9))

func _get_current_config() -> Dictionary:
	if current_stage_idx < STAGE_CONFIGS.size():
		return STAGE_CONFIGS[current_stage_idx]
	return {
		"stage": 99,
		"title": "MODO INFINITO ♾️",
		"mission_title": "SOBREVIVÊNCIA MÁXIMA",
		"mission_desc": "Desvie de projéteis e sobreviva o máximo que puder para bater o recorde global!",
		"mission_tip": "💡 Quanto mais tempo você sobrevive, maior o bônus de moedas acumulado.",
		"target_score": 99999,
		"star_1": 1000,
		"star_2": 2500,
		"star_3": 5000,
		"has_turret": true,
		"palette": {
			"name": "COSMIC PURPLE",
			"paddle": Color(0.9, 0.3, 1.0),
			"arena": Color(0.2, 0.1, 0.35, 0.7),
			"accent": Color(1.0, 0.4, 0.8)
		}
	}

func _trigger_game_over() -> void:
	current_state = GameState.GAME_OVER
	_play_sfx(sfx_gameover)

	# Consome 1 vida se não tiver revivido
	lives = maxi(0, lives - 1)
	if lives < MAX_LIVES and last_life_timestamp <= 0:
		last_life_timestamp = int(Time.get_unix_time_from_system())

	var stage_key = str(current_stage_idx)
	var prev_record = stage_high_scores.get(stage_key, 0)
	if score > prev_record:
		stage_high_scores[stage_key] = score

	if score > high_score:
		high_score = score
	_save_profile()

	# Configura labels gigantes do Game Over
	big_final_score_label.text = str(score)
	stage_record_label.text = "🏆 Recorde da Fase: %d pts" % stage_high_scores.get(stage_key, score)
	coins_saved_label.text = "🪙 Moedas no Banco: %d (Total Seguro!)" % (total_coins_bank + coins)
	lives_status_label.text = _get_lives_text()

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

	retry_stage_button.text = "🔄 TENTAR NOVAMENTE (-1 ❤️)" if lives > 0 else "SEM VIDAS ❤️ (Recarregar)"
	retry_stage_button.disabled = (lives <= 0)

	game_over_panel.visible = true
	_update_dimmer()
	queue_redraw()

func _on_retry_pressed() -> void:
	if lives <= 0:
		_open_shop()
		return
	game_over_panel.visible = false
	_update_dimmer()
	_show_stage_briefing(current_stage_idx)
