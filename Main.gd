extends Node2D

# ==============================================================================
# ORBIT BOUNCE (PONG CIRCULAR) - CAMPANHA DE FASES 2.0
# Sistema de 5 Fases por Objetivos + Mecânicas Únicas + Modo Infinito
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. PARÂMETROS GERAIS (@export)
# ------------------------------------------------------------------------------
@export_group("Arena e Estilo")
@export var arena_radius: float = 300.0
@export var arena_line_width: float = 5.0
@export var bg_color: Color = Color(0.04, 0.05, 0.08, 1.0)

@export_group("Jogador (Raquete Arredondada)")
@export var paddle_arc_degrees: float = 46.0
@export var paddle_thickness: float = 16.0
@export var paddle_smoothness: float = 24.0
@export var keyboard_rot_speed: float = 4.8

@export_group("Bolinha & Rastro")
@export var ball_radius: float = 11.0
@export var ball_base_speed: float = 380.0
@export var ball_speed_increment: float = 1.015
@export var max_trail_points: int = 14

@export_group("Efeitos Visuais")
@export var max_screen_shake: float = 9.0

# ------------------------------------------------------------------------------
# 2. ESTRUTURAS DE DADOS DAS ENTIDADES
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

class Block:
	var rect: Rect2
	var hp: int
	var max_hp: int
	var color: Color

class StaticTarget:
	var pos: Vector2
	var radius: float = 16.0
	var color: Color = Color(1.0, 0.85, 0.2)
	var pulse: float = 0.0

class Bumper:
	var pos: Vector2
	var radius: float = 26.0
	var base_radius: float = 26.0
	var impulse_scale: float = 1.0
	var color: Color = Color(0.2, 0.9, 1.0)

class HelixObstacle:
	var center: Vector2
	var angle: float = 0.0
	var rot_speed: float = 1.25 # rad/s
	var length: float = 160.0
	var thickness: float = 18.0
	var color: Color = Color(1.0, 0.28, 0.4)

class PowerupOrb:
	var pos: Vector2
	var radius: float = 18.0
	var pulse_time: float = 0.0
	var is_multiball: bool = true

# ------------------------------------------------------------------------------
# 3. DEFINIÇÃO DAS 5 FASES DA CAMPANHA
# ------------------------------------------------------------------------------
const STAGE_CONFIGS = [
	{
		"stage": 1,
		"title": "FASE 1: O DESPERTAR",
		"subtitle": "Destrua 5 alvos na órbita",
		"target_type": "targets",
		"palette": {
			"name": "NEON CYAN",
			"paddle": Color(0.18, 0.92, 1.0),
			"arena": Color(0.12, 0.28, 0.38, 0.7),
			"accent": Color(1.0, 0.85, 0.2)
		}
	},
	{
		"stage": 2,
		"title": "FASE 2: PRIMEIROS BLOQUEIOS",
		"subtitle": "Destrua os 2 blocos centrais",
		"target_type": "blocks_dual",
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
		"subtitle": "Ricocheteie nos bumpers e destrua o núcleo",
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
		"subtitle": "Ative o Multiball e limpe a nuvem de blocos",
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
		"subtitle": "Vença os reflexos da hélice rotativa",
		"target_type": "helix_boss",
		"palette": {
			"name": "SOLAR AMBER",
			"paddle": Color(1.0, 0.8, 0.15),
			"arena": Color(0.38, 0.26, 0.10, 0.7),
			"accent": Color(1.0, 0.35, 0.2)
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
var blocks: Array[Block] = []
var targets: Array[StaticTarget] = []
var bumpers: Array[Bumper] = []
var helix: HelixObstacle = null
var active_powerups: Array[PowerupOrb] = []

# Progresso de Campanha
var current_stage_idx: int = 0
var stage_targets_total: int = 0
var stage_targets_hit: int = 0
var score: int = 0
var coins: int = 0
var screen_shake: float = 0.0

# Referências de UI
@onready var wave_label: Label = $HUD/TopBar/VBoxContainer/HBoxContainer/WaveLabel
@onready var score_label: Label = $HUD/TopBar/VBoxContainer/HBoxContainer/ScoreLabel
@onready var coins_label: Label = $HUD/TopBar/VBoxContainer/HBoxContainer/CoinsLabel
@onready var objective_label: Label = $HUD/TopBar/VBoxContainer/ObjectiveLabel
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
	# Pós fase 5: Modo Infinito (repete com aceleração)
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
	
	particles.clear()
	_load_stage(current_stage_idx)

func start_infinite_mode() -> void:
	victory_panel.visible = false
	current_state = GameState.PLAYING
	_load_stage(current_stage_idx) # Continua a partir da fase infinita

# ------------------------------------------------------------------------------
# 6. CARREGAMENTO DAS FASES E OBJETIVOS
# ------------------------------------------------------------------------------
func _load_stage(stage_idx: int) -> void:
	blocks.clear()
	targets.clear()
	bumpers.clear()
	helix = null
	active_powerups.clear()
	balls.clear()
	stage_targets_hit = 0

	var cfg = _get_current_config()
	var palette = cfg["palette"]

	match cfg["target_type"]:
		"targets":
			# FASE 1: 5 Alvos estáticos para acertar
			stage_targets_total = 5
			_spawn_next_phase1_target()

		"blocks_dual":
			# FASE 2: 2 Blocos centrais retangulares
			stage_targets_total = 2
			var sz = Vector2(80, 26)
			_create_block(arena_center + Vector2(-40, -55), sz, 3, palette["accent"])
			_create_block(arena_center + Vector2(-40, 30), sz, 3, palette["accent"])

		"bumpers":
			# FASE 3: 3 Bumpers elásticos triangulares + 4 blocos de núcleo
			stage_targets_total = 4
			# Bumpers circulares elásticos
			var b_dist = 85.0
			for i in range(3):
				var ang = i * (TAU / 3.0) - PI / 2.0
				var b_pos = arena_center + Vector2.RIGHT.rotated(ang) * b_dist
				_create_bumper(b_pos, palette["paddle"])
			# Núcleo de blocos
			var sz = Vector2(28, 28)
			_create_block(arena_center + Vector2(-34, -14), sz, 2, palette["accent"])
			_create_block(arena_center + Vector2(6, -14), sz, 2, palette["accent"])
			_create_block(arena_center + Vector2(-14, -34), sz, 2, palette["accent"])
			_create_block(arena_center + Vector2(-14, 6), sz, 2, palette["accent"])

		"cloud_multiball":
			# FASE 4: Multiball imediato + Nuvem de 12 blocos
			stage_targets_total = 12
			for i in range(12):
				var ang = i * (TAU / 12.0)
				var pos = arena_center + Vector2.RIGHT.rotated(ang) * 92.0 - Vector2(16, 16)
				_create_block(pos, Vector2(32, 32), 2, palette["accent"])
			# Spawna power-up de Multiball no centro
			_spawn_powerup(arena_center)

		"helix_boss":
			# FASE 5: Hélice rotativa contínua + 6 geradores de energia
			stage_targets_total = 6
			helix = HelixObstacle.new()
			helix.center = arena_center
			helix.color = palette["accent"]
			# 6 blocos ao redor da órbita interna
			for i in range(6):
				var ang = i * (TAU / 6.0)
				var pos = arena_center + Vector2.RIGHT.rotated(ang) * 115.0 - Vector2(18, 18)
				_create_block(pos, Vector2(36, 36), 3, palette["paddle"])

	# Spawna a Bolinha inicial com velocidade base calibrada
	var speed = ball_base_speed + (stage_idx * 16.0)
	_spawn_ball(arena_center, randf_range(0.0, TAU), speed)

	# Atualiza HUD e Banner
	wave_label.text = cfg["title"]
	wave_label.add_theme_color_override("font_color", palette["paddle"])
	_update_objective_label()
	_show_wave_banner(cfg["title"])
	_update_hud()

func _spawn_next_phase1_target() -> void:
	if targets.size() == 0 and stage_targets_hit < stage_targets_total:
		var t = StaticTarget.new()
		var dist = randf_range(70.0, arena_radius * 0.55)
		t.pos = arena_center + Vector2.RIGHT.rotated(randf() * TAU) * dist
		targets.append(t)

func _create_block(pos: Vector2, size: Vector2, hp: int, col: Color) -> void:
	var b = Block.new()
	b.rect = Rect2(pos, size)
	b.hp = hp
	b.max_hp = hp
	b.color = col
	blocks.append(b)

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

func _update_objective_label() -> void:
	var remaining = stage_targets_total - stage_targets_hit
	var cfg = _get_current_config()
	objective_label.text = "%s (%d restantes)" % [cfg["subtitle"], remaining]

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
	elif event is InputEventMouseMotion and is_dragging:
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

	# Checagem de Conclusão da Fase
	if stage_targets_hit >= stage_targets_total:
		_complete_current_stage()

	queue_redraw()

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

		# Rastro
		b.trail.push_front(b.pos)
		if b.trail.size() > max_trail_points:
			b.trail.pop_back()

		b.pos += b.vel * delta
		var dist_center = b.pos.distance_to(arena_center)

		# Colisão com o perímetro circular
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
				b.vel = (b.vel + tangent * contact_ratio * (b.speed * 0.4)).normalized() * b.speed

				if b.vel.dot(outward_normal) > 0.0:
					b.vel = b.vel.bounce(inward_normal)

				b.speed *= ball_speed_increment
				b.vel = b.vel.normalized() * b.speed
				b.pos = arena_center + outward_normal * (boundary_limit - 1.0)

				score += 1
				_update_hud()
				_add_shake(3.0)
				_trigger_firework(b.pos, palette["paddle"], 12)

			else:
				# Bolinha perdida
				_trigger_firework(b.pos, Color(1.0, 0.2, 0.3), 16)
				balls.remove_at(i)
				continue

		# Colisões com Obstáculos e Alvos
		_check_ball_targets_collision(b)
		_check_ball_blocks_collision(b)
		_check_ball_bumpers_collision(b)
		_check_ball_helix_collision(b)

	# Se todas as bolinhas caírem -> Game Over
	if balls.is_empty():
		_trigger_game_over()

func _check_ball_targets_collision(b: Ball) -> void:
	for i in range(targets.size() - 1, -1, -1):
		var t = targets[i]
		if b.pos.distance_to(t.pos) <= ball_radius + t.radius:
			var normal = (b.pos - t.pos).normalized()
			b.vel = b.vel.bounce(normal)
			targets.remove_at(i)
			stage_targets_hit += 1
			score += 20
			coins += 1
			_add_shake(4.5)
			_trigger_firework(t.pos, Color(1.0, 0.85, 0.2), 24)
			_update_hud()
			_update_objective_label()
			_spawn_next_phase1_target()

func _check_ball_blocks_collision(b: Ball) -> void:
	for i in range(blocks.size() - 1, -1, -1):
		var blk = blocks[i]
		var closest_x = clampf(b.pos.x, blk.rect.position.x, blk.rect.end.x)
		var closest_y = clampf(b.pos.y, blk.rect.position.y, blk.rect.end.y)
		var closest_point = Vector2(closest_x, closest_y)
		var dist = b.pos.distance_to(closest_point)

		if dist <= ball_radius:
			var normal = (b.pos - closest_point).normalized()
			if normal.is_zero_approx():
				normal = (b.pos - blk.rect.get_center()).normalized()
				if normal.is_zero_approx():
					normal = Vector2.UP

			b.vel = b.vel.bounce(normal)
			b.pos = closest_point + normal * (ball_radius + 1.0)

			blk.hp -= 1
			_add_shake(4.0)
			_trigger_firework(closest_point, blk.color, 14)

			if blk.hp <= 0:
				blocks.remove_at(i)
				stage_targets_hit += 1
				score += 25
				coins += 1
				_trigger_firework(blk.rect.get_center(), Color(1.0, 0.9, 0.2), 26)
				_update_objective_label()

			_update_hud()
			break

func _check_ball_bumpers_collision(b: Ball) -> void:
	for bmp in bumpers:
		var dist = b.pos.distance_to(bmp.pos)
		if dist <= ball_radius + bmp.radius:
			var normal = (b.pos - bmp.pos).normalized()
			b.vel = b.vel.bounce(normal)
			# Impulso elástico extra (+20% de aceleração temporária até 650)
			b.speed = minf(b.speed * 1.15, 650.0)
			b.vel = b.vel.normalized() * b.speed
			b.pos = bmp.pos + normal * (bmp.radius + ball_radius + 2.0)

			bmp.impulse_scale = 1.35 # Animação elástica de mola
			_add_shake(5.5)
			_trigger_firework(bmp.pos + normal * bmp.radius, bmp.color, 18)
			score += 5
			_update_hud()

func _check_ball_helix_collision(b: Ball) -> void:
	if helix == null:
		return

	# Transforma a posição da bolinha para o espaço local da hélice
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
		# Momento angular transferido para a bolinha
		var surface_tangent = Vector2(-rel_pos.y, rel_pos.x) * helix.rot_speed
		
		b.vel = b.vel.bounce(world_normal) + surface_tangent * 0.4
		b.vel = b.vel.normalized() * b.speed
		b.pos = helix.center + (local_closest + local_normal * (ball_radius + 2.0)).rotated(helix.angle)

		_add_shake(5.0)
		_trigger_firework(b.pos, helix.color, 16)

func _process_powerups(delta: float) -> void:
	for i in range(active_powerups.size() - 1, -1, -1):
		var p = active_powerups[i]
		p.pulse_time += delta

		for b in balls:
			if b.pos.distance_to(p.pos) <= ball_radius + p.radius:
				_activate_multiball(p.pos, b.vel)
				_trigger_firework(p.pos, Color(1.0, 0.85, 0.2), 35)
				_add_shake(6.0)
				coins += 3
				score += 30
				_update_hud()
				active_powerups.remove_at(i)
				break

func _activate_multiball(origin: Vector2, base_vel: Vector2) -> void:
	var base_ang = base_vel.angle()
	var spd = base_vel.length()
	_spawn_ball(origin, base_ang + deg_to_rad(35.0), spd)
	_spawn_ball(origin, base_ang - deg_to_rad(35.0), spd)

func _complete_current_stage() -> void:
	score += 150
	coins += 5
	_trigger_firework(arena_center, Color(0.2, 1.0, 0.6), 50)
	
	if current_stage_idx == 4:
		# Concluiu a Fase 5 (Vitória na Campanha!)
		current_state = GameState.CAMPAIGN_CLEAR
		total_score_label.text = "Pontuação: %d  |  Moedas: %d" % [score, coins]
		victory_panel.visible = true
		current_stage_idx += 1
	else:
		current_stage_idx += 1
		_load_stage(current_stage_idx)

# ------------------------------------------------------------------------------
# 9. SISTEMA DE PARTÍCULAS PROCEDURAIS
# ------------------------------------------------------------------------------
func _trigger_firework(origin: Vector2, col: Color, count: int) -> void:
	for i in range(count):
		var p = Particle.new()
		p.pos = origin
		var ang = randf_range(0.0, TAU)
		var spd = randf_range(90.0, 270.0)
		p.vel = Vector2.RIGHT.rotated(ang) * spd
		p.color = col.lightened(randf_range(0.0, 0.4))
		p.max_life = randf_range(0.35, 0.65)
		p.life = p.max_life
		p.size = randf_range(2.5, 4.5)
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
		var h_norm = Vector2(-h_dir.y, h_dir.x)
		var p_start = h_center - h_dir * (helix.length / 2.0)
		var p_end = h_center + h_dir * (helix.length / 2.0)
		draw_line(p_start, p_end, helix.color, helix.thickness, true)
		draw_circle(p_start, helix.thickness / 2.0, helix.color)
		draw_circle(p_end, helix.thickness / 2.0, helix.color)
		draw_circle(h_center, helix.thickness * 0.7, Color.WHITE)

	# 3. Bumpers Elásticos de Pinball (Fase 3)
	for bmp in bumpers:
		var b_pos = bmp.pos + shake_offset
		draw_circle(b_pos, bmp.radius, bmp.color.darkened(0.3))
		draw_arc(b_pos, bmp.radius, 0.0, TAU, 32, Color.WHITE, 3.0, true)
		draw_circle(b_pos, bmp.radius * 0.45, Color.WHITE)

	# 4. Alvos Estáticos da Fase 1
	for t in targets:
		var t_pos = t.pos + shake_offset
		draw_circle(t_pos, t.radius, t.color)
		draw_arc(t_pos, t.radius, 0.0, TAU, 24, Color.WHITE, 2.0, true)

	# 5. Blocos Centrais (com durabilidade)
	for blk in blocks:
		var r_off = Rect2(blk.rect.position + shake_offset, blk.rect.size)
		var fill_col = blk.color
		if blk.hp < blk.max_hp:
			fill_col = fill_col.darkened(0.35)
		draw_rect(r_off, fill_col)
		draw_rect(r_off, Color.WHITE.lerp(fill_col, 0.3), false, 2.0)

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
	draw_arc(center, arena_radius, start_ang, end_ang, 40, p_color, paddle_thickness, true)
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
