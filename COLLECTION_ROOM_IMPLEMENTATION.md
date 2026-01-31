# Collection Room Implementation

## Overview
New game mechanic where after completing puzzles and answering mind puzzle, the player enters a collection room to pick up a mask and transform into the next character.

## Flow

```
Complete 2 Shapes
  → CollectionRoom scene
    → Mind puzzle POPUP appears (85% of screen)
    → Player answers question
      → CORRECT: popup disappears → player walks in from left to 1/3 position
      → WRONG: restart entire act
    → Player manually walks to mask at 2/3 position
    → When close (20px): collect mask
    → Instant sprite swap (old character → new character)
    → 0.5s pause + blackout
  → Next Act starts (with new character sprite)
```

## Files Created

### 1. `Scripts/collection_room.gd`
Main logic script for the collection room:
- Shows mind puzzle popup immediately on load
- Handles correct/wrong answer logic
- Manages player entrance animation (left to 1/3)
- Detects mask collection (distance check)
- Swaps character sprite instantly
- Transitions to next act

**Key Variables:**
- `play_area_size: Vector2(240, 135)` - Smaller than puzzle room
- `collection_distance: 20.0` - Trigger range for mask pickup
- `has_answered: bool` - Tracks if question answered
- `mask_collected: bool` - Prevents double collection

**Key Functions:**
- `show_mind_puzzle()` - Display question popup
- `start_player_entrance()` - Walk in from left
- `collect_mask()` - Handle pickup + sprite swap
- `load_mask_sprite(character)` - Load character_mask.png
- `swap_character_sprite(character)` - Load character_full.png

### 2. `Scenes/CollectionRoom.tscn`
Scene structure:
```
CollectionRoom (Node2D)
├── Background (ColorRect) - 240x135 dark gray
├── Camera2D - zoom 4x, centered
├── Player (instance) - hidden initially
├── Mask (Sprite2D) - at 2/3 position (160, 67.5)
└── UI (CanvasLayer)
    └── Popup (Control - full screen)
        └── Panel (280x150 - 85% of screen)
            └── QuestionText (Label)
            └── ChoicesContainer (VBoxContainer)
```

### 3. Updated `Scripts/puzzle_manager_new.gd`
Line 482 changed:
```gdscript
# OLD: get_tree().change_scene_to_file("res://Scenes/Dialogue.tscn")
# NEW: get_tree().change_scene_to_file("res://Scenes/CollectionRoom.tscn")
```

## Asset Requirements

### Mask Sprites (16x16 each)
Expected naming: `Assets/{character}_mask.png`
- farmer_mask.png
- merchant_mask.png
- guardsman_mask.png
- jester_mask.png
- queen_mask.png

**Fallback:** Uses `Main_Dude.png` or golden colored square if not found.

### Character Full Sprites (16x16 each)
Expected naming: `Assets/{character}_full.png`
- demon_full.png
- farmer_full.png
- merchant_full.png
- guardsman_full.png
- jester_full.png
- queen_full.png

**Fallback:** Keeps current sprite if not found.

## Future Enhancements (Not Implemented Yet)

1. **Mask Drop Animation**
   - Currently: mask is static on floor
   - Future: mask falls from above when popup disappears

2. **Collection Animation**
   - Currently: instant sprite swap
   - Future: mask flies to player's face, animation plays, swap happens

3. **Blackout Effect**
   - Currently: direct scene transition after 0.5s
   - Future: fade to black effect

## Testing Checklist

- [ ] Complete 2 shapes in Act 1
- [ ] Verify CollectionRoom loads
- [ ] Verify popup shows question + assembled shapes hint
- [ ] Test CORRECT answer:
  - [ ] Popup disappears
  - [ ] Player walks in from left to 1/3 position
  - [ ] Player can move toward mask
  - [ ] Mask collection triggers at correct distance
  - [ ] Sprite changes (if assets available)
  - [ ] Next act loads
- [ ] Test WRONG answer:
  - [ ] Act restarts from first shape
- [ ] Verify for all 6 acts

## Known Limitations

- Mask sprites use placeholder (Main_Dude.png) until artist provides files
- Character sprites don't change between acts yet (needs *_full.png files)
- No animations (instant swap only)
- Room size hardcoded at 240x135 (75% of puzzle area)

## Configuration

All easily adjustable in `collection_room.gd`:
```gdscript
@export var play_area_size: Vector2 = Vector2(240, 135)
@export var collection_distance: float = 20.0
```

Positions calculated automatically:
- Player entrance: 1/3 of play_area_size.x (80px)
- Mask position: 2/3 of play_area_size.x (160px)
