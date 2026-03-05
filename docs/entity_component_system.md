# Entity / Component System

## Overview

Entities are `Node2D` scene instances. Each entity carries a set of **components** —
child nodes that implement specific behaviours. Components self-register into a
dictionary on their parent entity so that any component can look up any sibling by
name at runtime.

```
Entity (Node2D)
├── MoverComponent        extends EntityComponent  (movement logic)
├── SpriteComponent       extends AnimatedSprite2D (visual + tweens)
├── MarkComponent         extends AIBehaviorComponent (AI + pickpocket target)
├── BumpableComponent     extends EntityComponent  (receives bump events)
├── InventoryComponent    extends EntityComponent  (holds loot)
├── MouseableComponent    extends EntityComponent  (hover detection Area2D)
└── BlocksMovementComponent extends EntityComponent (impassable tag)
```

---

## Key Classes

### `Entity` (`entities/entity.gd`)

A plain `Node2D` container. Has:
- `worldPosition: Vector3i` — tile x/y within a zone, z = zone ID.
- `components: Dictionary` — `StringName → Node`, populated by each component
  on first init.

Entity does **not** drive any logic itself. It just dispatches lifecycle events to
whichever components implement them (`onTakeTurn`, `onEndOfTurn`, `onHovered`, etc.).

### `EntityComponent` (`entities/entity_component.gd`)

Base class for most components (`extends Node`). Provides:
- `entity: Entity` — set during `_initialize()`.
- `_hasEnteredTree: bool` — distinguishes first add_child from re-entry.
- Lifecycle hooks (all virtual no-ops unless overridden):
  - `onAttached()` — connect signals, create sub-nodes, etc.
  - `onDetached()` — disconnect signals, free sub-nodes, etc.
  - `onTakeTurn()` — AI action each turn.
  - `onEndOfTurn()` — passive effects / state restore each turn.
  - `onHovered()` / `onUnhovered()` — mouse cursor events.

### `SpriteComponent` (`entities/components/sprite_component.gd`)

Extends `AnimatedSprite2D` **directly**, not `EntityComponent`. It manages its own
`_hasEnteredTree` flag and its own `_enter_tree()` / `_ready()` logic. It is still
stored in `entity.components[&"SpriteComponent"]` via its own `_initialize()`.

---

## Lifecycle: How Components Initialize

Entities are spawned **off-tree** (before being added to the scene), then registered,
then added to the scene only when the player is in the same zone.

### Step 1 — Instantiate

```gdscript
var entity := packed.instantiate() as Entity
entity.worldPosition = Vector3i(x, y, zoneId)
```

All child component nodes exist but `_ready()` has not fired. `entity` refs on
components are `null`.

### Step 2 — Register (`MapManager.registerEntity`)

```gdscript
entity._initialize()          # idempotent guard: _initialized = true
# for each child: child._initialize()  → sets child.entity, registers in components dict
# for each child: child.onAttached()   → connect signals, etc.
entityRegistry[entity.entityId] = entity
tile.entities.append(entity)
```

`onAttached()` fires here, **before the entity is in the scene tree**. Components
must be written to tolerate being attached off-tree (no `is_inside_tree()` assumed).

`AIBehaviorComponent` subclasses are also registered with `GameManager` here:
```gdscript
for child in entity.get_children():
    if child is AIBehaviorComponent:
        GameManager.registerAIComponent(child)
```

### Step 3 — Add to scene (`entityLayer.add_child(entity)`)

Called by `MapManager.refreshZoneSceneNodes()` when the player enters the entity's
zone. This triggers the normal Godot node lifecycle:

- `_enter_tree()` fires for the entity and each child component.
- `_ready()` fires for the entity and each child component.

Because `_initialize()` was already called in Step 2, `Entity._ready()` →
`Entity._initialize()` hits the `_initialized` guard and returns immediately.
`onAttached()` is **not** called again here.

For `EntityComponent` subclasses, `_ready()` sets `_hasEnteredTree = true` and
re-runs `_initialize()` (which re-sets `entity` and re-registers — harmless).

---

## Lifecycle: Zone Exit and Re-entry

### Zone Exit

When the player leaves a zone, `refreshZoneSceneNodes()` calls
`entityLayer.remove_child(entity)` for every entity in the departing zone.

Godot fires `_exit_tree()` on the entity and all children:

- `EntityComponent._exit_tree()` → calls `onDetached()`.
  - **Disconnect any signals connected in `onAttached()`.**
  - Free any sub-nodes created in `onAttached()` (e.g., `MouseableComponent`'s Area2D).
- `SpriteComponent._exit_tree()` → calls `SpriteComponent.onDetached()`:
  - Kills the active movement/bump tween.
  - Disconnects from `MoverComponent` signals.
  - If the mover state is not Idle (tween was mid-flight), snaps position and
    resets mover state.
- `SpriteComponent._notification(NOTIFICATION_EXIT_TREE)` → parks the shader
  material so the sprite stops consuming shader instance slots while off-screen.

The entity and all its components **remain in memory**. `entity.worldPosition`,
`MoverComponent.state`, AI behavior state, inventory contents — everything is
preserved.

### Zone Re-entry

`refreshZoneSceneNodes()` calls `entityLayer.add_child(entity)` again.
`_ready()` does **not** fire again (Godot only calls `_ready()` once per node
lifetime). Re-entry is handled via `_enter_tree()`.

**`EntityComponent._enter_tree()`** (base class):
```gdscript
func _enter_tree() -> void:
    if entity != null and _hasEnteredTree:
        onAttached.call_deferred()
```
- `entity != null` — true after first init.
- `_hasEnteredTree` — true after first `_ready()` call.
- Both true → deferred `onAttached()` call, re-connecting any signals that were
  disconnected in `onDetached()`.
- `call_deferred` ensures all siblings have finished `_enter_tree()` before
  `onAttached()` runs.

**`SpriteComponent._enter_tree()`** handles itself separately:
- Restores the parked shader material.
- Calls `onAttached.call_deferred()` on re-entry (re-connects mover signals,
  snaps entity position to world tile).

---

## The `super._enter_tree()` Rule

Any `EntityComponent` subclass that overrides `_enter_tree()` **must** call
`super._enter_tree()` if it needs `onAttached()` to be re-called on zone re-entry.

**Call `super._enter_tree()` when:**
- `onAttached()` connects signals or creates scene-tree-dependent objects.
- `onDetached()` disconnects those same signals / destroys those objects.
- Re-entry needs those connections restored.

**Do NOT call `super._enter_tree()` when:**
- `onAttached()` performs one-time initialization that must not repeat
  (e.g., setting initial AI state).
- There are no signals or sub-nodes to reconnect.

### Current components and their re-entry needs

| Component | Needs `super._enter_tree()`? | Why |
|---|---|---|
| `MarkComponent` | **Yes** | `onAttached` connects `bumpable.bumped` + `mover.movementBlocked` |
| `GuardComponent` | **No** | `onAttached` only sets initial behavior state — must not reset on re-entry |
| `SpriteComponent` | N/A — own implementation | Handles everything in its own `_enter_tree()` |

---

## Off-Screen Entity Movement

While an entity is out of the scene tree (in a zone the player isn't in),
`SpriteComponent` is disconnected from `MoverComponent` signals. The AI still
takes turns and calls `mover.tryMove()`.

`MoverComponent` handles this in `commitMove()` and `tryMove()`:
```gdscript
# After setting state = EState.Moving and emitting movementCommitted:
if not entity.is_inside_tree():
    state = EState.Idle   # nobody will call setMovingComplete() — reset immediately

# After setting state = EState.Bump and emitting movementBlocked:
if not entity.is_inside_tree():
    state = EState.Idle   # nobody will call setBumpComplete() — reset immediately
```

Without these guards, an off-screen entity would get stuck in `Moving` or `Bump`
state indefinitely, freezing it when it next appears on-screen.

---

## AI Turn Flow

```
GameManager._process()
  └─ _processMonsterPhase()
       └─ for each pendingAIComponent:
            AIBehaviorComponent.takeAction()
              ├─ decideWhatToDo()         ← sets nextStepDirection
              └─ mover.tryMove(dir)
                   ├─ [blocked]  state=Bump → movementBlocked.emit → SpriteComponent bump tween
                   └─ [success]  commitMove → state=Moving → movementCommitted.emit → SpriteComponent move tween
                                                                    └─ tween end → mover.setMovingComplete() → state=Idle
```

AI components are registered with `GameManager` at spawn (`registerAIComponent`)
and **never unregistered** unless the entity is fully destroyed. Zone changes do not
affect AI registration — `aiComponents` is a persistent flat list of all AI in the
world.

---

## Adding a New Component

1. Create `entities/components/my_component.gd` with `class_name MyComponent`.
2. Extend `EntityComponent` (or `AIBehaviorComponent` for AI).
3. Override `onAttached()` to connect signals / init tree-dependent state.
4. Override `onDetached()` to disconnect everything `onAttached()` connected.
5. If you override `_enter_tree()`, call `super._enter_tree()` **only if** your
   `onAttached()` is safe to call on re-entry (see rule above).
6. Add the component node as a child of the Entity scene in the editor.
   No manual `addComponent()` call needed — `_initialize()` handles registration.
