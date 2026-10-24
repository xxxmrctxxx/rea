extends Control
## Title screen: continue, or create a character (name, job, look).
## Uses the APK title background, job portraits and full-body art when they
## have been extracted.

signal start_game(progress: Dictionary)

const Data = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/rules.gd")
const Assets = preload("res://scripts/apk_assets.gd")
const SaveGame = preload("res://scripts/save_game.gd")

var job := "warrior"
var look_index := 0
var name_edit := LineEdit.new()
var job_buttons := {}
var look_view := TextureRect.new()
var look_label := Label.new()


func _ready() -> void:
	# The parent is a CanvasLayer, so anchors have no rect to follow.
	size = Vector2(Rules.VIEW_W, Rules.VIEW_H)
	var bg_tex := Assets.tex("title_bg")
	if bg_tex != null:
		var bg := TextureRect.new()
		bg.texture = bg_tex
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.size = size
		bg.modulate = Color(0.55, 0.55, 0.65)
		add_child(bg)
	else:
		var bg := ColorRect.new()
		bg.color = Color("#1b1440")
		bg.size = size
		add_child(bg)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.16, 0.88)
	style.set_corner_radius_all(20)
	style.set_content_margin_all(28)
	card.add_theme_stylebox_override("panel", style)
	card.position = Vector2(150, 70)
	card.custom_minimum_size = Vector2(980, 0)
	add_child(card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	card.add_child(row)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(640, 0)
	row.add_child(col)

	var title := Label.new()
	title.text = "Maple Godot"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("#ffb300"))
	col.add_child(title)
	var sub := Label.new()
	sub.text = "Phiêu lưu hành động 2D lấy cảm hứng từ MapleStory M"
	sub.add_theme_color_override("font_color", Color("#b0bec5"))
	col.add_child(sub)

	var saved = SaveGame.load_progress()
	if saved != null:
		var cont := _primary_button("Tiếp tục: %s (Lv.%d %s)" % [saved.name, saved.level, Data.JOBS[saved.job].name])
		cont.pressed.connect(func(): start_game.emit(saved))
		col.add_child(cont)

	name_edit.placeholder_text = "Tên nhân vật"
	name_edit.max_length = 12
	name_edit.custom_minimum_size = Vector2(0, 40)
	col.add_child(name_edit)

	var jobs := GridContainer.new()
	jobs.columns = 5
	jobs.add_theme_constant_override("h_separation", 10)
	col.add_child(jobs)
	for id in Data.JOBS:
		var b := Button.new()
		b.text = Data.JOBS[id].name
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(118, 112)
		b.icon = Assets.portrait(id)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_color_override("font_pressed_color", Color(Data.JOBS[id].color).lightened(0.3))
		b.pressed.connect(_select_job.bind(id))
		jobs.add_child(b)
		job_buttons[id] = b

	var start := _primary_button("Tạo nhân vật mới")
	start.pressed.connect(_on_start)
	col.add_child(start)
	var hint := Label.new()
	hint.text = "← → di chuyển · Space nhảy · Z đánh · A S D F kỹ năng · T tự động săn · H hướng dẫn"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("#90a4ae"))
	col.add_child(hint)
	if not Assets.available():
		var warn := Label.new()
		warn.text = "Chưa có hình từ APK: chạy tools/extract_apk_assets.py (xem README)."
		warn.add_theme_color_override("font_color", Color("#ffab91"))
		col.add_child(warn)

	# Look picker with the full-body art.
	var look_col := VBoxContainer.new()
	look_col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(look_col)
	look_view.custom_minimum_size = Vector2(260, 300)
	look_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	look_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	look_col.add_child(look_view)
	var arrows := HBoxContainer.new()
	arrows.alignment = BoxContainer.ALIGNMENT_CENTER
	look_col.add_child(arrows)
	var prev := Button.new()
	prev.text = "  ◀  "
	prev.pressed.connect(func(): _cycle_look(-1))
	arrows.add_child(prev)
	look_label.custom_minimum_size = Vector2(110, 0)
	look_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrows.add_child(look_label)
	var next := Button.new()
	next.text = "  ▶  "
	next.pressed.connect(func(): _cycle_look(1))
	arrows.add_child(next)
	look_col.visible = Assets.available()

	_select_job("warrior")
	name_edit.text_submitted.connect(func(_t): _on_start())


func _primary_button(label: String) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(0, 44)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#ffb300")
	sb.set_corner_radius_all(12)
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.bg_color = Color("#ffc233")
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_color_override("font_color", Color("#3e2723"))
	b.add_theme_color_override("font_hover_color", Color("#3e2723"))
	b.add_theme_font_size_override("font_size", 17)
	return b


func _select_job(id: String) -> void:
	job = id
	for k in job_buttons:
		job_buttons[k].button_pressed = k == id
	look_index = maxi(0, Assets.LOOKS.find(Assets.JOB_ART[id]))
	_cycle_look(0)


func _cycle_look(step: int) -> void:
	look_index = posmod(look_index + step, Assets.LOOKS.size())
	look_view.texture = Assets.tex(Assets.LOOKS[look_index])
	look_label.text = "Ngoại hình %d/%d" % [look_index + 1, Assets.LOOKS.size()]


func _on_start() -> void:
	var player_name := name_edit.text.strip_edges().substr(0, 12)
	var progress := Rules.new_progress(player_name if player_name != "" else "Maple", job)
	progress.look = Assets.LOOKS[look_index]
	start_game.emit(progress)
