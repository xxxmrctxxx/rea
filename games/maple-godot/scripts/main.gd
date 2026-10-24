extends Node
## Boot: input map, title screen, game scene, fixed-step update and save.

const Rules = preload("res://scripts/rules.gd")
const World = preload("res://scripts/world.gd")
const WorldView = preload("res://scripts/world_view.gd")
const Background = preload("res://scripts/background.gd")
const Hud = preload("res://scripts/hud.gd")
const Menu = preload("res://scripts/menu.gd")
const SaveGame = preload("res://scripts/save_game.gd")

const ACTIONS := {
	"move_left": [KEY_LEFT],
	"move_right": [KEY_RIGHT],
	"move_up": [KEY_UP],
	"move_down": [KEY_DOWN],
	"jump": [KEY_SPACE, KEY_C],
	"skill_0": [KEY_Z],
	"skill_1": [KEY_A],
	"skill_2": [KEY_S],
	"skill_3": [KEY_D],
	"skill_4": [KEY_F],
	"hp_potion": [KEY_Q],
	"mp_potion": [KEY_W],
	"toggle_auto": [KEY_T],
	"enhance": [KEY_U],
	"toggle_help": [KEY_H],
	"pause": [KEY_P, KEY_ESCAPE],
}

var world
var view: Node2D
var hud: Control
var game_root: Node
var menu: Control
var save_t := 0.0
var clicked_skills := {}


func _ready() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	_show_menu()


func _show_menu() -> void:
	menu = Menu.new()
	var layer := CanvasLayer.new()
	layer.add_child(menu)
	add_child(layer)
	menu.start_game.connect(func(p): layer.queue_free(); _start(p))


func _start(progress: Dictionary) -> void:
	world = World.new(progress)
	game_root = Node.new()
	add_child(game_root)

	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	var bg := Background.new()
	bg_layer.add_child(bg)
	game_root.add_child(bg_layer)

	view = WorldView.new()
	game_root.add_child(view)
	view.bind(world)
	bg.world = world
	bg.camera = view.camera

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 1
	hud = Hud.new()
	hud.world = world
	hud_layer.add_child(hud)
	game_root.add_child(hud_layer)

	world.map_changed.connect(func(): SaveGame.write(progress))
	SaveGame.write(progress)


func _read_input() -> Dictionary:
	var skills: Array = []
	for i in 5:
		skills.append(Input.is_action_pressed("skill_%d" % i) or clicked_skills.has(i))
	clicked_skills.clear()
	return {
		"left": Input.is_action_pressed("move_left"),
		"right": Input.is_action_pressed("move_right"),
		"up": Input.is_action_pressed("move_up"),
		"down": Input.is_action_pressed("move_down"),
		"up_pressed": Input.is_action_just_pressed("move_up"),
		"jump_pressed": Input.is_action_just_pressed("jump"),
		"skills": skills,
		"hp_pressed": Input.is_action_just_pressed("hp_potion"),
		"mp_pressed": Input.is_action_just_pressed("mp_potion"),
	}


func _physics_process(delta: float) -> void:
	if world == null:
		return
	if Input.is_action_just_pressed("toggle_help"):
		hud.show_help = not hud.show_help
	if Input.is_action_just_pressed("pause"):
		hud.paused = not hud.paused
	if hud.paused:
		return
	if Input.is_action_just_pressed("toggle_auto"):
		_toggle_auto()
	if Input.is_action_just_pressed("enhance"):
		world.enhance_weapon()
	world.update(delta, _read_input())
	save_t += delta
	if save_t > 10.0:
		save_t = 0.0
		SaveGame.write(world.progress)


func _toggle_auto() -> void:
	world.auto = not world.auto
	world.notice("Tự động săn: BẬT" if world.auto else "Tự động săn: TẮT", Color("#ffb300"))


func _unhandled_input(event: InputEvent) -> void:
	if world == null or not (event is InputEventMouseButton) or not event.pressed:
		return
	var pos: Vector2 = event.position
	var slots := Hud.skill_slots()
	for i in slots.size():
		if pos.distance_to(slots[i].pos) < slots[i].r:
			clicked_skills[i] = true
	for b in Hud.item_buttons():
		if b.rect.has_point(pos):
			if b.id == "auto":
				_toggle_auto()
			else:
				world.use_potion(b.id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and world != null:
		SaveGame.write(world.progress)
