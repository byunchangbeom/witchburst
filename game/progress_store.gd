extends RefCounted
## 단일 작성자 로컬 JSON. 교체에 성공한 스냅샷만 게임에 반영한다.
const VERSION := 1
const MAX_OFFLINE := 86400
var path := "user://progress.json"
var error_message := ""
var recovered := false

func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high

func valid(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	for key in ["schema_version", "local_owner_id", "saved_at", "reward_cursor", "pending_coins", "coins", "materials", "levels", "inventory", "equipped", "spirit", "rebirths", "boss_cleared"]:
		if not data.has(key):
			return false
	if data.schema_version != VERSION or not data.local_owner_id is String or data.local_owner_id.length() != 32 or not data.local_owner_id.is_valid_hex_number():
		return false
	for key in ["saved_at", "reward_cursor"]:
		if not _integer(data[key], 0, 4102444800):
			return false
	for key in ["pending_coins", "coins", "materials"]:
		if not _integer(data[key], 0, 1000000000):
			return false
	if not data.levels is Dictionary or data.levels.size() != 3:
		return false
	for key in ["attack", "speed", "yield"]:
		if not data.levels.has(key) or not _integer(data.levels[key], 0, 20):
			return false
	if not data.inventory is Array or data.inventory.size() != 3:
		return false
	for count in data.inventory:
		if not _integer(count, 0, 9999):
			return false
	if not _integer(data.equipped, -1, 2) or not _integer(data.rebirths, 0, 1000):
		return false
	if data.equipped >= 0 and data.inventory[int(data.equipped)] < 1:
		return false
	return data.spirit is bool and data.boss_cleared is bool

func _read(filename: String) -> Variant:
	if not FileAccess.file_exists(filename):
		return null
	var file := FileAccess.open(filename, FileAccess.READ)
	if file == null or file.get_length() > 65536:
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	return parser.data if valid(parser.data) else null

func write(data: Dictionary) -> bool:
	error_message = ""
	if not valid(data):
		error_message = "저장 데이터 검증 실패"
		return false
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		error_message = "저장 경로를 열 수 없어요"
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var status := file.get_error()
	file.close()
	if status != OK or _read(temp) == null:
		error_message = "임시 저장 검증 실패"
		return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(path)) != OK:
		error_message = "원자 저장 교체 실패"
		return false
	# 백업도 최신 스냅샷이다. 복구 시에는 오프라인 재발행을 금지한다.
	var backup_temp := path + ".bak.tmp"
	if DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup_temp)) == OK:
		DirAccess.rename_absolute(ProjectSettings.globalize_path(backup_temp), ProjectSettings.globalize_path(path + ".bak"))
	return true

func load_progress(now: int) -> Dictionary:
	recovered = false
	var data: Variant = _read(path)
	if data == null and FileAccess.file_exists(path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".invalid-" + str(Time.get_ticks_usec())))
	if data == null:
		data = _read(path + ".bak")
		recovered = data != null
		if data == null and FileAccess.file_exists(path + ".bak"):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(path + ".bak"), ProjectSettings.globalize_path(path + ".bak.invalid-" + str(Time.get_ticks_usec())))
	if data == null:
		return {}
	var original: Dictionary = data.duplicate(true)
	var timestamp := clampi(now, 0, 4102444800)
	var gap := mini(MAX_OFFLINE, maxi(0, timestamp - int(data.reward_cursor)))
	if recovered:
		# 오래된 백업에서 이미 수령한 보상이 재발행되지 않도록 보수적으로 폐기한다.
		data.pending_coins = 0
		gap = 0
	data.pending_coins = mini(1440 * (2 + int(data.rebirths)), int(data.pending_coins) + int(gap / 60) * (2 + int(data.rebirths)))
	data.reward_cursor = maxi(int(data.reward_cursor), timestamp)
	data.saved_at = maxi(int(data.saved_at), timestamp)
	if not write(data):
		# 지급 기준을 디스크에 확정하지 못하면 새 보상은 노출하지 않는다.
		original.pending_coins = 0
		return original
	return data
