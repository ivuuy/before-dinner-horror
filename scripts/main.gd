extends Node3D

## Before Dinner: a compact, playable vertical slice.
## The scene is built from code so the project stays easy to iterate in Godot.

const Props = preload("res://scripts/props.gd")

var player: CharacterBody3D
var granny: CharacterBody3D
var camera: Camera3D
var player_visual: Node3D
var granny_visual: Node3D
var ui: CanvasLayer
var objective_label: Label
var prompt_label: Label
var message_label: Label
var status_label: Label
var crosshair: Label
var film: ColorRect

var floor_mat: Material
var wood_mat: Material
var dark_wood_mat: Material
var plaster_mat: Material
var wallpaper_mat: Material
var brass_mat: Material
var ceramic_mat: Material
var cloth_mat: Material
var skin_mat: Material
var hair_mat: Material
var red_mat: Material

var bowl_taken := false
var bowl_placed := false
var tv_on := false
var key_taken := false
var escaped := false
var caught := false
var message_until := 0.0
var granny_state := "patrol"
var granny_target := Vector3(4.0, 0.0, -1.8)
var patrol_points := [Vector3(4.0,0,-1.8), Vector3(4.0,0,1.7), Vector3(-4.8,0,1.7), Vector3(-4.8,0,-2.8)]
var patrol_index := 0
var patrol_wait := 0.0
var alert_meter := 0.0
var noise_meter := 0.0
var lamp_lights: Array[OmniLight3D] = []
var rain_player: AudioStreamPlayer
var rain_playback: AudioStreamGeneratorPlayback
var nav := AStarGrid2D.new()
var nav_path := PackedVector2Array()
var nav_timer := 0.0
var hidden := false
var hide_return := Vector3.ZERO
var grace_time := 32.0
var tv_timer := 0.0
var game_started := false
var game_paused := false
var menu_root: Control
var pause_root: Control
var stamina := 100.0
var footstep_timer := 0.0
var step_sound: AudioStreamPlayer
var audio_nodes: Array[AudioStreamPlayer] = []
var menu_camera: Camera3D
var bowl_visual: Node3D
var placed_bowl: Node3D
var menu_font: Font
var noise_label: Label
var flashlight: SpotLight3D
var choice_label: Label

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_setup_materials()
	_setup_world()
	_setup_player()
	_setup_granny()
	_setup_ui()
	_setup_rain_audio()
	show_message("雨还在下。奶奶说，晚饭前不要离开房间。", 5.0)

func _setup_materials() -> void:
	floor_mat = aged_material(Color("#78533a"),1,0.67)
	wood_mat = aged_material(Color("#775038"),1,0.73)
	dark_wood_mat = aged_material(Color("#3c2f24"),1,0.85)
	plaster_mat = Props.material(Color("#726b60"), 0.96)
	wallpaper_mat = Props.material(Color("#4a4c43"), 0.91)
	brass_mat = Props.material(Color("#9b7440"), 0.3, 0.68)
	ceramic_mat = Props.material(Color("#d1d2bd"), 0.24)
	cloth_mat = aged_material(Color("#b4a68b"),4)
	skin_mat = Props.material(Color("#9b6f5d"), 0.76)
	hair_mat = Props.material(Color("#26201e"), 1.0)
	red_mat = aged_material(Color("#663c35"),4)

func aged_material(tint: Color, surface_type: int, roughness := 0.86) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/aged_surface.gdshader")
	sm.set_shader_parameter("tint", tint)
	sm.set_shader_parameter("surface_type", surface_type)
	sm.set_shader_parameter("roughness_value", roughness)
	return sm

func _setup_world() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#070b0f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#617083")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.18
	env.fog_enabled = true
	env.fog_light_color = Color("#202a31")
	env.fog_light_energy = 0.28
	env.fog_density = 0.006
	env.fog_height = 1.6
	env.fog_height_density = 0.05
	env_node.environment = env
	add_child(env_node)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48,-32,0)
	moon.light_color = Color("#9daec5")
	moon.light_energy = 0.15
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 30.0
	add_child(moon)

	# Floor, walls, ceiling trim: a compact house footprint.
	Props.body(self, Vector3(0,-0.14,0), Vector3(14,0.28,10), floor_mat)
	var wall_shader := aged_material(Color("#4e5048"), 2, 0.94)
	Props.body(self, Vector3(0,2.0,-4.9), Vector3(14,4.0,0.24), wall_shader)
	Props.body(self, Vector3(-6.9,2.0,-1.1), Vector3(0.24,4.0,7.6), wall_shader)
	Props.body(self, Vector3(-6.9,2.0,4.55), Vector3(0.24,4.0,0.7), wall_shader)
	Props.body(self, Vector3(-6.9,3.55,3.45), Vector3(0.24,0.9,1.5), wall_shader)
	Props.body(self, Vector3(6.9,2.0,0), Vector3(0.24,4.0,9.8), wall_shader)
	# Back wall is split around the escape door.
	Props.body(self, Vector3(-3.75,2.0,4.9), Vector3(6.3,4.0,0.24), wall_shader)
	Props.body(self, Vector3(3.75,2.0,4.9), Vector3(6.3,4.0,0.24), wall_shader)
	Props.body(self, Vector3(0,3.65,4.9), Vector3(1.2,0.7,0.24), wall_shader)
	Props.body(self, Vector3(-3.5,3.72,0), Vector3(0.12,0.22,9.7), dark_wood_mat)
	Props.body(self, Vector3(3.5,3.72,0), Vector3(0.12,0.22,9.7), dark_wood_mat)
	Props.body(self, Vector3(0,3.72,-4.78), Vector3(13.7,0.22,0.12), dark_wood_mat)

	_build_windows()
	_build_lighting()
	_build_dining_room()
	_build_kitchen()
	_build_entry()
	_build_props()

func _build_windows() -> void:
	var window_mat := ShaderMaterial.new()
	window_mat.shader = load("res://shaders/rain_window.gdshader")
	for x in [-4.7, 0.3, 5.2]:
		var panel := Props.box(self, Vector3(x,2.22,-4.72), Vector3(2.55,2.1,0.035), window_mat)
		panel.name = "RainWindow"
		for dx in [-1.25,1.25]: Props.box(self, Vector3(x+dx,2.22,-4.69), Vector3(0.055,2.15,0.16), dark_wood_mat)
		for dy in [1.17,3.27]: Props.box(self, Vector3(x,dy,-4.69), Vector3(2.62,0.055,0.16), dark_wood_mat)
		Props.box(self, Vector3(x,2.22,-4.66), Vector3(0.045,2.05,0.07), dark_wood_mat)
		Props.box(self, Vector3(x,2.22,-4.66), Vector3(2.55,0.045,0.07), dark_wood_mat)
		Props.box(self,Vector3(x,1.12,-4.51),Vector3(2.8,0.1,0.42),wood_mat)
		for side in [-1,1]:
			for fold in 7:
				Props.cylinder(self,Vector3(x+side*(1.36+fold*0.045),2.23,-4.43+sin(fold*2)*0.04),0.066,2.4,cloth_mat)
		Props.limb(self,Vector3(x-1.8,3.5,-4.4),Vector3(x+1.8,3.5,-4.4),0.025,brass_mat)
		var cool := OmniLight3D.new()
		cool.position = Vector3(x,2.15,-4.25)
		cool.light_color = Color("91b7cf")
		cool.light_energy = 1.0
		cool.omni_range = 4.0
		add_child(cool)

func _build_lighting() -> void:
	_add_lamp(Vector3(-3.0,2.9,0.8), Color("#f7c77c"), 5.2)
	_add_lamp(Vector3(3.0,2.9,0.8), Color("#f3b46d"), 4.8)
	_add_lamp(Vector3(0.0,2.65,-3.0), Color("#e0a264"), 3.8)
	# Decorative pendant shades.
	for x in [-3.0, 3.0]:
		Props.cylinder(self, Vector3(x,3.34,0.8), 0.035, 0.55, dark_wood_mat)
		var shade := Props.cylinder(self, Vector3(x,3.03,0.8), 0.24, 0.18, cloth_mat, 0.11)
		shade.rotation_degrees.x = 180

func _add_lamp(pos: Vector3, color: Color, energy: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 6.0
	light.shadow_enabled = true
	add_child(light)
	lamp_lights.append(light)

func _build_dining_room() -> void:
	# Rug and table.
	Props.box(self, Vector3(0,0.012,0.15), Vector3(5.7,0.035,3.3), Props.material(Color("#302528"),1.0))
	for x in [-2.05,2.05]:
		for z in [-0.98,1.2]: Props.cylinder(self, Vector3(x,0.92,z), 0.115, 1.78, dark_wood_mat)
	Props.box(self, Vector3(0,1.0,0.15), Vector3(4.65,0.16,1.65), wood_mat)
	Props.box(self, Vector3(0,1.1,0.15), Vector3(4.45,0.08,1.48), aged_material(Color("#8f7556"),1,0.9))
	for x in [-1.55,-0.52,0.52,1.55]:
		Props.box(self, Vector3(x,1.151,0.15), Vector3(0.73,0.018,1.08), Props.material(Color("#b0a58d"),1.0))
		Props.bowl(self, Vector3(x,1.19,0.15), ceramic_mat)
	# Family mannequins / placeholders seated at three positions.
	_make_dining_figure(Vector3(-2.1,0,-0.2), Color("#5b4c4b"), 0.95)
	_make_dining_figure(Vector3(2.1,0,-0.2), Color("#4e5552"), 1.0)
	_make_dining_figure(Vector3(0,0,1.55), Color("#6a5140"), 1.03)
	# Sideboard with the first bowl.
	Props.box(self, Vector3(-5.75,1.2,0.0), Vector3(1.1,2.0,0.72), dark_wood_mat)
	Props.box(self, Vector3(-5.75,2.24,0.0), Vector3(1.28,0.12,0.84), wood_mat)
	Props.bowl(self, Vector3(-5.75,2.34,0.0), ceramic_mat)
	_make_interactable(Vector3(-5.75,2.49,0.0), Vector3(0.5,0.22,0.5), "bowl", "拿起这只碗")
	# A family portrait that changes when the TV is powered.
	var portrait := Props.box(self, Vector3(-5.55,2.35,-2.45), Vector3(1.65,1.48,0.06), Props.material(Color("#342e28"),0.92))
	portrait.name = "Portrait"
	Props.box(self, Vector3(-5.55,2.35,-2.40), Vector3(1.42,1.26,0.03), Props.material(Color("#6d5848"),0.8))

func _make_dining_figure(pos: Vector3, color: Color, scale := 1.0) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	var body_mat := Props.material(color, 0.92)
	Props.cylinder(root, Vector3(0,0.72,0), 0.33*scale, 0.86*scale, body_mat, 0.45*scale)
	Props.sphere(root, Vector3(0,1.37,0), Vector3(0.31*scale,0.31*scale,0.31*scale), skin_mat)
	Props.sphere(root, Vector3(0,1.55,0), Vector3(0.36*scale,0.15*scale,0.36*scale), hair_mat)
	Props.limb(root, Vector3(-0.25,0.95,0), Vector3(-0.58,0.86,0.12), 0.075*scale, body_mat)
	Props.limb(root, Vector3(0.25,0.95,0), Vector3(0.58,0.86,0.12), 0.075*scale, body_mat)

func _build_kitchen() -> void:
	Props.box(self, Vector3(0,0.55,-3.55), Vector3(11.8,1.0,0.75), dark_wood_mat)
	Props.box(self, Vector3(0,1.1,-3.55), Vector3(11.8,0.08,0.75), aged_material(Color("#6a7065"),3,0.68))
	for x in [-4.9,-3.4,-1.8,1.8,3.4,4.9]:
		Props.box(self, Vector3(x,0.55,-3.15), Vector3(1.25,0.8,0.05), wood_mat)
		Props.limb(self,Vector3(x-0.12,0.7,-3.10),Vector3(x+0.12,0.7,-3.10),0.016,brass_mat)
	# Stove and kettle.
	Props.box(self, Vector3(0,1.25,-3.55), Vector3(1.9,0.18,0.68), dark_wood_mat)
	for x in [-0.58,0.58]: Props.torus(self, Vector3(x,1.36,-3.55), 0.16,0.20, Props.material(Color("#242c2d"),0.37,0.42))
	Props.cylinder(self, Vector3(0.1,1.64,-3.58), 0.27,0.32,brass_mat,0.18)
	Props.torus(self, Vector3(0.1,1.82,-3.58),0.16,0.21,brass_mat)
	# Kitchen key, hidden in the little cabinet.
	Props.box(self, Vector3(-4.85,1.32,-3.10), Vector3(0.86,0.9,0.05), Props.material(Color("#45362c"),0.85))
	Props.box(self, Vector3(-4.85,1.32,-3.05), Vector3(0.12,0.16,0.03), brass_mat)
	_make_interactable(Vector3(-4.85,1.34,-3.01), Vector3(0.38,0.58,0.20), "key", "打开柜门，取出钥匙")

func _build_entry() -> void:
	# Front/escape door.
	Props.box(self, Vector3(0,2.0,4.75), Vector3(1.15,3.5,0.16), wood_mat)
	Props.box(self, Vector3(0,2.0,4.64), Vector3(0.94,3.25,0.07), aged_material(Color("#614936"),1,0.85))
	Props.box(self, Vector3(0,0.87,4.61), Vector3(0.12,0.12,0.12), brass_mat)
	Props.cylinder(self, Vector3(-0.22,2.0,4.62),0.04,2.9,brass_mat)
	_make_interactable(Vector3(0,2.0,4.50), Vector3(0.98,3.2,0.2), "exit", "打开大门")
	# Muddy welcome mat.
	Props.box(self, Vector3(0,0.024,3.95), Vector3(2.0,0.04,0.75), Props.material(Color("#382b25"),1.0))

func _build_props() -> void:
	# TV and its interaction volume.
	Props.box(self, Vector3(5.55,1.3,-2.92), Vector3(1.4,1.95,0.55), dark_wood_mat)
	var screen_mat := ShaderMaterial.new()
	screen_mat.shader = load("res://shaders/screen.gdshader")
	var screen := Props.box(self, Vector3(5.55,1.55,-2.61), Vector3(1.05,0.94,0.035), screen_mat)
	screen.name = "TelevisionScreen"
	_make_interactable(Vector3(5.55,1.55,-2.52), Vector3(1.3,1.1,0.3), "tv", "打开电视，让噪声盖住脚步")
	# Old armchair, cover, and a tall coat closet.
	Props.box(self, Vector3(4.8,0.58,-1.05), Vector3(1.45,0.85,1.1), red_mat)
	Props.box(self, Vector3(4.8,1.35,-1.45), Vector3(1.45,1.35,0.4), red_mat)
	Props.box(self, Vector3(5.82,1.48,1.55), Vector3(1.3,2.8,0.7), dark_wood_mat)
	Props.box(self, Vector3(5.82,1.45,1.16), Vector3(1.0,2.5,0.05), Props.material(Color("#39251e"),0.92))
	_make_interactable(Vector3(5.82,1.47,1.03), Vector3(1.0,2.5,0.22), "closet", "躲进衣柜")
	# Rainy window sill plants.
	for x in [-4.7,5.2]:
		Props.cylinder(self, Vector3(x,1.26,-4.38),0.22,0.38,Props.material(Color("#5d4032"),0.9))
		for dx in [-0.15,0,0.15]: Props.sphere(self, Vector3(x+dx,1.61,-4.38),Vector3(0.15,0.28,0.14),Props.material(Color("#344938"),0.98))

func _make_interactable(pos: Vector3, size: Vector3, id: String, prompt: String) -> StaticBody3D:
	var node := StaticBody3D.new()
	add_child(node)
	node.position = pos
	node.collision_layer = 1
	node.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	node.add_child(shape)
	node.set_meta("interact_id", id)
	node.set_meta("prompt", prompt)
	return node

func _setup_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0,0.95,3.25)
	player.rotation.y = 0.0
	player.collision_layer = 2
	player.collision_mask = 1
	add_child(player)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.72
	shape.shape = capsule
	player.add_child(shape)
	player_visual = Node3D.new()
	player.add_child(player_visual)
	camera = Camera3D.new()
	camera.position = Vector3(0,0.56,0)
	camera.current = true
	camera.fov = 72.0
	player.add_child(camera)
	flashlight = SpotLight3D.new()
	camera.add_child(flashlight)
	flashlight.position = Vector3(0.15,-0.1,-0.1)
	flashlight.light_color = Color("e5ddbd")
	flashlight.light_energy = 2.5
	flashlight.spot_range = 12
	flashlight.spot_angle = 24
	flashlight.spot_attenuation = 1.2
	flashlight.shadow_enabled = true
	flashlight.visible = false

func _setup_granny() -> void:
	granny = CharacterBody3D.new()
	granny.name = "Granny"
	granny.position = Vector3(1.7,0,-2.85)
	granny.collision_layer = 4
	granny.collision_mask = 1
	add_child(granny)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.85
	shape.shape = capsule
	shape.position.y = 0.93
	granny.add_child(shape)
	granny_visual = Node3D.new()
	granny.add_child(granny_visual)
	_make_granny_model()

func _make_granny_model() -> void:
	var dress := Props.material(Color("#55474b"),0.94)
	Props.cylinder(granny_visual,Vector3(0,0.83,0),0.42,1.15,dress,0.62)
	Props.sphere(granny_visual,Vector3(0,1.65,0),Vector3(0.34,0.34,0.34),skin_mat)
	Props.sphere(granny_visual,Vector3(0,1.86,0),Vector3(0.44,0.19,0.42),hair_mat)
	Props.sphere(granny_visual,Vector3(-0.18,1.77,-0.20),Vector3(0.11,0.07,0.04),red_mat)
	Props.sphere(granny_visual,Vector3(0.18,1.77,-0.20),Vector3(0.11,0.07,0.04),red_mat)
	Props.limb(granny_visual,Vector3(-0.33,1.13,0),Vector3(-0.57,0.48,0.10),0.095,skin_mat)
	Props.limb(granny_visual,Vector3(0.33,1.13,0),Vector3(0.57,0.48,0.10),0.095,skin_mat)
	Props.limb(granny_visual,Vector3(-0.17,0.3,0),Vector3(-0.2,0.04,0.03),0.11,dark_wood_mat)
	Props.limb(granny_visual,Vector3(0.17,0.3,0),Vector3(0.2,0.04,0.03),0.11,dark_wood_mat)
	# Cane makes her silhouette readable in low light.
	Props.limb(granny_visual,Vector3(0.54,0.61,0.08),Vector3(0.75,0.04,0.08),0.035,brass_mat)
	Props.torus(granny_visual,Vector3(0.79,0.08,0.08),0.075,0.095,brass_mat)

func _setup_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var font := load("res://assets/fonts/NotoSansSC.ttf")
	var top := ColorRect.new()
	top.color = Color(0.015,0.022,0.024,0.76)
	top.position = Vector2(0,0)
	top.size = Vector2(1600,88)
	ui.add_child(top)
	var title := Label.new()
	title.text = "晚饭之前  /  BEFORE DINNER"
	title.position = Vector2(48,23)
	title.add_theme_font_size_override("font_size",22)
	title.add_theme_color_override("font_color",Color("#d9c5a1"))
	if font: title.add_theme_font_override("font",font)
	ui.add_child(title)
	status_label = Label.new()
	status_label.text = "雨夜 · 23:47"
	status_label.position = Vector2(1340,29)
	status_label.add_theme_font_size_override("font_size",16)
	status_label.add_theme_color_override("font_color",Color("#9caaa8"))
	if font: status_label.add_theme_font_override("font",font)
	ui.add_child(status_label)

	objective_label = Label.new()
	objective_label.position = Vector2(48,112)
	objective_label.size = Vector2(620,100)
	objective_label.add_theme_font_size_override("font_size",18)
	objective_label.add_theme_color_override("font_color",Color("#e6dbc9"))
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font: objective_label.add_theme_font_override("font",font)
	ui.add_child(objective_label)
	_update_objective()

	prompt_label = Label.new()
	prompt_label.position = Vector2(0,610)
	prompt_label.size = Vector2(1600,60)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size",20)
	prompt_label.add_theme_color_override("font_color",Color("#f0dfbb"))
	if font: prompt_label.add_theme_font_override("font",font)
	ui.add_child(prompt_label)

	message_label = Label.new()
	message_label.position = Vector2(350,710)
	message_label.size = Vector2(900,76)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size",20)
	message_label.add_theme_color_override("font_color",Color("#dbc8ad"))
	if font: message_label.add_theme_font_override("font",font)
	ui.add_child(message_label)

	crosshair = Label.new()
	crosshair.text = "·"
	crosshair.position = Vector2(798,432)
	crosshair.add_theme_font_size_override("font_size",30)
	crosshair.add_theme_color_override("font_color",Color("#e2d4bb"))
	ui.add_child(crosshair)
	film = ColorRect.new()
	film.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var film_mat := ShaderMaterial.new()
	film_mat.shader = load("res://shaders/film.gdshader")
	film.material = film_mat
	film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(film)
	# film needs to be above scene, below text
	ui.move_child(film,0)
	# Hint bar.
	var hint := Label.new()
	hint.text = "WASD 移动   Shift 奔跑   Ctrl 蹲下   鼠标观察   E 互动   Esc 释放鼠标"
	hint.position = Vector2(48,842)
	hint.add_theme_font_size_override("font_size",14)
	hint.add_theme_color_override("font_color",Color("#7e8c8b"))
	if font: hint.add_theme_font_override("font",font)
	ui.add_child(hint)

func _setup_rain_audio() -> void:
	rain_player = AudioStreamPlayer.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.8
	rain_player.stream = generator
	rain_player.volume_db = -15.0
	add_child(rain_player)
	rain_player.play()
	rain_playback = rain_player.get_stream_playback()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not escaped:
		player.rotate_y(-event.relative.x * 0.0025)
		camera.rotation.x = clamp(camera.rotation.x - event.relative.y * 0.0021, -1.35, 1.35)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		if event.keycode == KEY_E and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_interact()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if escaped or caught:
		return
	_update_player(delta)
	_update_granny(delta)
	_update_prompt()
	_update_film(delta)
	_update_rain()
	if message_until > 0.0:
		message_until -= delta
		if message_until <= 0.0: message_label.text = ""

func _update_player(delta: float) -> void:
	var input_vec := Vector2.ZERO
	if Input.is_key_pressed(KEY_A): input_vec.x -= 1
	if Input.is_key_pressed(KEY_D): input_vec.x += 1
	if Input.is_key_pressed(KEY_W): input_vec.y += 1
	if Input.is_key_pressed(KEY_S): input_vec.y -= 1
	input_vec = input_vec.normalized()
	var speed := 3.7
	var sprinting := Input.is_key_pressed(KEY_SHIFT)
	if sprinting: speed = 6.1
	var crouching := Input.is_key_pressed(KEY_CTRL)
	if crouching: speed = 1.9
	var forward := -player.global_transform.basis.z
	var right := player.global_transform.basis.x
	var direction := (right*input_vec.x + forward*input_vec.y).normalized()
	player.velocity.x = move_toward(player.velocity.x, direction.x*speed, delta*18.0)
	player.velocity.z = move_toward(player.velocity.z, direction.z*speed, delta*18.0)
	player.velocity.y = 0.0
	player.move_and_slide()
	player.position.x = clamp(player.position.x,-6.35,6.35)
	player.position.z = clamp(player.position.z,-4.2,4.25)
	noise_meter = lerp(noise_meter, (1.0 if sprinting else 0.0) + (0.22 if crouching else 0.0), delta*4.0)
	if direction.length() > 0.1:
		player_visual.position.y = sin(Time.get_ticks_msec()*0.012)*0.018 if not crouching else 0.0

func _update_granny(delta: float) -> void:
	var dist := granny.global_position.distance_to(player.global_position)
	var sees_player := _granny_can_see_player(dist)
	if granny_state == "patrol":
		if sees_player and dist < 6.8:
			granny_state = "investigate"
			granny_target = player.global_position
			show_message("奶奶停下来了。她听见了什么？", 2.4)
		elif noise_meter > 0.68 and dist < 7.5:
			granny_state = "investigate"
			granny_target = player.global_position
		else:
			granny_target = patrol_points[patrol_index]
			if granny.global_position.distance_to(granny_target) < 0.45:
				patrol_wait += delta
				if patrol_wait > 1.5:
					patrol_wait = 0.0
					patrol_index = (patrol_index + 1) % patrol_points.size()
	elif granny_state == "investigate":
		if dist < 3.7 or (sees_player and dist < 8.5):
			granny_state = "chase"
			show_message("她看见你了。快躲起来！", 2.0)
		elif granny.global_position.distance_to(granny_target) < 0.55:
			granny_state = "patrol"
		else:
			granny_target = player.global_position if noise_meter > 0.48 else granny_target
	elif granny_state == "chase":
		granny_target = player.global_position
		if dist > 11.0 and not sees_player:
			granny_state = "investigate"
		if dist < 0.9:
			_caught()
	var target := granny_target
	var dir := (target - granny.global_position)
	dir.y = 0.0
	if dir.length() > 0.12:
		dir = dir.normalized()
		var chase_speed := 3.35 if granny_state == "chase" else 1.15
		granny.velocity = dir*chase_speed
		granny.move_and_slide()
		granny.look_at(granny.global_position + dir, Vector3.UP)
	else:
		granny.velocity = Vector3.ZERO
	_update_granny_visual()

func _granny_can_see_player(dist: float) -> bool:
	# The opening minute gives the player time to understand the house.
	if dist > 5.5: return false
	var forward := -granny.global_transform.basis.z
	var to_player := (player.global_position-granny.global_position).normalized()
	if forward.dot(to_player) < 0.18: return false
	var query := PhysicsRayQueryParameters3D.create(granny.global_position+Vector3.UP*1.35, player.global_position+Vector3.UP*0.5)
	query.collision_mask = 1 | 2
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == player

func _update_granny_visual() -> void:
	var stride := sin(Time.get_ticks_msec()*0.008)*0.045
	if granny_state == "chase": stride *= 2.0
	if granny_visual:
		granny_visual.rotation.z = sin(Time.get_ticks_msec()*0.004)*0.015
		for node in granny_visual.get_children():
			if node is MeshInstance3D and node.position.y < 0.4: node.rotation.z = stride

func _update_prompt() -> void:
	if escaped or caught: return
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + -camera.global_transform.basis.z*2.5)
	query.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.has("collider"):
		var collider = hit["collider"]
		if collider and collider.has_meta("interact_id"):
			var id: String = collider.get_meta("interact_id")
			if id == "bowl" and bowl_taken: prompt_label.text = ""
			elif id == "key" and not tv_on: prompt_label.text = "先打开电视，奶奶会被声音吸引"
			elif id == "key" and key_taken: prompt_label.text = ""
			elif id == "exit" and not bowl_placed: prompt_label.text = "先把餐桌摆好"
			elif id == "exit" and not key_taken: prompt_label.text = "门锁着。钥匙在厨房里"
			elif id == "closet": prompt_label.text = "E  躲进衣柜"
			else: prompt_label.text = "E  " + str(collider.get_meta("prompt"))
			return
	prompt_label.text = ""

func _interact() -> void:
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + -camera.global_transform.basis.z*2.5)
	query.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return
	var collider = hit.get("collider")
	if collider == null or not collider.has_meta("interact_id"): return
	var id: String = collider.get_meta("interact_id")
	match id:
		"bowl":
			if not bowl_taken:
				bowl_taken = true
				collider.queue_free()
				_update_objective()
				show_message("你拿起了碗。餐桌上的三个座位都已经有人了。", 3.0)
		"tv":
			if not tv_on:
				tv_on = true
				var screen: MeshInstance3D = get_node_or_null("TelevisionScreen") as MeshInstance3D
				if screen and screen.material_override is ShaderMaterial: screen.material_override.set_shader_parameter("powered",true)
				granny_state = "investigate"
				granny_target = Vector3(5.5,0,-2.5)
				_update_objective()
				show_message("电视亮了。雪花噪声盖住了你的脚步。", 3.0)
		"key":
			if tv_on and not key_taken:
				key_taken = true
				collider.queue_free()
				_update_objective()
				show_message("钥匙在手里。门就在你身后。", 2.6)
		"exit":
			if bowl_placed and key_taken: _escape()
			elif not bowl_placed: show_message("先把碗放上餐桌。奶奶不喜欢客人空着手。",2.5)
			else: show_message("锁还没开。",1.5)
		"closet":
			_hide_in_closet()
	_update_objective()

func _hide_in_closet() -> void:
	if granny_state == "chase":
		player.position = Vector3(5.82,0.9,1.55)
		granny_state = "investigate"
		granny_target = player.global_position + Vector3(-1.0,0,0)
		show_message("衣柜里很窄。屏住呼吸，别碰到衣架。",2.2)
	else: show_message("你钻进了衣柜，但现在还没有必要。",1.5)

func _update_objective() -> void:
	if escaped:
		objective_label.text = "逃出去了\n雨声还在继续。"
	elif not bowl_taken:
		objective_label.text = "目标 01  ·  找到一只碗\n去餐厅的边柜拿走碗。"
	elif not bowl_placed:
		objective_label.text = "目标 02  ·  摆好餐桌\n走到桌边，把碗放到空位上。"
	elif not tv_on:
		objective_label.text = "目标 03  ·  制造噪声\n打开电视，让奶奶离开厨房。"
	elif not key_taken:
		objective_label.text = "目标 04  ·  找到钥匙\n趁奶奶被电视吸引时搜索厨房。"
	else:
		objective_label.text = "目标 05  ·  离开这里\n回到门口，打开大门。"

func _update_film(delta: float) -> void:
	var dist := granny.global_position.distance_to(player.global_position)
	alert_meter = lerp(alert_meter, clamp(1.0-(dist/5.0),0.0,1.0) if granny_state == "chase" else 0.0, delta*3.0)
	if film and film.material is ShaderMaterial:
		film.material.set_shader_parameter("danger",alert_meter)
		film.material.set_shader_parameter("darkness",0.0)
	status_label.text = "被发现" if granny_state == "chase" else ("电视噪声" if tv_on else "雨夜 · 23:47")

func _update_rain() -> void:
	if not rain_playback: return
	var frames := rain_playback.get_frames_available()
	while frames > 0:
		var n := randf_range(-0.24,0.24)
		var low := sin(Time.get_ticks_msec()*0.00009)*0.045
		rain_playback.push_frame(Vector2(n+low,n-low))
		frames -= 1

func _escape() -> void:
	escaped = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_objective()
	show_message("门外没有街道。只有一张餐桌，和你刚才坐过的椅子。\n—— 游戏首版结束 ——", 999.0)
	player.velocity = Vector3.ZERO

func _caught() -> void:
	caught = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_message("奶奶俯下身来：‘饭还没吃，去哪儿？’\n按 R 重新开始", 999.0)
	status_label.text = "她找到你了"

func show_message(text: String, duration: float) -> void:
	if message_label:
		message_label.text = text
		message_until = duration

func _input(event: InputEvent) -> void:
	if (escaped or caught) and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()
	if event is InputEventKey and event.pressed and event.keycode == KEY_E and bowl_taken and not bowl_placed:
		# A generous table placement zone makes the first minute feel good.
		if player.global_position.distance_to(Vector3(0,0,0.15)) < 2.25:
			bowl_placed = true
			show_message("碗落在桌面上。桌边的假人同时抬起了头。",3.2)
		_update_objective()
