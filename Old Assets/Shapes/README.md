# Shape Assets Guide

## Format Requirements

Each shape should be a **48x48 pixel PNG file** containing the complete 3×3 grid.

- **Dimensions:** 48×48 pixels (exactly)
- **Grid:** 3×3 tiles, each tile is 16×16 pixels
- **Format:** PNG with transparency (if needed)
- **Style:** Pixel art matching the game aesthetic

## File Naming

Name files exactly as shown below (lowercase, no spaces):

### Act 1 (Demon → Farmer)
- `scythe.png`
- `wheat.png`

### Act 2 (Farmer → Merchant)
- `coin.png`
- `chest.png`

### Act 3 (Merchant → Guardsman)
- `sword.png`
- `shield.png`

### Act 4 (Guardsman → Jester)
- `mask.png`
- `bells.png`

### Act 5 (Jester → Queen)
- `crown.png`
- `scepter.png`

### Act 6 (Queen → Victory)
- `throne.png`
- `orb.png`

## How It Works

The game will:
1. Load each 48×48 PNG
2. Split it into 9 tiles (16×16 each)
3. Scatter the tiles randomly
4. Player pushes tiles back together to reform the image

## Grid Layout

```
[0,0] [1,0] [2,0]    (top row)
[0,1] [1,1] [2,1]    (middle row)
[0,2] [1,2] [2,2]    (bottom row)
```

Each coordinate represents a 16×16 pixel square within the 48×48 image.

## Example

For `scythe.png`:
- Pixel range [0-15, 0-15] = Top-left tile
- Pixel range [16-31, 0-15] = Top-middle tile
- Pixel range [32-47, 0-15] = Top-right tile
- ... and so on

## Testing

Place your PNG files in this folder and run the game. If a file is missing, the game will use colored placeholder squares.
