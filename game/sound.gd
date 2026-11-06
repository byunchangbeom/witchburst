extends Node
## 외부 음원 없이 수학 함수로 만든 짧은 마법 효과음.

var enabled := true
var voices: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}

func _ready() -> void:
	for i in range(6):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -19.0
		add_child(voice)
		voices.append(voice)
	for kind in ["shot", "hit", "reward", "upgrade", "skill", "win", "lose"]:
		sounds[kind] = _make_sound(kind)

func play(kind: String) -> void:
	if not enabled or DisplayServer.get_name() == "headless":
		return
	for voice in voices:
		if not voice.playing:
			voice.stream = sounds[kind]
			voice.play()
			return

func _make_sound(kind: String) -> AudioStreamWAV:
	var duration := 0.09
	var frequency := 620.0
	match kind:
		"hit": frequency = 240.0
		"reward": frequency = 1046.5; duration = 0.16
		"upgrade": frequency = 523.25; duration = 0.32
		"skill": frequency = 140.0; duration = 0.4
		"win": frequency = 659.25; duration = 0.6
		"lose": frequency = 220.0; duration = 0.35
	var bytes := PackedByteArray()
	var count := int(22050 * duration)
	bytes.resize(count * 2)
	for i in range(count):
		var t := float(i) / 22050.0
		var progress := t / duration
		var pitch := frequency * (1.0 + progress * (1.1 if kind != "lose" else -0.5))
		var wave := sin(TAU * pitch * t) * 0.75 + sin(TAU * pitch * 2.0 * t) * 0.25
		var envelope := minf(t * 120.0, 1.0) * pow(1.0 - progress, 2.0)
		bytes.encode_s16(i * 2, int(wave * envelope * 13000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = bytes
	return stream
