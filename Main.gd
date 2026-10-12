extends Node2D

# ==============================================================================
# ORBIT BOUNCE (PONG CIRCULAR) - MVP GODOT 4.x
# Arquitetura vetorial/matemática customizada via _draw()
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. PARÂMETROS AJUSTÁVEIS (@export)
# ------------------------------------------------------------------------------
@export_group("Arena e Geometria")
@export var arena_radius: float = 280.0
@export var arena_line_width: float = 6.0
@export var arena_color: Color = Color(0.18, 0.22, 0.28, 1.0)

@export_group("Jogador (Raquete/Arco)")
@export var paddle_arc_degrees: float = 48.0   # Ângulo de cobertura da raquete
@export var paddle_width: float = 14.0          # Espessura visual do arco
@export var paddle_smoothness: float = 22.0     # Suavização da rotação (lerp)
@export var paddle_color: Color = Color(0.2, 0.85, 0.45, 1.0)
@export var keyboard_rot_speed: float = 4.5     # Velocidade ao usar setas/teclado

@export_group("Bolinha")
@export var ball_radius: float = 12.0
@export var ball_initial_speed: float = 380.0
@export var ball_speed_increment: float = 1.02 # Multiplicador de +2% por rebatida
@export var ball_color: Color = Color(0.95, 0.95, 0.95, 1.0)

@export_group("Alvos Centrais")
@export var target_spawn_interval: float = 2.8
@export var target_radius: float = 16.0
@export var max_targets: int = 4
@export var target_color: Color = Color(1.0, 0.82, 0.15, 1.0)

# ------------------------------------------------------------------------------
# 2. REFERÊNCIAS DE UI (@onready)
# ------------------------------------------------------------------------------
@onready var score_label: Label = $HUD/TopBar/HBoxContainer/ScoreLabel
@onready var coins_label: Label = $HUD/TopBar/HBoxContainer/CoinsLabel
@onready var game_over_panel: PanelContainer = $HUD/GameOverPanel
@onready var final_score_label: Label = $HUD/GameOverPanel/MarginContainer/VBoxContainer/FinalScoreLabel
@onready var restart_button: Button = $HUD/GameOverPanel/MarginContainer/VBoxContainer/RestartButton

# ------------------------------------------------------------------------------
# 3. ESTADO INTERNO DO JOGO
# ------------------------------------------------------------------------------
enum GameState { PLAYING, GAME_OVER }
var current_state: GameState = GameState.PLAYING

var arena_center: Vector2 = Vector2.ZERO

# Paddle
var paddle_angle: float = -PI / 2.0       # Ângulo atual (inicia no topo)
var target_paddle_angle: float = -PI / 2.0 # Ângulo alvo recebido do input

# Ball
var ball_pos: Vector2 = Vector2.ZERO
var ball_vel: Vector2 = Vector2.ZERO
var ball_current_speed: float = 0.0

# Pontuação
var score: int = 0
var coins: int = 0

# Alvos
class TargetData:
	var pos: Vector2
	var radius: float

var active_targets: Array[TargetData] = []
var spawn_timer: float = 0.0
var is_dragging: bool = false


# ------------------------------------------------------------------------------
# 4. CICLO DE VIDA (LIFECYCLE)
# ------------------------------------------------------------------------------
func _ready() -> void:
	_update_center_position()
	get_viewport().size_changed.connect(_update_center_position)
	
	restart_button.pressed.connect(start_game)
	start_game()


func _update_center_position() -> void:
	arena_center = get_viewport_rect().size / 2.0


func start_game() -> void:
	current_state = GameState.PLAYING
	game_over_panel.visible = false
	
	# Reset de pontuações
	score = 0
	coins = 0
	_update_hud()
	
	# Reset da bolinha
	ball_pos = arena_center
	ball_current_speed = ball_initial_speed
	
	# Ângulo inicial aleatório
	var random_angle: float = randf_range(0.0, TAU)
	ball_vel = Vector2.RIGHT.rotated(random_angle) * ball_current_speed
	
	# Reset da raquete e alvos
	paddle_angle = -PI / 2.0
	target_paddle_angle = paddle_angle
	active_targets.clear()
	spawn_timer = 0.0
	
	queue_redraw()


# ------------------------------------------------------------------------------
# 5. ENTRADA DE DADOS (TOUCH, MOUSE E TECLADO)
# ------------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if current_state != GameState.PLAYING:
		return

	if event is InputEventScreenTouch:
		is_dragging = event.pressed
		if event.pressed:
			_aim_at_position(event.position)

	elif event is InputEventScreenDrag:
		_aim_at_position(event.position)

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_dragging = event.pressed
		if event.pressed:
			_aim_at_position(event.position)

	elif event is InputEventMouseMotion and is_dragging:
		_aim_at_position(event.position)


func _aim_at_position(screen_pos: Vector2) -> void:
	var diff: Vector2 = screen_pos - arena_center
	if diff.length_squared() > 100.0:
		target_paddle_angle = diff.angle()


# ------------------------------------------------------------------------------
# 6. FÍSICA E PROCESSAMENTO DO JOGO
# ------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if current_state != GameState.PLAYING:
		return

	_process_paddle_movement(delta)
	_process_ball_movement(delta)
	_process_targets(delta)
	
	queue_redraw()


func _process_paddle_movement(delta: float) -> void:
	var key_input: float = Input.get_axis("ui_left", "ui_right")
	if key_input != 0.0:
		target_paddle_angle += key_input * keyboard_rot_speed * delta
		target_paddle_angle = wrapf(target_paddle_angle, -PI, PI)
	
	var angle_diff: float = angle_difference(paddle_angle, target_paddle_angle)
	paddle_angle += angle_diff * clampf(paddle_smoothness * delta, 0.0, 1.0)
	paddle_angle = wrapf(paddle_angle, -PI, PI)


func _process_ball_movement(delta: float) -> void:
	ball_pos += ball_vel * delta

	var dist_from_center: float = ball_pos.distance_to(arena_center)
	var boundary_limit: float = arena_radius - ball_radius

	if dist_from_center >= boundary_limit:
		var outward_normal: Vector2 = (ball_pos - arena_center).normalized()
		var impact_angle: float = outward_normal.angle()
		
		var diff: float = abs(angle_difference(paddle_angle, impact_angle))
		var paddle_half_arc: float = deg_to_rad(paddle_arc_degrees / 2.0)

		# 1. ACERTOU A RAQUETE
		if diff <= paddle_half_arc:
			var inward_normal: Vector2 = -outward_normal
			ball_vel = ball_vel.bounce(inward_normal)
			
			var contact_factor: float = angle_difference(paddle_angle, impact_angle) / paddle_half_arc
			var tangent: Vector2 = Vector2(-outward_normal.y, outward_normal.x)
			ball_vel = (ball_vel + tangent * contact_factor * (ball_current_speed * 0.35)).normalized() * ball_current_speed

			if ball_vel.dot(outward_normal) > 0.0:
				ball_vel = ball_vel.bounce(inward_normal)

			ball_current_speed *= ball_speed_increment
			ball_vel = ball_vel.normalized() * ball_current_speed
			ball_pos = arena_center + outward_normal * (boundary_limit - 1.0)

			score += 1
			_update_hud()

		# 2. PASSOU DIRETO (GAME OVER)
		else:
			trigger_game_over()


func _process_targets(delta: float) -> void:
	spawn_timer += delta
	if spawn_timer >= target_spawn_interval:
		spawn_timer = 0.0
		if active_targets.size() < max_targets:
			_spawn_target()

	for i in range(active_targets.size() - 1, -1, -1):
		var target: TargetData = active_targets[i]
		var hit_distance: float = ball_radius + target.radius

		if ball_pos.distance_to(target.pos) <= hit_distance:
			var collision_normal: Vector2 = (ball_pos - target.pos).normalized()
			ball_vel = ball_vel.bounce(collision_normal)
			
			active_targets.remove_at(i)
			score += 5
			coins += 1
			_update_hud()


func _spawn_target() -> void:
	var min_r: float = 50.0
	var max_r: float = arena_radius * 0.60
	var spawn_dist: float = randf_range(min_r, max_r)
	var spawn_dir: Vector2 = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	var potential_pos: Vector2 = arena_center + (spawn_dir * spawn_dist)

	if potential_pos.distance_to(ball_pos) < (ball_radius + target_radius * 2.5):
		return

	var new_target: TargetData = TargetData.new()
	new_target.pos = potential_pos
	new_target.radius = target_radius
	active_targets.append(new_target)


# ------------------------------------------------------------------------------
# 7. RENDERIZAÇÃO GRÁFICA VIA CÓDIGO (_draw)
# ------------------------------------------------------------------------------
func _draw() -> void:
	# Círculo da Arena (Borda externa)
	draw_arc(arena_center, arena_radius, 0.0, TAU, 72, arena_color, arena_line_width, true)
	draw_circle(arena_center, 4.0, arena_color * 1.5)

	# Alvos Centrais Ativos
	for target in active_targets:
		draw_circle(target.pos, target.radius, target_color)
		draw_arc(target.pos, target.radius, 0.0, TAU, 24, Color.WHITE, 2.0, true)

	# Raquete do Jogador (Arco deslizante)
	var half_arc: float = deg_to_rad(paddle_arc_degrees / 2.0)
	var start_angle: float = paddle_angle - half_arc
	var end_angle: float = paddle_angle + half_arc
	draw_arc(arena_center, arena_radius, start_angle, end_angle, 32, paddle_color, paddle_width, true)

	# Bolinha
	if current_state == GameState.PLAYING:
		draw_circle(ball_pos, ball_radius, ball_color)


# ------------------------------------------------------------------------------
# 8. GERENCIAMENTO DE ESTADO E HUD
# ------------------------------------------------------------------------------
func _update_hud() -> void:
	score_label.text = "PONTOS: %d" % score
	coins_label.text = "MOEDAS: %d" % coins


func trigger_game_over() -> void:
	current_state = GameState.GAME_OVER
	final_score_label.text = "Pontuação: %d  |  Moedas: %d" % [score, coins]
	game_over_panel.visible = true
	queue_redraw()
