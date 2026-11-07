extends SceneTree
var checks := 0
var failures := 0
var battle: Control

func _initialize() -> void:
	run.call_deferred()

func require(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func run() -> void:
	battle = load("res://main.tscn").instantiate()
	battle.set_script(load("res://tests/capture_battle.gd"))
	battle.save_path = OS.get_environment("WITCHBURST_TEST_ROOT").path_join("ui-check.json")
	root.add_child(battle)
	battle.set_process(false)
	battle.sound.enabled = false
	battle._refresh_ui()
	require(battle.status_label.z_index > battle.bar.z_index and battle.timer_label.z_index > battle.bar.z_index,"필수 진행/시간 글자가 바보다 앞에 표시됨")
	require(battle.upgrades.attack.state == "need" and battle.upgrades.attack.value == "6", "부족해도 현재 능력은 유지 표시")
	battle.coins = 1000000000
	battle.materials = 1000000000
	battle._refresh_ui()
	for dimensions in [Vector2(540,960),Vector2(540,1200),Vector2(720,960)]:
		battle.size = dimensions
		battle._layout_ui()
		for label in [battle.wallet_label,battle.leaf_label,battle.timer_label]:
			var measured: Vector2 = label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size"))
			require(measured.x <= label.size.x, "최대 자원 글자가 실제 표시 폭에 들어감")
		require(not battle.wallet_label.get_rect().intersects(battle.leaf_label.get_rect()) and not battle.leaf_label.get_rect().intersects(battle.sound_button.get_rect()), "자원과 소리 터치 영역 분리")
		for button in [battle.sound_button,battle.skill_button,battle.workshop_button,battle.upgrades.attack]:
			require(button.size.x >= 48 and button.size.y >= 48,"필수 터치 영역 유지")
	battle.levels.attack = 2
	battle.levels.speed = 1
	battle._refresh_ui()
	require(battle.upgrades.attack.detail.contains("다음 20"),"현재/다음 반올림을 독립 델타로 합산해 오표시하지 않음")
	require(battle.upgrades.speed.detail.contains("다음 1.4/초"),"속도는 실제 다음 절대값을 표시")
	battle.levels.attack = 20
	battle.levels.speed = 9
	battle._refresh_ui()
	require(battle.upgrades.attack.state == "max" and battle.upgrades.attack.disabled,"최대 강화 상태")
	require(battle.upgrades.speed.detail.contains("속도 상한"),"속도 하한 뒤 거짓 다음 상승 없음")
	battle.inventory = [9998,9998,1]
	battle._refresh_ui()
	require(battle.draw_button.disabled and battle.craft_button.disabled and battle.merge_button.disabled,"재화 외 기존 보유량 제한 반영")
	var before: Dictionary = battle.progress_data().duplicate(true)
	require(battle.draw_tool() == -1 and not battle.craft_tool(),"표시된 한도와 실제 함수 일치")
	battle._merge_available()
	require(before == battle.progress_data(),"합성은 기존 낮은 등급 우선과 한도 유지")
	battle.pending_coins = 100
	battle._refresh_ui()
	require(battle.claim_button.disabled and battle.claim_button.text.contains("한도") and not battle.claim_offline(),"미수령액 있어도 수령 후 재화 한도 표시")
	battle.coins = 0
	battle._refresh_ui()
	require(not battle.claim_button.disabled and battle.claim_offline() and battle.coins == 100 and battle.pending_coins == 0,"수령 가능은 실제 파일 확정과 연결")
	battle.inventory = [1,1,1]
	battle.equipped = 1
	battle.spirit = true
	battle._refresh_ui()
	require(battle.equip_buttons[1].state == "equipped" and battle.equip_buttons[0].state == "ready", "장착 완료와 장착 가능 구분")
	battle._start_boss()
	battle.toggle_workshop()
	var hp: float = battle.boss_hp
	require(battle.skill_button.disabled and battle.skill_button.text.contains("정지") and not battle.cast_skill() and battle.boss_hp == hp,"공방 일시정지 안내와 별비 실행 조건 일치")
	battle.toggle_workshop()
	require(not battle.skill_button.disabled and battle.cast_skill(),"공방 닫고 실제 스킬 재개")
	battle.boss_cleared = true
	battle.rebirths = 0
	battle._finish(false)
	require(not battle.result_panel.visible,"정화·실패 반응을 먼저 보이는 짧은 결과 전환")
	battle.advance(.5)
	battle.notice_time = 100
	battle.notice = "가시왕 등장! 별비 준비"
	battle._refresh_ui()
	require(battle.result_panel.visible and battle.rebirth_button.visible and battle.result_text.text.contains("미수령 보상") and battle.result_text.text.contains("보존"),"승리 후 패배에서도 환생 초기화/보존 안내")
	require(not battle.hint_label.text.contains("자동 사격") and not battle.hint_label.text.contains("등장") and battle.timer_label.text == "종료" and battle.skill_button.cooldown_ratio == 0.0,"패배 시 이전 보스 안내·전투중·쿨다운 표시가 남지 않음")
	battle.rebirths = 1000
	battle._refresh_ui()
	require(battle.rebirth_button.disabled and battle.result_text.text.contains("1,000") and not battle.rebirth(),"환생 최대 표시와 실행 조건 일치")
	# 정지 캡처의 custom_step과 별개로 정상 엔진 시간에서도 누름/복귀를 확인한다.
	battle.levels.attack = 0
	battle.coins = 1000
	battle.phase = battle.Phase.FOREST
	battle.workshop.visible = true
	battle._refresh_ui()
	var button: Button = battle.upgrades.attack
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle.set_process(true)
	# filter 변경으로 예약된 mouse_exit를 준비 단계에서 소진한다.
	await process_frame
	await process_frame
	button.button_down.emit()
	await create_timer(.20).timeout
	require(button.press_amount > .99,"정상 엔진 시간에서 누름 반응 도달")
	button.button_up.emit()
	await create_timer(.20).timeout
	require(button.press_amount < .01,"정상 엔진 시간에서 누름 해제 복귀")
	battle.set_process(false)
	battle.free()
	print("UI 상태·안내·실행 회귀: ",checks,"개, 실패 ",failures)
	quit(1 if failures else 0)
