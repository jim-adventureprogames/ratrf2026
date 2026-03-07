class_name HUD_Options
extends Control

static var _instance: HUD_Options

static func summon() -> HUD_Options:
	return _instance

@export var btnExit:     TextureButton
@export var sliderMusic: HSlider
@export var sliderSFX:   HSlider

const PREFS_PATH := "user://player_prefs.cfg"
const SECTION    := "audio"


func _ready() -> void:
	_instance = self
	# Load and apply saved prefs before connecting signals so the initial
	# value assignment doesn't double-trigger the change handlers.
	_loadPrefs()
	btnExit.pressed.connect(_onBtnExitPressed)
	sliderMusic.value_changed.connect(_onMusicChanged)
	sliderSFX.value_changed.connect(_onSFXChanged)


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func turnOn() -> void:
	show()


func turnOff() -> void:
	hide()


func _onBtnExitPressed() -> void:
	turnOff()


func _onMusicChanged(value: float) -> void:
	var db := _sliderToDb(value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Music"), db)
	AudioManager.summon().musicVolumeDb = db
	_savePrefs()


func _onSFXChanged(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"SFX"), _sliderToDb(value))
	_savePrefs()


# ── Persistence ────────────────────────────────────────────────────────────────

func _savePrefs() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "music_volume", sliderMusic.value)
	cfg.set_value(SECTION, "sfx_volume",   sliderSFX.value)
	cfg.save(PREFS_PATH)


func _loadPrefs() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PREFS_PATH) != OK:
		return  # first run — slider defaults stay as designed in the scene

	sliderMusic.value = cfg.get_value(SECTION, "music_volume", sliderMusic.value)
	sliderSFX.value   = cfg.get_value(SECTION, "sfx_volume",   sliderSFX.value)

	# Apply bus volumes now — signals aren't connected yet so we do it manually.
	var musicDb := _sliderToDb(sliderMusic.value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Music"), musicDb)
	AudioManager.summon().musicVolumeDb = musicDb
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"SFX"), _sliderToDb(sliderSFX.value))


# ── Helpers ────────────────────────────────────────────────────────────────────

# Maps a 0–100 slider value to a dB level for AudioServer.
# 100 → 0 dB (full volume), 0 → -80 dB (silence), 50 → ~-6 dB.
func _sliderToDb(value: float) -> float:
	if value <= 0.0:
		return -80.0
	return linear_to_db(value / 100.0)
