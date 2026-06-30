extends Node2D

# ── Constants ─────────────────────────────────────────────────────────────────
const TILE              := 32
const GRID_W            := 128
const GRID_H            := 80
const ROOM_MIN          := 4
const ROOM_MAX          := 7
const CORRIDOR_WIDTH    := 2
const MIN_ENEMY_DIST    := 7
const LEVEL_STEP_TILES  := 20.0
const MAX_ENEMY_LEVEL   := 8
const MAX_ENEMIES       := 20
const RESPAWN_INTERVAL  := 4.0

# Castle tiles
const TEX_FLOOR        := preload("res://assets/tilesets/tile_floor.png")
const TEX_WALL         := preload("res://assets/tilesets/tile_wall.png")
# Forest tiles
const TEX_FLOOR_FOREST := preload("res://assets/tilesets/tile_floor_forest.png")
const TEX_TREE         := preload("res://assets/tilesets/tile_tree.png")
const TEX_HOUSE_WALL   := preload("res://assets/tilesets/tile_house_wall.png")
# Cave tiles
const TEX_FLOOR_CAVE   := preload("res://assets/tilesets/tile_floor_cave.png")
const TEX_WALL_CAVE    := preload("res://assets/tilesets/tile_wall_cave.png")
# Swamp tiles
const TEX_FLOOR_SWAMP  := preload("res://assets/tilesets/tile_floor_swamp.png")
const TEX_WATER        := preload("res://assets/tilesets/tile_water.png")
# Ruins tiles
const TEX_FLOOR_RUINS  := preload("res://assets/tilesets/tile_floor_ruins.png")
const TEX_WALL_RUINS   := preload("res://assets/tilesets/tile_wall_ruins.png")
# Volcano tiles
const TEX_FLOOR_VOLCANO := preload("res://assets/tilesets/tile_floor_volcano.png")
const TEX_WALL_VOLCANO  := preload("res://assets/tilesets/tile_wall_volcano.png")

const STATS_WINDOW_SCRIPT  := preload("res://scripts/stats_window.gd")
const CLASS_SELECT_SCRIPT  := preload("res://scripts/class_select.gd")
const TEX_SPIKE        := preload("res://assets/sprites/trap_spike.png")
const TEX_SHADOW_SM    := preload("res://assets/sprites/shadow_small.png")
const TEX_SHADOW_LG    := preload("res://assets/sprites/shadow_large.png")
const ENEMY_SCRIPT     := preload("res://scripts/enemy.gd")
const TRAP_SCRIPT      := preload("res://scripts/trap_spike.gd")
const CHEST_SCRIPT     := preload("res://scripts/chest.gd")
const FLOAT_SCRIPT     := preload("res://scripts/floating_text.gd")
const ANIM_UTILS       := preload("res://scripts/anim_utils.gd")

@onready var player: CharacterBody2D = $Player
@onready var hp_label: Label         = $HUD/HPLabel
@onready var mp_label: Label         = $HUD/MPLabel
@onready var minimap: Control        = $HUD/Minimap
@onready var potion_bar: Control     = $HUD/PotionBar
@onready var buff_hud: Control       = $HUD/BuffHud

var stats_window:      CanvasLayer = null
var _class_select:     CanvasLayer = null
var _need_class_select: bool       = true
var level:             Node2D      = null
var rng            := RandomNumberGenerator.new()
var dungeon_level: int    = 1

# All available locations — selected randomly after each boss kill
const ALL_LOCATIONS: Array[String] = ["castle", "forest", "cave", "swamp", "ruins", "volcano"]
var _location: String = "castle"

var _spawn_cell:        Vector2i         = Vector2i.ZERO
var _enemy_spawn_cells: Array[Vector2i]  = []
var _respawn_timer:     float            = 0.0
var _house_wall_set:    Dictionary       = {}   # Vector2i -> true
var _current_grid:      PackedInt32Array = PackedInt32Array()
var _boss_cell:         Vector2i         = Vector2i.ZERO
var _chest_cells:       Array[Vector2i]  = []


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	rng.randomize()
	GameEvents.boss_defeated.connect(_on_boss_defeated)
	GameEvents.player_died.connect(_on_player_died)
	GameEvents.restart_requested.connect(_on_restart_requested)
	stats_window = CanvasLayer.new()
	stats_window.set_script(STATS_WINDOW_SCRIPT)
	add_child(stats_window)
	_location = "castle"
	_generate_level(true)


func _process(delta: float) -> void:
	_respawn_timer -= delta
	if _respawn_timer <= 0.0:
		_respawn_timer = RESPAWN_INTERVAL
		_try_spawn_enemy()
	if minimap != null:
		var pc := Vector2i(int(player.global_position.x / TILE),
		                   int(player.global_position.y / TILE))
		minimap.reveal_around(pc)


# ── Main generation dispatcher ────────────────────────────────────────────────

func _generate_level(is_first: bool) -> void:
	if level != null:
		level.queue_free()
	level = Node2D.new()
	level.name = "Level"
	add_child(level)
	move_child(level, 0)
	_respawn_timer = RESPAWN_INTERVAL
	_house_wall_set.clear()
	_chest_cells.clear()

	var layout: Dictionary
	match _location:
		"forest":  layout = _build_forest_grid()
		"cave":    layout = _build_cave_grid()
		"swamp":   layout = _build_swamp_grid()
		"ruins":   layout = _build_ruins_grid()
		"volcano": layout = _build_volcano_grid()
		_:         layout = _build_castle_grid()

	var grid:             PackedInt32Array = layout["grid"]
	var non_spawn:        Array[Vector2i]  = layout["non_spawn"]
	var enemy_candidates: Array[Vector2i]  = layout["enemies"]
	_spawn_cell    = layout["spawn"]
	_boss_cell     = layout["boss"]
	_current_grid  = grid

	_build_all_tiles(grid)
	_build_background()

	var used: Array[Vector2i] = [_boss_cell]

	var trap_n := rng.randi_range(4, 10) if _location == "forest" else rng.randi_range(10, 18)
	for c: Vector2i in _pick_cells(non_spawn, trap_n, 2, used):
		used.append(c)
		_build_trap(c)

	var chest_n := rng.randi_range(5, 9)
	for c: Vector2i in _pick_cells(non_spawn, chest_n, 3, used):
		used.append(c)
		_chest_cells.append(c)
		_build_chest(c)

	_build_boss(_boss_cell)

	for c: Vector2i in _pick_cells(enemy_candidates, rng.randi_range(12, 18), 3, used):
		used.append(c)
		_build_enemy(c)

	_enemy_spawn_cells = enemy_candidates

	var player_start := Vector2(
		_spawn_cell.x * TILE + TILE * 0.5,
		_spawn_cell.y * TILE + TILE * 0.5)
	player.global_position = player_start
	player.set_spawn_point(player_start)
	_on_health_changed(player.health, player.max_health)
	_on_mana_changed(int(player.mana), player.max_mana)

	if is_first:
		player.health_changed.connect(_on_health_changed)
		player.mana_changed.connect(_on_mana_changed)
		$InventoryUI.setup(player,
			player.get_node("Inventory"), player.get_node("Equipment"),
			player.get_node("Stats"),     player.get_node("SkillTree"))
		$SkillUI.setup(player, player.get_node("SkillTree"))
		if potion_bar != null:
			potion_bar.setup(player.get_node("Inventory"))
		if buff_hud != null:
			buff_hud.setup(player.get_node("Stats"))
		if stats_window != null:
			stats_window.setup(player.get_node("Stats"),
				player.get_node("Equipment"), player.get_node("SkillTree"), player)

	var cam: Camera2D = player.get_node("Camera2D")
	cam.zoom         = Vector2(1.5, 1.5)
	cam.limit_left   = -32
	cam.limit_top    = -64
	cam.limit_right  = GRID_W * TILE + 32
	cam.limit_bottom = GRID_H * TILE + 32

	if minimap != null:
		minimap.reset(_current_grid, GRID_W, GRID_H,
		              _boss_cell, _chest_cells, _location)

	if _need_class_select:
		_show_class_select()


# ── Class selection ───────────────────────────────────────────────────────────

func _show_class_select() -> void:
	if _class_select != null and is_instance_valid(_class_select):
		_class_select.queue_free()
	_class_select = CanvasLayer.new()
	_class_select.set_script(CLASS_SELECT_SCRIPT)
	add_child(_class_select)
	_class_select.class_chosen.connect(_on_class_chosen)
	GameEvents.open_ui()

func _on_class_chosen(class_id: String) -> void:
	GameEvents.close_ui()
	_need_class_select = false
	var stats: Node = player.get_node("Stats")
	var inventory: Node = player.get_node("Inventory")
	match class_id:
		"warrior":
			stats.add_base("strength")
			inventory.add_item(ItemDB.make_instance("sword_starter"))
		"archer":
			stats.add_base("agility")
			inventory.add_item(ItemDB.make_instance("bow_starter"))
		"mage":
			stats.add_base("intelligence")
			inventory.add_item(ItemDB.make_instance("wand_starter"))
	inventory.add_item(ItemDB.make_instance("potion_health"))


# ── Castle grid (BSP rooms) ───────────────────────────────────────────────────

func _build_castle_grid() -> Dictionary:
	var grid := PackedInt32Array()
	grid.resize(GRID_W * GRID_H)

	var rooms: Array[Rect2i] = []
	var room_count := rng.randi_range(20, 32)
	var tries := 0
	while rooms.size() < room_count and tries < 800:
		tries += 1
		var w := rng.randi_range(ROOM_MIN, ROOM_MAX)
		var h := rng.randi_range(ROOM_MIN, ROOM_MAX)
		var x := rng.randi_range(1, GRID_W - w - 2)
		var y := rng.randi_range(1, GRID_H - h - 2)
		var rect := Rect2i(x, y, w, h)
		var ok := true
		for r: Rect2i in rooms:
			if rect.grow(1).intersects(r.grow(1)): ok = false; break
		if ok:
			rooms.append(rect)
			_carve_rect(grid, rect)

	for i in range(1, rooms.size()):
		_carve_corridor(grid, _room_center(rooms[i-1]), _room_center(rooms[i]))

	var spawn  := _room_center(rooms[0])
	var sp_box := rooms[0].grow(1)
	var floor:  Array[Vector2i] = []
	var non_sp: Array[Vector2i] = []
	for y in GRID_H:
		for x in GRID_W:
			if grid[y * GRID_W + x] == 1:
				var c := Vector2i(x, y)
				floor.append(c)
				if not sp_box.has_point(c): non_sp.append(c)

	var enemy_cands: Array[Vector2i] = []
	for c: Vector2i in non_sp:
		if absi(c.x - spawn.x) + absi(c.y - spawn.y) >= MIN_ENEMY_DIST:
			enemy_cands.append(c)

	return {
		"grid": grid, "spawn": spawn,
		"non_spawn": non_sp, "enemies": enemy_cands,
		"boss": _farthest_cell(non_sp, spawn)
	}


# ── Forest grid (open field + trees + houses) ─────────────────────────────────

func _build_forest_grid() -> Dictionary:
	var grid := PackedInt32Array()
	grid.resize(GRID_W * GRID_H)
	grid.fill(1)   # open field

	# Border walls
	for x in GRID_W:
		grid[x] = 0; grid[(GRID_H - 1) * GRID_W + x] = 0
	for y in GRID_H:
		grid[y * GRID_W] = 0; grid[y * GRID_W + GRID_W - 1] = 0

	var spawn := Vector2i(GRID_W / 5, GRID_H / 2)

	# Tree clusters (avoid spawn zone)
	for _cl in 32:
		var cx := rng.randi_range(4, GRID_W - 5)
		var cy := rng.randi_range(4, GRID_H - 5)
		if absi(cx - spawn.x) + absi(cy - spawn.y) < 10: continue
		var count := rng.randi_range(2, 9)
		for _t in count:
			var tx := clampi(cx + rng.randi_range(-4, 4), 1, GRID_W - 2)
			var ty := clampi(cy + rng.randi_range(-4, 4), 1, GRID_H - 2)
			if absi(tx - spawn.x) + absi(ty - spawn.y) > 6:
				grid[ty * GRID_W + tx] = 0

	# Houses
	var houses: Array[Rect2i] = []
	var target := rng.randi_range(4, 7)
	var att    := 0
	while houses.size() < target and att < 300:
		att += 1
		var hw := rng.randi_range(7, 11)
		var hh := rng.randi_range(6, 9)
		var hx := rng.randi_range(3, GRID_W - hw - 3)
		var hy := rng.randi_range(3, GRID_H - hh - 3)
		var rect := Rect2i(hx, hy, hw, hh)
		if Rect2i(spawn.x - 5, spawn.y - 5, 10, 10).intersects(rect): continue
		var overlap := false
		for hr: Rect2i in houses:
			if rect.grow(3).intersects(hr.grow(3)): overlap = true; break
		if not overlap:
			houses.append(rect)
			_carve_house(grid, rect)

	# Collect floor cells
	var sp_box  := Rect2i(spawn.x - 4, spawn.y - 4, 8, 8)
	var non_sp: Array[Vector2i] = []
	for y in GRID_H:
		for x in GRID_W:
			if grid[y * GRID_W + x] == 1:
				var c := Vector2i(x, y)
				if not sp_box.has_point(c): non_sp.append(c)

	var enemy_cands: Array[Vector2i] = []
	for c: Vector2i in non_sp:
		if absi(c.x - spawn.x) + absi(c.y - spawn.y) >= MIN_ENEMY_DIST:
			enemy_cands.append(c)

	# Witch boss lives inside the farthest house interior
	var boss_cell := _farthest_cell(non_sp, spawn)
	if not houses.is_empty():
		var farthest_house := houses[0]
		var best_d := -1.0
		for h: Rect2i in houses:
			var hc := _room_center(h)
			var d: float = absf(float(hc.x - spawn.x)) + absf(float(hc.y - spawn.y))
			if d > best_d: best_d = d; farthest_house = h
		boss_cell = _room_center(farthest_house)

	return {
		"grid": grid, "spawn": spawn,
		"non_spawn": non_sp, "enemies": enemy_cands,
		"boss": boss_cell
	}


func _carve_house(grid: PackedInt32Array, rect: Rect2i) -> void:
	var x := rect.position.x; var y := rect.position.y
	var w := rect.size.x;     var h := rect.size.y
	# Ensure interior is floor
	for cy in range(y, y + h):
		for cx in range(x, x + w):
			grid[cy * GRID_W + cx] = 1
	# Perimeter walls
	for cx in range(x, x + w):
		grid[y * GRID_W + cx] = 0
		_house_wall_set[Vector2i(cx, y)] = true
		grid[(y + h - 1) * GRID_W + cx] = 0
		_house_wall_set[Vector2i(cx, y + h - 1)] = true
	for cy in range(y, y + h):
		grid[cy * GRID_W + x] = 0
		_house_wall_set[Vector2i(x, cy)] = true
		grid[cy * GRID_W + x + w - 1] = 0
		_house_wall_set[Vector2i(x + w - 1, cy)] = true
	# South doorway (2 tiles, centred)
	var door_x := x + w / 2 - 1
	for dx in 2:
		var dc := Vector2i(door_x + dx, y + h - 1)
		grid[dc.y * GRID_W + dc.x] = 1
		_house_wall_set.erase(dc)


# ── Cave grid (cellular automaton) ────────────────────────────────────────────

func _build_cave_grid() -> Dictionary:
	for _attempt in 3:
		var grid := PackedInt32Array()
		grid.resize(GRID_W * GRID_H)

		# Random init: 44 % walls
		for i in grid.size():
			grid[i] = 0 if rng.randf() < 0.44 else 1

		# Border always wall
		for x in GRID_W:
			grid[x] = 0; grid[(GRID_H - 1) * GRID_W + x] = 0
		for y in GRID_H:
			grid[y * GRID_W] = 0; grid[y * GRID_W + GRID_W - 1] = 0

		# Guarantee open spawn zone near top-left quarter
		var sx := GRID_W / 4; var sy := GRID_H / 2
		for dy in range(-5, 6):
			for dx in range(-5, 6):
				grid[(sy + dy) * GRID_W + (sx + dx)] = 1

		# Cellular automaton (4 passes)
		for _iter in 4:
			var ng := grid.duplicate()
			for y in range(1, GRID_H - 1):
				for x in range(1, GRID_W - 1):
					var walls := 0
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							walls += 1 if grid[(y + dy) * GRID_W + (x + dx)] == 0 else 0
					ng[y * GRID_W + x] = 0 if walls >= 5 else 1
			grid = ng

		var spawn := Vector2i(sx, sy)

		# Flood fill to find connected region from spawn
		var reachable := _flood_fill(grid, spawn)
		if reachable.size() < GRID_W * GRID_H / 6:
			continue   # too fragmented – retry

		# Remove isolated floor patches
		var reach_set: Dictionary = {}
		for c: Vector2i in reachable: reach_set[c] = true
		for y in GRID_H:
			for x in GRID_W:
				if grid[y * GRID_W + x] == 1 and not reach_set.has(Vector2i(x, y)):
					grid[y * GRID_W + x] = 0

		var sp_box := Rect2i(spawn.x - 5, spawn.y - 5, 10, 10)
		var non_sp: Array[Vector2i] = []
		for c: Vector2i in reachable:
			if not sp_box.has_point(c): non_sp.append(c)

		var enemy_cands: Array[Vector2i] = []
		for c: Vector2i in non_sp:
			if absi(c.x - spawn.x) + absi(c.y - spawn.y) >= MIN_ENEMY_DIST:
				enemy_cands.append(c)

		return {
			"grid": grid, "spawn": spawn,
			"non_spawn": non_sp, "enemies": enemy_cands,
			"boss": _farthest_cell(non_sp, spawn)
		}

	# Fallback: castle layout
	return _build_castle_grid()


# ── Swamp grid (open field + water puddles) ───────────────────────────────────

func _build_swamp_grid() -> Dictionary:
	var grid := PackedInt32Array()
	grid.resize(GRID_W * GRID_H)
	grid.fill(1)

	for x in GRID_W:
		grid[x] = 0; grid[(GRID_H - 1) * GRID_W + x] = 0
	for y in GRID_H:
		grid[y * GRID_W] = 0; grid[y * GRID_W + GRID_W - 1] = 0

	var spawn := Vector2i(GRID_W / 5, GRID_H / 2)

	# Circular water puddles
	for _cl in 24:
		var cx := rng.randi_range(5, GRID_W - 6)
		var cy := rng.randi_range(5, GRID_H - 6)
		if absi(cx - spawn.x) + absi(cy - spawn.y) < 8: continue
		var r  := rng.randi_range(2, 5)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx * dx + dy * dy <= r * r:
					var tx := cx + dx; var ty := cy + dy
					if tx > 0 and tx < GRID_W - 1 and ty > 0 and ty < GRID_H - 1:
						grid[ty * GRID_W + tx] = 0

	var sp_box: Rect2i = Rect2i(spawn.x - 5, spawn.y - 5, 10, 10)
	var non_sp: Array[Vector2i] = []
	for y in GRID_H:
		for x in GRID_W:
			if grid[y * GRID_W + x] == 1:
				var c := Vector2i(x, y)
				if not sp_box.has_point(c): non_sp.append(c)

	var enemy_cands: Array[Vector2i] = []
	for c: Vector2i in non_sp:
		if absi(c.x - spawn.x) + absi(c.y - spawn.y) >= MIN_ENEMY_DIST:
			enemy_cands.append(c)

	return {
		"grid": grid, "spawn": spawn,
		"non_spawn": non_sp, "enemies": enemy_cands,
		"boss": _farthest_cell(non_sp, spawn)
	}


# ── Ruins grid (BSP, larger rooms) ───────────────────────────────────────────

func _build_ruins_grid() -> Dictionary:
	var grid := PackedInt32Array()
	grid.resize(GRID_W * GRID_H)

	var rooms: Array[Rect2i] = []
	var room_count := rng.randi_range(14, 22)
	var tries := 0
	while rooms.size() < room_count and tries < 800:
		tries += 1
		var w := rng.randi_range(ROOM_MIN + 2, ROOM_MAX + 4)
		var h := rng.randi_range(ROOM_MIN + 2, ROOM_MAX + 4)
		var x := rng.randi_range(1, GRID_W - w - 2)
		var y := rng.randi_range(1, GRID_H - h - 2)
		var rect := Rect2i(x, y, w, h)
		var ok := true
		for r: Rect2i in rooms:
			if rect.grow(1).intersects(r.grow(1)): ok = false; break
		if ok:
			rooms.append(rect)
			_carve_rect(grid, rect)

	for i in range(1, rooms.size()):
		_carve_corridor(grid, _room_center(rooms[i-1]), _room_center(rooms[i]))

	var spawn  := _room_center(rooms[0])
	var sp_box := rooms[0].grow(1)
	var floor:  Array[Vector2i] = []
	var non_sp: Array[Vector2i] = []
	for y in GRID_H:
		for x in GRID_W:
			if grid[y * GRID_W + x] == 1:
				var c := Vector2i(x, y)
				floor.append(c)
				if not sp_box.has_point(c): non_sp.append(c)

	var enemy_cands: Array[Vector2i] = []
	for c: Vector2i in non_sp:
		if absi(c.x - spawn.x) + absi(c.y - spawn.y) >= MIN_ENEMY_DIST:
			enemy_cands.append(c)

	return {
		"grid": grid, "spawn": spawn,
		"non_spawn": non_sp, "enemies": enemy_cands,
		"boss": _farthest_cell(non_sp, spawn)
	}


# ── Volcano grid (cellular automaton, more open) ──────────────────────────────

func _build_volcano_grid() -> Dictionary:
	for _attempt in 3:
		var grid := PackedInt32Array()
		grid.resize(GRID_W * GRID_H)

		for i in grid.size():
			grid[i] = 0 if rng.randf() < 0.38 else 1

		for x in GRID_W:
			grid[x] = 0; grid[(GRID_H - 1) * GRID_W + x] = 0
		for y in GRID_H:
			grid[y * GRID_W] = 0; grid[y * GRID_W + GRID_W - 1] = 0

		var sx := GRID_W / 4; var sy := GRID_H / 2
		for dy in range(-5, 6):
			for dx in range(-5, 6):
				grid[(sy + dy) * GRID_W + (sx + dx)] = 1

		for _iter in 4:
			var ng := grid.duplicate()
			for y in range(1, GRID_H - 1):
				for x in range(1, GRID_W - 1):
					var walls := 0
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							walls += 1 if grid[(y + dy) * GRID_W + (x + dx)] == 0 else 0
					ng[y * GRID_W + x] = 0 if walls >= 5 else 1
			grid = ng

		var spawn := Vector2i(sx, sy)
		var reachable := _flood_fill(grid, spawn)
		if reachable.size() < GRID_W * GRID_H / 6:
			continue

		var reach_set: Dictionary = {}
		for c: Vector2i in reachable: reach_set[c] = true
		for y in GRID_H:
			for x in GRID_W:
				if grid[y * GRID_W + x] == 1 and not reach_set.has(Vector2i(x, y)):
					grid[y * GRID_W + x] = 0

		var sp_box := Rect2i(spawn.x - 5, spawn.y - 5, 10, 10)
		var non_sp: Array[Vector2i] = []
		for c: Vector2i in reachable:
			if not sp_box.has_point(c): non_sp.append(c)

		var enemy_cands: Array[Vector2i] = []
		for c: Vector2i in non_sp:
			if absi(c.x - spawn.x) + absi(c.y - spawn.y) >= MIN_ENEMY_DIST:
				enemy_cands.append(c)

		return {
			"grid": grid, "spawn": spawn,
			"non_spawn": non_sp, "enemies": enemy_cands,
			"boss": _farthest_cell(non_sp, spawn)
		}

	return _build_castle_grid()


func _flood_fill(grid: PackedInt32Array, start: Vector2i) -> Array[Vector2i]:
	var visited: Dictionary = {}
	var stack:   Array[Vector2i] = [start]
	var result:  Array[Vector2i] = []
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		if visited.has(c): continue
		if c.x < 0 or c.x >= GRID_W or c.y < 0 or c.y >= GRID_H: continue
		if grid[c.y * GRID_W + c.x] == 0: continue
		visited[c] = true
		result.append(c)
		stack.append(Vector2i(c.x + 1, c.y))
		stack.append(Vector2i(c.x - 1, c.y))
		stack.append(Vector2i(c.x, c.y + 1))
		stack.append(Vector2i(c.x, c.y - 1))
	return result


# ── Tile building ─────────────────────────────────────────────────────────────

func _build_all_tiles(grid: PackedInt32Array) -> void:
	var tex_floor := _floor_tex()
	var tex_wall  := _wall_tex()
	for y in GRID_H:
		for x in GRID_W:
			var idx  := y * GRID_W + x
			var cell := Vector2i(x, y)
			if grid[idx] == 1:
				_place_floor(x, y, tex_floor)
			elif _has_floor_neighbor(grid, x, y):
				if _location == "forest":
					var wt := TEX_HOUSE_WALL if _house_wall_set.has(cell) else TEX_TREE
					_place_wall(x, y, wt)
				else:
					_place_wall(x, y, tex_wall)


func _floor_tex() -> Texture2D:
	match _location:
		"forest":  return TEX_FLOOR_FOREST
		"cave":    return TEX_FLOOR_CAVE
		"swamp":   return TEX_FLOOR_SWAMP
		"ruins":   return TEX_FLOOR_RUINS
		"volcano": return TEX_FLOOR_VOLCANO
		_:         return TEX_FLOOR


func _wall_tex() -> Texture2D:
	match _location:
		"cave":    return TEX_WALL_CAVE
		"swamp":   return TEX_WATER
		"ruins":   return TEX_WALL_RUINS
		"volcano": return TEX_WALL_VOLCANO
		_:         return TEX_WALL


func _place_floor(x: int, y: int, tex: Texture2D) -> void:
	var spr := Sprite2D.new()
	spr.texture = tex; spr.centered = false
	spr.position = Vector2(x * TILE, y * TILE)
	level.add_child(spr)


func _place_wall(x: int, y: int, tex: Texture2D) -> void:
	var spr := Sprite2D.new()
	spr.texture = tex; spr.centered = false
	spr.position = Vector2(x * TILE, y * TILE - 8.0)
	level.add_child(spr)

	var body  := StaticBody2D.new()
	body.collision_layer = 0; body.collision_mask = 0
	body.set_collision_layer_value(1, true)
	var shape := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE)
	shape.shape = rect
	shape.position = Vector2(x * TILE + TILE * 0.5, y * TILE + TILE * 0.5)
	body.add_child(shape); level.add_child(body)


func _build_background() -> void:
	var bg := ColorRect.new()
	match _location:
		"forest":  bg.color = Color(0.10, 0.20, 0.06)
		"cave":    bg.color = Color(0.03, 0.03, 0.04)
		"swamp":   bg.color = Color(0.06, 0.12, 0.04)
		"ruins":   bg.color = Color(0.12, 0.11, 0.09)
		"volcano": bg.color = Color(0.14, 0.04, 0.02)
		_:         bg.color = Color(0.07, 0.06, 0.09)
	bg.z_index  = -10
	bg.position = Vector2(-200, -200)
	bg.size     = Vector2(GRID_W * TILE + 400, GRID_H * TILE + 400)
	level.add_child(bg)
	level.move_child(bg, 0)


# ── Object builders ───────────────────────────────────────────────────────────

func _build_enemy(cell: Vector2i) -> void:
	var enemy_id: String
	match _location:
		"forest":  enemy_id = "goblin"
		"cave":    enemy_id = "skeleton_archer"
		"swamp":   enemy_id = "swamp_shaman"
		"ruins":   enemy_id = "ghost"
		"volcano": enemy_id = "fire_imp"
		_:         enemy_id = EnemyDB.random_id()
	if enemy_id == "": return
	_spawn_enemy_node(cell, EnemyDB.get_enemy(enemy_id), false)


func _build_boss(cell: Vector2i) -> void:
	var boss_id: String
	match _location:
		"forest":  boss_id = "witch_boss"
		"cave":    boss_id = "dragon_boss"
		"swamp":   boss_id = "swamp_golem"
		"ruins":   boss_id = "lich_boss"
		"volcano": boss_id = "magma_titan"
		_:         boss_id = "castle_boss"
	var data := EnemyDB.get_enemy(boss_id)
	if data.is_empty(): return
	_spawn_enemy_node(cell, data, true)


func _spawn_enemy_node(cell: Vector2i, data: Dictionary, is_boss: bool) -> void:
	var col_r := float(data.get("collision_radius", 11 if not is_boss else 22))

	var e := CharacterBody2D.new()
	e.set_script(ENEMY_SCRIPT)
	e.position = Vector2(cell.x * TILE + TILE * 0.5, cell.y * TILE + TILE * 0.5)
	if is_boss: e.is_boss = true

	var shadow := Sprite2D.new()
	shadow.texture  = TEX_SHADOW_LG if is_boss else TEX_SHADOW_SM
	shadow.position = Vector2(0, 18 if is_boss else 10)
	e.add_child(shadow)

	var spr := AnimatedSprite2D.new()
	spr.name = "Sprite2D"
	spr.sprite_frames = ANIM_UTILS.build_sprite_frames({
		"walk":   _frame_paths(data, "sprite_frames",  "", 4),
		"attack": _frame_paths(data, "attack_frames",  "", 1)
	})
	spr.play("walk")
	e.add_child(spr)

	var shape  := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = col_r
	shape.shape = circle
	e.add_child(shape)

	var hit := Area2D.new()
	hit.name = "HitArea"
	hit.collision_layer = 0; hit.collision_mask = 0
	hit.set_collision_layer_value(3, true)
	hit.set_collision_mask_value(2, true)
	var hs := CollisionShape2D.new()
	var hc := CircleShape2D.new()
	hc.radius = col_r + 4.0
	hs.shape = hc
	hit.add_child(hs); e.add_child(hit)

	var enemy_level: int
	if is_boss:
		enemy_level = dungeon_level + MAX_ENEMY_LEVEL - 1
	else:
		enemy_level = _enemy_level(cell)

	e.setup(data, enemy_level)
	level.add_child(e)


func _build_trap(cell: Vector2i) -> void:
	var area := Area2D.new()
	area.position = Vector2(cell.x * TILE, cell.y * TILE)
	area.set_script(TRAP_SCRIPT)
	area.collision_layer = 0; area.collision_mask = 0
	area.set_collision_layer_value(4, true)
	area.set_collision_mask_value(2, true)
	var spr := Sprite2D.new()
	spr.texture = TEX_SPIKE; spr.centered = false
	area.add_child(spr)
	var shape := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()
	rect.size = Vector2(22, 22)
	shape.shape = rect
	shape.position = Vector2(TILE * 0.5, TILE * 0.5)
	area.add_child(shape); level.add_child(area)


func _build_chest(cell: Vector2i) -> void:
	var chest := Area2D.new()
	chest.set_script(CHEST_SCRIPT)
	chest.position = Vector2(cell.x * TILE, cell.y * TILE - 4.0)

	var drop_chance := LootConfig.drop_chance
	if player.has_method("get_loot_chance_pct"):
		drop_chance *= 1.0 + float(player.get_loot_chance_pct()) / 100.0

	var loot: Array[Dictionary] = []
	var chest_slots: Dictionary = {}
	for _i in LootConfig.rolls_per_chest:
		if rng.randf() < drop_chance:
			var id := ItemDB.random_id()
			if id == "":
				continue
			var item: Dictionary = ItemDB.get_item(id)
			var grade: String = str(item.get("grade", ""))
			if grade != "" and rng.randf() >= GradeDB.get_drop_mult(grade):
				continue
			var slot: String = str(item.get("slot", ""))
			if slot != "" and item.get("type", "") != "potion":
				if chest_slots.has(slot):
					continue
				chest_slots[slot] = true
			loot.append(LootConfig.roll_instance(id))
	chest.loot_items = loot

	var spr := Sprite2D.new(); spr.name = "Sprite2D"; spr.centered = false
	chest.add_child(spr)
	var shape := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()
	rect.size = Vector2(26, 26)
	shape.shape = rect; shape.position = Vector2(16, 18)
	chest.add_child(shape); level.add_child(chest)


# ── Respawning ────────────────────────────────────────────────────────────────

func _try_spawn_enemy() -> void:
	if level == null or _enemy_spawn_cells.is_empty(): return
	if get_tree().get_nodes_in_group("enemy").size() >= MAX_ENEMIES: return
	var pc := Vector2i(int(player.global_position.x / TILE),
	                   int(player.global_position.y / TILE))
	for _attempt in 20:
		var cell: Vector2i = _enemy_spawn_cells[
			rng.randi_range(0, _enemy_spawn_cells.size() - 1)]
		if absi(cell.x - pc.x) + absi(cell.y - pc.y) >= MIN_ENEMY_DIST:
			_build_enemy(cell)
			return


# ── Event handlers ────────────────────────────────────────────────────────────

func _loc_name(loc: String) -> String:
	match loc:
		"forest":  return "Лес"
		"cave":    return "Пещера"
		"swamp":   return "Болото"
		"ruins":   return "Руины"
		"volcano": return "Вулкан"
		_:         return "Замок"


func _on_boss_defeated() -> void:
	await get_tree().create_timer(1.0).timeout
	var pos := player.global_position
	dungeon_level += 1
	var candidates: Array[String] = []
	for loc: String in ALL_LOCATIONS:
		if loc != _location: candidates.append(loc)
	_location = candidates[rng.randi_range(0, candidates.size() - 1)]
	_generate_level(false)
	_show_message("%s — уровень %d" % [_loc_name(_location), dungeon_level], pos)


func _on_player_died() -> void:
	await get_tree().create_timer(1.0).timeout
	GameEvents.reset_ui()
	if stats_window != null: stats_window.force_close()
	$InventoryUI.force_close()
	var pos := player.global_position
	player.full_reset()
	dungeon_level = 1
	_location = "castle"
	_need_class_select = true
	_generate_level(false)
	_show_message("Вы погибли. Начало заново.", pos)


func _on_restart_requested() -> void:
	GameEvents.reset_ui()
	if stats_window != null: stats_window.force_close()
	$InventoryUI.force_close()
	player.full_reset()
	dungeon_level = 1
	_location = "castle"
	_need_class_select = true
	_generate_level(false)
	_show_message("Новая попытка!", player.global_position)


func _show_message(text: String, pos: Vector2) -> void:
	var txt := Node2D.new()
	txt.set_script(FLOAT_SCRIPT)
	add_child(txt)
	txt.global_position = pos + Vector2(-70.0, -20.0)
	txt.lifetime = 2.5
	txt.setup(text, Color(1.0, 0.9, 0.4))


# ── HUD callbacks ─────────────────────────────────────────────────────────────

func _on_health_changed(current: int, max_h: int) -> void:
	hp_label.text = "HP: %d/%d" % [current, max_h]

func _on_mana_changed(current: int, max_m: int) -> void:
	mp_label.text = "MP: %d/%d" % [current, max_m]


# ── Grid helpers ──────────────────────────────────────────────────────────────

func _carve_rect(grid: PackedInt32Array, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			grid[y * GRID_W + x] = 1


func _room_center(rect: Rect2i) -> Vector2i:
	return Vector2i(rect.position.x + rect.size.x / 2,
	                rect.position.y + rect.size.y / 2)


func _carve_corridor(grid: PackedInt32Array, a: Vector2i, b: Vector2i) -> void:
	var half := CORRIDOR_WIDTH / 2
	for x in range(min(a.x, b.x), max(a.x, b.x) + 1):
		for dy in range(-half, CORRIDOR_WIDTH - half):
			var yy := a.y + dy
			if yy >= 0 and yy < GRID_H: grid[yy * GRID_W + x] = 1
	for y in range(min(a.y, b.y), max(a.y, b.y) + 1):
		for dx in range(-half, CORRIDOR_WIDTH - half):
			var xx := b.x + dx
			if xx >= 0 and xx < GRID_W: grid[y * GRID_W + xx] = 1


func _has_floor_neighbor(grid: PackedInt32Array, x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0: continue
			var nx := x + dx; var ny := y + dy
			if nx >= 0 and nx < GRID_W and ny >= 0 and ny < GRID_H:
				if grid[ny * GRID_W + nx] == 1: return true
	return false


func _pick_cells(candidates: Array[Vector2i], count: int,
                 min_gap: int, used: Array[Vector2i]) -> Array[Vector2i]:
	var picked: Array[Vector2i] = []
	if candidates.is_empty(): return picked
	var attempts := 0
	while picked.size() < count and attempts < 200:
		attempts += 1
		var c: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		var ok := true
		for u: Vector2i in used:
			if absi(u.x - c.x) + absi(u.y - c.y) < min_gap: ok = false; break
		if ok:
			for p: Vector2i in picked:
				if absi(p.x - c.x) + absi(p.y - c.y) < min_gap: ok = false; break
		if ok: picked.append(c)
	return picked


func _farthest_cell(cells: Array[Vector2i], from: Vector2i) -> Vector2i:
	var best := from; var best_d := -1.0
	for c: Vector2i in cells:
		var d := absf(float(c.x - from.x)) + absf(float(c.y - from.y))
		if d > best_d: best_d = d; best = c
	return best


func _enemy_level(cell: Vector2i) -> int:
	var dist := absf(float(cell.x - _spawn_cell.x)) + absf(float(cell.y - _spawn_cell.y))
	return clampi(dungeon_level + int(floorf(dist / LEVEL_STEP_TILES)),
	              dungeon_level, dungeon_level + MAX_ENEMY_LEVEL - 1)


func _frame_paths(data: Dictionary, field: String, _fallback: String, count: int) -> Array[String]:
	var raw: Array = data.get(field, [])
	var out: Array[String] = []
	if raw.is_empty():
		for i in count: out.append("%s%d.png" % [_fallback, i])
	else:
		for p in raw: out.append(str(p))
	return out
