extends SceneTree
var checks := 0
var failures := 0
var serial := 0
func _initialize() -> void:
	run.call_deferred()
func require(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+message)
func fresh() -> Control:
	var b = load("res://main.tscn").instantiate()
	serial += 1
	b.save_path = OS.get_environment("WITCHBURST_TEST_ROOT").path_join("action-%d.json"%serial)
	root.add_child(b)
	b.set_process(false)
	b.sound.enabled = false
	return b
func run() -> void:
	var b := fresh()
	var m: Node2D = b.visuals.motion
	for tier in [0,3]:
		b.inventory = [1,1,1]
		b.equipped = tier-1
		b._start_boss()
		b.visuals.sync(0.0)
		var before := [b.enemies[0].hp,b.cooldown,b.skill_uses]
		b.skill_button.button_down.emit()
		b.visuals.sync(.016)
		require(m.state=="skill_prepare" and m.pose_key.ends_with("actions") and m.witch.frame%8==5,"실제 버튼 down의 고유 준비 자세")
		require(before==[b.enemies[0].hp,b.cooldown,b.skill_uses],"준비는 피해/쿨다운/실행 횟수를 바꾸지 않음")
		var gait_frames := {}
		for i in range(12):
			b.witch.x += 3
			b.visuals.sync(1.0/24.0)
			gait_frames[m.legs.frame] = true
			require(m.legs.visible and m.legs.frame/4==2 and m.state=="skill_prepare","조준N 준비 중 이동E 하체 프레임 독립 재생")
		require(gait_frames.size()==4,"이동 시전은 실제 네 다리 자세를 유지")
		b.skill_button.mouse_exited.emit()
		b.visuals.sync(.016)
		require(m.state=="skill_settle" and not m.skill_preparing,"누른 채 이탈하면 회복 자세로 취소")
		require(before==[b.enemies[0].hp,b.cooldown,b.skill_uses],"입력 취소에 피해/쿨다운/중복 이벤트 없음")
		b.skill_button.button_down.emit()
		require(b.cast_skill(),"기존 입력 발동은 즉시 수용")
		b.visuals.sync(0.0)
		require(b.skill_uses==before[2]+1 and b.enemies[0].hp<before[0] and b.cooldown==b.SKILL_COOLDOWN,"자세를 기다리지 않고 같은 시점에 기존 피해/쿨다운 발생")
		require(m.skill_targets.size()==1 and m.skill_targets[0].distance_to(b.visuals._point(b.enemies[0].pos))<.01,"별비 도착은 고정 필드가 아니라 판정 순간 실제 표적")
		require(m.state=="skill_release" and m.witch.frame%8==6,"일반 사격과 다른 고유 별비 방출")
		b._fire()
		b.visuals.sync(0.0)
		require(m.state=="skill_release","동시 자동사격이 별비 자세를 덮지 않음")
		var uses: int = b.skill_uses
		require(not b.cast_skill() and b.skill_uses==uses,"연타로 스킬/피해 이벤트 중복 없음")
		b.toggle_workshop()
		var paused: float = m.clock
		var paused_frame: int = m.witch.frame
		for i in range(4):b.visuals.sync(.1)
		require(m.clock==paused and m.witch.frame==paused_frame,"공방에서 시전 프레임/시계 동결")
		b.toggle_workshop()
		m.clock = m.skill_at+.2
		b.visuals.sync(0.0)
		require(m.state=="skill_recover" and m.witch.frame%8==7,"별비 고유 회복으로 연결")
		m.clock = m.skill_at+.5
		b.shot_clock = 10.0
		b.visuals.sync(0.0)
		require(m.state=="ready","회복 뒤 대기로 복귀")
		# 피격은 적에게만 존재한다. 실제 기존 판정을 사용한다.
		var enemy: Dictionary = b.enemies[0]
		b._hit(enemy,1)
		b.visuals.sync(0.0)
		require(m.enemies[enemy.id].frame==6,"가시왕 피격은 정화 웃음 대신 웅크린 자세")
		b._finish(false)
		b.restart_battle()
		b.visuals.sync(.016)
		require(m.skill_at < 0 and m.shot_at < 0 and not m.skill_preparing,"재도전 시 공격/스킬 상태 초기화")
		b.visuals.sync(0.0)
		require(m.ghosts.is_empty(),"살아 있는 적의 phase 교체는 정화 사망을 만들지 않음")
	b._start_boss()
	b.visuals.sync(0.0)
	b.skill_button.button_down.emit()
	b._handle_lifecycle(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	require(not m.skill_preparing and b.is_suspended(),"실제 포커스 상실이 준비를 취소하고 기존 suspend 유지")
	b._handle_lifecycle(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	require(not b.is_suspended() and not m.skill_preparing,"복귀에 눌린 준비 자세가 잔류하지 않음")
	b.free()
	# 서로 다른 시각 상태/시계가 동일한 규칙 리플레이 결과를 바꾸지 않아야 한다.
	var a := fresh()
	var c := fresh()
	for i in range(360):
		for v in [a,c]:v.advance(1.0/60.0)
		a.visuals.sync(1.0/60.0)
		if i%30==0:
			c.visuals.sync(0.0)
			require(a.witch==c.witch and a.total_shots==c.total_shots and a.total_hits==c.total_hits and a.coins==c.coins and a.kills==c.kills and a.phase==c.phase,"다른 시각 재생 빈도에도 이동/발사/명중/보상/phase 동일")
	# 마지막 시선·위상 유지, 방향 전환은 이동을 지연하지 않는다.
	var motion: Node2D = a.visuals.motion
	a.shot_clock = 10.0
	motion.reset_actions()
	motion.previous_rule = a.witch
	a.witch.x += 8
	a.visuals.sync(.1)
	var stride: float = motion.stride
	a.witch.x -= 8
	var position: Vector2 = a.witch
	a.visuals.sync(.016)
	require(motion.state=="turn" and motion.facing=="W" and a.witch==position and motion.stride>stride,"턴 자세 중에도 기존 이동/위상 즉시 보존")
	motion.clock += .2
	a.visuals.sync(.016)
	require(motion.facing=="W" and not motion.moving,"정지 뒤 마지막 시선 유지")
	a.free()
	c.free()
	print("행동·취소·규칙 보존 회귀: ",checks,"개, 실패 ",failures)
	quit(1 if failures else 0)
