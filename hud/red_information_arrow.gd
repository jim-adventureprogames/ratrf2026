class_name RedInformationArrow
extends Control

@onready var imgArrow: TextureRect = $imgArrow

var _entityTarget:  Entity
var _fromPixel:     Vector2
var _moveDuration:  float
var _waitDuration:  float
var _elapsed:       float  = 0.0
var _bMoving:       bool   = true
var _spawnZoneId:   int    = -1  # player's zone at launch time; zone change = dismiss


func launch(entitySource: Entity, entityTarget: Entity,
		moveDuration: float, waitDuration: float) -> void:
	_entityTarget = entityTarget
	_fromPixel    = MoverComponent.tileToPixel(entitySource.worldPosition)
	_moveDuration = moveDuration
	_waitDuration = waitDuration

	var player := GameManager.playerEntity
	_spawnZoneId = player.worldPosition.z if player != null else -1

	global_position = _fromPixel;


func _process(delta: float) -> void:
	# Dismiss if the target entity was freed.
	if not is_instance_valid(_entityTarget):
		queue_free()
		return

	# Dismiss if the player has crossed into a different zone.
	var player := GameManager.playerEntity
	if player == null or player.worldPosition.z != _spawnZoneId:
		queue_free()
		return

	# move to be just over the target, but point at the target.
	var targetPixel := _entityTarget.global_position - Vector2.UP * 6.0;

	# Always point toward the target's current position.
	var dir := _entityTarget.global_position - (global_position)
	if dir != Vector2.ZERO:
		imgArrow.rotation = dir.angle()

	_elapsed += delta

	if _bMoving:
		# Lerp from the original spawn position toward wherever the target is now.
		var alpha := clampf(_elapsed / _moveDuration, 0.0, 1.0)
		global_position = lerp(_fromPixel, targetPixel, alpha)
		if alpha >= 1.0:
			_bMoving  = false
			_elapsed  = 0.0
	else:
		# Snap to the target during the wait phase.
		global_position = targetPixel
		if _elapsed >= _waitDuration:
			queue_free()
