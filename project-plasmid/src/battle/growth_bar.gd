class_name GrowthBar
extends Control
## Banked growth against the target, with the immature pool shown beside it. Spec §2.1,
## §4.1.
##
## [b]The two are drawn differently on purpose.[/b] §2.1's split between banked growth and
## the immature pool is the whole economy: banked growth "cannot be spent, stolen, or
## lost", while the pool can be drained by emergency spending or destroyed outright. A bar
## that merged them would hide the one distinction the player most needs, and would make
## §2.5's death spiral — the pool draining while growth stands still — look like nothing
## happening at all.

const BAR_HEIGHT := 26.0
const BANKED := Color("59c27a")
const POOL := Color(0.25, 0.65, 0.85, 0.55)
const TRACK := Color("222a33")
const TEXT := Color("e8eef4")
const MUTED := Color("8b98a5")

var _banked: int = 0
var _pool: int = 0
var _target: int = 1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, BAR_HEIGHT + 40.0)


func show_state(state: SimState) -> void:
	_banked = state.banked_growth
	_pool = state.pool.available()
	_target = maxi(1, state.growth_target())
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 18.0, size.x, BAR_HEIGHT), TRACK, true)

	var banked_width := size.x * minf(1.0, float(_banked) / float(_target))
	draw_rect(Rect2(0, 18.0, banked_width, BAR_HEIGHT), BANKED, true)

	# The pool sits past the banked mark as a lighter, translucent block: this much
	# growth is coming *if* nothing spends it first.
	var pool_width := size.x * minf(1.0 - banked_width / size.x, float(_pool) / float(_target))
	if pool_width > 0.0:
		draw_rect(Rect2(banked_width, 18.0, pool_width, BAR_HEIGHT), POOL, true)

	_text("Growth %d of %d" % [_banked, _target], Vector2(0, 12.0), TEXT)
	_text(
		"banked (safe) — %d in the pool (spendable, and losable)" % _pool,
		Vector2(0, BAR_HEIGHT + 34.0),
		MUTED,
		11
	)


func _text(text: String, position: Vector2, colour: Color, font_size: int = 13) -> void:
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)
