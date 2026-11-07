extends "res://battle.gd"
## 제품 알림·자동 재시도 경로에 재현 가능한 시계만 주입한다.
var test_time := 1000000

func _now() -> int:
	return test_time
