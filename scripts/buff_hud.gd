extends Control

const STAT_LABELS: Dictionary = {
	"strength":     "Сила",
	"agility":      "Ловкость",
	"vitality":     "Живучесть",
	"intelligence": "Интеллект"
}

var stats_ref: Node = null
var _rows: Dictionary = {}   # stat -> Label

func setup(st: Node) -> void:
	stats_ref = st

func _ready() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)
	for stat: String in STAT_LABELS.keys():
		var bg := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.05, 0.14, 0.82)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(3)
		bg.add_theme_stylebox_override("panel", style)
		bg.visible = false

		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.78, 0.55, 1.0))
		bg.add_child(lbl)
		_rows[stat] = bg
		vbox.add_child(bg)

func _process(_delta: float) -> void:
	if stats_ref == null:
		return
	var buffs: Dictionary = stats_ref.get_active_buffs()
	for stat: String in STAT_LABELS.keys():
		var bg: PanelContainer = _rows.get(stat, null)
		if bg == null:
			continue
		if buffs.has(stat):
			var val: int = int(buffs[stat].get("value", 0))
			var timer: float = float(buffs[stat].get("timer", 0.0))
			var lbl: Label = bg.get_child(0)
			lbl.text = "+%d %s  %.0fс" % [val, str(STAT_LABELS.get(stat, stat)), timer]
			bg.visible = true
		else:
			bg.visible = false
