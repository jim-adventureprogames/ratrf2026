class_name MouseableComponent
extends EntityComponent

var _area: Area2D


func onAttached() -> void:
	var shape      := CollisionShape2D.new()
	var rect       := RectangleShape2D.new()
	rect.size       = Vector2(Globals.TILE_SIZE, Globals.TILE_SIZE)
	shape.shape     = rect

	_area                 = Area2D.new()
	_area.input_pickable  = true
	_area.add_child(shape)
	entity.add_child(_area)

	_area.mouse_entered.connect(entity.onHovered)
	_area.mouse_exited.connect(entity.onUnhovered)
	_area.input_event.connect(_onInputEvent)


func _onInputEvent(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			entity.onDebugPrint()


func onDetached() -> void:
	if is_instance_valid(_area):
		_area.queue_free()
