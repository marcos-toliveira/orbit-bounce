extends Node2D

# ==============================================================================
# ORBIT BOUNCE (PONG CIRCULAR) - EVOLUTION 3.0
# Progressão por Meta de Pontuação + Spawn Dinâmico Contínuo (Sem Tédio!)
# Barra de Progresso no Topo + Moedas Pass-Through & Blocos Previsíveis
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. PARÂMETROS GERAIS (@export)
# ------------------------------------------------------------------------------
@export_group("Arena e Estilo")
@export var arena_radius: float = 300.0
@export var arena_line_width: float = 5.0

@export_group("Jogador (Raquete Arredondada)")
@export var paddle_arc_degrees: float = 54.0
@export var paddle_thickness: float = 16.0
@export var paddle_smoothness: float = 48.0
@export var keyboard_rot_speed: float = 5.2

@export_group("Bolinha & Rastro")
@export var ball_radius: float = 11.0
@export var ball_base_speed: float = 310.0
@export var ball_speed_increment: float = 1.012
@export var max_trail_points: int = 12

@export_group("Efeitos Visuais")
@export var max_screen_shake: float = 8.0

# ------------------------------------------------------------------------------
# 2. ESTRUTURAS DE DADOS
# ------------------------------------------------------------------------------
class Ball:
	var pos: Vector2
	var vel: Vector2
	var speed: float
	var trail: Array[Vector2] = []
	var color: Color = Color.WHITE

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
	var spawn_anim: float = 0.0 # 0.0 a 1.0 (animação de entrada suave)

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

class PowerupOrb:
	var pos: Vector2
	var radius: float = 16.0
	var pulse_time: float = 0.0
	var is_multiball: bool = true

# ------------------------------------------------------------------------------
# 3. DEFINIÇÃO DAS 5 FASES COM METAS DE PONTUAÇÃO
# ------------------------------------------------------------------------------
const STAGE_CONFIGS = [
	{
		"stage": 1,
		"title": "FASE 1: O DESPERTAR",
		"subtitle": "Colete moedas e quebre bloquinhos",
		"start_score": 0,
		"target_score": 150,
		"target_type": "intro_blocks",
		"palette": {
			"name": "NEON CYAN",
			"paddle": Color(0.18, 0.92, 1.0),
			"arena": Color(0.12, 0.28, 0.38, 0.7),
			"accent": Color(0.2, 0.85, 1.0)
		}
	},
	{
		"stage": 2,
		"title": "FASE 2: MATRIZ DE BLOCOS",
		"subtitle": "Quebre os blocos que surgem na arena",
		"start_score": 150,
		"target_score": 350,
		"target_type": "grid_blocks",
		"palette": {
			"name": "SYNTH PURPLE",
			"paddle": Color(0.95, 0.25, 0.88),
			"arena": Color(0.35, 0.14, 0.35, 0.7),
			"accent": Color(0.9, 0.3, 0.9)
		}
	},
	{
		"stage": 3,
		"title": "FASE 3: PINBALL BUMPERS",
		"subtitle": "Bumpers elásticos adicionados à órbita!",
		"start_score": 350,
		"target_score": 650,
		"target_type": "bumpers",
		"palette": {
			"name": "ELECTRIC BLUE",
			"paddle": Color(0.2, 0.75, 1.0),
			"arena": Color(0.12, 0.25, 0.45, 0.7),
			"accent": Color(0.3, 0.85, 1.0)
		}
	},
	{
		"stage": 4,
		"title": "FASE 4: CAOS TRIPLO",
		"subtitle": "Aproveite o Multiball para acelerar o score!",
		"start_score": 650,
		"target_score": 1050,
		"target_type": "cloud_multiball",
		"palette": {
			"name": "EMERALD LIME",
			"paddle": Color(0.25, 0.95, 0.45),
			"arena": Color(0.14, 0.32, 0.20, 0.7),
			"accent": Color(0.3, 1.0, 0.5)
		}
	},
	{
		"stage": 5,
		"title": "FASE 5: A HÉLICE",
		"subtitle": "Supere a hélice rotativa para zerar a campanha!",
		"start_score": 1050,
		"target_score": 1600,
		"target_type": "helix_boss",
		"palette": {
			"name": "SOLAR AMBER",
			"paddle": Color(1.0, 0.8, 0.15),
			"arena": Color(0.38, 0.26, 0.10, 0.7),
			"accent": Color(1.0, 0.45, 0.2)
		}
	}
]

# ------------------------------------------------------------------------------
# 4. VARIÁVEIS DE ESTADO
# ------------------------------------------------------------------------------
enum GameState { PLAYING, GAME_OVER, CAMPAIGN_CLEAR }
var current_state: GameState = GameState.PLAYING

var arena_center: Vector2 = Vector2.ZERO
var paddle_angle: float = -PI / 2.0
var target_paddle_angle: float = -PI / 2.0
var is_dragging: bool = false

# Entidades ativas
var balls: Array[Ball] = []
var particles: Array[Particle] = []
var square_blocks: Array[SquareBlock] = []
var coins_items: Array[CoinItem] = []
var bumpers: Array[Bumper] = []
var helix: HelixObstacle = null
var active_powerups: Array[PowerupOrb] = []

# Progresso & Spawner Contínuo
var current_stage_idx: int = 0
var score: int = 0
var coins: int = 0
var screen_shake: float = 0.0
var dynamic_spawn_timer: float = 0.0

# Referências de UI
@onready var wave_label: Label = $HUD/TopBar/VBoxContainer/HBoxContainer/WaveLabel
@onready var score_label: Label = $HUD/TopBar/VBoxContainer/HBoxContainer/ScoreLabel
@onready var coins_label: Label = $HUD/TopBar/VBoxContainer/HBoxContainer/CoinsLabel
@onready var objective_label: Label = $HUD/TopBar/VBoxContainer/ObjectiveLabel
@onready var stage_progress_bar: ProgressBar = $HUD/TopBar/VBoxContainer/StageProgressBar
@onready var wave_banner: Label = $HUD/WaveBanner
@onready var game_over_panel: PanelContainer = $HUD/GameOverPanel
@onready var final_score_label: Label = $HUD/GameOverPanel/MarginContainer/VBoxContainer/FinalScoreLabel
@onready var waves_cleared_label: Label = $HUD/GameOverPanel/MarginContainer/VBoxContainer/WavesClearedLabel
@onready var restart_button: Button = $HUD/GameOverPanel/MarginContainer/VBoxContainer/RestartButton
@onready var victory_panel: PanelContainer = $HUD/VictoryPanel
@onready var total_score_label: Label = $HUD/VictoryPanel/MarginContainer/VBoxContainer/TotalScoreLabel
@onready var infinite_button: Button = $HUD/VictoryPanel/MarginContainer/VBoxContainer/InfiniteButton

# ------------------------------------------------------------------------------
# 5. INICIALIZAÇÃO
# ------------------------------------------------------------------------------
func _ready() -> void:
	_update_center_pos()
	get_viewport().size_changed.connect(_update_center_pos)
	restart_button.pressed.connect(start_new_campaign)
	infinite_button.pressed.connect(start_infinite_mode)
	start_new_campaign()

func _update_center_pos() -> void:
	arena_center = get_viewport_rect().size / 2.0

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
	wave_banner.visible = false

	score = 0
	coins = 0
	current_stage_idx = 0
	paddle_angle = -PI / 2.0
	target_paddle_angle = paddle_angle
	screen_shake = 0.0
	dynamic_spawn_timer = 0.0

	particles.clear()
	_load_stage(current_stage_idx)

func start_infinite_mode() -> void:
	victory_panel.visible = false
	current_state = GameState.PLAYING
	_load_stage(current_stage_idx)

# ------------------------------------------------------------------------------
# 6. CARREGAMENTO DAS FASES
# ------------------------------------------------------------------------------
func _load_stage(stage_idx: int) -> void:
	square_blocks.clear()
	coins_items.clear()
	bumpers.clear()
	helix = null
	active_powerups.clear()
	balls.clear()
	dynamic_spawn_timer = 0.0

	var cfg = _get_current_config()
	var palette = cfg["palette"]
	var blk_size = Vector2(28, 28)

	match cfg["target_type"]:
		"intro_blocks":
			# FASE 1: 4 blocos iniciais e 3 moedas
			var positions = [Vector2(-60, 0), Vector2(60, 0), Vector2(0, -60), Vector2(0, 60)]
			for p in positions:
				_create_square_block(arena_center + p - blk_size / 2.0, blk_size, palette["accent"])
			_spawn_coin(arena_center + Vector2(-35, -35))
			_spawn_coin(arena_center + Vector2(35, 35))

		"grid_blocks":
			# FASE 2: Matriz inicial
			for x in [-40, 0, 40]:
				for y in [-25, 25]:
					_create_square_block(arena_center + Vector2(x, y) - blk_size / 2.0, blk_size, palette["accent"])
			_spawn_coin(arena_center + Vector2(0, -70))

		"bumpers":
			# FASE 3: 2 Bumpers elásticos fixos + blocos centrais
			_create_bumper(arena_center + Vector2(-80, 0), palette["paddle"])
			_create_bumper(arena_center + Vector2(80, 0), palette["paddle"])
			for i in range(5):
				var ang = i * (TAU / 5.0)
				var pos = arena_center + Vector2.RIGHT.rotated(ang) * 55.0 - blk_size / 2.0
				_create_square_block(pos, blk_size, palette["accent"])
			_spawn_coin(arena_center)

		"cloud_multiball":
			# FASE 4: Multiball imediato + 8 blocos
			for i in range(8):
				var ang = i * (TAU / 8.0)
				var pos = arena_center + Vector2.RIGHT.rotated(ang) * 85.0 - blk_size / 2.0
				_create_square_block(pos, blk_size, palette["accent"])
			_spawn_powerup(arena_center)
			_spawn_coin(arena_center + Vector2(-40, 0))

		"helix_boss":
			# FASE 5: Hélice rotativa + 6 blocos
			helix = HelixObstacle.new()
			helix.center = arena_center
			helix.color = palette["accent"]
			for i in range(6):
				var ang = i * (TAU / 6.0)
				var pos = arena_center + Vector2.RIGHT.rotated(ang) * 115.0 - blk_size / 2.0
				_create_square_block(pos, blk_size, palette["paddle"])
			_spawn_coin(arena_center + Vector2(-70, -70))

	# Spawna a bola inicial
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
	b.spawn_anim = 0.0
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

func _spawn_powerup(pos: Vector2) -> void:
	var p = PowerupOrb.new()
	p.pos = pos
	active_powerups.append(p)

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
# 7. ENTRADAS DE DADOS
# ------------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if current_state != GameState.PLAYING:
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
# 8. FÍSICA E PROCESSAMENTO
# ------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if current_state != GameState.PLAYING:
		return

	_process_screen_shake(delta)
	_process_paddle(delta)
	_process_helix(delta)
	_process_bumpers(delta)
	_process_balls(delta)
	_process_particles(delta)
	_process_powerups(delta)
	_process_coins_animation(delta)
	_process_dynamic_spawning(delta)

	# Atualiza Barra de Progresso e Meta
	_update_objective_and_progress()

	# Condição de Avanço de Fase: Atingir a Meta de Pontuação!
	var cfg = _get_current_config()
	if score >= cfg["target_score"]:
		_complete_current_stage()

	queue_redraw()

# ------------------------------------------------------------------------------
# SPAWN ORGÂNICO CONTÍNUO (RESOLVE O PROBLEMA DO ÚLTIMO BLOCO!)
# ------------------------------------------------------------------------------
func _process_dynamic_spawning(delta: float) -> void:
	dynamic_spawn_timer += delta
	# A cada 3.2 segundos tenta reabastecer a arena
	if dynamic_spawn_timer >= 3.2:
		dynamic_spawn_timer = 0.0
		var palette = _get_current_palette()
		var blk_size = Vector2(28, 28)

		# Se houver menos de 7 blocos, spawna um novo em posição aleatória no miolo
		if square_blocks.size() < 7:
			var rand_dist = randf_range(40.0, arena_radius * 0.52)
			var rand_pos = arena_center + Vector2.RIGHT.rotated(randf() * TAU) * rand_dist - blk_size / 2.0
			_create_square_block(rand_pos, blk_size, palette["accent"])
			_trigger_firework(rand_pos + blk_size / 2.0, palette["accent"].lightened(0.3), 10)

		# Se houver menos de 3 moedas, spawna uma moeda no anel
		if coins_items.size() < 3:
			var coin_dist = randf_range(50.0, arena_radius * 0.65)
			var coin_pos = arena_center + Vector2.RIGHT.rotated(randf() * TAU) * coin_dist
			_spawn_coin(coin_pos)

		# 25% de chance de spawnar um orbe Multiball se o jogador estiver com apenas 1 bola
		if balls.size() == 1 and active_powerups.is_empty() and randf() < 0.25:
			var p_dist = randf_range(50.0, 110.0)
			_spawn_powerup(arena_center + Vector2.RIGHT.rotated(randf() * TAU) * p_dist)

	# Atualiza animação de entrada dos blocos
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

	objective_label.text = "Meta: %d PONTOS (%d/%d)" % [target_s, score, target_s]

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
		target_paddle_angle += key_axis * keyboard_rot_speed * delta
		target_paddle_angle = wrapf(target_paddle_angle, -PI, PI)

	var diff = angle_difference(paddle_angle, target_paddle_angle)
	paddle_angle += diff * clampf(paddle_smoothness * delta, 0.0, 1.0)
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

		b.trail.push_front(b.pos)
		if b.trail.size() > max_trail_points:
			b.trail.pop_back()

		b.pos += b.vel * delta
		var dist_center = b.pos.distance_to(arena_center)

		if dist_center >= boundary_limit:
			var outward_normal = (b.pos - arena_center).normalized()
			var impact_angle = outward_normal.angle()
			var ang_diff = abs(angle_difference(paddle_angle, impact_angle))
			var half_arc = deg_to_rad(paddle_arc_degrees / 2.0)

			# Acertou a raquete!
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
				_trigger_firework(b.pos, palette["paddle"], 12)

			else:
				_trigger_firework(b.pos, Color(1.0, 0.2, 0.3), 16)
				balls.remove_at(i)
				continue

		# Coleta de moedas pass-through
		_check_ball_coins_pickup(b)

		# Colisão ortogonal com blocos quadradinhos
		_check_ball_square_blocks_collision(b)

		# Bumpers e Hélice
		_check_ball_bumpers_collision(b)
		_check_ball_helix_collision(b)

	if balls.is_empty():
		_trigger_game_over()

func _check_ball_coins_pickup(b: Ball) -> void:
	for i in range(coins_items.size() - 1, -1, -1):
		var coin = coins_items[i]
		if b.pos.distance_to(coin.pos) <= ball_radius + coin.radius:
			coins += 1
			score += 15
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
			if overlap_x < overlap_y:
				b.vel.x = -b.vel.x
				b.pos.x = blk_center.x + (half_sz.x + ball_radius + 1.0) * signf(diff.x)
			else:
				b.vel.y = -b.vel.y
				b.pos.y = blk_center.y + (half_sz.y + ball_radius + 1.0) * signf(diff.y)

			square_blocks.remove_at(i)
			score += 25
			_add_shake(3.5)
			_trigger_firework(blk_center, blk.color, 16)
			_update_hud()
			break

func _check_ball_bumpers_collision(b: Ball) -> void:
	for bmp in bumpers:
		var dist = b.pos.distance_to(bmp.pos)
		if dist <= ball_radius + bmp.radius:
			var normal = (b.pos - bmp.pos).normalized()
			b.vel = b.vel.bounce(normal)
			b.pos = bmp.pos + normal * (bmp.radius + ball_radius + 2.0)

			bmp.impulse_scale = 1.25
			_add_shake(4.0)
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
		_trigger_firework(b.pos, helix.color, 16)

func _process_powerups(delta: float) -> void:
	for i in range(active_powerups.size() - 1, -1, -1):
		var p = active_powerups[i]
		p.pulse_time += delta

		for b in balls:
			if b.pos.distance_to(p.pos) <= ball_radius + p.radius:
				_activate_multiball(p.pos, b.vel)
				_trigger_firework(p.pos, Color(1.0, 0.85, 0.2), 30)
				_add_shake(5.0)
				coins += 3
				score += 35
				_update_hud()
				active_powerups.remove_at(i)
				break

func _activate_multiball(origin: Vector2, base_vel: Vector2) -> void:
	var base_ang = base_vel.angle()
	var spd = base_vel.length()
	_spawn_ball(origin, base_ang + deg_to_rad(30.0), spd)
	_spawn_ball(origin, base_ang - deg_to_rad(30.0), spd)

func _complete_current_stage() -> void:
	score += 100
	coins += 5
	_trigger_firework(arena_center, Color(0.2, 1.0, 0.6), 45)

	if current_stage_idx == 4:
		current_state = GameState.CAMPAIGN_CLEAR
		total_score_label.text = "Pontuação: %d  |  Moedas: %d" % [score, coins]
		victory_panel.visible = true
		current_stage_idx += 1
	else:
		current_stage_idx += 1
		_load_stage(current_stage_idx)

# ------------------------------------------------------------------------------
# 9. SISTEMA DE PARTÍCULAS
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
# 10. RENDERIZAÇÃO GRÁFICA VIA CÓDIGO (_draw)
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

	# 2. Hélice Rotativa (Fase 5)
	if helix != null:
		var h_center = helix.center + shake_offset
		var h_dir = Vector2.RIGHT.rotated(helix.angle)
		var p_start = h_center - h_dir * (helix.length / 2.0)
		var p_end = h_center + h_dir * (helix.length / 2.0)
		draw_line(p_start, p_end, helix.color, helix.thickness, true)
		draw_circle(p_start, helix.thickness / 2.0, helix.color)
		draw_circle(p_end, helix.thickness / 2.0, helix.color)
		draw_circle(h_center, helix.thickness * 0.7, Color.WHITE)

	# 3. Bumpers Elásticos (Fase 3)
	for bmp in bumpers:
		var b_pos = bmp.pos + shake_offset
		draw_circle(b_pos, bmp.radius, bmp.color.darkened(0.3))
		draw_arc(b_pos, bmp.radius, 0.0, TAU, 32, Color.WHITE, 2.5, true)
		draw_circle(b_pos, bmp.radius * 0.4, Color.WHITE)

	# 4. Moedas Coletáveis (Douradas com Brilho)
	for c in coins_items:
		var c_pos = c.pos + shake_offset
		var scale_p = 1.0 + 0.12 * sin(c.pulse)
		draw_circle(c_pos, c.radius * scale_p, Color(1.0, 0.85, 0.2))
		draw_circle(c_pos, c.radius * 0.75 * scale_p, Color(1.0, 0.95, 0.4))
		draw_line(c_pos + Vector2(0, -5), c_pos + Vector2(0, 5), Color(0.65, 0.45, 0.0), 2.0)

	# 5. Blocos Quadradinhos Quebráveis (com escala suave de spawn)
	for blk in square_blocks:
		var blk_scale = blk.spawn_anim
		var sz = blk.rect.size * blk_scale
		var top_left = blk.rect.get_center() - sz / 2.0 + shake_offset
		var r_off = Rect2(top_left, sz)
		draw_rect(r_off, blk.color)
		draw_rect(r_off, Color.WHITE.lerp(blk.color, 0.4), false, 2.0)

	# 6. Orbe de Multiball
	for p in active_powerups:
		var p_pos = p.pos + shake_offset
		var pulse = 1.0 + 0.15 * sin(p.pulse_time * 8.0)
		draw_circle(p_pos, p.radius * pulse, Color(1.0, 0.85, 0.2, 0.35))
		draw_circle(p_pos, p.radius * 0.7 * pulse, Color(1.0, 0.95, 0.5))
		for j in range(3):
			var dot_off = Vector2.RIGHT.rotated(j * (TAU / 3.0) + p.pulse_time * 3.0) * (p.radius * 0.35)
			draw_circle(p_pos + dot_off, 2.5, Color.BLACK)

	# 7. Raquete com Cápsula Arredondada
	var half_arc = deg_to_rad(paddle_arc_degrees / 2.0)
	var start_ang = paddle_angle - half_arc
	var end_ang = paddle_angle + half_arc
	var p_color = palette["paddle"]
	draw_arc(center, arena_radius, start_ang, end_ang, 42, p_color, paddle_thickness, true)
	var cap_radius = paddle_thickness / 2.0
	draw_circle(center + Vector2.RIGHT.rotated(start_ang) * arena_radius, cap_radius, p_color)
	draw_circle(center + Vector2.RIGHT.rotated(end_ang) * arena_radius, cap_radius, p_color)

	# 8. Rastro das Bolinhas
	for b in balls:
		var t_size = b.trail.size()
		for t_idx in range(t_size):
			var alpha = 1.0 - (float(t_idx) / float(t_size))
			var r_sz = ball_radius * (1.0 - (float(t_idx) / float(t_size)) * 0.6)
			var trail_color = palette["paddle"]
			trail_color.a = alpha * 0.45
			draw_circle(b.trail[t_idx] + shake_offset, r_sz, trail_color)

	# 9. Bolinhas
	for b in balls:
		draw_circle(b.pos + shake_offset, ball_radius, b.color)
		draw_circle(b.pos + shake_offset, ball_radius * 0.5, Color.WHITE)

	# 10. Partículas de Fogos de Artifício
	for pt in particles:
		var alpha = pt.life / pt.max_life
		var col = pt.color
		col.a = alpha
		draw_circle(pt.pos + shake_offset, pt.size * alpha, col)

# ------------------------------------------------------------------------------
# 11. HUD E GAME OVER
# ------------------------------------------------------------------------------
func _update_hud() -> void:
	score_label.text = "PONTOS: %d" % score
	coins_label.text = "🪙 %d" % coins

func _trigger_game_over() -> void:
	current_state = GameState.GAME_OVER
	final_score_label.text = "Pontuação: %d  |  Moedas: %d" % [score, coins]
	waves_cleared_label.text = "Fases Concluídas: %d" % current_stage_idx
	game_over_panel.visible = true
	queue_redraw()
