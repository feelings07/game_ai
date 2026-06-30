extends Control

## Fog-of-war minimap. Call reset() on new level, reveal_around() every frame.

const EXPLORE_R  := 8     # tiles revealed around player
const PANEL_W    := 200.0
const PANEL_H    := 128.0

var _grid: PackedInt32Array = PackedInt32Array()
var _grid_w: int = 128
var _grid_h: int = 80
var _location: String = "castle"

var _visited: Dictionary    = {}          # Vector2i -> int (0=wall 1=floor)
var _player_cell: Vector2i  = Vector2i.ZERO
var _boss_cell: Vector2i    = Vector2i.ZERO
var _chest_cells: Array[Vector2i] = []


func reset(grid: PackedInt32Array, gw: int, gh: int,
           boss_c: Vector2i, chests: Array[Vector2i], loc: String) -> void:
	_grid        = grid
	_grid_w      = gw
	_grid_h      = gh
	_boss_cell   = boss_c
	_chest_cells = chests
	_location    = loc
	_visited.clear()
	_player_cell = Vector2i.ZERO
	queue_redraw()


func reveal_around(pcell: Vector2i) -> void:
	if _grid.is_empty():
		return
	_player_cell = pcell
	var changed  := false
	for dy in range(-EXPLORE_R, EXPLORE_R + 1):
		for dx in range(-EXPLORE_R, EXPLORE_R + 1):
			if dx * dx + dy * dy > EXPLORE_R * EXPLORE_R:
				continue
			var c := Vector2i(pcell.x + dx, pcell.y + dy)
			if c.x < 0 or c.x >= _grid_w or c.y < 0 or c.y >= _grid_h:
				continue
			if not _visited.has(c):
				_visited[c] = _grid[c.y * _grid_w + c.x]
				changed = true
	if changed:
		queue_redraw()


func _draw() -> void:
	# Panel background + border
	draw_rect(Rect2(0.0, 0.0, PANEL_W, PANEL_H), Color(0.05, 0.05, 0.07, 0.88))
	draw_rect(Rect2(0.0, 0.0, PANEL_W, PANEL_H), Color(0.50, 0.48, 0.42, 0.70), false, 1.5)

	var sx := PANEL_W / float(_grid_w)
	var sy := PANEL_H / float(_grid_h)

	var floor_col: Color
	var wall_col:  Color
	match _location:
		"forest":
			floor_col = Color(0.36, 0.55, 0.22, 1.0)
			wall_col  = Color(0.12, 0.26, 0.06, 1.0)
		"cave":
			floor_col = Color(0.30, 0.26, 0.18, 1.0)
			wall_col  = Color(0.09, 0.08, 0.06, 1.0)
		_:
			floor_col = Color(0.48, 0.44, 0.38, 1.0)
			wall_col  = Color(0.18, 0.16, 0.14, 1.0)

	for cell: Vector2i in _visited:
		var tile: int = _visited[cell]
		var col := floor_col if tile == 1 else wall_col
		draw_rect(Rect2(cell.x * sx, cell.y * sy, maxf(sx, 1.0), maxf(sy, 1.0)), col)

	# Chests – yellow (only if explored)
	for c: Vector2i in _chest_cells:
		if _visited.has(c):
			draw_circle(
				Vector2(c.x * sx + sx * 0.5, c.y * sy + sy * 0.5), 2.5,
				Color(1.0, 0.85, 0.1))

	# Boss – red (only if area explored)
	if _visited.has(_boss_cell):
		draw_circle(
			Vector2(_boss_cell.x * sx + sx * 0.5, _boss_cell.y * sy + sy * 0.5), 3.0,
			Color(1.0, 0.2, 0.1))

	# Player – white dot
	draw_circle(
		Vector2(_player_cell.x * sx + sx * 0.5, _player_cell.y * sy + sy * 0.5), 3.5,
		Color.WHITE)

	# Label
	draw_string(ThemeDB.fallback_font,
		Vector2(4.0, PANEL_H - 4.0),
		"Карта  ●=игрок  ●=босс  ●=сундук",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		Color(0.6, 0.6, 0.6, 0.7))
