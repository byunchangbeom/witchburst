extends RefCounted
## 호스트가 공급한 원본 UI 자산을 재사용한다. 텍스트/수치는 런타임 상태에서 그린다.
const ICONS = preload("res://assets/art/ui-icons.png")
const TOOLS = preload("res://assets/art/ui-tools.png")
const PANELS = preload("res://assets/art/ui-panels.png")
static var icons: Dictionary = {}
static var panels: Dictionary = {}
static var metadata: Dictionary = {}

static func _ready_data() -> void:
	if metadata.is_empty():
		metadata = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/ui-atlas.json"))

static func icon(symbol: String) -> Texture2D:
	_ready_data()
	var names := ["cannon","speed","leaf","book","star","coin","material","sound","tool0","tool1","tool2"]
	var index := names.find(symbol)
	if index < 0:
		index = 4
	if not icons.has(index):
		var region: Array = metadata.tools.regions[index-8] if index >= 8 else metadata.icons.regions[index]
		var atlas := AtlasTexture.new()
		atlas.atlas = TOOLS if index >= 8 else ICONS
		atlas.region = Rect2(region[0],region[1],region[2],region[3])
		atlas.filter_clip = true
		icons[index] = atlas
	return icons[index]

static func panel(index: int = 0, tint: Color = Color.WHITE) -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = [Color("f1e7ce"),Color("88dfc4"),Color("9cdea8"),Color("efc264")][index]*tint
	style.border_color = Color("543b27")
	style.set_border_width_all(3)
	style.set_corner_radius_all(9)
	style.set_content_margin_all(7)
	return style

static func compact(value: float) -> String:
	if absf(value) >= 1000000000000.0:
		return "%.1f조" % (value / 1000000000000.0)
	if absf(value) >= 100000000.0:
		return "%.1f억" % (value / 100000000.0)
	if absf(value) >= 10000.0:
		return "%.1f만" % (value / 10000.0)
	return str(roundi(value))
