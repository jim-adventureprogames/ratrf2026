class_name PlayerInputComponent
extends EntityComponent


func processInput() -> void:
	var direction := getInputDirection()
	if direction == Vector2i.ZERO:
		return
	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover:
		mover.tryMove(direction)


# Numpad diagonals are checked first — single key, unambiguous.
# Cardinal actions are then combined, giving WASD/arrow diagonal support
# by holding two keys (e.g. W+D = up-right).
func getInputDirection() -> Vector2i:
	if Input.is_action_pressed("move_up_left"):    return Vector2i(-1, -1)
	if Input.is_action_pressed("move_up_right"):   return Vector2i( 1, -1)
	if Input.is_action_pressed("move_down_left"):  return Vector2i(-1,  1)
	if Input.is_action_pressed("move_down_right"): return Vector2i( 1,  1)

	var x := 0
	var y := 0
	if Input.is_action_pressed("move_right"): x += 1
	if Input.is_action_pressed("move_left"):  x -= 1
	if Input.is_action_pressed("move_down"):  y += 1
	if Input.is_action_pressed("move_up"):    y -= 1
	return Vector2i(x, y)
