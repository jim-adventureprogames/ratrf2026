extends Node2D

@onready var tileMapLayer:           WorldTileMap = $TileMapLayer
@onready var tileMapLayerDecoration: TileMapLayer = $TileMapLayerDecoration
@onready var entityLayer:            Node2D       = $EntityLayer

var playerEntity:         Entity
var playerMoverComponent: MoverComponent
var playerInputComponent: PlayerInputComponent


func _ready() -> void:
	tileMapLayer.decorationLayer = tileMapLayerDecoration
	generateWorld()
	tileMapLayer.loadZone(Globals.STARTING_ZONE)
	_createPlayerEntity()


func generateWorld() -> void:
	MapManager.zones.resize(Globals.ZONE_COUNT)
	for i in Globals.ZONE_COUNT:
		var zone          := Zone.new()
		zone.id            = i
		zone.friendlyName  = "Zone %d" % i
		zone.region        = "The Faire Grounds"
		ZoneGenerator.generateZone(zone)
		MapManager.zones[i] = zone


func _createPlayerEntity() -> void:
	playerEntity = Entity.new()
	playerEntity.worldPosition = Vector3i(
		Globals.ZONE_WIDTH_TILES  / 2,
		Globals.ZONE_HEIGHT_TILES / 2,
		Globals.STARTING_ZONE
	)

	playerMoverComponent = MoverComponent.new()
	playerMoverComponent.worldMap = tileMapLayer
	playerEntity.addComponent(playerMoverComponent)

	# SpriteComponent connects to MoverComponent.movementCommitted in onAttached —
	# MoverComponent must be added first.
	playerEntity.addComponent(SpriteComponent.new(entityLayer, 0))

	playerInputComponent = PlayerInputComponent.new()
	playerEntity.addComponent(playerInputComponent)

	# zoneCrossed fires before movementCommitted so the tilemap is reloaded
	# before the sprite begins tweening into the fresh zone.
	playerMoverComponent.zoneCrossed.connect(onPlayerZoneCrossed)
	playerMoverComponent.turnTaken.connect(onPlayerTurnTaken)

	MapManager.registerEntity(playerEntity)


func _process(_delta: float) -> void:
	if playerMoverComponent.bMoving:
		return
	playerInputComponent.processInput()


func onPlayerZoneCrossed(newZoneId: int) -> void:
	tileMapLayer.loadZone(newZoneId)


func onPlayerTurnTaken() -> void:
	MapManager.processTurn()
