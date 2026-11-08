extends Node
## Звук игры: щелчки кнопок, уведомления, музыка меню и гаража, фон гаража (днём птицы, ночью сверчки).
## Звуки синтезируются кодом (SoundSynth) в фоновом потоке при запуске, чтобы меню не подвисало.
## Если положить запись в assets/audio/<имя>.ogg или .wav, она заменит синтезированный звук.
## Громкость задают шины Music и SFX из настроек.

const OVERRIDE_PATHS: Array[String] = ["res://assets/audio/%s.ogg", "res://assets/audio/%s.wav"]
## Сначала короткие звуки интерфейса — они нужны сразу, потом музыка и фон.
const ALL_SOUNDS: Array[String] = [
	"click", "hover", "chime", "coin", "clank",
	"music_menu", "music_garage", "ambience_day", "ambience_night",
]
const SFX_VOLUME := {"click": -6.0, "hover": -18.0, "chime": -4.0, "coin": -3.0, "clank": -5.0}
const MUSIC_VOLUME := -8.0
const AMBIENCE_VOLUME := -10.0
const FADE_SECONDS := 1.2
const SFX_VOICES := 6

## Последний сыгранный звук: для проверок и отладки.
var last_played := ""
var music_track := ""
var _streams := {}
var _mutex := Mutex.new()
var _thread: Thread
var _sfx: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music: AudioStreamPlayer
var _ambience := {}
var _wanted_ambience := ""
## Фон, который уже затихает: второй раз его не гасим.
var _fading_out := {}
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in SFX_VOICES:
		_sfx.append(_make_player(Settings.BUS_SFX))
	_music = _make_player(Settings.BUS_MUSIC)
	for night in [false, true]:
		_ambience[night] = _make_player(Settings.BUS_SFX)
	get_tree().node_added.connect(_on_node_added)
	_thread = Thread.new()
	_thread.start(_generate_all)


func _exit_tree() -> void:
	release_all()


## Глушит всё и отпускает звуки: при выходе из игры, чтобы ничего не утекло.
func release_all() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	if _music_tween != null:
		_music_tween.kill()
	music_track = ""
	_wanted_ambience = ""
	_fading_out.clear()
	for player in _sfx + [_music] + _ambience.values():
		(player as AudioStreamPlayer).stop()
		(player as AudioStreamPlayer).stream = null
	_mutex.lock()
	_streams.clear()
	_mutex.unlock()


## Пока фон генерируется, музыка и фон, которые уже попросили, запускаются, как только готовы.
func _process(_delta: float) -> void:
	if not music_track.is_empty() and _music.stream == null and has_sound(music_track):
		_start_music(music_track)
	if not _wanted_ambience.is_empty() and not _ambience_player(_wanted_ambience).playing:
		_apply_ambience()


func has_sound(sound_name: String) -> bool:
	_mutex.lock()
	var made := _streams.has(sound_name)
	_mutex.unlock()
	return made


## Звук по имени. Если фон ещё не успел его сделать, делает сразу.
func stream(sound_name: String) -> AudioStream:
	_mutex.lock()
	var cached: AudioStream = _streams.get(sound_name)
	_mutex.unlock()
	if cached != null:
		return cached
	var made := _load_or_make(sound_name)
	_mutex.lock()
	_streams[sound_name] = made
	_mutex.unlock()
	return made


func play(sound_name: String) -> void:
	if not has_sound(sound_name):
		return  # Короткий звук не готов в первые доли секунды — просто пропускаем.
	var player := _sfx[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx.size()
	player.stream = stream(sound_name)
	player.volume_db = SFX_VOLUME.get(sound_name, -6.0)
	player.play()
	last_played = sound_name


## Включает музыку с плавным переходом. Тот же трек не перезапускается.
func play_music(track: String) -> void:
	if track == music_track:
		return
	music_track = track
	if has_sound(track):
		_start_music(track)
	else:
		_music.stop()
		_music.stream = null


func stop_music() -> void:
	music_track = ""
	_fade(_music, -60.0, func() -> void:
		_music.stop()
		_music.stream = null)


## Фон гаража: дневной или ночной. Пустая строка — без фона.
func set_ambience(kind: String) -> void:
	_wanted_ambience = kind
	_apply_ambience()


func current_ambience() -> String:
	return _wanted_ambience


func _start_music(track: String) -> void:
	_music.stream = stream(track)
	_music.volume_db = -40.0
	_music.play()
	_fade(_music, MUSIC_VOLUME)


func _ambience_player(kind: String) -> AudioStreamPlayer:
	return _ambience[kind == "ambience_night"]


## Нужный фон плавно вступает, ненужный плавно затихает. Смена дня и ночи — перекрёстное затухание.
func _apply_ambience() -> void:
	for night: bool in _ambience:
		var player: AudioStreamPlayer = _ambience[night]
		var kind := "ambience_night" if night else "ambience_day"
		if kind == _wanted_ambience:
			if (player.playing and not _fading_out.has(kind)) or not has_sound(kind):
				continue
			_fading_out.erase(kind)
			if not player.playing:
				player.stream = stream(kind)
				player.volume_db = -40.0
				player.play()
			_fade(player, AMBIENCE_VOLUME)
		elif player.playing and not _fading_out.has(kind):
			_fading_out[kind] = true
			_fade(player, -40.0, func() -> void:
				if _fading_out.has(kind):
					_fading_out.erase(kind)
					player.stop())


func _fade(player: AudioStreamPlayer, target_db: float, then: Callable = Callable()) -> void:
	var tween := create_tween()
	tween.tween_property(player, "volume_db", target_db, FADE_SECONDS)
	if then.is_valid():
		tween.tween_callback(then)
	if player == _music:
		if _music_tween != null:
			_music_tween.kill()
		_music_tween = tween


## Каждая кнопка в игре щёлкает при нажатии и тихо тикает при наведении.
func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button == null:
		return
	button.pressed.connect(play.bind("click"))
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			play("hover"))


func _generate_all() -> void:
	for sound_name in ALL_SOUNDS:
		if has_sound(sound_name):
			continue
		var made := _load_or_make(sound_name)
		_mutex.lock()
		if not _streams.has(sound_name):
			_streams[sound_name] = made
		_mutex.unlock()


func _load_or_make(sound_name: String) -> AudioStream:
	for pattern in OVERRIDE_PATHS:
		var path := pattern % sound_name
		if ResourceLoader.exists(path):
			return load(path)
	return SoundSynth.make(sound_name)


func _make_player(bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player
