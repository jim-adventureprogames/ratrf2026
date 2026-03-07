class_name WorldSettings
extends Resource

# Minimum and maximum number of zones along each axis.
# The actual grid size is chosen randomly between min and max each new game.
@export_range(3, 20) var zoneGridMinWidth:  int = 7
@export_range(3, 20) var zoneGridMaxWidth:  int = 10
@export_range(3, 20) var zoneGridMinHeight: int = 7
@export_range(3, 20) var zoneGridMaxHeight: int = 10


@export var roadsideBuildingArray : Array[PackedScene];
@export var emptyAreaBuildingArray: Array[PackedScene];
