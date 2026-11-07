extends "res://battle.gd"
## 캡처 fixture만 호스트 창 알림과 분리한다. 제품 알림 회귀는 원본 battle.gd를 사용한다.
var ignored_host_notifications: Array[int] = []

func _handle_lifecycle(what: int, _now: int = -1) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_RESUMED,
			NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		ignored_host_notifications.append(what)
