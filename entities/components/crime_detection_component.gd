class_name CrimeDetectionComponent
extends EntityComponent

# Added to a crime's detectionRadius for the soft-detect range.
# Simulates a sixth sense — awareness beyond line-of-sight.
@export var softDetectionBonus: float = 0.0


func onAttached() -> void:
	CrimeManager.summon().crimeRegistered.connect(_onCrimeRegistered)


func onDetached() -> void:
	var cm := CrimeManager.summon()
	if cm and cm.crimeRegistered.is_connected(_onCrimeRegistered):
		cm.crimeRegistered.disconnect(_onCrimeRegistered)


func _onCrimeRegistered(event: CrimeEvent) -> void:
	var tag := "[CrimeDetection:%s crime#%d]" % [entity.name, event.id]

	# Must be in the same zone.
	if event.location.z != entity.worldPosition.z:
		# print(tag, " skipped — different zone (%d vs %d)" % [entity.worldPosition.z, event.location.z])
		return

	var entityPos := Vector2(entity.worldPosition.x, entity.worldPosition.y)
	var crimePos  := Vector2(event.location.x, event.location.y)
	var distance  := entityPos.distance_to(crimePos)

	var hardRange := event.detectionRadius
	var softRange := event.detectionRadius + softDetectionBonus

	print(tag, " dist=%.1f hardRange=%.1f softRange=%.1f" % [distance, hardRange, softRange])

	if distance > softRange:
		print(tag, " out of range — no detect")
		return

	var bFacing := _isFacingToward(crimePos)
	print(tag, " in range — facing=%s" % bFacing)

	# Hard detect requires being within range AND facing toward the crime.
	if distance <= hardRange and bFacing:
		print(tag, " HARD DETECT")
		entity.onHardDetectCrime(event)
	else:
		print(tag, " SOFT DETECT")
		entity.onSoftDetectCrime(event)


# Returns true if this entity's facing direction points into the hemisphere
# that contains the crime (dot product > 0 against the vector to the crime).
func _isFacingToward(crimePos: Vector2) -> bool:
	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover == null:
		return false
	var toTarget := crimePos - Vector2(entity.worldPosition.x, entity.worldPosition.y)
	if toTarget == Vector2.ZERO:
		return true
	return _facingToVector(mover.facing).dot(toTarget.normalized()) > 0.0


func _facingToVector(f: Globals.EFacing) -> Vector2:
	match f:
		Globals.EFacing.Up:   return Vector2( 0, -1)
		Globals.EFacing.Down: return Vector2( 0,  1)
		Globals.EFacing.Left: return Vector2(-1,  0)
		_:                    return Vector2( 1,  0)
