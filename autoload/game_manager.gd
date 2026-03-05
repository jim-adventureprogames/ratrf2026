extends Node

enum EGamePhase {
	Player,
	Monster,
	EndOfTurnCleanup,
}

enum EGameState {
	MainMenu,
	Gameplay,
	GameOver,
}

# Rates the quality of the player's approach when pickpocketing,
# measured relative to the mark's facing direction.
# Brazen = straight-on (mark sees you); Perfect = directly behind.
enum EApproachRating {
	Brazen,   # directly in front of the mark
	Sketchy,  # front diagonal (45° off front)
	Normal,   # side (90° off front)
	Smooth,   # rear diagonal (135° off front)
	Perfect,  # directly behind the mark
}

# Set by main.gd before startGame() is called.
var entityLayer: Node2D

var playerEntity:        Entity
var currentPhase:        EGamePhase             = EGamePhase.Player

var gameState:			 EGameState				= EGameState.MainMenu

@export var timeKeeper: TimeKeeper

# All AI components in the world, registered when their entity is registered.
var aiComponents:        Array[AIBehaviorComponent] = []

# AIs that still need to finish their action this turn.
# Populated at the start of each Monster phase; shrinks as AIs report done.
var pendingAIComponents: Array[AIBehaviorComponent] = []

# Tweens that must finish before phase processing resumes.
# Write-only from outside GameManager via addGameDelayingTween().
var _gameDelayingTweens: Array[Tween] = []


func _ready() -> void:
	Console.add_command("test_inventory", _cmdTestInventory, [], 0, "Fills the inventory grid with random loot from mark_loot_table_01.")
	Console.add_command("test_coin_flip", _cmdTestCoinFlip, ["string"], 0, "Launches N coins (default 3) with random heads/tails results.")
	Console.add_command("test_dialog", _cmdTestDialog, [], 0, "Opens a test dialog between the player and a nearby guard.")


func getEntityByID(id: int) -> Entity:
	return MapManager.entityRegistry.get(id, null)


var itemRegistry: Dictionary = {}   # int → Item

func registerItem(item: Item) -> void:
	itemRegistry[item.itemId] = item

func unregisterItem(item: Item) -> void:
	itemRegistry.erase(item.itemId)

func getItemByID(id: int) -> Item:
	return itemRegistry.get(id, null)


const _FLOATING_SHOUT := preload("res://hud/floating_shout.tscn")

func spawnBark(entity: Entity, message: String, shoutType: FloatingShout.EShoutType,
				 lifetime: float = 3.0) -> void:
	var shout          := _FLOATING_SHOUT.instantiate() as FloatingShout
	shout.lifetime     = lifetime
	shout.setMessage(message)
	shout.attachToSpeaker(entity)
	shout.setShoutType(shoutType);


func startGame() -> void:
	if timeKeeper == null:
		timeKeeper = TimeKeeper.new()
	generateWorld()
	spawnPlayer()
	_spawnDebugMarks()
	_spawnDebugGuards()
	print("GameManager: %d entities registered." % MapManager.entityRegistry.size())
	HUDMiniMap.summon().populate();
	HUDMiniMap.summon().setPlayerZone(playerEntity.worldPosition.z);
	MapManager.worldTileMap.loadZone(playerEntity.worldPosition.z)
	gameState = EGameState.Gameplay;


func generateWorld() -> void:
	WorldGenerator.generateWorld()


func _pickPlayerSpawn() -> Vector3i:
	var points: Array = MapManager.spawnPoints.get("player", [])
	if points.is_empty():
		push_warning("GameManager: no 'player' spawn points found, falling back to zone centre.")
		return Vector3i(
			Globals.ZONE_WIDTH_TILES  / 2,
			Globals.ZONE_HEIGHT_TILES / 2,
			Globals.STARTING_ZONE
		)
	return points[randi() % points.size()]


func spawnPlayer() -> void:
	playerEntity               = load("res://entity_prefabs/player.tscn").instantiate()
	playerEntity.worldPosition  = _pickPlayerSpawn()
	MapManager.registerEntity(playerEntity)
	entityLayer.add_child(playerEntity)

	var mover := playerEntity.getComponent(&"MoverComponent") as MoverComponent
	if mover:
		mover.turnTaken.connect(_onPlayerTurnTaken)
		mover.zoneCrossed.connect(_onPlayerZoneChanged)

	var playerCharacter := playerEntity.getComponent(&"PlayerCharacterComponent") as PlayerCharacterComponent
	if playerCharacter:
		playerCharacter.apDepleted.connect(_onPlayerTurnTaken)

	var inventory := playerEntity.getComponent(&"InventoryComponent") as InventoryComponent
	if inventory:
		var hud := HUD_Main.summon()
		if hud:
			hud.showInventory(inventory)


# ── Debug helpers ────────────────────────────────────────────────────────────

func _spawnDebugMarks() -> void:
	var packed := load("res://entity_prefabs/mark.tscn") as PackedScene
	if packed == null:
		push_error("GameManager: could not load mark.tscn")
		return

	for zone: Zone in MapManager.zones:
		_spawnDebugMarksInZone(packed, zone.id, 6)


func _spawnDebugGuards() -> void:
	var packed := load("res://entity_prefabs/guard.tscn") as PackedScene
	if packed == null:
		push_error("GameManager: could not load guard.tscn")
		return

	for zone: Zone in MapManager.zones:
		_spawnGuardInZone(packed, zone.id)


func _spawnGuardInZone(packed: PackedScene, zoneId: int) -> void:
	var inset    := WorldGenerator.WALL_INSET + 1
	var attempts := 0
	while attempts < 200:
		attempts += 1
		var x        := randi_range(inset, Globals.ZONE_WIDTH_TILES  - 1 - inset)
		var y        := randi_range(inset, Globals.ZONE_HEIGHT_TILES - 1 - inset)
		var worldPos := Vector3i(x, y, zoneId)
		if MapManager.testDestinationTile(worldPos, false) != Globals.EMoveTestResult.OK:
			continue
		var guard := packed.instantiate() as Entity
		if guard == null:
			return
		guard.worldPosition = worldPos
		MapManager.applySpawnVariant(guard)
		MapManager.registerEntity(guard)
		var guardComp := guard.getComponent(&"GuardComponent") as GuardComponent
		if guardComp:
			guardComp.behaviorFlags |= AIBehaviorComponent.EBehaviorFlags.guarding_zone
		return


func _spawnDebugMarksInZone(packed: PackedScene, zoneId: int, count: int) -> void:
	var inset    := WorldGenerator.WALL_INSET + 1
	var spawned  := 0
	var attempts := 0
	while spawned < count and attempts < 200:
		attempts += 1
		var x        := randi_range(inset, Globals.ZONE_WIDTH_TILES  - 1 - inset)
		var y        := randi_range(inset, Globals.ZONE_HEIGHT_TILES - 1 - inset)
		var worldPos := Vector3i(x, y, zoneId)
		if MapManager.testDestinationTile(worldPos, false) != Globals.EMoveTestResult.OK:
			continue
		var mark := packed.instantiate() as Entity
		if mark == null:
			continue
		mark.worldPosition = worldPos
		MapManager.applySpawnVariant(mark)
		MapManager.registerEntity(mark)
		spawned += 1


# ── Player actions ───────────────────────────────────────────────────────────

func onDialogueFinished(result: String) -> void:
	var splitsies = result.split(":");
	match splitsies[0]:
		"challenge":
			ChallengeManager.BeginChallenge(splitsies[1]);
		"gameover":
			pass
		
	pass


func _cmdTestCoinFlip(textCount: String = "3") -> void:
	var count = (int)(textCount);
	var hud := HUDCoinFlipContest.summon()
	if hud == null:
		Console.print_warning("test_coin_flip: HUD_CoinFlipContest not ready.")
		return
	var results: Array[bool] = []
	for i in count:
		results.append(randi() % 2 == 0)
	hud.flip(results)
	Console.print_line("test_coin_flip: flipping %d coin(s)." % count)


var _activeDialogResource: DialogueResource
var _activeDialogSpeaker:  Entity


func HandleGuardApprehendPlayer(guard: Entity, player: Entity) -> void:
	if HUDDialog.summon() == null:
		return
	_activeDialogResource = load("res://dialogue/guard_dialog.dialogue")
	_activeDialogSpeaker  = guard
	DialogueStateManager.resetForNewDialog()
	get_tree().paused = true
	HUDDialog.turnOn()
	_advanceDialog("capture_player")


func _cmdTestDialog() -> void:
	if playerEntity == null:
		Console.print_warning("test_dialog: start the game first.")
		return
	var dlg := HUDDialog.summon()
	if dlg == null:
		Console.print_warning("test_dialog: HUDDialog not in scene.")
		return

	# Find any guard in the current zone.
	var guard: Entity = null
	for entity: Entity in MapManager.entityRegistry.values():
		if entity.getComponent(&"GuardComponent") != null \
				and entity.worldPosition.z == MapManager.currentZoneId:
			guard = entity
			break
	if guard == null:
		Console.print_warning("test_dialog: no guard found in the current zone.")
		return

	_activeDialogResource = load("res://dialogue/guard_dialog.dialogue")
	_activeDialogSpeaker  = guard
	DialogueStateManager.resetForNewDialog()
	get_tree().paused     = true
	HUDDialog.turnOn()
	_advanceDialog("start")


# Async dialogue loop — gets the next line, presents it, then hooks the
# appropriate signal to advance again when the player is ready.
func _advanceDialog(key: String) -> void:
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(
			_activeDialogResource, key)

	if line == null:
		HUDDialog.turnOff()
		get_tree().paused = false
		onDialogueFinished(DialogueStateManager.getResultFromLastDialog())
		return

	var dlg := HUDDialog.summon()
	dlg.dboxAnswer.displayCharacter(playerEntity)
	dlg.presentLine(line, _activeDialogSpeaker)

	if line.responses.is_empty():
		# Speak-only line — auto-advance after the text finishes typing.
		await dlg.dboxSpeak.txtMessage.finished_typing
		_advanceDialog(line.next_id)
	else:
		dlg.dboxAnswer.replyCommitted.connect(
				func(reply: DialogReply): _advanceDialog(reply.response.next_id),
				CONNECT_ONE_SHOT)


func _cmdTestInventory() -> void:
	if playerEntity == null:
		Console.print_warning("test_inventory: no player entity, start the game first.")
		return
	var inventory := playerEntity.getComponent(&"InventoryComponent") as InventoryComponent
	if inventory == null:
		Console.print_warning("test_inventory: player has no InventoryComponent.")
		return
	for i in 10:
		var result := RandomTable.rollOnTable("mark_loot_table_01")
		if result.begins_with("coin"):
			continue
		inventory.addItem(Item.new(result))
	var hud := HUD_Main.summon()
	if hud == null:
		Console.print_warning("test_inventory: HUD_Main not ready.")
		return
	hud.showInventory(inventory)
	Console.print_line("test_inventory: populated player inventory grid.")


# Returns a unit Vector2 corresponding to the given EFacing value.
func _facingToVector(f: Globals.EFacing) -> Vector2:
	match f:
		Globals.EFacing.Up:   return Vector2( 0, -1)
		Globals.EFacing.Down: return Vector2( 0,  1)
		Globals.EFacing.Left: return Vector2(-1,  0)
		_:                    return Vector2( 1,  0)  # Right


# Rates how well the player approached the mark for a pickpocket attempt,
# relative to the direction the mark is currently facing.
# Uses the dot product of the mark's facing vector against the vector from
# mark to player: dot ≈ 1.0 means straight-on (Brazen); dot ≈ -1.0 means
# crept up from behind (Perfect).
func _calcApproachRating(attacker: PlayerCharacterComponent, victim: MarkComponent) -> EApproachRating:
	var victimMover := victim.entity.getComponent(&"MoverComponent") as MoverComponent
	if victimMover == null:
		return EApproachRating.Normal

	var victimFacing := _facingToVector(victimMover.facing)
	var toAttacker   := Vector2(
		attacker.entity.worldPosition.x - victim.entity.worldPosition.x,
		attacker.entity.worldPosition.y - victim.entity.worldPosition.y
	).normalized()

	if toAttacker == Vector2.ZERO:
		return EApproachRating.Normal

	# Thresholds are the cosines of the midpoint angles between each bucket:
	# 22.5°, 67.5°, 112.5°, 157.5°
	var dot := victimFacing.dot(toAttacker)
	if dot >=  0.924: return EApproachRating.Brazen
	if dot >=  0.383: return EApproachRating.Sketchy
	if dot >= -0.383: return EApproachRating.Normal
	if dot >= -0.924: return EApproachRating.Smooth
	return EApproachRating.Perfect


func handlePlayerDoPickPocket(attacker: PlayerCharacterComponent, victim: MarkComponent) -> void:

	var approachRating := _calcApproachRating(attacker, victim)

	#hold up the game while the bump happens.
	delayNextPhaseForSeconds(0.25)

	print( "" + attacker.name + " pickpockets " + victim.name + " with rating " + EApproachRating.find_key(approachRating) );

	if( !victim.onMugAttempt(attacker, approachRating) ):
		pass
		#play wiff/confusion/miss?
	else:	
		
		var loot := getLootFromTable(victim.lootTable)

		if loot["bSuccess"]:
			var inventory := attacker.entity.getComponent(&"InventoryComponent") as InventoryComponent
			if inventory == null:
				push_warning("handlePlayerDoPickPocket: player has no InventoryComponent.")
			elif loot["coin"] > 0:
				inventory.addCoin(loot["coin"])
				_spawnCoinFloater(attacker.entity, loot["coin"])
			elif loot["item"] != null:
				inventory.addItem(loot["item"])
				_spawnLootFloater(attacker.entity, loot["item"])

		_registerPickpocketCrime(attacker, victim, approachRating, loot)
	
	#finally,
	attacker.spendAP()


func _spawnLootFloater(sourceEntity: Entity, item: Item) -> void:
	var hud := HUD_Main.summon()
	if hud == null:
		return
	# Centre the 14×14 floater above the entity's tile.
	var tilePixel  := MoverComponent.tileToPixel(sourceEntity.worldPosition)
	var spawnPos   := tilePixel + Vector2(-7, -16)
	hud.spawnFloatingDisplay(spawnPos, item.getImage(), "", 1.5, Vector2(0, -12), true)


func _spawnCoinFloater(sourceEntity: Entity, amount: int) -> void:
	var hud := HUD_Main.summon()
	if hud == null:
		return
	var tilePixel := MoverComponent.tileToPixel(sourceEntity.worldPosition)
	var spawnPos  := tilePixel + Vector2(-7, -16)
	var dollars   := amount / 100
	var cents     := amount % 100
	var text      := "$%d.%02d" % [dollars, cents]
	hud.spawnFloatingDisplay(spawnPos, null, text, 1.5, Vector2(0, -12), true)


# Registers a pickpocket attempt as a CrimeEvent.
# For unique stolen items, finds the registered inventory stack so the correct
# itemId is recorded rather than the transient Item passed into addItem().
func _registerPickpocketCrime(attacker: PlayerCharacterComponent, victim: MarkComponent,
		rating: EApproachRating, loot: Dictionary) -> void:
	var stolenItems: Array[Item] = []
	var lootItem := loot.get("item") as Item
	if lootItem != null:
		if lootItem.isUnique():
			var inventory := attacker.entity.getComponent(&"InventoryComponent") as InventoryComponent
			var registered := inventory.findItem(lootItem.archetypeName) if inventory else null
			if registered:
				stolenItems.append(registered)
		else:
			stolenItems.append(lootItem)

	var radius := CrimeManager.summon().getDetectionRadius(rating)
	
	#allow futzing with radius here based on player stats or other conditions.
	
	CrimeManager.summon().registerCrime(
		attacker.entity.entityId,
		victim.entity.entityId,
		attacker.entity.worldPosition,
		stolenItems,
		radius
	)


# Rolls on the named table and returns a result dictionary:
#   bSuccess : bool  — false only if the table is missing or returns nothing
#   item     : Item  — the rolled item, or null if the result was coin/empty
#   coin     : int   — coin amount (> 0 only when the result was a coin roll)
func getLootFromTable(lootTable: String) -> Dictionary:
	var result := RandomTable.rollOnTable(lootTable)
	print("Loot roll [", lootTable, "]: ", result)

	if result.is_empty():
		return { "bSuccess": false, "item": null, "coin": 0 }

	if result.begins_with("coin"):
		return { "bSuccess": true, "item": null, "coin": _parseCoinAmount(result) }

	return { "bSuccess": true, "item": Item.new(result), "coin": 0 }


# Parses the coin amount out of a result string like "coin,(1-300)".
# Returns a random value in [min, max], or 1 if no range is present.
func _parseCoinAmount(coinResult: String) -> int:
	var openParen  := coinResult.find("(")
	var closeParen := coinResult.find(")")
	if openParen == -1 or closeParen == -1:
		return 1
	var parts := coinResult.substr(openParen + 1, closeParen - openParen - 1).split("-")
	if parts.size() != 2:
		return 1
	return randi_range(int(parts[0]), int(parts[1]))


# ── AI registration ───────────────────────────────────────────────────────────

func registerAIComponent(ai: AIBehaviorComponent) -> void:
	if not aiComponents.has(ai):
		aiComponents.append(ai)


func unregisterAIComponent(ai: AIBehaviorComponent) -> void:
	aiComponents.erase(ai)
	pendingAIComponents.erase(ai)


# ── Main loop ─────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	match gameState:
		EGameState.MainMenu:
			#wait
			_processMainMenu(_delta);
		EGameState.Gameplay:
			_processMainGameplay(_delta);

func _processMainMenu(_delta: float) -> void:
	pass

func addGameDelayingTween(delayTween: Tween) -> void:
	_gameDelayingTweens.append(delayTween)


func delayNextPhaseForSeconds(time: float) -> void:
	var tween := create_tween()
	tween.tween_interval(time)
	_gameDelayingTweens.append(tween)


func _processMainGameplay(_delta: float) -> void:
	for tween in _gameDelayingTweens:
		if tween.is_running():
			return

	match currentPhase:
		EGamePhase.Player:
			_processPlayerPhase()
		EGamePhase.Monster:
			_processMonsterPhase()
		EGamePhase.EndOfTurnCleanup:
			_processEndOfTurnCleanup()

	var i := _gameDelayingTweens.size() - 1
	while i >= 0:
		if not _gameDelayingTweens[i].is_running():
			_gameDelayingTweens.remove_at(i)
		i -= 1

# ── Phase handlers ────────────────────────────────────────────────────────────

func _processPlayerPhase() -> void:
	if playerEntity == null:
		return
	var inputComp := playerEntity.getComponent(&"PlayerInputComponent") as PlayerInputComponent
	if inputComp:
		inputComp.processInput()
	# Phase transition is driven by mover.turnTaken → _onPlayerTurnTaken.


func _onPlayerTurnTaken() -> void:
	# Snapshot all AIs into the pending list for this turn.
	pendingAIComponents = aiComponents.duplicate()
	currentPhase = EGamePhase.Monster


func _onPlayerZoneChanged(newZoneId: int) -> void:
	HUDMiniMap.summon().setPlayerZone(newZoneId)


func _processMonsterPhase() -> void:
	# Each frame, give every pending AI a chance to act.
	# Remove ones that report done (true); keep ones still busy (false).
	# The phase holds here across as many frames as needed until all are done.
	var i := pendingAIComponents.size() - 1
	while i >= 0:
		if pendingAIComponents[i].takeAction():
			pendingAIComponents.remove_at(i)
		i -= 1

	if pendingAIComponents.is_empty():
		currentPhase = EGamePhase.EndOfTurnCleanup


func _processEndOfTurnCleanup() -> void:
	for entity: Entity in MapManager.entityRegistry.values():
		entity.onEndOfTurn()
	timeKeeper.advanceTurn()
	currentPhase = EGamePhase.Player

func getPlayerComponent() -> PlayerCharacterComponent:
	return playerEntity.getComponent("&PlayerCharacterComponent") as PlayerCharacterComponent;
	
