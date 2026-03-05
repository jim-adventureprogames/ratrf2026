class_name BehaviorState
extends RefCounted

# Human-readable identifier for this state (e.g. &"observing", &"investigating").
var stateName: StringName = &""

# Active behavior flags while in this state.
var flags: int = 0

# Arbitrary per-state payload.  Common keys by convention:
#   "location"      — Vector2i tile anchor (guarding_location, investigating)
#   "target"        — Entity reference    (following_entity, chasing_entity)
#   "turnsRemaining"— int countdown       (investigating, following_entity)
var data: Dictionary = {}


func _init(p_name: StringName = &"", p_flags: int = 0) -> void:
	stateName = p_name
	flags     = p_flags
