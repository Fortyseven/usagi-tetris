-- TETRIS // ORBITAL STATION BLOCK ASSEMBLY
-- Sci-fi themed Tetris clone for Usagi Engine
--------------------------------------------------------------------------------
-- _config
--------------------------------------------------------------------------------
function _config()
    return {
        name = "Tetris // Orbital Station",
        game_id = "com.usagiengine.tetris_orbital"
    }
end

--------------------------------------------------------------------------------
-- Constants (file-scope locals — safe to rebind on live reload)
--------------------------------------------------------------------------------
local BOARD_W = 10
local BOARD_H = 22 -- 20 visible + 2 hidden rows at top (for rotation room)
local HIDDEN_ROWS = 2
local VISIBLE_H = BOARD_H - HIDDEN_ROWS -- 20
local CELL = 8
local BOARD_X = 6
local BOARD_Y = 8
local BOARD_PX_W = BOARD_W * CELL
local BOARD_PX_H = VISIBLE_H * CELL -- only visible portion

-- Right panel layout
local PANEL_X = BOARD_X + BOARD_PX_W + 10

-- Scoring: lines cleared -> base points
local SCORE_TABLE = {0, 40, 100, 300, 1200}

-- Lines needed per level
local LINES_PER_LEVEL = 10

-- Max level (caps speed)
local MAX_LEVEL = 15

-- Input cooldowns (seconds)
local MOVE_COOLDOWN = 0.10
local ROTATE_COOLDOWN = 0.08
local SOFT_COOLDOWN = 0.05

-- Piece type index -> color
local PIECE_COLORS = {gfx.COLOR_BLUE, -- 1: I
gfx.COLOR_YELLOW, -- 2: O
gfx.COLOR_DARK_PURPLE, -- 3: T
gfx.COLOR_GREEN, -- 4: S
gfx.COLOR_RED, -- 5: Z
gfx.COLOR_INDIGO, -- 6: J
gfx.COLOR_ORANGE -- 7: L
}

-- Holographic accent color (bright blue for sci-fi feel)
local HOLO = gfx.COLOR_BLUE

-- Tetromino shapes: all 4 rotation states pre-defined per piece type.
-- SHAPES[type][rot] returns cells as {{x,y}, ...} where rot is 1..4.
-- Each state is a distinct shape — no rotation math at runtime.
local SHAPES = { -- I piece
{{{-1, 0}, {0, 0}, {1, 0}, {2, 0}}, -- rot 1: horizontal
{{0, -1}, {0, 0}, {0, 1}, {0, 2}}, -- rot 2: vertical
{{-1, 0}, {0, 0}, {1, 0}, {2, 0}}, -- rot 3: horizontal (flipped)
{{0, -1}, {0, 0}, {0, 1}, {0, 2}} -- rot 4: vertical
}, -- O piece (all rotations identical)
{{{0, 0}, {1, 0}, {0, 1}, {1, 1}}, {{0, 0}, {1, 0}, {0, 1}, {1, 1}}, {{0, 0}, {1, 0}, {0, 1}, {1, 1}},
 {{0, 0}, {1, 0}, {0, 1}, {1, 1}}}, -- T piece
{{{-1, 0}, {0, 0}, {1, 0}, {0, -1}}, -- rot 1: T upright
{{0, -1}, {0, 0}, {0, 1}, {-1, 0}}, -- rot 2: pointing left
{{-1, 0}, {0, 0}, {1, 0}, {0, 1}}, -- rot 3: T inverted
{{0, -1}, {0, 0}, {0, 1}, {1, 0}} -- rot 4: pointing right
}, -- S piece
{{{0, 0}, {1, 0}, {-1, 1}, {0, 1}}, -- rot 1: horizontal
{{-1, -1}, {-1, 0}, {0, 0}, {0, 1}}, -- rot 2: vertical
{{0, 0}, {1, 0}, {-1, 1}, {0, 1}}, -- rot 3: horizontal
{{-1, -1}, {-1, 0}, {0, 0}, {0, 1}} -- rot 4: vertical
}, -- Z piece
{{{-1, 0}, {0, 0}, {0, 1}, {1, 1}}, -- rot 1: horizontal
{{0, -1}, {0, 0}, {-1, 0}, {-1, 1}}, -- rot 2: vertical
{{-1, 0}, {0, 0}, {0, 1}, {1, 1}}, -- rot 3: horizontal
{{0, -1}, {0, 0}, {-1, 0}, {-1, 1}} -- rot 4: vertical
}, -- J piece
{{{-1, 0}, {0, 0}, {1, 0}, {-1, -1}}, -- rot 1: J upright
{{0, -1}, {0, 0}, {0, 1}, {-1, 1}}, -- rot 2: pointing left
{{-1, 0}, {0, 0}, {1, 0}, {1, 1}}, -- rot 3: J inverted
{{0, -1}, {0, 0}, {0, 1}, {1, -1}} -- rot 4: pointing right
}, -- L piece
{{{-1, 0}, {0, 0}, {1, 0}, {1, -1}}, -- rot 1: L upright
{{0, -1}, {0, 0}, {0, 1}, {-1, -1}}, -- rot 2: pointing left
{{-1, 0}, {0, 0}, {1, 0}, {-1, 1}}, -- rot 3: L inverted
{{0, -1}, {0, 0}, {0, 1}, {1, 1}} -- rot 4: pointing right
}}

--------------------------------------------------------------------------------
-- Helper: get cells for a piece type and rotation level (1-indexed)
--------------------------------------------------------------------------------
local function get_cells(type, rot)
    return SHAPES[type][rot]
end

--------------------------------------------------------------------------------
-- Helper: check if piece cells collide with board boundaries or locked cells
-- board is 1-indexed: board[col][row], col 1..BOARD_W, row 1..BOARD_H
--------------------------------------------------------------------------------
local function collides(board, cells, cx, cy)
    for i = 1, #cells do
        local c = cells[i]
        local col = cx + c[1] + 1 -- convert to 1-indexed
        local row = cy + c[2] + 1
        if col < 1 or col > BOARD_W or row > BOARD_H then
            return true
        end
        if row >= 1 and board[col] and board[col][row] then
            return true
        end
    end
    return false
end

--------------------------------------------------------------------------------
-- Helper: find ghost piece Y (lowest non-colliding position)
--------------------------------------------------------------------------------
local function ghost_y(board, cells, cx, cy)
    local gy = cy
    while not collides(board, cells, cx, gy + 1) do
        gy = gy + 1
    end
    return gy
end

--------------------------------------------------------------------------------
-- Helper: place piece onto board (bake cells into board with color)
--------------------------------------------------------------------------------
local function place_piece(board, cells, cx, cy, color)
    for i = 1, #cells do
        local c = cells[i]
        local col = cx + c[1] + 1
        local row = cy + c[2] + 1
        if row >= 1 and row <= BOARD_H and col >= 1 and col <= BOARD_W then
            board[col][row] = color
        end
    end
end

--------------------------------------------------------------------------------
-- Helper: clear full lines, collapse board, return (lines_cleared, scored_rows)
-- scored_rows is a list of row indices that were cleared (for animation)
--------------------------------------------------------------------------------
local function clear_lines(board)
    local cleared = 0
    local scored_rows = {}
    -- Only check visible rows (hidden rows at top are never cleared)
    for row = BOARD_H, HIDDEN_ROWS + 1, -1 do
        local full = true
        for col = 1, BOARD_W do
            if not board[col][row] then
                full = false
                break
            end
        end
        if full then
            cleared = cleared + 1
            table.insert(scored_rows, row)
            -- Shift everything above down
            for r = row, HIDDEN_ROWS + 2, -1 do
                for col = 1, BOARD_W do
                    board[col][r] = board[col][r - 1] or false
                end
            end
            -- Clear row just below hidden area
            for col = 1, BOARD_W do
                board[col][HIDDEN_ROWS + 1] = false
            end
        end
    end
    return cleared, scored_rows
end

--------------------------------------------------------------------------------
-- Helper: drop interval in seconds based on level
-- Exponential curve: fast at high levels
--------------------------------------------------------------------------------
local function drop_interval(level)
    local t = 0.8 - (util.clamp(level, 1, MAX_LEVEL) - 1) * 0.05
    return math.max(t, 0.05)
end

--------------------------------------------------------------------------------
-- Helper: create an empty board (1-indexed: board[col][row])
--------------------------------------------------------------------------------
local function new_board()
    local board = {}
    for col = 1, BOARD_W do
        board[col] = {}
        for row = 1, BOARD_H do
            board[col][row] = false
        end
    end
    return board
end

--------------------------------------------------------------------------------
-- Helper: spawn a new piece from the next piece queue
--------------------------------------------------------------------------------
local function spawn_piece()
    -- Current becomes the next queued piece
    State.Type = State.NextType
    State.Rot = 1 -- 1-indexed rotation state
    State.PieceX = 2 -- center-ish
    State.PieceY = HIDDEN_ROWS - 1 -- spawn in hidden area (row 1 in 1-indexed)
    State.Cells = get_cells(State.Type, State.Rot)

    -- Reset all timers so the new piece is immediately controllable
    State.RotateTimer = 0
    State.MoveTimer = 0
    State.SoftTimer = 0
    State.DropTimer = -0.4 -- grace period: gravity paused for 400ms after spawn
    State.UpHeld = false
    State.RotationsThisPiece = 0 -- track rotations for wall kick logic

    -- Queue a new next piece
    State.NextType = math.random(1, 7)

    -- Check for immediate collision (game over)
    if collides(State.Board, State.Cells, State.PieceX, State.PieceY) then
        State.GameState = "gameover"
    end

end

--------------------------------------------------------------------------------
-- Helper: try to rotate the current piece (with wall kick)
--------------------------------------------------------------------------------
local function try_rotate()
    local new_rot = State.Rot == 1 and 4 or State.Rot - 1 -- 1→4→3→2→1
    local new_cells = get_cells(State.Type, new_rot)

    -- Priority 1: no shift at all
    if not collides(State.Board, new_cells, State.PieceX, State.PieceY) then
        State.Rot = new_rot
        State.Cells = new_cells
        State.RotationsThisPiece = State.RotationsThisPiece + 1
        return true
    end

    -- Priority 2: horizontal kicks only (keeps piece at same row)
    for kx = -2, 2 do
        if kx == 0 then
            goto continue
        end
        if not collides(State.Board, new_cells, State.PieceX + kx, State.PieceY) then
            State.Rot = new_rot
            State.Cells = new_cells
            State.PieceX = State.PieceX + kx
            State.RotationsThisPiece = State.RotationsThisPiece + 1
            return true
        end
        ::continue::
    end

    -- Rotation blocked (piece too close to edge) — no vertical kicks
    return false
end

--------------------------------------------------------------------------------
-- Helper: hard drop — place piece at ghost position
--------------------------------------------------------------------------------
local function hard_drop()
    local gy = ghost_y(State.Board, State.Cells, State.PieceX, State.PieceY)
    -- Place and lock
    place_piece(State.Board, State.Cells, State.PieceX, gy, PIECE_COLORS[State.Type])

    -- Check for line clears
    local cleared = clear_lines(State.Board)
    if cleared > 0 then
        State.Score = State.Score + SCORE_TABLE[cleared] * State.Level
        State.Lines = State.Lines + cleared
        local new_level = math.floor(State.Lines / LINES_PER_LEVEL) + 1
        if new_level > State.Level then
            State.Level = new_level
            sfx.play("levelup")
        end
        sfx.play("lineclear")
        effect.flash(0.15, gfx.COLOR_WHITE)
        effect.screen_shake(0.2, 3)
    else
        sfx.play("lock")
    end

    -- Spawn next piece
    spawn_piece()
end

--------------------------------------------------------------------------------
-- _init: called once at startup and on F5 reset
--------------------------------------------------------------------------------
function _init()
    State = {
        -- Game state
        GameState = "title", -- "title" | "playing" | "gameover"
        Board = new_board(),
        Type = 1, -- current piece type (1-7)
        Rot = 1, -- current rotation (1-4, 1-indexed)
        PieceX = 2, -- current piece X (0-indexed, relative)
        PieceY = 0, -- current piece Y (0-indexed, relative)
        Cells = nil, -- current cell offsets
        NextType = math.random(1, 7),
        Score = 0,
        Level = 1,
        Lines = 0,

        -- Timers
        DropTimer = 0,
        MoveTimer = 0,
        RotateTimer = 0,
        SoftTimer = 0,

        -- Input tracking
        UpHeld = false,
        RotationsThisPiece = 0,

        -- Starfield
        Stars = {}
    }

    -- Generate starfield
    for i = 1, 80 do
        table.insert(State.Stars, {
            x = math.random(0, usagi.GAME_W - 1),
            y = math.random(0, usagi.GAME_H - 1),
            brightness = math.random(), -- 0..1 base brightness
            twinkle_speed = 0.5 + math.random() * 2 -- Hz
        })
    end

    -- Register a custom menu item for resetting
    usagi.menu_item("Reset Station", function()
        _init()
        return true
    end)
end

--------------------------------------------------------------------------------
-- _update: game logic
--------------------------------------------------------------------------------
function _update(dt)
    if State.GameState == "title" then
        if input.pressed(input.BTN1) then
            State.GameState = "playing"
            State.Board = new_board()
            State.Score = 0
            State.Level = 1
            State.Lines = 0
            State.DropTimer = 0
            State.MoveTimer = 0
            State.RotateTimer = 0
            State.SoftTimer = 0
            spawn_piece()
        end
        return
    end

    if State.GameState == "gameover" then
        if input.pressed(input.BTN1) then
            State.GameState = "playing"
            State.Board = new_board()
            State.Score = 0
            State.Level = 1
            State.Lines = 0
            State.DropTimer = 0
            spawn_piece()
        end
        return
    end

    -- === PLAYING STATE ===
    State.MoveTimer = State.MoveTimer - dt
    State.RotateTimer = State.RotateTimer - dt
    State.SoftTimer = State.SoftTimer - dt
    -- Horizontal movement (held, gated by cooldown for repeat)
    if input.held(input.LEFT) and State.MoveTimer <= 0 then
        if not collides(State.Board, State.Cells, State.PieceX - 1, State.PieceY) then
            State.PieceX = State.PieceX - 1
            State.MoveTimer = MOVE_COOLDOWN
            sfx.play("move")
        end
    end
    if input.held(input.RIGHT) and State.MoveTimer <= 0 then
        if not collides(State.Board, State.Cells, State.PieceX + 1, State.PieceY) then
            State.PieceX = State.PieceX + 1
            State.MoveTimer = MOVE_COOLDOWN
            sfx.play("move")
        end
    end

    -- Rotation (manual edge detection to bypass Usagi input quirks)
    local up_now = input.key_held(input.KEY_UP) or input.key_held(input.KEY_W)
    local up_edge = up_now and not State.UpHeld
    if up_edge then
        if try_rotate() then
            sfx.play("rotate")
        end
    end
    State.UpHeld = up_now

    -- Soft drop
    local is_soft_dropping = input.held(input.DOWN)
    if is_soft_dropping and State.SoftTimer <= 0 then
        if not collides(State.Board, State.Cells, State.PieceX, State.PieceY + 1) then
            State.PieceY = State.PieceY + 1
            State.Score = State.Score + 1
            State.SoftTimer = SOFT_COOLDOWN
            State.DropTimer = 0 -- reset gravity timer on soft drop
            sfx.play("drop")
        else
            -- Lock piece at bottom
            place_piece(State.Board, State.Cells, State.PieceX, State.PieceY, PIECE_COLORS[State.Type])
            local cleared = clear_lines(State.Board)
            if cleared > 0 then
                State.Score = State.Score + SCORE_TABLE[cleared] * State.Level
                State.Lines = State.Lines + cleared
                local new_level = math.floor(State.Lines / LINES_PER_LEVEL) + 1
                if new_level > State.Level then
                    State.Level = new_level
                    sfx.play("levelup")
                end
                sfx.play("lineclear")
                effect.flash(0.15, gfx.COLOR_WHITE)
                effect.screen_shake(0.2, 3)
            else
                sfx.play("lock")
            end
            spawn_piece()
            return -- skip gravity for the newly spawned piece
        end
    end

    -- Hard drop
    if input.pressed(input.BTN1) then
        hard_drop()
        return -- skip gravity processing this frame
    end

    -- Gravity
    local interval = is_soft_dropping and math.min(drop_interval(State.Level), 0.05) or drop_interval(State.Level)
    State.DropTimer = State.DropTimer + dt
    if State.DropTimer >= interval then
        State.DropTimer = State.DropTimer - interval
        if not collides(State.Board, State.Cells, State.PieceX, State.PieceY + 1) then
            State.PieceY = State.PieceY + 1
        else
            -- Lock piece
            place_piece(State.Board, State.Cells, State.PieceX, State.PieceY, PIECE_COLORS[State.Type])
            local cleared = clear_lines(State.Board)
            if cleared > 0 then
                State.Score = State.Score + SCORE_TABLE[cleared] * State.Level
                State.Lines = State.Lines + cleared
                local new_level = math.floor(State.Lines / LINES_PER_LEVEL) + 1
                if new_level > State.Level then
                    State.Level = new_level
                    sfx.play("levelup")
                end
                sfx.play("lineclear")
                effect.flash(0.15, gfx.COLOR_WHITE)
                effect.screen_shake(0.2, 3)
            else
                sfx.play("lock")
            end
            spawn_piece()
        end
    end
end

--------------------------------------------------------------------------------
-- _draw: rendering
--------------------------------------------------------------------------------
function _draw(dt)
    -- Background: deep space dark blue
    gfx.clear(gfx.COLOR_DARK_BLUE)

    -- Starfield with twinkling
    for i = 1, #State.Stars do
        local star = State.Stars[i]
        local twinkle = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(usagi.elapsed * star.twinkle_speed * 2 * math.pi))
        local alpha = star.brightness * twinkle
        if alpha > 0.5 then
            gfx.px(star.x, star.y, gfx.COLOR_WHITE)
        elseif alpha > 0.25 then
            gfx.px(star.x, star.y, gfx.COLOR_LIGHT_GRAY)
        else
            gfx.px(star.x, star.y, gfx.COLOR_DARK_GRAY)
        end
    end

    -- Scanline overlay (subtle — every other row, very dim)
    for y = 0, usagi.GAME_H - 1, 2 do
        for x = 0, usagi.GAME_W - 1 do
            -- Only draw scanlines in non-board areas for subtlety
            local in_board = x >= BOARD_X and x < BOARD_X + BOARD_PX_W and y >= BOARD_Y and y < BOARD_Y + BOARD_PX_H
            if not in_board then
                gfx.px(x, y, gfx.COLOR_DARK_BLUE)
            end
        end
    end

    if State.GameState == "title" then
        draw_title_screen()
    elseif State.GameState == "gameover" then
        draw_game_board()
        draw_game_over_screen()
    else
        draw_game_board()
        draw_right_panel()
    end

end

--------------------------------------------------------------------------------
-- Draw: game board (holographic style)
--------------------------------------------------------------------------------
function draw_game_board()
    -- Board background (slightly lighter than space)
    gfx.rect_fill(BOARD_X - 1, BOARD_Y - 1, BOARD_PX_W + 2, BOARD_PX_H + 2, gfx.COLOR_BLACK)

    -- Holographic grid lines (dim) — visible rows only
    for col = 0, BOARD_W do
        local x = BOARD_X + col * CELL
        gfx.line(x, BOARD_Y, x, BOARD_Y + BOARD_PX_H, gfx.COLOR_DARK_GRAY)
    end
    for row = 0, VISIBLE_H do
        local y = BOARD_Y + row * CELL
        gfx.line(BOARD_X, y, BOARD_X + BOARD_PX_W, y, gfx.COLOR_DARK_GRAY)
    end

    -- Locked cells (visible rows only, offset by hidden rows)
    for col = 1, BOARD_W do
        for row = HIDDEN_ROWS + 1, BOARD_H do
            if State.Board[col][row] then
                local x = BOARD_X + (col - 1) * CELL
                local y = BOARD_Y + (row - 1 - HIDDEN_ROWS) * CELL
                gfx.rect_fill(x + 1, y + 1, CELL - 2, CELL - 2, State.Board[col][row])
                -- Highlight edge for 3D effect
                gfx.px(x + 1, y + 1, gfx.COLOR_LIGHT_GRAY)
                gfx.px(x + 1, y + 2, gfx.COLOR_LIGHT_GRAY)
                gfx.px(x + 2, y + 1, gfx.COLOR_LIGHT_GRAY)
            end
        end
    end

    -- Ghost piece (only during gameplay, visible rows only)
    if State.GameState == "playing" and State.Cells then
        local gy = ghost_y(State.Board, State.Cells, State.PieceX, State.PieceY)
        if gy ~= State.PieceY then
            for i = 1, #State.Cells do
                local c = State.Cells[i]
                local br_row = gy + c[2] + 1 -- board row (1-indexed)
                if br_row > HIDDEN_ROWS then -- only draw visible cells
                    local gx = BOARD_X + (State.PieceX + c[1]) * CELL
                    local gy_px = BOARD_Y + (br_row - 1 - HIDDEN_ROWS) * CELL
                    gfx.rect(gx + 1, gy_px + 1, CELL - 2, CELL - 2, gfx.COLOR_BLUE)
                end
            end
        end
    end

    -- Active piece (visible rows only)
    if State.GameState == "playing" and State.Cells then
        local color = PIECE_COLORS[State.Type]
        for i = 1, #State.Cells do
            local c = State.Cells[i]
            local br_row = State.PieceY + c[2] + 1 -- board row (1-indexed)
            if br_row > HIDDEN_ROWS then -- only draw visible cells
                local x = BOARD_X + (State.PieceX + c[1]) * CELL
                local y = BOARD_Y + (br_row - 1 - HIDDEN_ROWS) * CELL
                gfx.rect_fill(x + 1, y + 1, CELL - 2, CELL - 2, color)
                -- Highlight edge
                gfx.px(x + 1, y + 1, gfx.COLOR_LIGHT_GRAY)
                gfx.px(x + 1, y + 2, gfx.COLOR_LIGHT_GRAY)
                gfx.px(x + 2, y + 1, gfx.COLOR_LIGHT_GRAY)
            end
        end
    end

    -- Pulsing holographic border
    local pulse = util.flash(usagi.elapsed, 3)
    local border_color = pulse and HOLO or gfx.COLOR_BLUE
    gfx.rect(BOARD_X - 2, BOARD_Y - 2, BOARD_PX_W + 4, BOARD_PX_H + 4, border_color)

    -- Corner accents
    local cl = 4 -- corner length
    -- Top-left
    gfx.line(BOARD_X - 2, BOARD_Y - 2, BOARD_X - 2 + cl, BOARD_Y - 2, HOLO)
    gfx.line(BOARD_X - 2, BOARD_Y - 2, BOARD_X - 2, BOARD_Y - 2 + cl, HOLO)
    -- Top-right
    gfx.line(BOARD_X + BOARD_PX_W + 2 - cl, BOARD_Y - 2, BOARD_X + BOARD_PX_W + 2, BOARD_Y - 2, HOLO)
    gfx.line(BOARD_X + BOARD_PX_W + 2, BOARD_Y - 2, BOARD_X + BOARD_PX_W + 2, BOARD_Y - 2 + cl, HOLO)
    -- Bottom-left
    gfx.line(BOARD_X - 2, BOARD_Y + BOARD_PX_H + 2, BOARD_X - 2 + cl, BOARD_Y + BOARD_PX_H + 2, HOLO)
    gfx.line(BOARD_X - 2, BOARD_Y + BOARD_PX_H + 2 - cl, BOARD_X - 2, BOARD_Y + BOARD_PX_H + 2, HOLO)
    -- Bottom-right
    gfx.line(BOARD_X + BOARD_PX_W + 2 - cl, BOARD_Y + BOARD_PX_H + 2, BOARD_X + BOARD_PX_W + 2,
        BOARD_Y + BOARD_PX_H + 2, HOLO)
    gfx.line(BOARD_X + BOARD_PX_W + 2, BOARD_Y + BOARD_PX_H + 2 - cl, BOARD_X + BOARD_PX_W + 2,
        BOARD_Y + BOARD_PX_H + 2, HOLO)
end

--------------------------------------------------------------------------------
-- Draw: right panel (next piece, score, level, lines)
--------------------------------------------------------------------------------
function draw_right_panel()
    local x = PANEL_X
    local y = BOARD_Y

    -- Panel background
    gfx.rect_fill(x - 2, y - 2, 100, BOARD_PX_H + 4, gfx.COLOR_BLACK)
    gfx.rect(x - 2, y - 2, 100, BOARD_PX_H + 4, gfx.COLOR_DARK_GRAY)

    -- "NEXT" label
    gfx.text("NEXT", x + 4, y, HOLO)

    -- Next piece preview (small grid)
    local preview_cells = get_cells(State.NextType, 1)
    local preview_color = PIECE_COLORS[State.NextType]
    -- Center the preview piece in a small area
    local min_x, max_x, min_y, max_y = 0, 0, 0, 0
    for i = 1, #preview_cells do
        local c = preview_cells[i]
        if c[1] < min_x then
            min_x = c[1]
        end
        if c[1] > max_x then
            max_x = c[1]
        end
        if c[2] < min_y then
            min_y = c[2]
        end
        if c[2] > max_y then
            max_y = c[2]
        end
    end
    local pw = (max_x - min_x + 1) * 6
    local px_offset = x + 4 + (80 - pw) / 2
    local py_offset = y + 10

    for i = 1, #preview_cells do
        local c = preview_cells[i]
        local cx = px_offset + (c[1] - min_x) * 6
        local cy = py_offset + (c[2] - min_y) * 6
        gfx.rect_fill(cx, cy, 5, 5, preview_color)
    end

    -- SCORE
    local score_y = y + 50
    gfx.text("SCORE", x + 4, score_y, gfx.COLOR_LIGHT_GRAY)
    gfx.text(string.format("%06d", State.Score), x + 4, score_y + 10, gfx.COLOR_WHITE)

    -- LEVEL
    local level_y = y + 80
    gfx.text("LEVEL", x + 4, level_y, gfx.COLOR_LIGHT_GRAY)
    gfx.text(tostring(State.Level), x + 4, level_y + 10, gfx.COLOR_YELLOW)

    -- LINES
    local lines_y = y + 110
    gfx.text("LINES", x + 4, lines_y, gfx.COLOR_LIGHT_GRAY)
    gfx.text(tostring(State.Lines), x + 4, lines_y + 10, gfx.COLOR_GREEN)

    -- Controls reference
    local ctrl_y = y + 140
    gfx.text("CONTROLS", x + 4, ctrl_y, HOLO)
    gfx.text("< > MOVE", x + 4, ctrl_y + 10, gfx.COLOR_DARK_GRAY)
    gfx.text("^ ROTATE", x + 4, ctrl_y + 20, gfx.COLOR_DARK_GRAY)
    gfx.text("v SOFT", x + 4, ctrl_y + 30, gfx.COLOR_DARK_GRAY)
    gfx.text("Z DROP", x + 4, ctrl_y + 40, gfx.COLOR_DARK_GRAY)
end

--------------------------------------------------------------------------------
-- Draw: title screen
--------------------------------------------------------------------------------
function draw_title_screen()
    -- Title
    local title = "T E T R I S"
    local tw, th = usagi.measure_text(title)
    local tx = (usagi.GAME_W - tw) / 2
    local ty = 30
    gfx.text(title, tx, ty, HOLO)

    -- Subtitle
    local sub = "ORBITAL STATION // BLOCK ASSEMBLY"
    local sw, _ = usagi.measure_text(sub)
    local sx = (usagi.GAME_W - sw) / 2
    gfx.text(sub, sx, ty + 16, gfx.COLOR_BLUE)

    -- Decorative line
    gfx.line(sx, ty + 28, sx + sw, ty + 28, gfx.COLOR_INDIGO)

    -- Animated piece preview
    local demo_type = math.random(1, 7)
    local demo_cells = get_cells(demo_type, 1)
    local demo_color = PIECE_COLORS[demo_type]
    local demo_x = usagi.GAME_W / 2 - 16
    local demo_y = 70
    for i = 1, #demo_cells do
        local c = demo_cells[i]
        gfx.rect_fill(demo_x + c[1] * 8, demo_y + c[2] * 8, 7, 7, demo_color)
    end

    -- Pulsing "PRESS BTN1" prompt
    local prompt = "PRESS " .. (input.mapping_for(input.BTN1) or "Z") .. " TO START"
    local pw, _ = usagi.measure_text(prompt)
    local px = (usagi.GAME_W - pw) / 2
    if util.flash(usagi.elapsed, 2) then
        gfx.text(prompt, px, 110, gfx.COLOR_WHITE)
    end

    -- Version / credits
    gfx.text("USAGI ENGINE v1.0", 10, usagi.GAME_H - 10, gfx.COLOR_DARK_GRAY)
end

--------------------------------------------------------------------------------
-- Draw: game over screen (overlay on top of board)
--------------------------------------------------------------------------------
function draw_game_over_screen()
    -- Semi-transparent overlay
    gfx.rect_fill(0, 0, usagi.GAME_W, usagi.GAME_H, gfx.COLOR_BLACK)

    -- Re-draw board dimly in background
    draw_game_board()

    -- Darken overlay
    gfx.rect_fill(BOARD_X - 2, BOARD_Y - 2, BOARD_PX_W + 4, BOARD_PX_H + 4, gfx.COLOR_BLACK)

    -- Game over text
    local go_text = "S Y S T E M   F A I L U R E"
    local gw, gh = usagi.measure_text(go_text)
    local gx = (usagi.GAME_W - gw) / 2
    gfx.text(go_text, gx, 20, gfx.COLOR_RED)

    -- Subtitle
    local sub = "STRUCTURAL BREACH DETECTED"
    local sw, _ = usagi.measure_text(sub)
    gfx.text(sub, (usagi.GAME_W - sw) / 2, 36, gfx.COLOR_ORANGE)

    -- Final stats
    gfx.text("FINAL SCORE: " .. State.Score, 20, 60, gfx.COLOR_WHITE)
    gfx.text("LEVEL: " .. State.Level, 20, 74, gfx.COLOR_YELLOW)
    gfx.text("LINES: " .. State.Lines, 20, 88, gfx.COLOR_GREEN)

    -- Restart prompt
    local restart = "PRESS " .. (input.mapping_for(input.BTN1) or "Z") .. " TO REBOOT"
    local rw, _ = usagi.measure_text(restart)
    if util.flash(usagi.elapsed, 2) then
        gfx.text(restart, (usagi.GAME_W - rw) / 2, 120, HOLO)
    end
end
