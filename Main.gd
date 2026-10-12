extends Node2D

# ==============================================================================
# ORBIT BOUNCE (PONG CIRCULAR) - EVOLUTION 2.0
# Estilo Dark Neon, Multiball (3 Bolas), Blocos Centrais, Partículas & Fases
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
@export var firework_particle_count: int = 24
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
	var is_bumper: bool = false # Se for bumper, impulsiona com mais força

class PowerupOrb:
	var pos: Vector2
	var radius: float = 18.0
	var pulse_time: float = 0.0
	var is_multiball: bool = true

# ------------------------------------------------------------------------------
# 3. PALETAS NEON POR FASE
# ------------------------------------------------------------------------------
const WAVE_PALETTES = [
	{ "name": "NEON CYAN",    "paddle": Color(0.15, 0.9, 1.0),   "arena": Color(0.12, 0.25, 0.35, 0.6), "block": Color(0.15, 0.8, 1.0) },
	{ "name": "SYNTH PURPLE", "paddle": Color(0.95, 0.2, 0.85),  "arena": Color(0.32, 0.12, 0.32, 0.6), "block": Color(0.9, 0.25, 0.85) },
	{ "name": "EMERALD LIME", "paddle": Color(0.2, 0.95, 0.45),  "arena": Color(0.12, 0.30, 0.20, 0.6), "block": Color(0.25, 0.95, 0.5) },
	{ "name": "SOLAR AMBER",  "paddle": Color(1.0, 0.78, 0.15),  "arena": Color(0.35, 0.28, 0.10, 0.6), "block": Color(1.0, 0.75, 0.2) },
	{ "name": "HYPER RED",    "paddle": Color(1.0, 0.25, 0.35),  "arena": Color(0.38, 0.12, 0.15, 0.6), "block": Color(1.0, 0.3, 0.38) }
]

# ------------------------------------------------------------------------------
# 4. VARIÁVEIS DE ESTADO
# ------------------------------------------------------------------------------
enum GameState { PLAYING, GAME_OVER }
var current_state: GameState = GameState.PLAYING

var arena_center: Vector2 = Vector2.ZERO
var paddle_angle: float = -PI / 2.0
var target_paddle_angle: float = -PI / 2.0
var is_dragging: bool = false

# Coleções ativas
var balls: Array[Ball] = []
var particles: Array[Particle] = []
var blocks: Array[Block] = []
var active_powerups: Array[PowerupOrb] = []

# Progressão
var current_wave: int = 1
var score: int = 0
var coins: int = 0
var screen_shake: float = 0.0

# Referências de UI
@onready var wave_label: Label = $HUD/TopBar/HBoxContainer/WaveLabel
@onready var score_label: Label = $HUD/TopBar/HBoxContainer/ScoreLabel
@onready var coins_label: Label = $HUD/TopBar/HBoxContainer/CoinsLabel
@onready var wave_banner: Label = $HUD/WaveBanner
@onready var game_over_panel: PanelContainer = $HUD/GameOverPanel
@onready var final_score_label: Label = $HUD/GameOverPanel/MarginContainer/VBoxContainer/FinalScoreLabel
@onready var waves_cleared_label: Label = $HUD/GameOverPanel/MarginContainer/VBoxContainer/WavesClearedLabel
@onready var restart_button: Button = $HUD/GameOverPanel/MarginContainer/VBoxContainer/RestartButton

# ------------------------------------------------------------------------------
# 5. INICIALIZAÇÃO
# ------------------------------------------------------------------------------
func _ready() -> void:
	_update_center_pos()
	get_viewport().size_changed.connect(_update_center_pos)
	restart_button.pressed.connect(start_new_game)
	start_new_game()

func _update_center_pos() -> void:
	arena_center = get_viewport_rect().size / 2.0

func _get_current_palette() -> Dictionary:
	var idx = (current_wave - 1) % WAVE_PALETTES.size()
	return WAVE_PALETTES[idx]

func start_new_game() -> void:
	current_state = GameState.PLAYING
	game_over_panel.visible = false
	wave_banner.visible = false
	
	score = 0
	coins = 0
	current_wave = 1
	paddle_angle = -PI / 2.0
	target_paddle_angle = paddle_angle
	screen_shake = 0.0
	
	particles.clear()
	_load_wave(current_wave)
	_update_hud()

# ------------------------------------------------------------------------------
# 6. SISTEMA DE FASES (WAVES)
# ------------------------------------------------------------------------------
func _load_wave(wave_num: int) -> void:
	blocks.clear()
	active_powerups.clear()
	balls.clear()

	var palette = _get_current_palette()
	var block_color = palette["block"]

	# Gera blocos centrais conforme a fase
	match (wave_num % 4):
		1: # Padrão Cruz Central
			var block_sz = Vector2(36, 36)
			var offsets = [
				Vector2(-50, 0), Vector2(50, 0), Vector2(0, -50), Vector2(0, 50),
				Vector2(-100, 0), Vector2(100, 0), Vector2(0, -100), Vector2(0, 100)
			]
			for off in offsets:
				_create_block(arena_center + off - block_sz / 2.0, block_sz, 1, block_color)

		2: # Quadrado/Anel Intermediário
			var block_sz = Vector2(40, 24)
			for i in range(8):
				var ang = i * (TAU / 8.0)
				var pos = arena_center + Vector2.RIGHT.rotated(ang) * 95.0 - block_sz / 2.0
				_create_block(pos, block_sz, 2, block_color)

		3: # Bumpers Centrais Reforçados + Proteção
			var block_sz = Vector2(32, 32)
			for x in [-60, 0, 60]:
				for y in [-60, 0, 60]:
					if x == 0 and y == 0:
						continue # Deixa o centro livre para spawn da bola
					_create_block(arena_center + Vector2(x, y) - block_sz / 2.0, block_sz, 2, block_color)

		0: # Anel Denso
			var block_sz = Vector2(32, 22)
			for i in range(10):
				var ang = i * (TAU / 10.0)
				var pos = arena_center + Vector2.RIGHT.rotated(ang) * 110.0 - block_sz / 2.0
				_create_block(pos, block_sz, 2, block_color)

	# Spawna 1 Bolinha inicial no centro
	_spawn_ball(arena_center, randf_range(0.0, TAU), ball_base_speed + (current_wave - 1) * 18.0)

	# Spawna 1 Power-up de Multiball próximo ao centro
	_spawn_powerup(arena_center + Vector2.RIGHT.rotated(randf() * TAU) * 65.0)

	# Banner de início de fase
	_show_wave_banner("FASE %d" % current_wave)
	_update_hud()

func _create_block(top_left: Vector2, size: Vector2, hp: int, col: Color) -> void:
	var b = Block.new()
	b.rect = Rect2(top_left, size)
	b.hp = hp
	b.max_hp = hp
	b.color = col
	blocks.append(b)

func _spawn_ball(origin: Vector2, angle: float, spd: float) -> void:
	var b = Ball.new()
	b.pos = origin
	b.speed = spd
	b.vel = Vector2.RIGHT.rotated(angle) * spd
	b.color = Color(1.0, 1.0, 1.0)
	balls.append(b)

func _spawn_powerup(pos: Vector2) -> void:
	var p = PowerupOrb.new()
	p.pos = pos
	p.is_multiball = true
	active_powerups.append(p)

func _show_wave_banner(text: String) -> void:
	wave_banner.text = text
	wave_banner.visible = true
	var tween = create_tween()
	wave_banner.modulate = Color(1, 1, 1, 0)
	tween.tween_property(wave_banner, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.2)
	tween.tween_property(wave_banner, "modulate:a", 0.0, 0.4)
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
	_process_balls(delta)
	_process_particles(delta)
	_process_powerups(delta)
	
	# Condição de vitória da fase: todos os blocos foram destruídos!
	if blocks.is_empty():
		current_wave += 1
		score += 100
		coins += 5
		_trigger_firework(arena_center, Color(0.2, 1.0, 0.6), 40)
		_load_wave(current_wave)

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

func _process_balls(delta: float) -> void:
	var boundary_limit = arena_radius - ball_radius
	var palette = _get_current_palette()

	for i in range(balls.size() - 1, -1, -1):
		var b = balls[i]
		
		# Atualiza rastro
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

				# Impulso tangencial dependendo de onde atingiu no arco
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
				_add_shake(3.5)
				_trigger_firework(b.pos, palette["paddle"], 12)

			else:
				# Essa bola saiu! Remove da lista
				_trigger_firework(b.pos, Color(1.0, 0.2, 0.3), 16)
				balls.remove_at(i)
				continue

		# Colisão com blocos centrais
		_check_ball_blocks_collision(b)

	# Se todas as bolas foram perdidas -> Game Over!
	if balls.is_empty():
		_trigger_game_over()

func _check_ball_blocks_collision(b: Ball) -> void:
	for i in range(blocks.size() - 1, -1, -1):
		var blk = blocks[i]
		
		# Ponto mais próximo do retângulo em relação ao centro da bola
		var closest_x = clampf(b.pos.x, blk.rect.position.x, blk.rect.end.x)
		var closest_y = clampf(b.pos.y, blk.rect.position.y, blk.rect.end.y)
		var closest_point = Vector2(closest_x, closest_y)
		var dist = b.pos.distance_to(closest_point)

		if dist <= ball_radius:
			# Vetor normal de colisão
			var normal = (b.pos - closest_point).normalized()
			if normal.is_zero_approx():
				normal = (b.pos - blk.rect.get_center()).normalized()
				if normal.is_zero_approx():
					normal = Vector2.UP

			b.vel = b.vel.bounce(normal)
			b.pos = closest_point + normal * (ball_radius + 1.0)

			# Reduz vida do bloco
			blk.hp -= 1
			_add_shake(4.0)
			_trigger_firework(closest_point, blk.color, 16) # Efeito de faíscas estilo fogos de artifício!

			if blk.hp <= 0:
				blocks.remove_at(i)
				score += 10
				coins += 1
				_trigger_firework(blk.rect.get_center(), Color(1.0, 0.9, 0.2), 26)
			_update_hud()
			break

func _process_powerups(delta: float) -> void:
	for i in range(active_powerups.size() - 1, -1, -1):
		var p = active_powerups[i]
		p.pulse_time += delta

		# Checa se alguma bolinha pegou o orbe de poder
		for b in balls:
			if b.pos.distance_to(p.pos) <= ball_radius + p.radius:
				# ATIVA O MULTIBALL (3 Bolinhas!)
				_activate_multiball(p.pos, b.vel)
				_trigger_firework(p.pos, Color(1.0, 0.85, 0.2), 35)
				_add_shake(6.0)
				coins += 3
				score += 25
				_update_hud()
				active_powerups.remove_at(i)
				break

func _activate_multiball(origin: Vector2, base_vel: Vector2) -> void:
	var base_ang = base_vel.angle()
	var spd = base_vel.length()
	# Solta duas novas bolinhas com divergência angular de +35° e -35°
	_spawn_ball(origin, base_ang + deg_to_rad(35.0), spd)
	_spawn_ball(origin, base_ang - deg_to_rad(35.0), spd)

# ------------------------------------------------------------------------------
# 9. SISTEMA DE PARTÍCULAS PROCEDURAIS ("FOGOS DE ARTIFÍCIO / TCHIU!")
# ------------------------------------------------------------------------------
func _trigger_firework(origin: Vector2, col: Color, count: int) -> void:
	for i in range(count):
		var p = Particle.new()
		p.pos = origin
		var ang = randf_range(0.0, TAU)
		var spd = randf_range(90.0, 260.0)
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
		p.vel *= (1.0 - 2.5 * delta) # Desaceleração aerodinâmica

func _add_shake(amount: float) -> void:
	screen_shake = clampf(screen_shake + amount, 0.0, max_screen_shake)

# ------------------------------------------------------------------------------
# 10. RENDERIZAÇÃO GRÁFICA VIA CÓDIGO (_draw)
# ------------------------------------------------------------------------------
func _draw() -> void:
	# Aplica deslocamento do Screen Shake
	var shake_offset = Vector2.ZERO
	if screen_shake > 0.0:
		shake_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * screen_shake
	
	var center = arena_center + shake_offset
	var palette = _get_current_palette()

	# 1. Fundo estilizado do círculo da Arena (Sombra interior sutil)
	draw_circle(center, arena_radius, Color(0.06, 0.07, 0.11, 0.9))
	draw_arc(center, arena_radius, 0.0, TAU, 84, palette["arena"], arena_line_width, true)

	# 2. Blocos Centrais (com borda de destaque e efeito de vida)
	for blk in blocks:
		var rect_offset = Rect2(blk.rect.position + shake_offset, blk.rect.size)
		var fill_col = blk.color
		if blk.hp < blk.max_hp:
			fill_col = fill_col.darkened(0.3)
		draw_rect(rect_offset, fill_col)
		# Borda de contorno elegante
		draw_rect(rect_offset, Color.WHITE.lerp(fill_col, 0.3), false, 2.0)

	# 3. Orbes de Power-up (Multiball) pulsantes
	for p in active_powerups:
		var p_pos = p.pos + shake_offset
		var pulse = 1.0 + 0.15 * sin(p.pulse_time * 8.0)
		# Brilho externo
		draw_circle(p_pos, p.radius * pulse, Color(1.0, 0.85, 0.2, 0.35))
		# Núcleo
		draw_circle(p_pos, p.radius * 0.7 * pulse, Color(1.0, 0.95, 0.5))
		# Símbolo visual "3" (três pontinhos dentro indicando multiball)
		for j in range(3):
			var dot_off = Vector2.RIGHT.rotated(j * (TAU / 3.0) + p.pulse_time * 3.0) * (p.radius * 0.35)
			draw_circle(p_pos + dot_off, 2.5, Color.BLACK)

	# 4. Raquete do Jogador (Arco Moderno com Extremidades Arredondadas em Cápsula)
	var half_arc = deg_to_rad(paddle_arc_degrees / 2.0)
	var start_ang = paddle_angle - half_arc
	var end_ang = paddle_angle + half_arc
	var p_color = palette["paddle"]

	# Arco principal
	draw_arc(center, arena_radius, start_ang, end_ang, 40, p_color, paddle_thickness, true)
	
	# Extremidades arredondadas (Cápsula suave nas pontas)
	var cap_radius = paddle_thickness / 2.0
	var p1 = center + Vector2.RIGHT.rotated(start_ang) * arena_radius
	var p2 = center + Vector2.RIGHT.rotated(end_ang) * arena_radius
	draw_circle(p1, cap_radius, p_color)
	draw_circle(p2, cap_radius, p_color)

	# 5. Rastro Luminoso das Bolinhas
	for b in balls:
		var trail_count = b.trail.size()
		for t_idx in range(trail_count):
			var alpha = 1.0 - (float(t_idx) / float(trail_count))
			var r_size = ball_radius * (1.0 - (float(t_idx) / float(trail_count)) * 0.6)
			var trail_color = palette["paddle"]
			trail_color.a = alpha * 0.45
			draw_circle(b.trail[t_idx] + shake_offset, r_size, trail_color)

	# 6. Bolinhas Principais
	for b in balls:
		draw_circle(b.pos + shake_offset, ball_radius, b.color)
		# Brilho central
		draw_circle(b.pos + shake_offset, ball_radius * 0.5, Color.WHITE)

	# 7. Partículas de Fogos de Artifício (Faíscas)
	for pt in particles:
		var alpha = pt.life / pt.max_life
		var col = pt.color
		col.a = alpha
		draw_circle(pt.pos + shake_offset, pt.size * alpha, col)

# ------------------------------------------------------------------------------
# 11. HUD E GAME OVER
# ------------------------------------------------------------------------------
func _update_hud() -> void:
	wave_label.text = "FASE %d" % current_wave
	score_label.text = "PONTOS: %d" % score
	coins_label.text = "🪙 %d" % coins

func _trigger_game_over() -> void:
	current_state = GameState.GAME_OVER
	final_score_label.text = "Pontuação: %d  |  Moedas: %d" % [score, coins]
	waves_cleared_label.text = "Fases Concluídas: %d" % (current_wave - 1)
	game_over_panel.visible = true
	queue_redraw()
