extends Node2D
## управление: a/d - влево/вправо, w/пробел - прыжочек, тоже самое со стрелками
## Esc или P - пауза (на телефоне: кнопка паузы справа вверху и системная кнопка «Назад»)
## либо свайпами мышкой

enum State { MENU, PLAYING, GAME_OVER, PAUSED }

## настройки баланса
const SWIPE_MIN := 60.0
const JUMP_TIME := 0.6
const JUMP_HEIGHT := 170.0
const JUMP_BUFFER := 0.15
const ITEM_R := 48.0
const TOP_UI_H := 380.0
const FLOOR_H := 190.0
const CAT_W := 150.0
const CAT_H := 300.0
const TOWER_LIFT := 0.0          # на сколько px поднять башню над головой (минус = ниже)
const TOWER_STEP := 40.0
const HEART_SIZE := 56.0         # размер сердца-жизни в HUD, px
const BG_TILE_SCALE := 1.0       # размер плитки обоев (1.0 = как в файле, 0.5 = вдвое мельче)
const FLOOR_TILE_SCALE := 0.25    # то же для пола
const SHOW_CATCH_LINE := false
const DEBUG_INSET := 0.0         # >0 = эмулировать вырез камеры на ПК (попробуй 90)

const START_LIVES := 3
const FALL_SPEED_START := 460.0
const FALL_SPEED_MAX := 950.0
const FALL_SPEED_STEP := 32.0
const SPAWN_START := 1.1
const SPAWN_MIN := 0.6
const SPAWN_STEP := 0.04
const PATIENCE_BASE := 5.0
const PATIENCE_PER_ITEM := 2.5
const WRONG_PENALTY := 3.0
const NEEDED_GUARANTEE := 2.2
const NEEDED_CHANCE := 0.4
const MAX_RECIPE := 5
const KINDS_TOTAL := 8        # всего ингредиентов
const START_KINDS := 5        # доступно в начале
const UNLOCK_EVERY := 4       # новый ингредиент каждые N заказов
const HEAL_EVERY_COMBO := 4

const BARREL_R := 46.0
const BARREL_SPRITE_K := 1.5     # размер спрайта бочки относительно BARREL_R (1.0 = диаметр 2*BARREL_R)
const BARREL_FROM_ORDER := 3
const BARREL_EVERY_START := 6.0
const BARREL_EVERY_MIN := 3.2
const BARREL_EVERY_STEP := 0.25
const BARREL_SPEED_START := 650.0
const BARREL_SPEED_MAX := 1000.0
const BARREL_SPEED_STEP := 15.0
const WARN_TIME := 1.0
const INVULN_TIME := 1.2
const FAIR_WINDOW := 0.6

const SPRITE_K := 2.3             # размер спрайта ингредиента относительно радиуса
const CAT_SPRITE_EXTRA := 0.0     # спрайт кота = CAT_H + это (уши)
const CAT_FEET_SINK := 12.0       # на сколько px кот "проваливается" в пол (только картинка)
const CLIENT_SPRITE := 190.0      # размер клиента в облачке
const ING_FILES := {0: "coffee", 1: "milk", 2: "blueberry", 3: "strawberry", 4: "caramel", 5: "chocolate", 6: "marshmallow", 7: "vanilla"}

const MENU_ZOOM := 2.5            # во сколько раз камера приближена в меню
const MENU_CAM_BOTTOM := 100.0    # центр кадра меню: столько px от нижнего края
const WAKE_TIME := 0.5            # кот подпрыгивает при пробуждении, сек

class Item:
	var lane: int = 0
	var kind: int = 0
	var y: float = 0.0
	var passed: bool = false

class FloatText:
	var text: String = ""
	var pos: Vector2 = Vector2.ZERO
	var color: Color = Color.WHITE
	var t: float = 0.0

class Barrel:
	var x: float = 0.0
	var dir: int = 1
	var warn: float = 1.0
	var hit: bool = false

## cостояния
var state: State = State.MENU
var state_time: float = 0.0

var lane: int = 1
var cat_x: float = 540.0
var jump_t: float = -1.0
var jump_buffer: float = 0.0

var items: Array[Item] = []
var popups: Array[FloatText] = []
var barrels: Array[Barrel] = []
var tower: Array = []
var recipe: Array = []
var recipe_idx: int = 0

var patience: float = 10.0
var patience_max: float = 10.0
var order_perfect: bool = true
var lives: int = START_LIVES
var score: int = 0
var run_coins: int = 0              # монеты, заработанные за текущую смену
var orders_done: int = 0
var combo: int = 0
var best_combo: int = 0

var spawn_timer: float = 0.5
var barrel_timer: float = 2.5
var since_needed: float = 0.0
var last_lane: int = -1
var lane_repeat: int = 0
var last_kind: int = -1
var kind_repeat: int = 0

var flash_t: float = 0.0
var flash_col: Color = Color.WHITE
var red_t: float = 0.0
var shake_t: float = 0.0
var invuln_t: float = 0.0
var ing_a: float = 1.0
var client_t: float = 0.0
var ui_off: float = 0.0          # отступ сверху под вырез камеры
var snd: Sfx                     # звуки (sfx.gd)
var ui: CanvasLayer              # слой для экранов меню/паузы/конца
var cam: Camera2D
var cam_tween: Tween
var screen: Control = null       # текущий экран (меню / пауза / конец)
var overlay: Control = null      # настройки / туториал поверх меню
var wake_t: float = -1.0         # анимация пробуждения кота
var over_shown: bool = false
var over_earned: int = 0
var over_record: bool = false
var ing_tex: Dictionary = {}
var cat_tex: Texture2D = null
var barrel_tex: Texture2D = null
var cat_closed_tex: Texture2D = null
var heart_tex: Texture2D = null
var heart_empty_tex: Texture2D = null
var pause_icon_tex: Texture2D = null
var bg_tex: Texture2D = null
var floor_tex: Texture2D = null
var client_texs: Array = []
var client_idx: int = 0

var touch_start: Vector2 = Vector2.ZERO
var touch_active: bool = false
var touch_done: bool = false

# ---------- ЦВЕТА ----------
var col_bg := Color("f6ecda")
var col_lane := Color(0, 0, 0, 0.05)
var col_floor := Color("8a5a3b")
var col_cat := Color("e9a14a")
var col_dark := Color("2b1d14")
var col_strip := Color("5a4636")
var col_heart := Color("e5484d")
var col_line := Color("f0a020")


func _ready() -> void:
	load_art()
	snd = Sfx.new()
	add_child(snd)
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	cam = Camera2D.new()
	add_child(cam)
	update_safe_area()
	get_viewport().size_changed.connect(_on_resized)
	cat_x = lane_cx(lane)
	new_order()
	show_menu(true)


func _on_resized() -> void:
	update_safe_area()
	if state == State.MENU:
		snap_cam_menu()
	else:
		snap_cam_game()


func load_art() -> void:
	for k in ING_FILES:
		var path: String = "res://art/%s.png" % ING_FILES[k]
		if ResourceLoader.exists(path):
			ing_tex[k] = load(path)
	if ResourceLoader.exists("res://art/cat.png"):
		cat_tex = load("res://art/cat.png") as Texture2D
		barrel_tex = UIKit.art_texture("barrel")   # res://art/barrel.png
		if ResourceLoader.exists("res://art/cat_closed.png"):
			cat_closed_tex = load("res://art/cat_closed.png") as Texture2D
		heart_tex = UIKit.art_texture("heart")              # res://art/heart.png
		heart_empty_tex = UIKit.art_texture("heart_empty")  # необязательно: пустое сердце
		pause_icon_tex = UIKit.art_texture("icon_pause")    # res://art/icon_pause.png
		if ResourceLoader.exists("res://art/background.png"):
			bg_tex = load("res://art/background.png") as Texture2D
		if ResourceLoader.exists("res://art/floor.png"):
			floor_tex = load("res://art/floor.png") as Texture2D
	for i in range(1, 10):
		var cp: String = "res://art/client%d.png" % i
		if ResourceLoader.exists(cp):
			client_texs.append(load(cp) as Texture2D)

## Заливает прямоугольник бесшовной текстурой; плитка начинается от угла rect
func draw_tiled(tex: Texture2D, rect: Rect2, tile_scale: float) -> void:
	draw_set_transform(rect.position, 0.0, Vector2(tile_scale, tile_scale))
	draw_texture_rect(tex, Rect2(Vector2.ZERO, rect.size / tile_scale), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## рисует текстуру по центру pos, вписывая в квадрат size x size с сохранением пропорций
func draw_fit(tex: Texture2D, pos: Vector2, size: float, mod: Color = Color.WHITE) -> void:
	var ts: Vector2 = tex.get_size()
	var sz: Vector2 = ts * (size / maxf(ts.x, ts.y))
	draw_texture_rect(tex, Rect2(pos - sz * 0.5, sz), false, mod)

func sfx(key: String, pitch: float = 1.0) -> void:
	snd.play(key, pitch)


func buzz(ms: int) -> void:
	snd.buzz(ms)   # на ПК ничего не делает


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		on_back()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		pause_game()


## кнопка «Назад» на телефоне / Esc на ПК
func on_back() -> void:
	match state:
		State.PLAYING:
			pause_game()
		State.PAUSED:
			resume_game()
		State.GAME_OVER:
			if over_shown:
				show_menu(false)
		State.MENU:
			if overlay != null:
				close_overlay()
			else:
				get_tree().quit()


func pause_game() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	state_time = 0.0
	touch_active = false
	snd.music_pause(true)
	sfx("click")
	var p := PauseScreen.new()
	p.resumed.connect(resume_game)
	p.restarted.connect(on_pause_restart)
	p.to_menu.connect(on_pause_menu)
	ui.add_child(p)
	screen = p


func resume_game() -> void:
	if state != State.PAUSED:
		return
	clear_screens()
	state = State.PLAYING
	state_time = 0.0
	touch_active = false
	invuln_t = maxf(invuln_t, 0.6)   # короткая страховка после паузы
	snd.music_pause(false)
	sfx("click")


func on_pause_restart() -> void:
	sfx("click")
	bank_run()
	start_shift()


func on_pause_menu() -> void:
	sfx("click")
	bank_run()
	show_menu(false)


## сохранить рекорд и монеты текущей смены; true = новый рекорд
func bank_run() -> bool:
	var record: bool = SaveData.submit_score(score)
	if run_coins > 0:
		SaveData.add_coins(run_coins)
	run_coins = 0
	return record


# ---------- экраны: меню, настройки, туториал, конец ----------
func clear_screens() -> void:
	if is_instance_valid(screen):
		screen.queue_free()
	screen = null
	close_overlay()


func close_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null


func show_menu(instant: bool = false) -> void:
	clear_screens()
	reset_world()
	state = State.MENU
	state_time = 0.0
	wake_t = -1.0
	snd.menu_audio_start()
	if instant:
		snap_cam_menu()
	else:
		tween_cam(cam_menu_pos(), Vector2.ONE * MENU_ZOOM, 0.6)
	var m := MenuScreen.new()
	m.top_inset = ui_off
	m.coins = SaveData.coins
	m.play_pressed.connect(on_menu_play)
	m.settings_pressed.connect(open_settings)
	m.help_pressed.connect(open_tutorial.bind(false))
	ui.add_child(m)
	screen = m


func on_menu_play() -> void:
	if overlay != null or state != State.MENU:
		return
	sfx("click")
	if SaveData.tutorial_seen:
		begin_game_from_menu()
	else:
		open_tutorial(true)


func begin_game_from_menu() -> void:
	start_shift()
	wake_t = 0.0   # кот просыпается и подпрыгивает
	add_popup("!", Vector2(cat_x, catch_y() - 190.0), UIKit.GOLD)
	tween_cam(cam_game_pos(), Vector2.ONE, 0.8)


func open_settings() -> void:
	if overlay != null:
		return
	sfx("click")
	var s := SettingsScreen.new()
	s.closed.connect(on_settings_closed)
	ui.add_child(s)
	overlay = s


func on_settings_closed() -> void:
	sfx("click")
	close_overlay()


func open_tutorial(first_run: bool) -> void:
	if overlay != null:
		return
	sfx("click")
	var t := TutorialScreen.new()
	t.first_run = first_run
	t.top_inset = ui_off
	t.finished.connect(on_tutorial_finished.bind(first_run))
	ui.add_child(t)
	overlay = t


func on_tutorial_finished(first_run: bool) -> void:
	close_overlay()
	if first_run:
		SaveData.tutorial_seen = true
		SaveData.save()
		begin_game_from_menu()


func show_game_over() -> void:
	over_shown = true
	sfx("over")
	var g := GameOverScreen.new()
	g.data = {
		"score": score,
		"best": SaveData.best_score,
		"new_record": over_record,
		"orders": orders_done,
		"combo": best_combo,
		"coins": over_earned,
		"total": SaveData.coins,
	}
	g.restarted.connect(on_over_restart)
	g.to_menu.connect(on_over_menu)
	ui.add_child(g)
	screen = g


func on_over_restart() -> void:
	sfx("click")
	start_shift()


func on_over_menu() -> void:
	sfx("click")
	show_menu(false)


## чистый мир для меню
func reset_world() -> void:
	items.clear()
	popups.clear()
	barrels.clear()
	tower.clear()
	lane = 1
	cat_x = lane_cx(lane)
	jump_t = -1.0
	jump_buffer = 0.0
	invuln_t = 0.0
	flash_t = 0.0
	red_t = 0.0
	shake_t = 0.0
	new_order()


# ---------- камера ----------
func cam_game_pos() -> Vector2:
	return get_viewport_rect().size * 0.5


func cam_menu_pos() -> Vector2:
	var vp: Vector2 = get_viewport_rect().size
	var y: float = minf(vp.y - MENU_CAM_BOTTOM, vp.y - vp.y / (2.0 * MENU_ZOOM))
	return Vector2(vp.x * 0.5, y)


func snap_cam_menu() -> void:
	if cam_tween != null:
		cam_tween.kill()
	cam.zoom = Vector2.ONE * MENU_ZOOM
	cam.position = cam_menu_pos()


func snap_cam_game() -> void:
	if cam_tween != null:
		cam_tween.kill()
	cam.zoom = Vector2.ONE
	cam.position = cam_game_pos()


func tween_cam(pos: Vector2, zoom_to: Vector2, time: float) -> void:
	if cam_tween != null:
		cam_tween.kill()
	cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	cam_tween.tween_property(cam, "zoom", zoom_to, time)
	cam_tween.tween_property(cam, "position", pos, time)


func update_safe_area() -> void:
	ui_off = 0.0
	if DEBUG_INSET > 0.0:
		ui_off = DEBUG_INSET
		return
	if not OS.has_feature("mobile"):
		return
	var win: Vector2i = DisplayServer.window_get_size()
	var vp: Vector2 = get_viewport_rect().size
	if win.x <= 0:
		return
	var px_scale: float = float(win.x) / vp.x
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	ui_off = clampf(float(safe.position.y) / px_scale, 0.0, 160.0)


func top_h() -> float:
	return TOP_UI_H + ui_off


## инпут
func pause_rect() -> Rect2:
	var vp: Vector2 = get_viewport_rect().size
	return Rect2(vp.x - 40.0 - UIKit.ICON_BTN, 8.0 + ui_off, UIKit.ICON_BTN, UIKit.ICON_BTN)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			if state != State.MENU or overlay != null:
				on_back()
			return
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			if state == State.MENU and overlay == null:
				on_menu_play()
				return
			if state == State.GAME_OVER and over_shown:
				start_shift()
				return
	if state != State.PLAYING:
		return

	if event is InputEventScreenTouch:
		if event.pressed and pause_rect().grow(24.0).has_point(event.position):
			pause_game()
			return
		touch_active = event.pressed
		touch_done = false
		if event.pressed:
			touch_start = event.position
	elif event is InputEventScreenDrag and touch_active and not touch_done:
		var d: Vector2 = event.position - touch_start
		if d.length() >= SWIPE_MIN:
			touch_done = true
			if absf(d.x) > absf(d.y):
				move_lane(1 if d.x > 0.0 else -1)
			elif d.y < 0.0:
				try_jump()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				move_lane(-1)
			KEY_RIGHT, KEY_D:
				move_lane(1)
			KEY_UP, KEY_W:
				try_jump()
			KEY_SPACE:
				try_jump()


func move_lane(dir: int) -> void:
	lane = clampi(lane + dir, 0, 2)


func try_jump() -> void:
	if jump_t < 0.0:
		jump_t = 0.0
		sfx("jump")
	else:
		jump_buffer = JUMP_BUFFER


## состояния игры
func start_shift() -> void:
	clear_screens()
	snd.game_audio_start()
	lives = START_LIVES
	run_coins = 0
	over_shown = false
	wake_t = -1.0
	score = 0
	orders_done = 0
	combo = 0
	best_combo = 0
	items.clear()
	popups.clear()
	barrels.clear()
	lane = 1
	cat_x = lane_cx(lane)
	jump_t = -1.0
	jump_buffer = 0.0
	invuln_t = 0.0
	spawn_timer = 0.6
	barrel_timer = 2.5
	last_lane = -1
	lane_repeat = 0
	last_kind = -1
	kind_repeat = 0
	new_order()
	state = State.PLAYING
	state_time = 0.0


func end_game() -> void:
	state = State.GAME_OVER
	state_time = 0.0
	over_shown = false
	over_earned = run_coins
	over_record = bank_run()
	snd.music_fade_out()


func new_order() -> void:
	var n: int = mini(2 + int(orders_done * 0.5), MAX_RECIPE)
	var kinds: Array = range(pool_size())
	kinds.shuffle()
	recipe = kinds.slice(0, n)
	recipe_idx = 0
	patience_max = PATIENCE_BASE + PATIENCE_PER_ITEM * n
	patience = patience_max
	order_perfect = true
	tower.clear()
	since_needed = 1.0
	client_t = 0.0
	if client_texs.size() > 1:
		client_idx = (client_idx + 1 + randi() % (client_texs.size() - 1)) % client_texs.size()


## обновления
func _process(delta: float) -> void:
	state_time += delta
	update_fx(delta)
	if state == State.PLAYING:
		update_game(delta)
	elif state == State.GAME_OVER and not over_shown and state_time > 0.8:
		show_game_over()
	queue_redraw()


func update_fx(delta: float) -> void:
	cat_x = lerpf(cat_x, lane_cx(lane), 1.0 - exp(-25.0 * delta))
	client_t += delta
	if wake_t >= 0.0 and wake_t < WAKE_TIME:
		wake_t += delta

	if jump_t >= 0.0:
		jump_t += delta
		if jump_t >= JUMP_TIME:
			jump_t = -1.0
			if jump_buffer > 0.0:
				jump_t = 0.0
				jump_buffer = 0.0
				sfx("jump")
	jump_buffer = maxf(jump_buffer - delta, 0.0)

	flash_t = maxf(flash_t - delta, 0.0)
	red_t = maxf(red_t - delta, 0.0)
	shake_t = maxf(shake_t - delta, 0.0)
	invuln_t = maxf(invuln_t - delta, 0.0)
	position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 22.0 * clampf(shake_t / 0.3, 0.0, 1.0)

	var k: int = popups.size() - 1
	while k >= 0:
		var p: FloatText = popups[k]
		p.t += delta
		p.pos.y -= 140.0 * delta
		if p.t > 0.9:
			popups.remove_at(k)
		k -= 1

func pool_size() -> int:
	return mini(START_KINDS + floori(float(orders_done) / UNLOCK_EVERY), KINDS_TOTAL)


func other_kind(k: int, avoid_a: int = -1, avoid_b: int = -1) -> int:
	var r: int = k
	for _i in 8:
		r = (k + 1 + randi() % (pool_size() - 1)) % pool_size()
		if r != avoid_a and r != avoid_b:
			break
	return r
	
	

func fall_speed() -> float:
	return minf(FALL_SPEED_START + FALL_SPEED_STEP * orders_done, FALL_SPEED_MAX)


func barrel_speed() -> float:
	return minf(BARREL_SPEED_START + BARREL_SPEED_STEP * orders_done, BARREL_SPEED_MAX)


func update_game(delta: float) -> void:
	patience -= delta
	since_needed += delta

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = maxf(SPAWN_START - SPAWN_STEP * orders_done, SPAWN_MIN)
		spawn_item()

	if orders_done >= BARREL_FROM_ORDER:
		barrel_timer -= delta
		if barrel_timer <= 0.0:
			try_spawn_barrel()

	var speed: float = fall_speed()
	var cy: float = catch_y()
	var fy: float = floor_y()
	var i: int = items.size() - 1
	while i >= 0:
		var cur: Item = items[i]
		cur.y += speed * delta
		var gone: bool = false
		if not cur.passed and cur.y >= cy:
			cur.passed = true
			if cur.lane == lane and jump_t < 0.0:
				on_catch(cur.kind)
				gone = true
		if cur.y > fy + ITEM_R:
			gone = true
		if gone:
			items.remove_at(i)
		i -= 1

	update_barrels(delta)
	if state != State.PLAYING:
		return

	if patience <= 0.0:
		client_left()


func update_barrels(delta: float) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var bs: float = barrel_speed()
	var lift: float = jump_offset()
	var i: int = barrels.size() - 1
	while i >= 0:
		var b: Barrel = barrels[i]
		if b.warn > 0.0:
			b.warn -= delta
		else:
			b.x += b.dir * bs * delta
			var close: bool = absf(b.x - cat_x) < CAT_W * 0.5 + BARREL_R * 0.8
			if not b.hit and invuln_t <= 0.0 and close and lift < BARREL_R * 1.6:
				b.hit = true
				hit_by_barrel()
				if state != State.PLAYING:
					return
			if b.x < -BARREL_R * 3.0 or b.x > vp.x + BARREL_R * 3.0:
				barrels.remove_at(i)
		i -= 1


func hit_by_barrel() -> void:
	lives -= 1
	invuln_t = INVULN_TIME
	shake_t = 0.45
	red_t = 0.35
	flash_t = 0.25
	flash_col = Color("e5484d")
	add_popup("-1 LIFE", Vector2(cat_x, catch_y() - 100.0), Color("e5484d"))
	buzz(140)
	if lives <= 0:
		end_game()
	else:
		sfx("hit")


func barrel_time_at(b: Barrel, x: float, bs: float) -> float:
	var dist: float = (x - b.x) * b.dir
	if dist < -BARREL_R:
		return -1.0
	return maxf(b.warn, 0.0) + maxf(dist, 0.0) / bs


func conflicts(b: Barrel, lane_i: int, arrive_t: float, bs: float) -> bool:
	var t: float = barrel_time_at(b, lane_cx(lane_i), bs)
	return t >= 0.0 and absf(t - arrive_t) < FAIR_WINDOW


func try_spawn_barrel() -> void:
	if barrels.size() >= 2:
		barrel_timer = 0.5
		return
	var vp: Vector2 = get_viewport_rect().size
	var b := Barrel.new()
	b.dir = 1 if randf() < 0.5 else -1
	b.x = -BARREL_R * 2.0 if b.dir > 0 else vp.x + BARREL_R * 2.0
	b.warn = WARN_TIME

	var need: int = recipe[recipe_idx]
	var fs: float = fall_speed()
	var bs: float = barrel_speed()
	var cy: float = catch_y()
	for it in items:
		if it.passed or it.kind != need:
			continue
		var arrive: float = (cy - it.y) / fs
		if conflicts(b, it.lane, arrive, bs):
			barrel_timer = 0.25
			return

	barrels.append(b)
	sfx("warn")
	barrel_timer = maxf(BARREL_EVERY_START - BARREL_EVERY_STEP * orders_done, BARREL_EVERY_MIN)

## какой по счёту ингредиент рецепта ещё не "в полёте" (смотрим по порядку прилёта)
func next_uncovered() -> int:
	var flying: Array[Item] = []
	for it in items:
		if not it.passed:
			flying.append(it)
	flying.sort_custom(func(a: Item, b: Item) -> bool: return a.y > b.y)
	var j: int = recipe_idx
	for it in flying:
		if j < recipe.size() and it.kind == recipe[j]:
			j += 1
	return j
	
	
func spawn_item() -> void:
	var j: int = next_uncovered()
	var want: int = -1
	if j < recipe.size() and j - recipe_idx < 2:
		want = recipe[j]

	var l: int = randi() % 3
	if l == last_lane and lane_repeat >= 2:
		l = (l + 1 + randi() % 2) % 3
	if l == last_lane:
		lane_repeat += 1
	else:
		last_lane = l
		lane_repeat = 1

	var k: int
	if want >= 0 and (since_needed >= NEEDED_GUARANTEE or randf() < NEEDED_CHANCE):
		k = want
	else:
		k = randi() % 5
	if k == last_kind and kind_repeat >= 2:
		k = (k + 1 + randi() % 4) % 5

	if k == recipe[recipe_idx] or k == want:
		var arrive: float = (catch_y() - (top_h() - ITEM_R * 2.0)) / fall_speed()
		for b in barrels:
			if conflicts(b, l, arrive, barrel_speed()):
				k = (k + 1 + randi() % 4) % 5
				break

	if k == last_kind:
		kind_repeat += 1
	else:
		last_kind = k
		kind_repeat = 1
	if want >= 0 and k == want:
		since_needed = 0.0

	var it := Item.new()
	it.lane = l
	it.kind = k
	it.y = top_h() - ITEM_R * 2.0
	items.append(it)


## правила
func on_catch(kind: int) -> void:
	if kind == recipe[recipe_idx]:
		sfx("catch", 1.0 + 0.12 * tower.size())
		tower.append(kind)
		recipe_idx += 1
		flash_t = 0.12
		flash_col = Color.WHITE
		add_popup("OK", Vector2(cat_x, catch_y() - 60.0 - tower.size() * TOWER_STEP), Color("5bb98c"))
		if recipe_idx >= recipe.size():
			complete_order()
	else:
		patience -= WRONG_PENALTY
		order_perfect = false
		combo = 0
		flash_t = 0.25
		flash_col = Color("e5484d")
		red_t = 0.25
		shake_t = 0.3
		sfx("wrong")
		buzz(60)
		add_popup("WRONG!  -%ds" % int(WRONG_PENALTY), Vector2(cat_x, catch_y() - 100.0), Color("e5484d"))


func complete_order() -> void:
	var ratio: float = patience / patience_max
	var tip: int = int(ratio * 60.0)
	combo = combo + 1 if order_perfect else 0
	best_combo = maxi(best_combo, combo)
	var mult: int = maxi(1, mini(combo, 5))
	var gained: int = (recipe.size() * 40 + tip) * mult
	score += gained
	var coin_gain: int = recipe.size() + int(tip / 20.0) + (1 if order_perfect else 0)
	run_coins += coin_gain
	var pool_before: int = pool_size()
	orders_done += 1
	if pool_size() > pool_before:
		add_popup("NEW INGREDIENT!", Vector2(get_viewport_rect().size.x * 0.5, 690.0 + ui_off), Color("8fd3f4"))
	sfx("done")
	var msg: String = "+%d" % gained
	if mult > 1:
		msg += "  x%d" % mult
	add_popup(msg, Vector2(get_viewport_rect().size.x * 0.5, 470.0 + ui_off), Color("f2b705"))
	add_popup("+%d coins" % coin_gain, Vector2(get_viewport_rect().size.x * 0.5, 540.0 + ui_off), UIKit.GOLD)
	if order_perfect and combo > 0 and combo % HEAL_EVERY_COMBO == 0 and lives < START_LIVES:
		lives += 1
		sfx("heal", 1.0)
		add_popup("+1 LIFE", Vector2(get_viewport_rect().size.x * 0.5, 620.0 + ui_off), Color("5bb98c"))
	new_order()


func client_left() -> void:
	lives -= 1
	combo = 0
	shake_t = 0.45
	red_t = 0.35
	buzz(80)
	add_popup("TOO SLOW!", Vector2(get_viewport_rect().size.x * 0.5, 470.0 + ui_off), Color("e5484d"))
	if lives <= 0:
		end_game()
	else:
		sfx("wrong")
		new_order()


func add_popup(text: String, pos: Vector2, color: Color) -> void:
	var p := FloatText.new()
	p.text = text
	p.pos = pos
	p.color = color
	popups.append(p)


## разметка
func lane_cx(i: int) -> float:
	return get_viewport_rect().size.x * (2.0 * i + 1.0) / 6.0


func floor_y() -> float:
	return get_viewport_rect().size.y - FLOOR_H


func catch_y() -> float:
	return floor_y() - CAT_H


func jump_offset() -> float:
	if jump_t < 0.0:
		return 0.0
	var p: float = jump_t / JUMP_TIME
	return 4.0 * p * (1.0 - p) * JUMP_HEIGHT


func pulse() -> float:
	return 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)


func ease_out_back(x: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


## отрисовка
func _draw() -> void:
	draw_world()
	if state != State.MENU:
		draw_order()
		draw_hud()
	if red_t > 0.0:
		var vp: Vector2 = get_viewport_rect().size
		draw_rect(Rect2(-60, -60, vp.x + 120, vp.y + 120), Color(1.0, 0.1, 0.1, 0.35 * clampf(red_t / 0.25, 0.0, 1.0)))
	for p in popups:
		var a: float = clampf(1.0 - p.t / 0.9, 0.0, 1.0)
		text_at(p.text, Vector2(p.pos.x - 300.0, p.pos.y), 64, Color(p.color.r, p.color.g, p.color.b, a), HORIZONTAL_ALIGNMENT_CENTER, 600.0, true)


func draw_world() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var fy: float = floor_y()
	var cy: float = catch_y()
	var lift: float = jump_offset()
	var lane_w: float = vp.x / 3.0

	if bg_tex != null:
		draw_tiled(bg_tex, Rect2(-60, -60, vp.x + 120, vp.y + 120), BG_TILE_SCALE)
	else:
		draw_rect(Rect2(-60, -60, vp.x + 120, vp.y + 120), col_bg)
	for i in 3:
		if i % 2 == 0:
			draw_rect(Rect2(i * lane_w, top_h(), lane_w, fy - top_h()), col_lane)
	if floor_tex != null:
		draw_tiled(floor_tex, Rect2(-60, fy, vp.x + 120, vp.y - fy + 60), FLOOR_TILE_SCALE)
	else:
		draw_rect(Rect2(-60, fy, vp.x + 120, vp.y - fy + 60), col_floor)
	if SHOW_CATCH_LINE:
		draw_dashed_line(Vector2(0, cy), Vector2(vp.x, cy), col_line, 4.0, 16.0)

	draw_barrels()

	var wake_lift: float = 0.0
	if wake_t >= 0.0 and wake_t < WAKE_TIME:
		wake_lift = 90.0 * sin(PI * wake_t / WAKE_TIME)
	var shadow_k: float = 1.0 - (lift + wake_lift) / (JUMP_HEIGHT * 1.6)
	draw_set_transform(Vector2(cat_x, fy), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, CAT_W * 0.55 * shadow_k, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var top: float = cy - lift - wake_lift
	var left_x: float = cat_x - CAT_W * 0.5
	var cat_c: Color = col_cat.lerp(flash_col, clampf(flash_t / 0.12, 0.0, 1.0) * 0.6)
	if invuln_t > 0.0 and int(invuln_t * 14.0) % 2 == 0:
		cat_c.a = 0.35
	draw_cat(left_x, top, cat_c)
	if state == State.MENU:
		draw_sleep_z(top)

	for i in tower.size():
		draw_ingredient(tower[i], Vector2(cat_x, top - TOWER_LIFT - (i + 0.5) * TOWER_STEP), ITEM_R * 0.5)
	if state == State.PLAYING and recipe_idx < recipe.size():
		ing_a = 0.35
		draw_ingredient(recipe[recipe_idx], Vector2(cat_x, top - TOWER_LIFT - (tower.size() + 0.5) * TOWER_STEP), ITEM_R * 0.5)
		ing_a = 1.0

	for it in items:
		draw_ingredient(it.kind, Vector2(lane_cx(it.lane), it.y), ITEM_R)


func draw_cat(_left_x: float, top: float, cat_c: Color) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	var sleeping: bool = state == State.MENU
	# моргание: два несовпадающих периода, чтобы не было как у метронома
	var blinking: bool = fposmod(t, 4.3) > 4.18 or fposmod(t, 6.7) > 6.58
	# idle-анимация: дыхание и лёгкое покачивание (во сне медленнее)
	var br: float = sin(t * (1.4 if sleeping else 2.6))
	var sx: float = 1.0 - 0.018 * br
	var sy: float = 1.0 + 0.03 * br
	var rot: float = 0.02 * sin(t * (0.8 if sleeping else 1.7))
	# растяжение в прыжке и при пробуждении
	var stretch: float = 0.0
	if jump_t >= 0.0:
		stretch = sin(PI * jump_t / JUMP_TIME)
	elif wake_t >= 0.0 and wake_t < WAKE_TIME:
		stretch = sin(PI * wake_t / WAKE_TIME)
	sx -= 0.07 * stretch
	sy += 0.12 * stretch

	var feet := Vector2(cat_x, top + CAT_H + CAT_FEET_SINK)
	draw_set_transform(feet, rot, Vector2(sx, sy))
	if cat_tex != null:
		# размер берём от открытого спрайта: закрытый рисуется в тот же прямоугольник, кот не "дёргается"
		var h: float = CAT_H + CAT_SPRITE_EXTRA
		var ts: Vector2 = cat_tex.get_size()
		var sz: Vector2 = ts * (h / ts.y)
		var tex: Texture2D = cat_tex
		if (sleeping or blinking) and cat_closed_tex != null:
			tex = cat_closed_tex
		var tint := Color.WHITE
		if flash_t > 0.0 and flash_col != Color.WHITE:
			tint = Color(1.0, 0.5, 0.5)
		elif sleeping and cat_closed_tex == null:
			tint = Color(0.78, 0.78, 0.9)   # нет спрайта со сном: просто затемняем
		tint.a = cat_c.a
		draw_texture_rect(tex, Rect2(Vector2(-sz.x * 0.5, -sz.y), sz), false, tint)
	else:
		var c: Color = cat_c
		if sleeping:
			c = c.darkened(0.15)
		var hw: float = CAT_W * 0.5
		draw_rect(Rect2(-hw, -CAT_H, CAT_W, CAT_H), c)
		draw_colored_polygon(PackedVector2Array([Vector2(-hw + 8, -CAT_H), Vector2(-hw + 8, -CAT_H - 36), Vector2(-hw + 48, -CAT_H)]), c)
		draw_colored_polygon(PackedVector2Array([Vector2(hw - 8, -CAT_H), Vector2(hw - 8, -CAT_H - 36), Vector2(hw - 48, -CAT_H)]), c)
		if sleeping or blinking:
			draw_line(Vector2(-46, -CAT_H + 60), Vector2(-18, -CAT_H + 60), col_dark, 6.0)
			draw_line(Vector2(18, -CAT_H + 60), Vector2(46, -CAT_H + 60), col_dark, 6.0)
		else:
			draw_circle(Vector2(-32, -CAT_H + 60), 10, col_dark)
			draw_circle(Vector2(32, -CAT_H + 60), 10, col_dark)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## «Z-z-z» над спящим котом в меню
func draw_sleep_z(top: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	for i in 3:
		var ph: float = fposmod(t * 0.45 + i / 3.0, 1.0)
		var pos := Vector2(cat_x + 50.0 + ph * 70.0 + sin(ph * 6.0) * 10.0, top - 20.0 - ph * 150.0)
		text_at("Z", pos, 40 + int(ph * 36.0), Color(0.0, 0.0, 0.0, 0.392), HORIZONTAL_ALIGNMENT_LEFT, -1.0, false)


func draw_barrels() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var fy: float = floor_y()
	var red := Color(0.9, 0.28, 0.3)
	for b in barrels:
		if b.warn > 0.0:
			var ex: float = 80.0 if b.dir > 0 else vp.x - 80.0
			var c := Vector2(ex, fy - 90.0)
			var a: float = 0.55 + 0.45 * pulse()
			var tri := PackedVector2Array([c + Vector2(0, -56), c + Vector2(54, 36), c + Vector2(-54, 36), c + Vector2(0, -56)])
			draw_colored_polygon(tri, Color(0.94, 0.63, 0.12, a))
			draw_polyline(tri, col_dark, 6.0)
			text_at("!", Vector2(c.x - 100.0, c.y + 28.0), 64, col_dark, HORIZONTAL_ALIGNMENT_CENTER, 200.0, false)
		elif barrel_tex != null:
			# спрайт бочки: катится и вращается вокруг центра картинки
			draw_set_transform(Vector2(b.x, fy - BARREL_R), b.x / BARREL_R, Vector2.ONE)
			draw_fit(barrel_tex, Vector2.ZERO, BARREL_R * 2.0 * BARREL_SPRITE_K, Color(1, 1, 1, 0.35 if b.hit else 1.0))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			var pos := Vector2(b.x, fy - BARREL_R)
			var al: float = 0.35 if b.hit else 1.0
			var rc := Color(red.r, red.g, red.b, al)
			draw_circle(pos, BARREL_R, Color(0.23, 0.14, 0.09, al))
			draw_arc(pos, BARREL_R - 3.0, 0.0, TAU, 40, rc, 6.0)
			draw_set_transform(pos, b.x / BARREL_R, Vector2.ONE)
			draw_line(Vector2(-BARREL_R * 0.7, 0.0), Vector2(BARREL_R * 0.7, 0.0), rc, 5.0)
			draw_line(Vector2(0.0, -BARREL_R * 0.7), Vector2(0.0, BARREL_R * 0.7), rc, 5.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_client(o: float, ratio: float) -> void:
	var a: float = clampf(client_t / 0.45, 0.0, 1.0)
	var off: float = -280.0 * (1.0 - ease_out_back(a))
	var bob: float = sin(Time.get_ticks_msec() * 0.004) * 4.0
	var jitter: float = 0.0
	if ratio < 0.25:
		jitter = sin(Time.get_ticks_msec() * 0.09) * 5.0
	var c := Vector2(130.0 + off + jitter, 250.0 + o + bob)
	var col: Color = Color("b8b8b8").lerp(Color("e5484d"), clampf(inverse_lerp(0.4, 0.1, ratio), 0.0, 1.0))
	if client_texs.size() > 0:
		var tint: Color = Color.WHITE.lerp(Color(1.0, 0.45, 0.45), clampf(inverse_lerp(0.4, 0.1, ratio), 0.0, 1.0))
		draw_fit(client_texs[client_idx], c, CLIENT_SPRITE, tint)
		return
	draw_circle(c, 70.0, col)
	draw_circle(c + Vector2(-24, -14), 8.0, col_dark)
	draw_circle(c + Vector2(24, -14), 8.0, col_dark)
	if ratio > 0.55:
		draw_arc(c + Vector2(0, 6), 26.0, 0.25, PI - 0.25, 14, col_dark, 6.0)
	elif ratio > 0.25:
		draw_line(c + Vector2(-22, 26), c + Vector2(22, 26), col_dark, 6.0)
	else:
		draw_arc(c + Vector2(0, 52), 26.0, PI + 0.35, TAU - 0.35, 14, col_dark, 6.0)


func draw_order() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var o: float = ui_off
	var ratio: float = clampf(patience / patience_max, 0.0, 1.0)
	draw_rect(Rect2(-60, 120 + o, vp.x + 120, TOP_UI_H - 120), col_strip)

	var bubble := Rect2(240, 140 + o, vp.x - 280, 220)
	draw_colored_polygon(PackedVector2Array([Vector2(236, 206 + o), Vector2(236, 276 + o), Vector2(184, 244 + o)]), col_dark)
	draw_rect(bubble, Color.WHITE)
	draw_rect(bubble, col_dark, false, 6.0)
	draw_colored_polygon(PackedVector2Array([Vector2(246, 218 + o), Vector2(246, 264 + o), Vector2(206, 244 + o)]), Color.WHITE)

	draw_client(o, ratio)

	var n: int = recipe.size()
	for i in n:
		var pos := Vector2(bubble.position.x + bubble.size.x * (i + 1.0) / (n + 1.0), 225.0 + o)
		if i < recipe_idx:
			ing_a = 0.3
			draw_ingredient(recipe[i], pos, 44.0)
		elif i == recipe_idx:
			draw_circle(pos, 76.0, Color(0.94, 0.63, 0.12, 0.35))
			ing_a = 1.0
			draw_ingredient(recipe[i], pos, 62.0)
		else:
			ing_a = 1.0
			draw_ingredient(recipe[i], pos, 44.0)
	ing_a = 1.0

	var bar := Rect2(bubble.position.x + 24.0, 322.0 + o, bubble.size.x - 48.0, 22.0)
	draw_rect(bar, Color("e6dccb"))
	var pc: Color = Color("5bb98c").lerp(Color("f2b705"), clampf(inverse_lerp(0.6, 0.35, ratio), 0.0, 1.0))
	pc = pc.lerp(Color("e5484d"), clampf(inverse_lerp(0.3, 0.1, ratio), 0.0, 1.0))
	if ratio < 0.25:
		pc = pc.lerp(Color.WHITE, 0.45 * pulse())
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), pc)


func draw_hud() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var o: float = ui_off
	draw_rect(Rect2(-60, -60, vp.x + 120, 180 + o), col_dark)
	for h in 3:
		var hp := Vector2(70 + h * 60, 60 + o)
		if heart_tex != null:
			if h < lives:
				draw_fit(heart_tex, hp, HEART_SIZE)
			elif heart_empty_tex != null:
				draw_fit(heart_empty_tex, hp, HEART_SIZE)
			else:
				draw_fit(heart_tex, hp, HEART_SIZE, Color(0.25, 0.25, 0.25, 0.55))
		else:
			var hc: Color = col_heart if h < lives else Color(1, 1, 1, 0.15)
			draw_circle(hp, 22, hc)
	text_at(str(score), Vector2(0, 88 + o), 72, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vp.x, false)
	if combo >= 2:
		text_at("x%d" % mini(combo, 5), Vector2(0, 88 + o), 64, Color("f2b705"), HORIZONTAL_ALIGNMENT_RIGHT, vp.x - 180.0, false)
	# кнопка паузы (касание обрабатывается в _input)
	var pr: Rect2 = pause_rect()
	draw_rect(pr, Color(1, 1, 1, 0.12))
	if pause_icon_tex != null:
		draw_fit(pause_icon_tex, pr.get_center(), pr.size.x - 2.0 * UIKit.ICON_MARGIN)
	else:
		draw_rect(Rect2(pr.position + Vector2(34, 28), Vector2(16, 54)), Color.WHITE)
		draw_rect(Rect2(pr.position + Vector2(60, 28), Vector2(16, 54)), Color.WHITE)


func text_at(s: String, pos: Vector2, size: int, col: Color, align: HorizontalAlignment, width: float, outline: bool) -> void:
	var f: Font = Fonts.main()
	if outline:
		draw_string_outline(f, pos, s, align, width, size, int(size * 0.12), Color(0.0, 0.0, 0.0, col.a * 0.8))
	draw_string(f, pos, s, align, width, size, col)


func ca(c: Color) -> Color:
	return Color(c.r, c.g, c.b, c.a * ing_a)


func draw_ingredient(kind: int, pos: Vector2, r: float) -> void:
	if ing_tex.has(kind):
		draw_fit(ing_tex[kind], pos, r * SPRITE_K, Color(1, 1, 1, ing_a))
		return
	draw_set_transform(pos, 0.0, Vector2.ONE)
	match kind:
		0:  # зерно
			draw_set_transform(pos, 0.0, Vector2(0.72, 1.0))
			draw_circle(Vector2.ZERO, r, ca(Color("6b3f1d")))
			draw_set_transform(pos, 0.0, Vector2.ONE)
			draw_line(Vector2(-r * 0.12, -r * 0.8), Vector2(r * 0.12, r * 0.8), ca(col_dark), r * 0.12)
		1:  # молоко
			draw_rect(Rect2(-r * 0.7, -r * 0.5, r * 1.4, r * 1.5), ca(Color.WHITE))
			draw_rect(Rect2(-r * 0.7, r * 0.1, r * 1.4, r * 0.4), ca(Color("3d7fd6")))
			draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.7, -r * 0.5), Vector2(0.0, -r), Vector2(r * 0.7, -r * 0.5)]), ca(Color("c9d6e3")))
			draw_rect(Rect2(-r * 0.7, -r * 0.5, r * 1.4, r * 1.5), ca(Color("4a5a6a")), false, 4.0)
		2:  # лёд
			draw_set_transform(pos, -0.25, Vector2.ONE)
			draw_rect(Rect2(-r * 0.8, -r * 0.8, r * 1.6, r * 1.6), ca(Color("8fd3f4")))
			draw_rect(Rect2(-r * 0.55, -r * 0.55, r * 0.5, r * 0.5), ca(Color("d9f2fc")))
		3:  # клубника: круглая ягода с зелёной шапкой и семечками
			var red := ca(Color("d62839"))
			draw_circle(Vector2(0.0, -r * 0.1), r * 0.82, red)
			draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.62, r * 0.35), Vector2(r * 0.62, r * 0.35), Vector2(0.0, r)]), red)
			var leaf := ca(Color("3f9b4a"))
			draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.55, -r * 0.62), Vector2(0.0, -r), Vector2(r * 0.55, -r * 0.62), Vector2(0.0, -r * 0.5)]), leaf)
			var seed := ca(Color("f9d977"))
			draw_circle(Vector2(-r * 0.3, -r * 0.05), r * 0.07, seed)
			draw_circle(Vector2(r * 0.3, -r * 0.05), r * 0.07, seed)
			draw_circle(Vector2(0.0, r * 0.25), r * 0.07, seed)
		4:  # сироп
			var gold := ca(Color("f2b705"))
			draw_circle(Vector2(0.0, r * 0.3), r * 0.7, gold)
			draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.62, r * 0.05), Vector2(r * 0.62, r * 0.05), Vector2(0.0, -r)]), gold)
		5:  # шоколад: плитка с делениями
			var choc := ca(Color("4a2814"))
			var lc := ca(Color("7a4a2c"))
			draw_rect(Rect2(-r * 0.62, -r * 0.9, r * 1.24, r * 1.8), choc)
			draw_line(Vector2(0.0, -r * 0.9), Vector2(0.0, r * 0.9), lc, 4.0)
			draw_line(Vector2(-r * 0.62, -r * 0.3), Vector2(r * 0.62, -r * 0.3), lc, 4.0)
			draw_line(Vector2(-r * 0.62, r * 0.3), Vector2(r * 0.62, r * 0.3), lc, 4.0)
		6:  # зефир: розовая капсула
			var pink := ca(Color("f7a8c8"))
			draw_circle(Vector2(-r * 0.45, 0.0), r * 0.6, pink)
			draw_circle(Vector2(r * 0.45, 0.0), r * 0.6, pink)
			draw_rect(Rect2(-r * 0.45, -r * 0.6, r * 0.9, r * 1.2), pink)
			draw_circle(Vector2(-r * 0.45, -r * 0.2), r * 0.18, ca(Color("fde0ec")))
		7:  # корица: оранжевая палочка по диагонали
			draw_set_transform(pos, 0.6, Vector2.ONE)
			draw_rect(Rect2(-r * 0.22, -r, r * 0.44, r * 2.0), ca(Color("c2611f")))
			draw_rect(Rect2(-r * 0.06, -r, r * 0.12, r * 2.0), ca(Color("8a3f12")))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
