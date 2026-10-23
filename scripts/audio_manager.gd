
extends Node

const SETTINGS_PATH := "user://settings.cfg"

const MASTER_BUS := "Master"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

const DEFAULT_MASTER := 1.0
const DEFAULT_MUSIC := 0.8
const DEFAULT_SFX := 1.0

var master_volume: float = DEFAULT_MASTER
var music_volume: float = DEFAULT_MUSIC
var sfx_volume: float = DEFAULT_SFX


func _ready() -> void:
	load_settings()
	apply_all_volumes()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_volume(MASTER_BUS, master_volume)
	save_settings()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volume(MUSIC_BUS, music_volume)
	save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volume(SFX_BUS, sfx_volume)
	save_settings()


func _apply_volume(bus_name: String, value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)

	if bus_index == -1:
		push_warning("Audio bus not found: " + bus_name)
		return

	# Use a very low decibel value for silence.
	var db := -80.0 if value <= 0.001 else linear_to_db(value)
	AudioServer.set_bus_volume_db(bus_index, db)


func apply_all_volumes() -> void:
	_apply_volume(MASTER_BUS, master_volume)
	_apply_volume(MUSIC_BUS, music_volume)
	_apply_volume(SFX_BUS, sfx_volume)


func save_settings() -> void:
	var config := ConfigFile.new()

	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)

	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save audio settings.")


func load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)

	if error != OK:
		# No saved settings yet; use defaults.
		return

	master_volume = float(
		config.get_value("audio", "master", DEFAULT_MASTER)
	)
	music_volume = float(
		config.get_value("audio", "music", DEFAULT_MUSIC)
	)
	sfx_volume = float(
		config.get_value("audio", "sfx", DEFAULT_SFX)
	)

	master_volume = clampf(master_volume, 0.0, 1.0)
	music_volume = clampf(music_volume, 0.0, 1.0)
	sfx_volume = clampf(sfx_volume, 0.0, 1.0)
