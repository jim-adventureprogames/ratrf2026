# Game Reset Plan

## State inventory — what holds game data

**GameManager**
- `playerEntity` — must be freed and nulled
- `gameState` / `currentPhase` — must be reset
- `aiComponents` / `pendingAIComponents` — must be cleared (entries point to freed nodes)
- `_gameDelayingTweens` — must be cleared
- `itemRegistry` — must be cleared
- `timeKeeper` — turn count must be reset
- `_activeDialogResource` / `_activeDialogSpeaker` — must be nulled
- Signal connections from `spawnPlayer()` (mover.turnTaken, mover.zoneCrossed, playerCharacter.apDepleted) — auto-disconnect when playerEntity is freed

**MapManager**
- `entityRegistry` — entities must be freed (`queue_free`) then registry cleared
- `zones` — all Zone objects and their tile arrays, must be cleared
- `spawnPoints` / `waypointRegistry` — must be cleared
- `currentZoneId` — reset to -1
- Four TileMapLayer nodes — must each call `clear()`

**ChallengeManager**
- `activeChallengeType`, `targetEntities` — cleared
- `challengeSuccessCount` — cleared (full reset means fresh difficulty curve)

**HUD / UI**
- `get_tree().paused` — force false
- `HUDDialog` — turn off if open
- `HUDCoinFlipContest` — hide if visible
- `HUD_Main` — disconnect `timeKeeper.turnAdvanced` from `_onTurnAdvanced`, show start button, blank time/coin labels

---

## New methods

**`MapManager.reset()`**
```
for entity in entityRegistry.values(): entity.queue_free()
entityRegistry.clear()
zones.clear()
spawnPoints.clear()
waypointRegistry.clear()
currentZoneId = -1
clear all four TileMapLayer nodes via worldTileMap refs
```

**`ChallengeManager.reset()`**
```
activeChallengeType = ""
targetEntities.clear()
challengeSuccessCount.clear()
```

**`HUD_Main.reset()`**
```
if timeKeeper.turnAdvanced.is_connected(_onTurnAdvanced):
    timeKeeper.turnAdvanced.disconnect(_onTurnAdvanced)
btnDebugStart.show()
txtTime.text = ""
txtCoin.text = ""
```

**`GameManager.goToGameOver()`**
```
gameState = EGameState.GameOver
get_tree().paused = false          # ensure input works for the menu
HUDDialog.turnOff() if open
HUDCoinFlipContest.hide() if visible
# show game over screen / await player acknowledgement
# then call resetToMainMenu()
```

**`GameManager.resetToMainMenu()`** — the orchestrator, called after player dismisses game over
```
1. get_tree().paused = false (belt-and-suspenders)
2. HUD_Main.summon().reset()
3. MapManager.reset()           ← frees all entities including playerEntity
4. playerEntity        = null
5. aiComponents.clear()
6. pendingAIComponents.clear()
7. _gameDelayingTweens.clear()
8. itemRegistry.clear()
9. timeKeeper.reset()           ← needs a reset() on TimeKeeper
10. _activeDialogResource = null
11. _activeDialogSpeaker  = null
12. ChallengeManager.reset()
13. currentPhase = EGamePhase.Player
14. gameState    = EGameState.MainMenu
```

Then `startGame()` already does everything needed for a fresh game — generate world, spawn player, spawn NPCs, populate minimap, load zone.

---

## Gotchas

- **`queue_free` is deferred** — `resetToMainMenu()` nulls `playerEntity` immediately after the call; by the time the player clicks "Start Again" (at least one frame later), all nodes will be gone.
- **`timeKeeper`** — currently created fresh in `startGame()` if null, but after first game it's already set. Needs an explicit `reset()` method added to `TimeKeeper` to zero the turn counter, or re-create it.
- **`EntityLayer` children** — all entity nodes are children of `entityLayer` (Node2D in main.tscn). `queue_free()`-ing every entity in the registry removes them from the tree. No need to touch `entityLayer` itself.
- **`_onPlayerTurnTaken` / `_onPlayerZoneChanged`** — connected in `spawnPlayer()` on the player's `MoverComponent`. When `playerEntity.queue_free()` fires, Godot auto-disconnects all signals from that node, so no manual cleanup needed.
- **MiniMap** — `populate()` is called in `startGame()` so it rebuilds itself on each new game automatically.

---

## Implementation order

1. `TimeKeeper.reset()` — add turn counter reset
2. `MapManager.reset()` — world + entity teardown
3. `ChallengeManager.reset()` — stat/challenge state
4. `HUD_Main.reset()` — UI teardown
5. `GameManager.resetToMainMenu()` — orchestrates 2-4 then clears its own state
6. `GameManager.goToGameOver()` — entry point, stub game over screen, calls 5
