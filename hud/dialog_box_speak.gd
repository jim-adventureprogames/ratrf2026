class_name DialogBox_Speak
extends Control

static var _instance: DialogBox_Speak

static func summon() -> DialogBox_Speak:
	return _instance

static func turnOn() -> void:
	if _instance:
		_instance.show()

static func turnOff() -> void:
	if _instance:
		_instance.hide()

@export var imgCharacter: TextureRect
@export var txtName:      RichTextLabel
@export var txtMessage:   DialogueLabel


func _ready() -> void:
	_instance    = self
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func speak(entity: Entity, line: DialogueLine) -> void:
	txtName.text             = line.character
	txtMessage.dialogue_line = line
	txtMessage.type_out()
	var sprite := entity.getComponent(&"SpriteComponent") as SpriteComponent
	if sprite != null and sprite.sprite_frames != null:
		imgCharacter.texture = sprite.sprite_frames.get_frame_texture(&"idle_down", 0)
	else:
		imgCharacter.texture = null
