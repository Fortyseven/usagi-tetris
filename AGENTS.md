# Tetris // Orbital Station — Agent Reference

Sci-fi themed Tetris clone built with the [Usagi Engine](https://usagiengine.com) (Lua 5.5, 320×180 native resolution). All game logic lives in `main.lua`.

---

## Game Identity

| Property       | Value                                |
| -------------- | ------------------------------------ |
| **Title**      | Tetris // Orbital Station            |
| **Subtitle**   | Block Assembly                       |
| **Theme**      | Sci-fi holographic station interface |
| **Engine**     | Usagi v1.0.0                         |
| **Language**   | Lua 5.5                              |
| **Resolution** | 320×180 (default)                    |
| **Game ID**    | `com.usagiengine.tetris_orbital`     |

---

## Core Architecture

### Game States (`State.GameState`)

Three states drive the game loop:

| State        | Description                                                     |
| ------------ | ---------------------------------------------------------------
| `"title"`    | Title screen with animated piece preview and start prompt
| `"playing"`  | Active gameplay — the main update/draw loop
| `"gameover"` | Overlay on the frozen board with final stats and restart prompt

State transitions:

- `title → playing`: BTN1 pressed (Z/J)
- `playing → gameover`: Spawn collision detected in `spawn_piece()`
- `gameover → playing`: BTN1 pressed, full board reset

### The `State` Table

All cross-frame game state lives in the `State` global, initialized in `_init()`:

| Field                | Type    | Description                                                    |
| -------------------- | ------- | -------------------------------------------------------------- |
| `GameState`          | string  | `"title"` / `"playing"` / `"gameover"`                         |
| `Board`              | table   | `board[col][row]` — color index or `false` (empty). 1-indexed. |
| `Type`               | number  | Current piece type (1–7)                                       |
| `Rot`                | number  | Current rotation state (1–4, 1-indexed)                        |
| `PieceX`             | number  | Active piece X position (0-indexed, relative to board)         |
| `PieceY`             | number  | Active piece Y position (0-indexed, relative to board)         |
| `Cells`              | table   | Current cell offsets `{{x,y}, ...}`                            |
| `NextType`           | number  | Next queued piece type (1–7)                                   |
| `Score`              | number  | Current score                                                  |
| `Level`              | number  | Current level (1–15)                                           |
| `Lines`              | number  | Total lines cleared                                            |
| `DropTimer`          | number  | Gravity accumulator (seconds)                                  |
| `MoveTimer`          | number  | Horizontal move cooldown                                       |
| `RotateTimer`        | number  | Rotation cooldown                                              |
| `SoftTimer`          | number  | Soft drop cooldown                                             |
| `UpHeld`             | boolean | Manual edge-detection for UP key rotation                      |
| `RotationsThisPiece` | number  | Rotation count for current piece (wall kick tracking)          |
| `Stars`              | table   | Starfield data `{{x, y, brightness, twinkle_speed}, ...}`      |

---

## Board Mechanics

### Dimensions

| Constant      | Value | Notes                                    |
| ------------- | ----- | ---------------------------------------- |
| `BOARD_W`     | 10    | Standard Tetris width                    |
| `BOARD_H`     | 22    | 20 visible + 2 hidden rows               |
| `HIDDEN_ROWS` | 2     | Hidden rows at top for rotation room     |
| `VISIBLE_H`   | 20    | Visible rows only                        |
| `CELL`        | 8     | Cell size in pixels                      |
| `BOARD_X`     | 6     | Board screen X offset                    |
| `BOARD_Y`     | 8     | Board screen Y offset (visible area top) |

### Coordinate Systems

- **Board storage**: 1-indexed `board[col][row]`, col 1–10, row 1–22
- **Piece position**: 0-indexed `(PieceX, PieceY)`, relative to board origin
- **Cell offsets**: relative to piece center, converted with `col = cx + offset_x + 1`
- **Screen pixels**: `x = BOARD_X + (col - 1) * CELL`, `y = BOARD_Y + (row - 1 - HIDDEN_ROWS) * CELL`

### Collision Detection

`collides(board, cells, cx, cy)` checks:

1. Horizontal bounds: col < 1 or col > BOARD_W
2. Bottom bounds: row > BOARD_H
3. Locked cells: `board[col][row]` is truthy (rows >= 1 only)

Rows below 1 (above the board) are never checked — pieces can float in the hidden area.

---

## Tetromino System

### Piece Types

| Index | Name | Color       |
| ----- | ---- | ----------- |
| 1     | I    | Blue        |
| 2     | O    | Yellow      |
| 3     | T    | Dark Purple |
| 4     | S    | Green       |
| 5     | Z    | Red         |
| 6     | J    | Indigo      |
| 7     | L    | Orange      |

### Rotation Model

All 4 rotation states are **pre-defined** in `SHAPES[type][rot]`. No runtime rotation math — just table lookups. Rotations cycle `1 → 4 → 3 → 2 → 1` (counter-clockwise).

Each rotation state defines cells as `{{x, y}, ...}` offsets relative to the piece center.

### Wall Kicks

`try_rotate()` attempts placement in priority order:

1. **No shift** — rotation at current position
2. **Horizontal kicks** — ±1, ±2 columns from current position
3. **Fail** — rotation blocked (no vertical kicks implemented)

### Ghost Piece

`ghost_y(board, cells, cx, cy)` finds the lowest non-colliding Y by stepping down one row at a time. Rendered as a blue outline on visible rows only.

---

## Scoring & Progression

### Score Table

| Lines Cleared | Base Points |
| ------------- | ----------- |
| 0             | 0           |
| 1             | 40          |
| 2             | 100         |
| 3             | 300         |
| 4 (Tetris)    | 1200        |

**Final score** = `base_points × level`

### Level System

- **Lines per level**: 10
- **Max level**: 15
- **Level formula**: `floor(lines / 10) + 1`

### Drop Speed Curve

`drop_interval(level)` = `max(0.8 - (level - 1) × 0.05, 0.05)`

| Level | Interval (s) |
| ----- | ------------ |
| 1     | 0.80         |
| 5     | 0.60         |
| 10    | 0.35         |
| 15    | 0.10         |
| 16+   | 0.05 (floor) |

Soft drop forces a minimum interval of 0.05s regardless of level.

---

## Input Mapping

| Action     | Keyboard | Gamepad                   | In-Game Function               |
| ---------- | -------- | ------------------------- | ------------------------------ |
| `LEFT`     | ← / A    | D-pad left / stick left   | Move left                      |
| `RIGHT`    | → / D    | D-pad right / stick right | Move right                     |
| `UP` / `W` | ↑ / W    | D-pad up / stick up       | Rotate (manual edge detection) |
| `DOWN`     | ↓ / S    | D-pad down / stick down   | Soft drop                      |
| `BTN1`     | Z / J    | A / Cross                 | Hard drop                      |

### Input Cooldowns

| Action          | Cooldown (s) |
| --------------- | ------------ |
| Horizontal move | 0.10         |
| Rotation        | 0.08         |
| Soft drop       | 0.05         |

### Spawn Grace Period

New pieces get a `-0.4s` drop timer (400ms grace period with no gravity) so the player can position before the piece starts falling.

---

## Sound Effects

| SFX File        | Trigger                        |
| --------------- | ------------------------------ |
| `move.wav`      | Horizontal movement            |
| `rotate.wav`    | Successful rotation            |
| `drop.wav`      | Soft drop step / hard drop     |
| `lock.wav`      | Piece locks with no line clear |
| `lineclear.wav` | One or more lines cleared      |
| `levelup.wav`   | Level increases                |

All SFX play via `sfx.play("name")` (fire-and-forget, restarts if already playing).

---

## Visual Design

### Aesthetic

Sci-fi holographic station terminal. Deep space background with twinkling starfield, dim scanline overlay, and a pulsing blue holographic border around the board.

### Color Palette (Pico-8)

| Usage                    | Color Constant           |
| ------------------------ | ------------------------ |
| Background               | `gfx.COLOR_DARK_BLUE`    |
| Holographic accent       | `gfx.COLOR_BLUE` (HOLO)  |
| Grid lines               | `gfx.COLOR_DARK_GRAY`    |
| Cell highlight (3D edge) | `gfx.COLOR_LIGHT_GRAY`   |
| Ghost piece              | `gfx.COLOR_BLUE` outline |
| Title text               | `HOLO`                   |
| Game over text           | `gfx.COLOR_RED`          |

### Rendering Order (per frame)

1. Clear screen (dark blue)
2. Starfield with twinkling
3. Scanline overlay (non-board areas only)
4. State-specific rendering:
    - **Title**: title text, subtitle, decorative line, random piece preview, pulsing start prompt
    - **Playing**: game board (locked cells, ghost piece, active piece, holographic border) + right panel
    - **Game Over**: dimmed board overlay, "SYSTEM FAILURE" text, final stats, restart prompt

### Right Panel Layout

Positioned at `PANEL_X` (board right edge + 10px). Contains:

- **NEXT** piece preview (6px cells, centered)
- **SCORE** (6-digit zero-padded)
- **LEVEL**
- **LINES**
- **CONTROLS** reference

---

## Effects (Juice)

| Effect                | Trigger    | Parameters          |
| --------------------- | ---------- | ------------------- |
| `effect.flash`        | Line clear | 0.15s, white        |
| `effect.screen_shake` | Line clear | 0.2s, 3px intensity |

No effects on piece lock (no line clear), rotation, or movement.

---

## Code Conventions

### Naming

| Convention           | Example                                           |
| -------------------- | ------------------------------------------------- |
| File-scope constants | `BOARD_W`, `CELL`, `MOVE_COOLDOWN`                |
| Cross-frame globals  | `State` (Capitalized)                             |
| Locals / functions   | `snake_case`: `collides`, `ghost_y`, `try_rotate` |
| Engine API           | lowercase: `gfx`, `input`, `sfx`, `usagi`         |

### Indentation

2 spaces. No tabs. Enforced by `.luarc.json`.

### Compound Assignment

Usagi preprocessor supports `+=`, `-=`, `*=`, `/=`, `%=`. Used in timer accumulation (`State.Score += 1`).

### Modularization

Currently single-file (`main.lua`). For growth, split into modules via `require`:

- `pieces.lua` — tetromino definitions, rotation, wall kicks
- `board.lua` — grid management, line clears, collision
- `scoring.lua` — score calculation, level progression
- `render.lua` — all draw functions
- `input.lua` — input handling, cooldowns

---

## Key Functions

| Function                  | Purpose                                                       |
| ------------------------- | ------------------------------------------------------------- |
| `_config()`               | Game metadata (name, game_id)                                 |
| `_init()`                 | Initialize State, generate starfield, register menu items     |
| `_update(dt)`             | Game logic: input, gravity, piece locking, line clears        |
| `_draw(dt)`               | Rendering pipeline: background, board, UI                     |
| `collides()`              | Collision detection against board bounds and locked cells     |
| `ghost_y()`               | Find lowest non-colliding Y for ghost piece                   |
| `place_piece()`           | Bake active piece cells into the board                        |
| `clear_lines()`           | Remove full lines, shift board down, return count             |
| `drop_interval()`         | Calculate gravity interval from level                         |
| `spawn_piece()`           | Promote next piece, reset timers, check game over             |
| `try_rotate()`            | Attempt rotation with wall kick priority                      |
| `hard_drop()`             | Drop to ghost position, lock, score, spawn next               |
| `new_board()`             | Create empty 10×22 board                                      |
| `draw_game_board()`       | Render board: grid, locked cells, ghost, active piece, border |
| `draw_right_panel()`      | Render next piece, score, level, lines, controls              |
| `draw_title_screen()`     | Render title, subtitle, piece preview, start prompt           |
| `draw_game_over_screen()` | Render game over overlay with stats                           |

---

## Running the Game

```bash
usagi dev    # Live-reload development mode
usagi run    # Run without live-reload
usagi export # Package for distribution
```

### Development Tips

- **Live reload**: Save `main.lua` to hot-reload without restarting. State persists.
- **Full reset**: Press F5 in dev mode to re-run `_init()`.
- **Pause menu**: Esc/P opens built-in pause with volume, fullscreen, and key remapping.
- **Custom reset**: Pause menu → "Reset Station" calls `_init()`.

---

## Asset Checklist

| Asset               | Required | Notes                       |
| ------------------- | -------- | --------------------------- |
| `sfx/move.wav`      | Yes      | Horizontal movement         |
| `sfx/rotate.wav`    | Yes      | Rotation                    |
| `sfx/drop.wav`      | Yes      | Soft/hard drop              |
| `sfx/lock.wav`      | Yes      | Piece lock (no clear)       |
| `sfx/lineclear.wav` | Yes      | Line clear                  |
| `sfx/levelup.wav`   | Yes      | Level increase              |
| `sprites.png`       | No       | Not used (pure gfx drawing) |
| `font.png`          | No       | Uses bundled monogram font  |
| `palette.png`       | No       | Uses default Pico-8 palette |

---

## Future Considerations

Areas identified for potential expansion:

- **7-bag randomizer**: Current system uses `math.random(1, 7)` per piece. A 7-bag system ensures fair distribution.
- **Hold piece**: Standard Tetris hold mechanic (swap current piece to hold slot).
- **Vertical wall kicks**: Current wall kicks are horizontal-only. SRS-style vertical kicks would improve corner rotations.
- **Line clear animation**: Currently instant. Could add a flash/fade animation with a delay before collapsing.
- **Combo system**: Consecutive line clears could multiply score.
- **Sound assets**: SFX files need to be created (currently referenced but not present).
- **Code modularization**: Split `main.lua` into separate modules for pieces, board, rendering, and input.
