class_name NpcSettings
extends Resource

# One entry per visual variant for marks.  A random entry is chosen each time
# a mark is spawned so the crowd looks varied.
@export var markSpriteFrames: Array[SpriteFrames] = []
