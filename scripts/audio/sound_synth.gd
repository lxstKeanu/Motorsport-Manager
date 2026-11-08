class_name SoundSynth
## Звуки игры, синтезированные кодом: щелчки интерфейса, уведомления, музыка и фон гаража.
## Своих записей пока нет, поэтому всё собирается из синусов и шума. Случайности с постоянным
## зерном: каждый раз звучит одинаково. Музыка и фон зациклены без щелчка на стыке.

const RATE := 22050
## Частоты нот от ля первой октавы.
const A4 := 440.0


static func make(sound_name: String) -> AudioStreamWAV:
	match sound_name:
		"click":
			return click()
		"hover":
			return hover()
		"chime":
			return chime()
		"coin":
			return coin()
		"clank":
			return clank()
		"music_menu":
			return music([[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]], 80.0, 0.9)
		"music_garage":
			return music([[50, 53, 57], [46, 50, 53], [53, 57, 60], [48, 52, 55]], 68.0, 0.7)
		"ambience_day":
			return ambience(false)
		"ambience_night":
			return ambience(true)
	return null


## Короткий сухой щелчок кнопки.
static func click() -> AudioStreamWAV:
	var samples := _buffer(0.05)
	var rng := _rng(1)
	for i in samples.size():
		var t := float(i) / RATE
		var envelope := exp(-t * 90.0)
		samples[i] = (sin(TAU * 1700.0 * t) * 0.6 + rng.randf_range(-1.0, 1.0) * 0.25) * envelope
	return _to_wav(samples, false, 0.5)


## Едва слышный тик при наведении.
static func hover() -> AudioStreamWAV:
	var samples := _buffer(0.025)
	for i in samples.size():
		var t := float(i) / RATE
		samples[i] = sin(TAU * 2600.0 * t) * exp(-t * 180.0)
	return _to_wav(samples, false, 0.25)


## Уведомление: две ноты вверх.
static func chime() -> AudioStreamWAV:
	var samples := _buffer(0.7)
	_bell(samples, 0.0, _note(76), 0.55, 6.0)
	_bell(samples, 0.12, _note(83), 0.5, 5.0)
	return _to_wav(samples, false, 0.55)


## Зарплата: звон монет — быстрые высокие ноты с металлическим призвуком.
static func coin() -> AudioStreamWAV:
	var samples := _buffer(0.6)
	for step in 3:
		var start := step * 0.07
		_bell(samples, start, _note(84 + step * 3), 0.4, 9.0)
		_bell(samples, start, _note(84 + step * 3) * 2.76, 0.12, 14.0)
	return _to_wav(samples, false, 0.55)


## Задача выполнена: удар по металлу — негармоничные призвуки, быстро затухают.
static func clank() -> AudioStreamWAV:
	var samples := _buffer(0.6)
	var partials := [[420.0, 1.0, 9.0], [1013.0, 0.6, 14.0], [1690.0, 0.4, 18.0], [2470.0, 0.25, 24.0]]
	var rng := _rng(2)
	for i in samples.size():
		var t := float(i) / RATE
		var value := rng.randf_range(-1.0, 1.0) * 0.3 * exp(-t * 120.0)
		for partial: Array in partials:
			value += sin(TAU * partial[0] * t) * partial[1] * exp(-t * partial[2])
		samples[i] = value
	return _to_wav(samples, false, 0.5)


## Зацикленная мелодия: на каждый аккорд такт из четырёх долей. Пэд из аккорда,
## арпеджио восьмыми и бас на сильных долях. Ноты пишутся по кругу, поэтому хвосты
## последнего аккорда плавно уходят в начало и стык не слышен.
static func music(chords: Array, bpm: float, brightness: float) -> AudioStreamWAV:
	var beat := 60.0 / bpm
	var bar := beat * 4.0
	var samples := _buffer(bar * chords.size())
	var size := samples.size()
	for c in chords.size():
		var chord: Array = chords[c]
		var bar_start := int(c * bar * RATE)
		# Пэд: мягкая атака и долгий хвост в следующий такт.
		for midi: int in chord:
			var frequency := _note(midi)
			var length := int((bar + beat) * RATE)
			for i in length:
				var t := float(i) / RATE
				var envelope := minf(t / 0.6, 1.0) * clampf((bar + beat - t) / (beat * 1.5), 0.0, 1.0)
				var value := sin(TAU * frequency * t) + 0.25 * sin(TAU * frequency * 2.0 * t + 0.4)
				samples[(bar_start + i) % size] += value * envelope * 0.12
		# Арпеджио восьмыми по нотам аккорда на октаву выше.
		var pattern := [0, 1, 2, 1, 0, 2, 1, 2]
		for step in 8:
			var frequency := _note(int(chord[pattern[step]]) + 12)
			var start := bar_start + int(step * beat * 0.5 * RATE)
			var length := int(0.6 * RATE)
			for i in length:
				var t := float(i) / RATE
				var envelope := minf(t / 0.005, 1.0) * exp(-t * 7.0)
				var value := sin(TAU * frequency * t) + brightness * 0.3 * sin(TAU * frequency * 3.0 * t)
				samples[(start + i) % size] += value * envelope * 0.1
		# Бас: корень аккорда двумя октавами ниже на первой и третьей доле.
		for half in 2:
			var frequency := _note(int(chord[0]) - 12)
			var start := bar_start + int(half * beat * 2.0 * RATE)
			var length := int(beat * 2.0 * RATE)
			for i in length:
				var t := float(i) / RATE
				var envelope := minf(t / 0.02, 1.0) * exp(-t * 1.6)
				samples[(start + i) % size] += sin(TAU * frequency * t) * envelope * 0.22
	return _to_wav(samples, true, 0.6)


## Фон гаража: ветер из отфильтрованного шума с медленной волной громкости.
## Днём поверх изредка поют птицы, ночью стрекочут сверчки.
static func ambience(night: bool) -> AudioStreamWAV:
	var seconds := 12.0
	var samples := _buffer(seconds)
	var size := samples.size()
	var rng := _rng(3 if night else 4)
	var low := 0.0
	var lower := 0.0
	for i in size:
		var t := float(i) / RATE
		low += 0.02 * (rng.randf_range(-1.0, 1.0) - low)
		lower += 0.02 * (low - lower)
		# Волна громкости укладывается в длину петли ровно дважды.
		var gust := 0.6 + 0.4 * sin(TAU * t * 2.0 / seconds)
		samples[i] = lower * gust * (6.0 if night else 9.0)
	# Шум на стыке сводим перекрёстным затуханием.
	var fade := int(0.5 * RATE)
	for i in fade:
		var k := float(i) / fade
		samples[i] = samples[i] * k + samples[size - fade + i] * (1.0 - k)
	if night:
		# Сверчки: пачки коротких щелчков высокого тона.
		var chirp := 0.0
		while chirp < seconds:
			var start := int(chirp * RATE)
			for pulse in 3:
				for i in int(0.03 * RATE):
					var t := float(i) / RATE
					samples[(start + int(pulse * 0.045 * RATE) + i) % size] += sin(TAU * 4400.0 * t) * sin(PI * t / 0.03) * 0.05
			chirp += rng.randf_range(0.35, 0.8)
	else:
		# Птицы: короткие трели — частота скользит вверх-вниз.
		var next_call := rng.randf_range(0.5, 1.5)
		while next_call < seconds - 1.0:
			var base := rng.randf_range(2600.0, 3800.0)
			var notes := rng.randi_range(2, 4)
			for n in notes:
				var start := int((next_call + n * 0.13) * RATE)
				var length := int(0.09 * RATE)
				var phase := 0.0
				for i in length:
					var t := float(i) / RATE
					var frequency := base + 900.0 * sin(PI * t / 0.09)
					phase += TAU * frequency / RATE
					samples[(start + i) % size] += sin(phase) * sin(PI * t / 0.09) * 0.07
			next_call += rng.randf_range(1.5, 3.5)
	return _to_wav(samples, true, 0.35)


# --- Помощники ---

## Звонкая нота: синус с быстрой атакой и экспоненциальным затуханием.
static func _bell(samples: PackedFloat32Array, start_seconds: float, frequency: float, volume: float, decay: float) -> void:
	var start := int(start_seconds * RATE)
	for i in range(start, samples.size()):
		var t := float(i - start) / RATE
		samples[i] += sin(TAU * frequency * t) * volume * minf(t / 0.004, 1.0) * exp(-t * decay)


static func _note(midi: int) -> float:
	return A4 * pow(2.0, (midi - 69) / 12.0)


static func _buffer(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(seconds * RATE))
	return samples


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Нормирует громкость до peak, мягко ограничивает и упаковывает в 16-битный WAV.
static func _to_wav(samples: PackedFloat32Array, looped: bool, peak: float) -> AudioStreamWAV:
	var loudest := 0.0001
	for value in samples:
		loudest = maxf(loudest, absf(value))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	var gain := peak / loudest
	for i in samples.size():
		data.encode_s16(i * 2, int(tanh(samples[i] * gain) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav
