class_name Hud
extends Control

const REFERENCE_HEIGHT := 720.0
const OUTLINE := 10
const SHADOW := Vector2(4.0, 4.0)
const TEXT_COLOR := Color(0.96, 0.96, 0.96)
const LAP_TIME_COLOR := Color(0.95, 0.12, 0.1)
const GOLD := Color(1.0, 0.82, 0.28)
const ICON_FLAG := preload("res://icons/flag.png")
const ICON_MEDAL := preload("res://icons/medal1.png")
const ICON_STAR := preload("res://icons/star.png")
const ICON_TROPHY := preload("res://icons/trophy.png")
const SPEED_MAX := 160.0
const SPEED_STEP := 20.0
const DIAL_RADIUS := 92.0
const SPEED_LABEL_STEP := 40.0
const DIAL_START := PI * 5.0 / 6.0
const DIAL_SWEEP := PI * 4.0 / 3.0
const MAP_SIZE := 230.0
const MAP_MARGIN := 14.0
const SPEED_RATE := 20.0
const ICON_SCALE := 2.5
const SCORE_IN := 0.18
const SCORE_HOLD := 0.28
const SCORE_BUMP := 0.2
const SCORE_TOTAL := SCORE_IN + SCORE_HOLD + SCORE_BUMP

var player: Car
var race: Race
var battle: Battle
var font: Font
var map_points := PackedVector2Array()
var map_bounds := Rect2()
var speed := 0.0
var score_seen := 0
var score_anim := 0.0
var count_layer: CountdownLayer
var count_clock := -1.0
var finish_shown := false
var finish_title := 0.0
var finish_place := 0.0
var finish_mark := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = HudTheme.font()
	count_layer = CountdownLayer.new()
	count_layer.hud = self
	count_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	count_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(count_layer)
	if race:
		for i in race.track.nodes.size():
			var p := race.track.node_position(i)
			map_points.append(Vector2(p.x, p.z))
		map_bounds = Rect2(map_points[0], Vector2.ZERO)
		for p in map_points:
			map_bounds = map_bounds.expand(p)


func _process(delta: float) -> void:
	speed = lerpf(speed, player.speed_kmh(), 1.0 - exp(-SPEED_RATE * delta))
	if battle and battle.score_serial != score_seen:
		score_seen = battle.score_serial
		score_anim = 0.0
	if battle and battle.score_serial > 0 and score_anim < SCORE_TOTAL:
		score_anim += delta
	advance_countdown(delta)
	watch_finish()
	count_layer.queue_redraw()
	queue_redraw()


func _draw() -> void:
	var s := size.y / REFERENCE_HEIGHT
	if battle:
		draw_battle(s)
		draw_map(-1, s)
		return
	if Session.time_trial and Session.trial_models.size() > 1 and not Net.in_match:
		var who := "P%d" % (Session.trial_turn + 1)
		var who_px := 64
		var who_width := font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, int(who_px * s)).x
		outlined(Vector2((size.x - who_width) / 2.0, 72.0 * s), who, who_px, s, player.color)
	draw_speedometer(Vector2(DIAL_RADIUS + 34.0, REFERENCE_HEIGHT - DIAL_RADIUS - 30.0) * s, s)
	if not race:
		return
	var me := race.cars.find(player)
	draw_lap_and_place(me, s)
	draw_item(s)
	draw_times(me, s)
	draw_map(me, s)
	if race.finish_time[me] >= 0.0:
		draw_finish(me, s)


func watch_finish() -> void:
	if finish_shown or battle or not race:
		return
	var me := race.cars.find(player)
	if race.finish_time[me] < 0.0:
		return
	finish_shown = true
	var show_place := not Session.time_trial and race.cars.size() > 1
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "finish_title", 1.0, 0.46).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if show_place:
		tween.tween_property(self, "finish_place", 1.0, 0.46).set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		finish_place = 1.0
	if race.new_best:
		var delay := 0.24 if show_place else 0.12
		tween.tween_property(self, "finish_mark", 1.0, 0.46).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		finish_mark = 1.0


func advance_countdown(delta: float) -> void:
	if not race:
		return
	if count_clock < 0.0:
		if race.countdown != 1:
			return
		count_clock = 0.0
	if count_clock < CountdownLayer.SEQUENCE:
		count_clock += delta


class CountdownLayer extends Control:
	var hud: Hud

	const BEAT := 0.6
	const LEAVE := 0.35
	const SEQUENCE := BEAT * 4.0 + LEAVE
	const WORDS: Array[String] = ["3", "2", "1", "GO!"]
	const REST_SIZE := 168.0
	const PEAK := 1.42
	# FUN_0003574c bobs the bumper-car sign below the centre of the 240-line
	# screen with the sine table at 0x14e60, one cycle every 16 frames.
	const BUMPER_BOB: Array[int] = [0, 1, 4, 9, 16, 22, 27, 30, 31, 30, 27, 22, 15, 9, 4, 1]

	func _draw() -> void:
		if hud.race and hud.race.bumper and hud.race.countdown == 1:
			paint_bumper(size.y / Hud.REFERENCE_HEIGHT)
		if hud.count_clock < 0.0 or hud.count_clock >= SEQUENCE:
			return
		var s := size.y / Hud.REFERENCE_HEIGHT
		var travel := size.x * 0.34
		var clock := hud.count_clock
		if clock >= BEAT * 4.0:
			var leave := 1.0 - pow(1.0 - clampf((clock - BEAT * 4.0) / LEAVE, 0.0, 1.0), 3.0)
			paint_word("GO!", 1.0, 0.0, s, 1.0 - leave, lerpf(1.0, 1.75, leave))
			return
		var index := mini(int(clock / BEAT), 3)
		var t := 1.0 - pow(1.0 - fmod(clock, BEAT) / BEAT, 4.0)
		if index == 3:
			paint_word("GO!", 1.0, 0.0, s, 1.0, t)
			return
		if index > 0:
			paint_word(WORDS[index - 1], t + 1.0, travel, s, 1.0 - t, 1.0)
		paint_word(WORDS[index], t, travel, s, 1.0, lerpf(PEAK, 1.0, t))

	func paint_bumper(s: float) -> void:
		var text := "BUMPER CARS"
		var px := int(56.0 * s)
		var width := hud.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var line := 0xa0 + BUMPER_BOB[(Engine.get_physics_frames() >> 2) & 15]
		paint_outlined(Vector2((size.x - width) * 0.5, size.y * line / 240.0), text, px, s, 1.0)

	func paint_word(text: String, t: float, travel: float, s: float, alpha: float, scale: float) -> void:
		if text.is_empty() or alpha <= 0.0 or scale <= 0.02:
			return
		var px := int(REST_SIZE * PEAK * s)
		var width := hud.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var origin := Vector2(size.x * 0.5 + (1.0 - t) * travel, size.y * 0.56)
		var local := Vector2(-width * 0.5, (hud.font.get_ascent(px) - hud.font.get_descent(px)) * 0.5)
		draw_set_transform(origin, 0.0, Vector2.ONE * scale / PEAK)
		paint_outlined(local, text, px, s, alpha)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func paint_outlined(pos: Vector2, text: String, px: int, s: float, alpha: float) -> void:
		var shadow := Hud.SHADOW * s
		var outline := int(Hud.OUTLINE * s)
		draw_string_outline(hud.font, pos + shadow, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline, Color(0.0, 0.0, 0.0, 0.6 * alpha))
		draw_string_outline(hud.font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline, Color(0.0, 0.0, 0.0, alpha))
		draw_string(hud.font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(Hud.TEXT_COLOR.r, Hud.TEXT_COLOR.g, Hud.TEXT_COLOR.b, alpha))


func draw_finish(me: int, s: float) -> void:
	var show_place := not Session.time_trial and race.cars.size() > 1
	var place_text := ""
	var field_text := ""
	var place_color := TEXT_COLOR
	if show_place:
		place_text = ordinal(race.place(me))
		field_text = "/%d" % race.cars.size()
		if race.new_place:
			place_color = GOLD
	var time_main := ""
	var time_cents := ""
	if race.new_best:
		var total := int(race.finish_time[me] * 100.0)
		time_main = "%d:%02d" % [total / 6000, total / 100 % 60]
		time_cents = "%02d" % (total % 100)

	var title := "FINISHED"
	var title_size := 68
	var title_px := int(title_size * s)
	var flag := 58.0 * s
	var title_gap := 16.0 * s
	var title_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x
	var title_row := flag + title_gap + title_w
	var title_h := font.get_ascent(title_px) + font.get_descent(title_px)

	var badge := 78.0 * s
	var place_px := int(50 * s)
	var field_px := int(26 * s)
	var time_px := int(46 * s)
	var cents_px := int(23 * s)
	var text_gap := 8.0 * s
	var place_text_w := 0.0
	var time_text_w := 0.0
	if show_place:
		place_text_w = font.get_string_size(place_text, HORIZONTAL_ALIGNMENT_LEFT, -1, place_px).x + text_gap + font.get_string_size(field_text, HORIZONTAL_ALIGNMENT_LEFT, -1, field_px).x
	if race.new_best:
		time_text_w = font.get_string_size(time_main, HORIZONTAL_ALIGNMENT_LEFT, -1, time_px).x + 4.0 * s + font.get_string_size(time_cents, HORIZONTAL_ALIGNMENT_LEFT, -1, cents_px).x

	var place_col := 0.0
	var time_col := 0.0
	if show_place:
		place_col = maxf(badge, place_text_w)
	if race.new_best:
		time_col = maxf(badge, time_text_w)
	var col_gap := 64.0 * s
	var stats_w := place_col + time_col
	if show_place and race.new_best:
		stats_w += col_gap
	var label_h := 0.0
	if show_place:
		label_h = font.get_ascent(place_px) + font.get_descent(place_px)
	if race.new_best:
		label_h = maxf(label_h, font.get_ascent(time_px) + font.get_descent(time_px))
	var below := 26.0 * s
	var stats_h := 0.0
	if label_h > 0.0:
		stats_h = badge + below + label_h
	var block_gap := 26.0 * s if stats_h > 0.0 else 0.0
	var block_h := title_h + block_gap + stats_h
	var top := size.y * 0.42 - block_h * 0.5

	var title_base := top + font.get_ascent(title_px)
	var title_x := (size.x - title_row) * 0.5
	var title_mid := title_base - (font.get_ascent(title_px) - font.get_descent(title_px)) * 0.5
	var title_alpha := begin_pop(Vector2(size.x * 0.5, title_mid), finish_title, s)
	if title_alpha > 0.0:
		draw_icon(ICON_FLAG, Rect2(Vector2(title_x, title_mid - flag * 0.5), Vector2(flag, flag)), GOLD, s, title_alpha)
		outlined(Vector2(title_x + flag + title_gap, title_base), title, title_size, s, TEXT_COLOR, title_alpha)
		end_pop()

	if stats_h == 0.0:
		return

	var badge_y := top + title_h + block_gap
	var label_mid := badge_y + badge + below + label_h * 0.5
	var x := (size.x - stats_w) * 0.5
	if show_place:
		var place_alpha := begin_pop(Vector2(x + place_col * 0.5, badge_y + stats_h * 0.5), finish_place, s)
		if place_alpha > 0.0:
			var badge_x := x + (place_col - badge) * 0.5
			draw_icon(ICON_MEDAL, Rect2(Vector2(badge_x, badge_y), Vector2(badge, badge)), place_color, s, place_alpha)
			if race.new_place:
				var pip := 34.0 * s
				draw_icon(ICON_STAR, Rect2(Vector2(badge_x + badge - pip * 0.72, badge_y - pip * 0.22), Vector2(pip, pip)), GOLD, s, place_alpha)
			var main_w := font.get_string_size(place_text, HORIZONTAL_ALIGNMENT_LEFT, -1, place_px).x
			var field_w := font.get_string_size(field_text, HORIZONTAL_ALIGNMENT_LEFT, -1, field_px).x
			var run := main_w + text_gap + field_w
			var text_x := x + (place_col - run) * 0.5
			var main_base := label_mid + (font.get_ascent(place_px) - font.get_descent(place_px)) * 0.5
			outlined(Vector2(text_x, main_base), place_text, 50, s, place_color, place_alpha)
			var field_color := place_color
			if not race.new_place:
				field_color.a = 0.72
			outlined(Vector2(text_x + main_w + text_gap, main_base), field_text, 26, s, field_color, place_alpha)
			end_pop()
		x += place_col
		if race.new_best:
			var div_x := x + col_gap * 0.5
			var line_alpha := clampf((finish_mark - 0.05) / 0.3, 0.0, 1.0)
			draw_line(Vector2(div_x, badge_y + 8.0 * s), Vector2(div_x, badge_y + stats_h - 4.0 * s), Color(1, 1, 1, 0.28 * line_alpha), maxf(2.0, 2.0 * s))
			x += col_gap
	if race.new_best:
		var mark_alpha := begin_pop(Vector2(x + time_col * 0.5, badge_y + stats_h * 0.5), finish_mark, s)
		if mark_alpha > 0.0:
			var badge_x := x + (time_col - badge) * 0.5
			draw_icon(ICON_TROPHY, Rect2(Vector2(badge_x, badge_y), Vector2(badge, badge)), GOLD, s, mark_alpha)
			var main_w := font.get_string_size(time_main, HORIZONTAL_ALIGNMENT_LEFT, -1, time_px).x
			var cents_w := font.get_string_size(time_cents, HORIZONTAL_ALIGNMENT_LEFT, -1, cents_px).x
			var run := main_w + 4.0 * s + cents_w
			var text_x := x + (time_col - run) * 0.5
			var main_base := label_mid + (font.get_ascent(time_px) - font.get_descent(time_px)) * 0.5
			outlined(Vector2(text_x, main_base), time_main, 46, s, GOLD, mark_alpha)
			outlined(Vector2(text_x + main_w + 4.0 * s, main_base - 46.0 * 0.42 * s), time_cents, 23, s, GOLD, mark_alpha)
			end_pop()


func begin_pop(center: Vector2, scale: float, s: float) -> float:
	if scale <= 0.05:
		return 0.0
	var drop := (1.0 - minf(scale, 1.0)) * 36.0 * s
	draw_set_transform(center * (1.0 - scale) + Vector2(0.0, drop), 0.0, Vector2(scale, scale))
	return clampf((scale - 0.05) / 0.3, 0.0, 1.0)


func end_pop() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_icon(texture: Texture2D, rect: Rect2, color: Color, s: float, alpha := 1.0) -> void:
	paint_icon(self, texture, rect, color, s, alpha)


static func paint_icon(canvas: CanvasItem, texture: Texture2D, rect: Rect2, color: Color, s: float, alpha := 1.0) -> void:
	if alpha <= 0.0:
		return
	var center := rect.get_center()
	var radius := rect.size.x * 0.52
	canvas.draw_circle(center + SHADOW * s, radius, Color(0.0, 0.0, 0.0, 0.45 * alpha))
	canvas.draw_circle(center, radius, Color(0.07, 0.02, 0.04, 0.84 * alpha))
	canvas.draw_arc(center, radius, 0.0, TAU, 48, Color(color.r, color.g, color.b, 0.95 * alpha), maxf(2.5, 3.0 * s), true)
	var previous := canvas.texture_filter
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var glyph := rect.size * 0.5
	canvas.draw_texture_rect(texture, Rect2(center - glyph * 0.5, glyph), false, Color(color.r, color.g, color.b, alpha))
	canvas.texture_filter = previous


func draw_lap_and_place(me: int, s: float) -> void:
	outlined(Vector2(30.0, 58.0) * s, "LAP", 34, s)
	outlined(Vector2(30.0, 128.0) * s, "%d/%d" % [race.lap(me), race.laps], 72, s)
	outlined(Vector2(30.0, 180.0) * s, ordinal(race.place(me)), 42, s)


func draw_item(s: float) -> void:
	draw_car_item(player, Vector2(30.0, 205.0) * s, ICON_SCALE, s)


func draw_car_item(car: Car, pos: Vector2, icon_scale: float, s: float) -> void:
	var type := car.selected_item
	var count := car.item_counts[type]
	if count == 0:
		return
	var tint: Array = Items.HUD_COLORS[type]
	# FUN_00060b48 samples a 32 by 20 icon into a 32 by 19 sprite. The framebuffer
	# is 512 by 240, so that sprite is square on a 4:3 screen.
	var source := Rect2(Vector2((type & 1) * 32.0, (type >> 1) * 32.0), Items.ICON_SIZE)
	var side := Items.ICON_SIZE.x * icon_scale * s
	var at := Rect2(pos, Vector2(side, side))
	draw_rect(at.grow(3.0 * s), Color(0.0, 0.0, 0.0, 0.55))
	draw_texture_rect_region(car.items.icons, at, source, Color(minf(tint[0] / 128.0, 1.0), minf(tint[1] / 128.0, 1.0), minf(tint[2] / 128.0, 1.0)))
	if count > 1:
		outlined(Vector2(at.end.x + 10.0 * s, at.end.y - 4.0 * s), str(count), int(17 * icon_scale), s)


# One row per player in the top-left. A won bout flashes that round's points to
# the right of each score, then the total pops to its new value. A won match
# still announces the winner in the middle.
func draw_battle(s: float) -> void:
	var n := battle.cars.size()
	var scoring := battle.score_serial > 0 and score_seen == battle.score_serial and score_anim < SCORE_TOTAL
	var px := int(40 * s)
	var left := 28.0 * s
	var label_w := font.get_string_size("P%d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var score_w := font.get_string_size("%d/%d" % [Battle.target, Battle.target], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var bonus_w := font.get_string_size("+%d" % maxi(n - 1, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, int(30 * s)).x
	var score_x := left + label_w + 16.0 * s
	var icon := Items.ICON_SIZE.x * 1.6 * s
	var icon_x := score_x + score_w + bonus_w + 36.0 * s
	var row := maxf(58.0 * s, icon + 14.0 * s)
	var mid := (font.get_ascent(px) - font.get_descent(px)) * 0.5
	var y := 18.0 * s + font.get_ascent(px)
	for i in n:
		var color := battle.cars[i].color
		if battle.out[i] == 1:
			color = color.darkened(0.6)
		outlined(Vector2(left, y), "P%d" % (i + 1), 40, s, color)
		draw_battle_score(i, Vector2(score_x, y), s, scoring, color.lightened(0.35))
		var cursor := icon_x
		draw_car_item(battle.cars[i], Vector2(cursor, y - mid - icon * 0.5), 1.6, s)
		cursor += icon + 12.0 * s
		if Battle.experts[i] == 1:
			var expert_px := int(20 * s)
			var expert_mid := (font.get_ascent(expert_px) - font.get_descent(expert_px)) * 0.5
			outlined(Vector2(cursor, y - mid + expert_mid), "EXPERT", 20, s, color)
		y += row
	if battle.match_winner < 0 or battle.round_frame == 0:
		return
	var text := "P%d WINNER" % (battle.match_winner + 1)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(80 * s)).x
	outlined(Vector2((size.x - width) / 2.0, size.y * 0.4), text, 80, s, battle.cars[battle.match_winner].color)


func draw_battle_score(i: int, pos: Vector2, s: float, scoring: bool, color: Color) -> void:
	var target := "/%d" % Battle.target
	if not scoring:
		outlined(pos, "%d%s" % [battle.points[i], target], 40, s, color)
		return
	var from := battle.score_from[i]
	var to := battle.points[i]
	var gain := battle.round_points[i]
	if battle.round_frame >= 2:
		gain = to - from
	if gain <= 0:
		outlined(pos, "%d%s" % [from if battle.round_frame < 2 else to, target], 40, s, color)
		return
	var bump := clampf((score_anim - SCORE_IN - SCORE_HOLD) / SCORE_BUMP, 0.0, 1.0)
	var shown := to if bump > 0.0 else from
	var text := "%d%s" % [shown, target]
	if bump > 0.0:
		draw_score_pop(pos, text, s, score_bump(bump), color)
	else:
		outlined(pos, text, 40, s, color)
	var bonus_alpha := 1.0 - clampf(bump / 0.55, 0.0, 1.0)
	if bonus_alpha <= 0.0:
		return
	var appear := clampf(score_anim / SCORE_IN, 0.0, 1.0)
	var pop := ease_out_back(appear)
	var bonus_size := roundi(30.0 * pop)
	if bonus_size < 1:
		return
	var px := int(40 * s)
	var bonus_px := int(bonus_size * s)
	var from_width := font.get_string_size(str(from), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var score_mid := (font.get_ascent(px) - font.get_descent(px)) * 0.5
	var bonus_mid := (font.get_ascent(bonus_px) - font.get_descent(bonus_px)) * 0.5
	var target_width := font.get_string_size(target, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var slide := 1.0 - pow(1.0 - appear, 3.0)
	var rest := pos + Vector2(from_width + target_width + 14.0 * s, bonus_mid - score_mid)
	outlined(rest + Vector2(28.0 * s * (1.0 - slide), 0.0), "+%d" % gain, bonus_size, s, battle.cars[i].color, bonus_alpha * minf(appear * 4.0, 1.0))


func draw_score_pop(pos: Vector2, text: String, s: float, scale: float, color: Color) -> void:
	var px := int(40 * s)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var mid := (font.get_ascent(px) - font.get_descent(px)) * 0.5
	draw_set_transform(pos + Vector2(width * 0.5, -mid), 0.0, Vector2(scale, scale))
	outlined(Vector2(-width * 0.5, mid), text, 40, s, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func score_bump(t: float) -> float:
	var peak := 1.4
	var rise := clampf(t / 0.28, 0.0, 1.0)
	if t <= 0.28:
		return lerpf(1.0, peak, 1.0 - pow(1.0 - rise, 3.0))
	var settle := clampf((t - 0.28) / 0.72, 0.0, 1.0)
	return lerpf(peak, 1.0, 1.0 - pow(1.0 - settle, 2.0))


func ease_out_back(t: float) -> float:
	var c := 1.70158
	var x := t - 1.0
	return 1.0 + x * x * ((c + 1.0) * x + c)


func draw_times(me: int, s: float) -> void:
	var right := size.x - 30.0 * s
	draw_time(Vector2(right, 76.0 * s), race.race_time(me), 64, TEXT_COLOR, s)
	var y := 120.0
	for t in race.lap_times[me]:
		draw_time(Vector2(right, y * s), t, 36, TEXT_COLOR, s)
		y += 42.0


static func format_time(seconds: float) -> String:
	var total := int(seconds * 100.0)
	return "%d:%02d.%02d" % [total / 6000, total / 100 % 60, total % 100]


func draw_time(right_edge: Vector2, seconds: float, font_size: int, color: Color, s: float) -> void:
	var total := int(seconds * 100.0)
	var main := "%d:%02d" % [total / 6000, total / 100 % 60]
	var cents := "%02d" % (total % 100)
	var small := int(font_size * 0.5)
	var cents_width := font.get_string_size(cents, HORIZONTAL_ALIGNMENT_LEFT, -1, int(small * s)).x
	var main_width := font.get_string_size(main, HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * s)).x
	var cents_pos := right_edge - Vector2(cents_width, font_size * 0.45 * s)
	outlined(cents_pos, cents, small, s, color)
	outlined(right_edge - Vector2(cents_width + main_width + 4.0 * s, 0.0), main, font_size, s, color)


func draw_speedometer(center: Vector2, s: float) -> void:
	var radius := DIAL_RADIUS * s
	draw_circle(center, radius + 6.0 * s, Color(0.0, 0.0, 0.0, 0.55))
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.9, 0.9, 0.9, 0.8), 3.0 * s, true)
	var lit_end := DIAL_START + DIAL_SWEEP * clampf(speed / SPEED_MAX, 0.0, 1.0)
	draw_arc(center, radius - 10.0 * s, DIAL_START, lit_end, 48, Color(1.0, 0.55, 0.1, 0.9), 8.0 * s, true)
	var value := 0.0
	while value <= SPEED_MAX:
		var angle := DIAL_START + DIAL_SWEEP * value / SPEED_MAX
		var dir := Vector2.from_angle(angle)
		var major := fmod(value, SPEED_LABEL_STEP) == 0.0
		draw_line(center + dir * (radius - (22.0 if major else 14.0) * s), center + dir * (radius - 4.0 * s), TEXT_COLOR, (3.0 if major else 2.0) * s, true)
		if major:
			var label := str(int(value))
			var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * s))
			draw_string(font, center + dir * (radius - 38.0 * s) + Vector2(-label_size.x / 2.0, 6.0 * s), label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * s), TEXT_COLOR)
		value += SPEED_STEP
	var needle := Vector2.from_angle(DIAL_START + DIAL_SWEEP * clampf(speed / SPEED_MAX, 0.0, 1.05))
	draw_line(center - needle * 12.0 * s, center + needle * (radius - 14.0 * s), LAP_TIME_COLOR, 5.0 * s, true)
	draw_circle(center, 8.0 * s, Color(0.15, 0.15, 0.15))
	var readout := "%d" % roundi(speed)
	var readout_width := font.get_string_size(readout, HORIZONTAL_ALIGNMENT_LEFT, -1, int(34 * s)).x
	outlined(center + Vector2(-readout_width / 2.0, radius * 0.7), readout, 34, s)
	var unit_width := font.get_string_size("KM/H", HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * s)).x
	draw_string(font, center + Vector2(-unit_width / 2.0, radius * 0.92), "KM/H", HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * s), TEXT_COLOR)


func draw_map(me: int, s: float) -> void:
	var box := Rect2(size - Vector2(MAP_SIZE + 24.0, MAP_SIZE + 24.0) * s, Vector2(MAP_SIZE, MAP_SIZE) * s)
	draw_rect(box, Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(box, Color(0.9, 0.9, 0.9, 0.6), false, 2.0 * s)
	var inner := box.grow(-MAP_MARGIN * s)
	var map_scale := minf(inner.size.x / map_bounds.size.x, inner.size.y / map_bounds.size.y)
	var map_offset := inner.get_center() - map_bounds.get_center() * map_scale
	var line := PackedVector2Array()
	for p in map_points:
		line.append(p * map_scale + map_offset)
	line.append(line[0])
	draw_polyline(line, Color(0.0, 0.0, 0.0, 0.8), 7.0 * s, true)
	draw_polyline(line, Color(0.85, 0.85, 0.85), 3.0 * s, true)
	var start := race.track.gate_a(0).lerp(race.track.gate_b(0), 0.5) * map_scale + map_offset
	draw_circle(start, 4.0 * s, TEXT_COLOR)
	for i in race.cars.size():
		if i != me:
			draw_racer(race.cars[i], race.cars[i].color, 6.0 * s, map_scale, map_offset)
	if me >= 0:
		draw_racer(player, player.color, 8.0 * s, map_scale, map_offset)
		draw_time(Vector2(box.end.x, box.position.y - 10.0 * s), race.lap_time(me), 40, LAP_TIME_COLOR, s)


func draw_racer(car: Car, color: Color, radius: float, map_scale: float, map_offset: Vector2) -> void:
	var p := car.get_global_transform_interpolated().origin
	var at := Vector2(p.x, p.z) * map_scale + map_offset
	draw_circle(at, radius + 2.0, Color.BLACK)
	draw_circle(at, radius, color)


func outlined(pos: Vector2, text: String, font_size: int, s: float, color := TEXT_COLOR, alpha := 1.0) -> void:
	if alpha <= 0.0:
		return
	var px := int(font_size * s)
	draw_string_outline(font, pos + SHADOW * s, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, int(OUTLINE * s), Color(0.0, 0.0, 0.0, 0.6 * alpha))
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, int(OUTLINE * s), Color(0.0, 0.0, 0.0, alpha))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(color.r, color.g, color.b, alpha))


static func ordinal(n: int) -> String:
	var suffix := "TH"
	if n % 100 < 11 or n % 100 > 13:
		suffix = ["TH", "ST", "ND", "RD", "TH", "TH", "TH", "TH", "TH", "TH"][n % 10]
	return "%d%s" % [n, suffix]


class IconBadge extends Control:
	var icon: Texture2D
	var tint := Color.WHITE
	var mark_alpha := 1.0

	func _init(mark_icon: Texture2D) -> void:
		icon = mark_icon
		mouse_filter = MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(64, 64)
		size_flags_horizontal = SIZE_SHRINK_CENTER
		size_flags_vertical = SIZE_SHRINK_CENTER

	func _draw() -> void:
		var badge := 46.0
		var origin := (size - Vector2(badge, badge)) * 0.5 + Vector2(-2.0, -3.0)
		Hud.paint_icon(self, icon, Rect2(origin, Vector2(badge, badge)), tint, 1.0, mark_alpha)
