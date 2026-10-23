extends Node2D
## управление: a/d - влево/вправо, w/пробел - прыжочек, тоже самое со стрелками
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
const CAT_H := 170.0
const TOWER_STEP := 40.0
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
const CAT_SPRITE_EXTRA := 36.0    # спрайт кота = CAT_H + это (уши)
const CLIENT_SPRITE := 190.0      # размер клиента в облачке
const ING_FILES := {0: "coffee", 1: "milk", 3: "strawberry", 5: "chocolate", 6: "marshmallow"}

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
var best_score: int = 0
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
var sfx_players: Dictionary = {}
var ing_tex: Dictionary = {}
var cat_tex: Texture2D = null
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
	setup_audio()
	update_safe_area()
	get_viewport().size_changed.connect(update_safe_area)
	cat_x = lane_cx(lane)
	new_order()


func load_art() -> void:
	for k in ING_FILES:
		var path: String = "res://art/%s.png" % ING_FILES[k]
		if ResourceLoader.exists(path):
			ing_tex[k] = load(path)
	if ResourceLoader.exists("res://art/cat.png"):
		cat_tex = load("res://art/cat.png") as Texture2D
	for i in range(1, 10):
		var cp: String = "res://art/client%d.png" % i
		if ResourceLoader.exists(cp):
			client_texs.append(load(cp) as Texture2D)


## рисует текстуру по центру pos, вписывая в квадрат size x size с сохранением пропорций
func draw_fit(tex: Texture2D, pos: Vector2, size: float, mod: Color = Color.WHITE) -> void:
	var ts: Vector2 = tex.get_size()
	var sz: Vector2 = ts * (size / maxf(ts.x, ts.y))
	draw_texture_rect(tex, Rect2(pos - sz * 0.5, sz), false, mod)

## звук, в дальнейшем замениться на мп3 или вав или ещё какие-нибудь файлы
func tone_wav(freqs: Array, dur: float, vol: float, sweep: float, noise: float) -> AudioStreamWAV:
	var rate: int = 22050
	var data := PackedByteArray()
	var n: int = int(rate * dur)
	for f in freqs:
		var chunk := PackedByteArray()
		chunk.resize(n * 2)
		var phase: float = 0.0
		for i in n:
			var t: float = float(i) / rate
			var x: float = float(i) / n
			var env: float = minf(1.0, float(i) / (rate * 0.004)) * pow(1.0 - x, 1.5)
			phase += TAU * (float(f) + sweep * t) / rate
			var s: float = sin(phase)
			if noise > 0.0:
				s = lerpf(s, randf() * 2.0 - 1.0, noise)
			var v: int = int(clampf(s * env * vol, -1.0, 1.0) * 32767.0)
			chunk.encode_s16(i * 2, v)
		data.append_array(chunk)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


func setup_audio() -> void:
	var defs: Dictionary = {
		"catch": tone_wav([660.0], 0.12, 0.5, 300.0, 0.0),
		"wrong": tone_wav([170.0], 0.28, 0.6, -120.0, 0.5),
		"done": tone_wav([523.0, 659.0, 784.0, 1047.0], 0.09, 0.5, 0.0, 0.0),
		"heal": tone_wav([660.0, 880.0], 0.1, 0.5, 0.0, 0.0),
		"jump": tone_wav([280.0], 0.15, 0.35, 900.0, 0.0),
		"hit": tone_wav([130.0], 0.35, 0.7, -90.0, 0.65),
		"warn": tone_wav([880.0], 0.13, 0.3, 0.0, 0.0),
		"start": tone_wav([523.0, 659.0, 784.0], 0.1, 0.5, 0.0, 0.0),
		"over": tone_wav([440.0, 370.0, 311.0, 247.0], 0.2, 0.55, -30.0, 0.0),
	}
	for key in defs:
		var p := AudioStreamPlayer.new()
		p.stream = defs[key]
		p.volume_db = -6.0
		add_child(p)
		sfx_players[key] = p


func sfx(key: String, pitch: float = 1.0) -> void:
	var p: AudioStreamPlayer = sfx_players.get(key)
	if p == null:
		return
	p.pitch_scale = pitch
	p.play()


func buzz(ms: int) -> void:
	Input.vibrate_handheld(ms)   # на ПК ничего не делает

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_PAUSED:
		pause_game()


func pause_game() -> void:
	if state == State.PLAYING:
		state = State.PAUSED
		state_time = 0.0
		touch_active = false


## вырез под камеру чтоб иконки не закрывались
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
func _input(event: InputEvent) -> void:
	if state == State.PAUSED:
		var tap_p: bool = event is InputEventScreenTouch and event.pressed
		var key_p: bool = event is InputEventKey and event.pressed and not event.echo
		if (tap_p or key_p) and state_time > 0.3:
			state = State.PLAYING
			state_time = 0.0
		return
	if state != State.PLAYING:
		var tap: bool = event is InputEventScreenTouch and event.pressed
		var key: bool = event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)
		if (tap or key) and state_time > 0.5:
			start_shift()
		return

	if event is InputEventScreenTouch:
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
			KEY_UP, KEY_W, KEY_SPACE:
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
	lives = START_LIVES
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
	sfx("start")


func end_game() -> void:
	state = State.GAME_OVER
	state_time = 0.0
	best_score = maxi(best_score, score)
	sfx("over")


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
	queue_redraw()


func update_fx(delta: float) -> void:
	cat_x = lerpf(cat_x, lane_cx(lane), 1.0 - exp(-25.0 * delta))
	client_t += delta

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
	var pool_before: int = pool_size()
	orders_done += 1
	if pool_size() > pool_before:
		add_popup("NEW INGREDIENT!", Vector2(get_viewport_rect().size.x * 0.5, 650.0 + ui_off), Color("8fd3f4"))
	sfx("done")
	var msg: String = "+%d" % gained
	if mult > 1:
		msg += "  x%d" % mult
	add_popup(msg, Vector2(get_viewport_rect().size.x * 0.5, 470.0 + ui_off), Color("f2b705"))
	if order_perfect and combo > 0 and combo % HEAL_EVERY_COMBO == 0 and lives < START_LIVES:
		lives += 1
		sfx("heal", 1.0)
		add_popup("+1 LIFE", Vector2(get_viewport_rect().size.x * 0.5, 560.0 + ui_off), Color("5bb98c"))
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
	draw_order()
	draw_hud()
	if red_t > 0.0:
		var vp: Vector2 = get_viewport_rect().size
		draw_rect(Rect2(-60, -60, vp.x + 120, vp.y + 120), Color(1.0, 0.1, 0.1, 0.35 * clampf(red_t / 0.25, 0.0, 1.0)))
	for p in popups:
		var a: float = clampf(1.0 - p.t / 0.9, 0.0, 1.0)
		text_at(p.text, Vector2(p.pos.x - 300.0, p.pos.y), 64, Color(p.color.r, p.color.g, p.color.b, a), HORIZONTAL_ALIGNMENT_CENTER, 600.0, true)
	draw_overlay()


func draw_world() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var fy: float = floor_y()
	var cy: float = catch_y()
	var lift: float = jump_offset()
	var lane_w: float = vp.x / 3.0

	draw_rect(Rect2(-60, -60, vp.x + 120, vp.y + 120), col_bg)
	for i in 3:
		if i % 2 == 0:
			draw_rect(Rect2(i * lane_w, top_h(), lane_w, fy - top_h()), col_lane)
	draw_rect(Rect2(-60, fy, vp.x + 120, vp.y - fy + 60), col_floor)
	if SHOW_CATCH_LINE:
		draw_dashed_line(Vector2(0, cy), Vector2(vp.x, cy), col_line, 4.0, 16.0)

	draw_barrels()

	var shadow_k: float = 1.0 - lift / (JUMP_HEIGHT * 1.6)
	draw_set_transform(Vector2(cat_x, fy), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, CAT_W * 0.55 * shadow_k, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var top: float = cy - lift
	var left_x: float = cat_x - CAT_W * 0.5
	var cat_c: Color = col_cat.lerp(flash_col, clampf(flash_t / 0.12, 0.0, 1.0) * 0.6)
	if invuln_t > 0.0 and int(invuln_t * 14.0) % 2 == 0:
		cat_c.a = 0.35
	draw_cat(left_x, top, cat_c)

	for i in tower.size():
		draw_ingredient(tower[i], Vector2(cat_x, top - (i + 0.5) * TOWER_STEP), ITEM_R * 0.5)
	if state == State.PLAYING and recipe_idx < recipe.size():
		ing_a = 0.35
		draw_ingredient(recipe[recipe_idx], Vector2(cat_x, top - (tower.size() + 0.5) * TOWER_STEP), ITEM_R * 0.5)
		ing_a = 1.0

	for it in items:
		draw_ingredient(it.kind, Vector2(lane_cx(it.lane), it.y), ITEM_R)


func draw_cat(left_x: float, top: float, cat_c: Color) -> void:
	if cat_tex != null:
		var h: float = CAT_H + CAT_SPRITE_EXTRA
		var ts: Vector2 = cat_tex.get_size()
		var sz: Vector2 = ts * (h / ts.y)
		var tint := Color.WHITE
		if flash_t > 0.0 and flash_col != Color.WHITE:
			tint = Color(1.0, 0.5, 0.5)
		tint.a = cat_c.a
		var feet := Vector2(cat_x, top + CAT_H)
		draw_texture_rect(cat_tex, Rect2(feet - Vector2(sz.x * 0.5, sz.y), sz), false, tint)
		return
	draw_rect(Rect2(left_x, top, CAT_W, CAT_H), cat_c)
	draw_colored_polygon(PackedVector2Array([Vector2(left_x + 8, top), Vector2(left_x + 8, top - 36), Vector2(left_x + 48, top)]), cat_c)
	draw_colored_polygon(PackedVector2Array([Vector2(left_x + CAT_W - 8, top), Vector2(left_x + CAT_W - 8, top - 36), Vector2(left_x + CAT_W - 48, top)]), cat_c)
	draw_circle(Vector2(cat_x - 32, top + 60), 10, col_dark)
	draw_circle(Vector2(cat_x + 32, top + 60), 10, col_dark)


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
		var hc: Color = col_heart if h < lives else Color(1, 1, 1, 0.15)
		draw_circle(Vector2(70 + h * 60, 60 + o), 22, hc)
	text_at(str(score), Vector2(0, 88 + o), 72, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vp.x, false)
	if combo >= 2:
		text_at("x%d" % mini(combo, 5), Vector2(0, 88 + o), 64, Color("f2b705"), HORIZONTAL_ALIGNMENT_RIGHT, vp.x - 40.0, false)


func draw_overlay() -> void:
	if state == State.PLAYING:
		return
	var vp: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(-60, -60, vp.x + 120, vp.y + 120), Color(0, 0, 0, 0.6))
	var blink := Color(1, 1, 1, 0.5 + 0.5 * pulse())

	if state == State.MENU:
		text_c("NEKOFE", 760, 150, Color.WHITE, true)
		text_c("Catch the ingredients in order", 870, 46, Color("f2e6d0"), true)
		text_c("Swipe left / right to move", 940, 40, Color("f2e6d0"), true)
		text_c("Swipe up to jump over barrels", 1005, 40, Color("f2e6d0"), true)
		if state_time > 0.5:
			text_c("Tap to start", 1150, 64, blink, true)
	elif state == State.PAUSED:
		text_c("PAUSED", 900, 120, Color.WHITE, true)
		text_c("Tap to continue", 1040, 56, blink, true)
	else:
		draw_rect(Rect2(110, 560, vp.x - 220, 780), Color("fffaf0"))
		draw_rect(Rect2(110, 560, vp.x - 220, 780), col_dark, false, 8.0)
		text_c("YOU'RE FIRED!", 690, 92, Color("e5484d"), false)
		text_c("Score  %d" % score, 810, 68, col_dark, false)
		text_c("Best  %d" % best_score, 890, 52, col_dark, false)
		text_c("Orders  %d" % orders_done, 965, 52, col_dark, false)
		text_c("Best combo  x%d" % best_combo, 1040, 52, col_dark, false)
		if state_time > 0.5:
			text_c("Tap for a new shift", 1230, 52, Color(0.17, 0.11, 0.08, 0.5 + 0.5 * pulse()), false)


func text_at(s: String, pos: Vector2, size: int, col: Color, align: HorizontalAlignment, width: float, outline: bool) -> void:
	var f: Font = ThemeDB.fallback_font
	if outline:
		draw_string_outline(f, pos, s, align, width, size, int(size * 0.12), Color(0.0, 0.0, 0.0, col.a * 0.8))
	draw_string(f, pos, s, align, width, size, col)


func text_c(s: String, y: float, size: int, col: Color, outline: bool) -> void:
	text_at(s, Vector2(0, y), size, col, HORIZONTAL_ALIGNMENT_CENTER, get_viewport_rect().size.x, outline)


## 5 ингредиентов: у каждого свой цвет И своя форма
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
