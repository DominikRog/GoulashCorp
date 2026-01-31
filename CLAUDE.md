# Get To The King - Project Context

Quick reference for Claude Code when working on this project.

---

## Game Overview

**"Get To The King"** is a top-down physics puzzle game where a demon possesses six different characters to reach the king's throne, solving puzzles under time pressure.

**Core Mechanic:** Push scattered 16x16 tile pieces to reassemble shapes before time runs out.

**Progression:** 6 acts, each with 2 shapes to complete + mind puzzle with multiple choice answers.

**Narrative:** Demon possesses: Demon → Farmer → Merchant → Guardsman → Jester → Queen → King

---

## Architecture

### Node Structure

```
PuzzleGame (Node2D)
├── Player (CharacterBody2D) - player.gd
│   └── Sprite2D (animated walk cycle)
├── Tiles (RigidBody2D instances) - tile.gd
│   ├── Sprite2D (16x16 texture slice)
│   └── CollisionShape2D (RectangleShape2D 16x16)
├── TileSlots (Node2D) - tile_slot.gd (visual guides)
├── ShapeDisplay (Node2D) - preview container
└── UI (Control) - timer, labels
```

### Physics Configuration

**Tiles (RigidBody2D):**
- `mass = 2.0`
- `gravity_scale = 0.0` (top-down)
- `linear_damp = 10.0`, `angular_damp = 10.0`
- `lock_rotation = true`
- `collision_layer = 2`, `collision_mask = 7`

**Player (CharacterBody2D):**
- `speed = 200.0`, `push_force = 150.0`
- `motion_mode = MOTION_MODE_FLOATING`
- `collision_layer = 1`, `collision_mask = 6`

**Walls (StaticBody2D):**
- `collision_layer = 4`, `collision_mask = 3`

**Collision Layers:**
- Layer 1: Player
- Layer 2: Tiles
- Layer 4: Walls

**Snapped Tiles (walkthrough):**
- `collision_layer = 0`, `collision_mask = 0`
- `freeze = true`

---

## File Structure

```
GoulashCorp/
├── Assets/
│   └── Shapes/          # 48x48 PNG images (3x3 grid)
│       ├── scythe.png
│       ├── wheat.png
│       └── [other shapes...]
├── Scenes/
│   ├── MainMenu.tscn
│   ├── PuzzleGame.tscn  # Main puzzle scene
│   ├── Dialogue.tscn    # Mind puzzle scene
│   ├── Tile.tscn        # Tile prefab
│   └── player.tscn
├── Scripts/
│   ├── tile.gd          # Tile behavior
│   ├── player.gd        # Player movement + push
│   ├── puzzle_manager_new.gd  # Main game loop
│   ├── shape_data.gd    # Act configuration (autoload)
│   ├── game_manager.gd  # Global state (autoload)
│   ├── dialogue_manager.gd
│   ├── tile_slot.gd
│   └── main_menu.gd
└── project.godot
```

---

## Key Scripts

### `Scripts/tile.gd`
RigidBody2D tile with snap logic.

**Key Variables:**
- `correct_position: Vector2` - Target grid position
- `is_snapped: bool` - Whether locked in place
- `can_snap: bool` - Enabled after scatter delay
- `tile_index: int` - Position in 3x3 grid (0-8)
- `shape_id: String` - Which shape this belongs to

**Key Methods:**
- `snap_to_position()` - Lock tile at correct position
- `scatter_to(target_pos)` - Throw tile with velocity

### `Scripts/player.gd`
CharacterBody2D with push mechanics.

**Exports:** `speed`, `animation_speed`, `push_force`

**Key Variables:**
- `can_move: bool` - Movement enabled flag
- `is_entering: bool` - Entrance animation state

**Key Methods:**
- `_physics_process(delta)` - Movement + collision-based push logic
- `start_entrance(from_pos, to_pos)` - Walk-on animation

### `Scripts/puzzle_manager_new.gd`
Spawns tiles, validates completion, manages timer.

**Exports:**
- `play_area_size: Vector2` - Scene bounds (1280x720)
- `shape_preview_duration: float` - Preview time (1.0s)
- `tile_scene: PackedScene` - Tile prefab
- `target_window_size: Vector2` - Resolution (320x180)
- `tile_friction: float` - Physics material friction
- `disable_collision_when_snapped: bool` - Walkthrough behavior

**Key Variables:**
- `current_shapes: Array[String]` - Shape names for act
- `tiles: Array` - Spawned tile instances
- `timer: float` - Countdown timer

**Key Methods:**
- `start_next_shape()` - Begin next puzzle
- `spawn_and_scatter_tiles(shape_name)` - Create and throw tiles
- `_on_tile_snapped(index)` - Handle tile snap event
- `complete_current_shape()` - Clean up and advance

### `Scripts/shape_data.gd` (Autoload)
Act configuration singleton.

**Structure:**
```gdscript
acts = {
    1: {
        "character": "demon",
        "next_character": "farmer",
        "shapes": ["scythe", "wheat"],
        "question": "What did you do your whole life?",
        "answers": [...],
        "timer": 45,
        "dialogue_before": "..."
    }
}
```

**Methods:**
- `get_act(act_number)` - Get act config
- `get_shapes_for_act(act_number)` - Get shape list
- `get_timer_for_act(act_number)` - Get timer duration

### `Scripts/game_manager.gd` (Autoload)
Global game state singleton.

**Key Variables:**
- `current_act: int` - Current act (1-6)
- `current_character: String` - Current body possessed
- `completed_shapes: Array[String]` - Shapes done in current act

**Methods:**
- `complete_shape(shape_name)` - Mark shape done
- `advance_to_next_act(next_character)` - Move to next act
- `get_current_act_data()` - Get current act config from ShapeData

---

## Autoload Configuration

In `project.godot`:
```ini
[autoload]
GameManager="*res://Scripts/game_manager.gd"
ShapeData="*res://Scripts/shape_data.gd"
```

Access globally:
```gdscript
GameManager.complete_shape("scythe")
var act_data = ShapeData.get_act(1)
```

---

## Shape System

Shapes are **48x48 PNG** images divided into 3x3 grid of **16x16 tiles**.

**Tile Index Mapping:**
```
0  1  2
3  4  5
6  7  8
```

**Loading:**
```gdscript
var path = "res://Assets/Shapes/" + shape_name + ".png"
var texture = load(path)
```

**Extraction (using AtlasTexture):**
```gdscript
var atlas = AtlasTexture.new()
atlas.atlas = shape_texture
atlas.region = Rect2(tile_x * 16, tile_y * 16, 16, 16)
sprite.texture = atlas
```

---

## Current Implementation Status

See `IMPLEMENTATION_STATUS.md` for detailed status.

**Completed:**
- Core physics system (push, snap, scatter)
- Timer system with countdown
- Act progression (6 acts configured)
- Dialogue system with mind puzzles
- Full game loop (Menu → Dialogue → Puzzle → Mind → Next Act)
- Collision system (player, tiles, walls)

**Awaiting from Artist:**
- Character sprites (16x16): Demon, Farmer, Merchant, Guardsman, Jester, Queen
- Shape images (48x48): 12 total shapes (2 per act)
  - Act 1: scythe.png, wheat.png
  - Act 2: coin.png, chest.png
  - Act 3: sword.png, shield.png
  - Act 4: mask.png, bells.png
  - Act 5: crown.png, scepter.png
  - Act 6: throne.png, orb.png

**Currently Using:**
- Placeholder colored squares for tiles
- Main_Dude.png for player (doesn't change between acts)

---

## Current Limitations

**Hardcoded Constraints:**
- Tiles are always 16x16 squares
- Grid is always 3x3 (9 tiles)
- Only RectangleShape2D collision supported
- No rotation of tiles
- No multi-tile pieces (each tile is 1x1)

**Known Issues:**
- Timer values may need balance tuning
- Act 2-6 have placeholder shape names (awaiting artist input)
- Character sprite doesn't change between acts yet

---

## Testing Checklist

Before committing changes, verify:
- [ ] Tiles scatter evenly without getting stuck
- [ ] Player can push tiles in all directions
- [ ] Tiles snap at correct distance (8px threshold)
- [ ] Snapped tiles don't block player (walkthrough)
- [ ] Timer counts down correctly
- [ ] Shape completion advances to next puzzle
- [ ] All 6 acts load proper shapes/timers
- [ ] Mind puzzle shows correct completed shapes
- [ ] Wrong answer restarts current act
- [ ] Timer expiration restarts puzzle only

---

## Common Development Tasks

### Adding a New Shape

1. Create 48x48 PNG in `Assets/Shapes/shape_name.png`
2. Add to `shape_data.gd` in appropriate act's `"shapes"` array
3. No code changes needed - system auto-loads

### Modifying Physics Feel

**Heavier/lighter tiles:**
```gdscript
# In tile.gd _ready()
mass = 5.0  # Heavier
```

**Stronger push:**
```gdscript
# In player.gd
@export var push_force := 200.0
```

**Less sliding:**
```gdscript
# In tile.gd _ready()
linear_damp = 15.0
```

### Adjusting Snap

**Change snap distance:**
```gdscript
# In tile.gd
@export var snap_threshold: float = 12.0  # Easier
```

**Adjust snap delay:**
```gdscript
# In tile.gd scatter_to()
await get_tree().create_timer(1.0).timeout  # Longer
```

### Modifying Timer

**Change act timer:**
```gdscript
# In shape_data.gd
acts = {
    1: {
        "timer": 60,  # 60 seconds
        ...
    }
}
```

---

## Input Map

Configure in Project Settings → Input Map:
- `player_up` - W, Up Arrow
- `player_down` - S, Down Arrow
- `player_left` - A, Left Arrow
- `player_right` - D, Right Arrow
- `ui_select` - Space, Enter

---

## Game Flow

```
MainMenu
  → Dialogue (Opening "Get to the king")
    → PuzzleGame (Act 1: 2 shapes)
      → Dialogue (Mind Puzzle + possession)
        → PuzzleGame (Act 2)
          → ... (repeat for Acts 3-6)
            → Dialogue (Victory)
              → MainMenu
```

**Timer expiration:** Restarts current puzzle only (not whole act)
**Wrong answer:** Restarts entire act from first shape

---

## Version Info

- **Godot Version:** 4.6
- **Compatibility Mode:** GL Compatibility
- **Target Resolution:** 320x180 (pixel art)
- **Play Area:** 1280x720 internal coordinates

---

## Artist Integration Notes

**Shape images:**
- **Format:** 48x48 PNG
- **Grid:** 3x3 tiles (each 16x16)
- **Naming:** Lowercase, match `shape_data.gd` names exactly
- **Location:** `Assets/Shapes/` folder
- **Missing files:** Show colored placeholders automatically

**Character sprites:**
- **Size:** 16x16 PNG (or appropriate sprite sheet)
- **Location:** `Assets/` folder
- **Integration:** Update `player.tscn` Sprite2D texture
- **Future:** Need dynamic sprite change system for act transitions

---

*For reusable Godot 4.x physics patterns and best practices, see `.claude/skills/godot-puzzle-dev.md`*
