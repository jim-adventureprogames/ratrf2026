class_name EntityComponent
extends RefCounted

var entity: Entity

func onAttached() -> void: pass
func onDetached() -> void: pass
func onTakeTurn() -> void: pass   # override in AI components
