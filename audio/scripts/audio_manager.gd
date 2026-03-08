extends Node

static var _instance: AudioManager

static func summon() -> AudioManager:
	return _instance


enum EMusicState {
	None,     # default; no music state has been set yet
	Normal,
	Alart,
	MainMenu,
	Victory,
	Defeat,
	Romance,
	Tension,
}

# How long the music fades in when entering Normal state from silence.
const NORMAL_FADEIN_DURATION: float = 3.0

# How long a Normal-mode crossfade between background tracks takes.
const NORMAL_CROSSFADE_DURATION: float = 3.0

# How long each Normal-mode track plays before rotating to the next.
const NORMAL_TRACK_DURATION_SECS: float = 180.0  # 3 minutes


var audioData: AudioData

# Master volume for all music, in dB.  0 = full, -80 = silence.
# Changing this while music is playing takes effect on the next playMusic() call.
var musicVolumeDb: float = 0.0

var currentMusicState: EMusicState = EMusicState.None

# Two players cross-fade between each other.  _activePlayer is audible;
# _inactivePlayer is queued up to receive the next track.
var _playerA: AudioStreamPlayer
var _playerB: AudioStreamPlayer
var _activePlayer:   AudioStreamPlayer
var _inactivePlayer: AudioStreamPlayer

# Killed and replaced whenever a new fade begins.
var _activeMusicTween: Tween

# Fires every NORMAL_TRACK_DURATION_SECS while in Normal state to rotate tracks.
var _normalTrackTimer: Timer


func _ready() -> void:
	_instance = self

	audioData = load("res://audio/AudioData.tres") as AudioData
	if audioData == null:
		push_warning("AudioManager: AudioData.tres not found.")
		audioData = AudioData.new()

	_playerA      = AudioStreamPlayer.new()
	_playerB      = AudioStreamPlayer.new()
	_playerA.name = "MusicPlayerA"
	_playerB.name = "MusicPlayerB"
	_playerA.bus  = &"Music"
	_playerB.bus  = &"Music"
	add_child(_playerA)
	add_child(_playerB)

	_activePlayer   = _playerA
	_inactivePlayer = _playerB

	_normalTrackTimer          = Timer.new()
	_normalTrackTimer.name     = "NormalTrackTimer"
	_normalTrackTimer.one_shot = false
	_normalTrackTimer.wait_time = NORMAL_TRACK_DURATION_SECS
	_normalTrackTimer.timeout.connect(_onNormalTrackTimerTimeout)
	add_child(_normalTrackTimer)


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


# ── State ─────────────────────────────────────────────────────────────────────

func getMusicState() -> EMusicState:
	return currentMusicState;

# Transitions to a new music state.  Each state is responsible for starting
# its own music; add cases here as states are fleshed out.
func setMusicState(state: EMusicState) -> void:
	if state == currentMusicState:
		return
	var prevName := String(EMusicState.keys()[currentMusicState])
	currentMusicState = state
	Console.print_line("[AudioManager] Music state: %s → %s" % [prevName, EMusicState.keys()[state]])

	match currentMusicState:
		EMusicState.Normal:
			_enterNormal()
		EMusicState.Alart:
			_enterAlart()
		EMusicState.Tension:
			_enterTension()
		EMusicState.MainMenu:
			_enterMainMenu()
		EMusicState.Victory, EMusicState.Defeat:
			_enterGameOver()
		_:
			# Other states not yet implemented — stop the Normal rotation timer
			# so it doesn't fire while a different state is active.
			_normalTrackTimer.stop()


func _enterNormal() -> void:
	# Fade in from silence if nothing is playing; crossfade if something already is.
	var fadeDuration := NORMAL_FADEIN_DURATION if not isMusicPlaying() else NORMAL_CROSSFADE_DURATION
	playRandomBackgroundMusic(fadeDuration)
	_normalTrackTimer.start()


func _onNormalTrackTimerTimeout() -> void:
	if currentMusicState == EMusicState.Normal:
		playRandomBackgroundMusic(NORMAL_CROSSFADE_DURATION)


func _enterAlart() -> void:
	_normalTrackTimer.stop()
	stopMusic(0.0)  # instant cut — no fade, very sudden
	Console.print_line("[AudioManager] Alart — silence for 1.5s...")
	# Wait 1.5 seconds then slam in a random alart track.
	# Guard against state changes during the wait (e.g. guards give up immediately).
	var timer := get_tree().create_timer(1.5)
	timer.timeout.connect(func():
		if currentMusicState != EMusicState.Alart:
			return
		if audioData.AlartMusic.is_empty():
			push_warning("AudioManager: AlartMusic array is empty.")
			return
		var track := audioData.AlartMusic.pick_random() as AudioStream
		playMusic(track, 0.0)  # instant start, no fade
	)


func _enterMainMenu() -> void:
	_normalTrackTimer.stop()
	if audioData.TitleScreenMusic == null:
		push_warning("AudioManager: TitleScreenMusic not set.")
		return
	playMusic(audioData.TitleScreenMusic, 0.0)


func _enterGameOver() -> void:
	_normalTrackTimer.stop()
	if audioData.GameOverMusic == null:
		push_warning("AudioManager: GameOverMusic not set.")
		return
	stopMusic(1.0)
	_activeMusicTween.tween_callback(func(): playMusic(audioData.GameOverMusic, 0.0))


func _enterTension() -> void:
	_normalTrackTimer.stop()
	if audioData.TensionMusic.is_empty():
		push_warning("AudioManager: TensionMusic array is empty.")
		return
	var track := audioData.TensionMusic.pick_random() as AudioStream
	playMusic(track, 1.5)


func playAlartBark() -> void:
	if audioData.AlartBark == null:
		return
	playSfx(audioData.AlartBark)


# ── Music ─────────────────────────────────────────────────────────────────────

# Crossfades from the current track to stream over fadeDuration seconds.
# If nothing is playing the new track fades in from silence.
# Pass fadeDuration = 0 for an instant cut.
func playMusic(stream: AudioStream, fadeDuration: float = 1.0) -> void:
	if _activeMusicTween:
		_activeMusicTween.kill()

	var trackName := stream.resource_path.get_file()

	_inactivePlayer.stream    = stream
	_inactivePlayer.volume_db = -80.0
	_inactivePlayer.play()

	if fadeDuration <= 0.0:
		_activePlayer.stop()
		_inactivePlayer.volume_db = musicVolumeDb
		_swapPlayers()
		Console.print_line("[AudioManager] Now playing (instant): %s" % trackName)
		return

	Console.print_line("[AudioManager] Fading in: %s (%.1fs)" % [trackName, fadeDuration])
	_activeMusicTween = create_tween().set_parallel(true)
	_activeMusicTween.tween_property(_activePlayer,   "volume_db", -80.0,         fadeDuration)
	_activeMusicTween.tween_property(_inactivePlayer, "volume_db", musicVolumeDb, fadeDuration)
	_activeMusicTween.finished.connect(func():
		_activePlayer.stop()
		_swapPlayers()
		Console.print_line("[AudioManager] Now playing: %s" % trackName)
	)


# Fades the current track out and stops.  No-op if nothing is playing.
func stopMusic(fadeDuration: float = 1.0) -> void:
	if _activeMusicTween:
		_activeMusicTween.kill()

	if not _activePlayer.playing:
		return

	if fadeDuration <= 0.0:
		Console.print_line("[AudioManager] Stopped music (instant).")
		_activePlayer.stop()
		return

	Console.print_line("[AudioManager] Fading out music (%.1fs)." % fadeDuration)
	_activeMusicTween = create_tween()
	_activeMusicTween.tween_property(_activePlayer, "volume_db", -80.0, fadeDuration)
	_activeMusicTween.tween_callback(func():
		_activePlayer.stop()
		Console.print_line("[AudioManager] Music stopped.")
	)


# Picks a random track from AudioData.BackgroundMusic and crossfades to it.
# No-op if the array is empty.
func playRandomBackgroundMusic(fadeDuration: float = 1.0) -> void:
	if audioData.BackgroundMusic.is_empty():
		push_warning("AudioManager: BackgroundMusic array is empty.")
		return
	var track := audioData.BackgroundMusic.pick_random() as AudioStream
	playMusic(track, fadeDuration)


# ── SFX ───────────────────────────────────────────────────────────────────────

# Plays a one-shot sound effect on the SFX bus and auto-frees when done.
func playSfx(stream: AudioStream) -> void:
	var player      := AudioStreamPlayer.new()
	player.stream    = stream
	player.bus       = &"SFX"
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


# Picks a random grumble from AudioData.GuardGrumbles and plays it.
func playRandomGuardGrumble() -> void:
	if audioData.GuardGrumbles.is_empty():
		return
	playSfx(audioData.GuardGrumbles.pick_random())


# ── Queries ───────────────────────────────────────────────────────────────────

# Returns true if any music is currently playing or fading.
func isMusicPlaying() -> bool:
	return _activePlayer.playing or _inactivePlayer.playing


func _swapPlayers() -> void:
	var temp        := _activePlayer
	_activePlayer   = _inactivePlayer
	_inactivePlayer = temp
