-- TETRIS // ORBITAL STATION BLOCK ASSEMBLY
-- Sci-fi themed Tetris clone for Usagi Engine
--
-- Modules:
--   pieces  — tetromino definitions, colors
--   board   — grid management, collision, line clears
--   scoring — score calc, level progression, drop speed
--   render  — all draw functions

local board = require("board")
local pieces = require("pieces")
local scoring = require("scoring")
local render = require("render")

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
local CELL = 8
local BOARD_X = 6
local BOARD_Y = 8
local BOARD_PX_W = board.BOARD_W * CELL
local BOARD_PX_H = board.VISIBLE_H * CELL

-- Input cooldowns (seconds)
local MOVE_COOLDOWN = 0.10
local ROTATE_COOLDOWN = 0.08
local SOFT_COOLDOWN = 0.05

-- Line clear animation
local LINE_CLEAR_DURATION = 0.4

-- Holographic accent color
local HOLO = gfx.COLOR_BLUE

--------------------------------------------------------------------------------
-- Helper: spawn a new piece from the next piece queue
--------------------------------------------------------------------------------
local function spawn_piece()
    -- Current becomes the next queued piece
    State.Type = State.NextType
    State.Rot = 1 -- 1-indexed rotation state
    State.PieceX = 2 -- center-ish
    State.PieceY = board.HIDDEN_ROWS - 1 -- spawn in hidden area (row 1 in 1-indexed)
    State.Cells = pieces.get_cells(State.Type, State.Rot)

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
    if board.collides(State.Board, State.Cells, State.PieceX, State.PieceY) then
        State.GameState = "gameover"
    end
end

--------------------------------------------------------------------------------
-- Helper: try to rotate the current piece (with wall kick)
--------------------------------------------------------------------------------
local function try_rotate()
    local new_rot = State.Rot == 1 and 4 or State.Rot - 1 -- 1→4→3→2→1
    local new_cells = pieces.get_cells(State.Type, new_rot)

    -- Priority 1: no shift at all
    if not board.collides(State.Board, new_cells, State.PieceX, State.PieceY) then
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
        if not board.collides(State.Board, new_cells, State.PieceX + kx, State.PieceY) then
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
-- Helper: start line clear animation
-- full_rows: table of board row indices to clear
-- Returns true if animation started, false if no lines to clear
--------------------------------------------------------------------------------
local function start_line_clear_animation(full_rows)
    if #full_rows == 0 then
        return false
    end
    State.Animating = true
    State.AnimTimer = LINE_CLEAR_DURATION
    State.AnimDuration = LINE_CLEAR_DURATION
    State.AnimFullRows = full_rows
    State.AnimClearedCount = #full_rows
    State.InputBuffer = {}
    sfx.play("lineclear")
    effect.flash(0.15, gfx.COLOR_WHITE)
    effect.screen_shake(0.2, 3)
    return true
end

--------------------------------------------------------------------------------
-- Helper: process buffered input after animation completes
--------------------------------------------------------------------------------
local function process_input_buffer()
    -- Process a limited number of buffered actions to avoid overwhelming
    local max_actions = 3
    local processed = 0
    for i = 1, #State.InputBuffer do
        if processed >= max_actions then
            break
        end
        local action = State.InputBuffer[i]
        if action == "left" then
            if not board.collides(State.Board, State.Cells, State.PieceX - 1, State.PieceY) then
                State.PieceX = State.PieceX - 1
                sfx.play("move")
                processed = processed + 1
            end
        elseif action == "right" then
            if not board.collides(State.Board, State.Cells, State.PieceX + 1, State.PieceY) then
                State.PieceX = State.PieceX + 1
                sfx.play("move")
                processed = processed + 1
            end
        elseif action == "rotate" then
            if try_rotate() then
                sfx.play("rotate")
                processed = processed + 1
            end
        elseif action == "hard_drop" then
            -- Forward to hard_drop (defined below)
            hard_drop()
            return -- hard_drop spawns next piece, so stop processing
        end
    end
    State.InputBuffer = {}
end

--------------------------------------------------------------------------------
-- Helper: finish line clear animation (apply changes, spawn next piece)
--------------------------------------------------------------------------------
local function finish_line_clear()
    -- Apply line clears to board
    board.apply_line_clears(State.Board, State.AnimFullRows)

    -- Update score
    local cleared = State.AnimClearedCount
    State.Score = State.Score + scoring.calculate_score(cleared, State.Level)
    State.Lines = State.Lines + cleared
    local new_level = scoring.calculate_new_level(State.Lines)
    if new_level > State.Level then
        State.Level = new_level
        sfx.play("levelup")
    end

    -- Reset animation state
    State.Animating = false
    State.AnimTimer = 0
    State.AnimDuration = 0
    State.AnimFullRows = {}
    State.AnimClearedCount = 0

    -- Spawn next piece
    spawn_piece()

    -- Process buffered input
    process_input_buffer()
end

--------------------------------------------------------------------------------
-- Helper: hard drop — place piece at ghost position
--------------------------------------------------------------------------------
local function hard_drop()
    local gy = board.ghost_y(State.Board, State.Cells, State.PieceX, State.PieceY)
    -- Place and lock
    board.place_piece(State.Board, State.Cells, State.PieceX, gy, pieces.get_piece_color(State.Type))

    -- Check for line clears
    local full_rows = board.find_full_lines(State.Board)
    if #full_rows > 0 then
        if not start_line_clear_animation(full_rows) then
            board.apply_line_clears(State.Board, full_rows)
            local cleared = #full_rows
            State.Score = State.Score + scoring.calculate_score(cleared, State.Level)
            State.Lines = State.Lines + cleared
            local new_level = scoring.calculate_new_level(State.Lines)
            if new_level > State.Level then
                State.Level = new_level
                sfx.play("levelup")
            end
        end
    else
        sfx.play("lock")
    end

    -- Only spawn next piece if not animating
    if not State.Animating then
        spawn_piece()
    end
end

--------------------------------------------------------------------------------
-- Helper: lock piece at current position (shared by soft drop & gravity)
-- Returns true if a new piece was spawned (caller should skip gravity)
--------------------------------------------------------------------------------
local function lock_piece()
    board.place_piece(State.Board, State.Cells, State.PieceX, State.PieceY, pieces.get_piece_color(State.Type))
    local full_rows = board.find_full_lines(State.Board)
    if #full_rows > 0 then
        if not start_line_clear_animation(full_rows) then
            board.apply_line_clears(State.Board, full_rows)
            local cleared = #full_rows
            State.Score = State.Score + scoring.calculate_score(cleared, State.Level)
            State.Lines = State.Lines + cleared
            local new_level = scoring.calculate_new_level(State.Lines)
            if new_level > State.Level then
                State.Level = new_level
                sfx.play("levelup")
            end
        end
    else
        sfx.play("lock")
    end
    if not State.Animating then
        spawn_piece()
    end
    return true
end

--------------------------------------------------------------------------------
-- _init: called once at startup and on F5 reset
--------------------------------------------------------------------------------
function _init()
    State = {
        -- Game state
        GameState = "title", -- "title" | "playing" | "gameover"
        Board = board.new_board(),
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

        -- Line clear animation
        Animating = false,
        AnimTimer = 0,
        AnimDuration = 0,
        AnimFullRows = {}, -- board row indices being cleared
        AnimClearedCount = 0,

        -- Input buffer (queued actions during animation)
        InputBuffer = {},

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
            State.Board = board.new_board()
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
            State.Board = board.new_board()
            State.Score = 0
            State.Level = 1
            State.Lines = 0
            State.DropTimer = 0
            spawn_piece()
        end
        return
    end

    -- === PLAYING STATE ===

    -- If animating a line clear, handle animation timer and buffer input
    if State.Animating then
        State.AnimTimer = State.AnimTimer - dt

        -- Buffer input during animation (one action per key press, not held)
        if input.pressed(input.LEFT) then
            table.insert(State.InputBuffer, "left")
        elseif input.pressed(input.RIGHT) then
            table.insert(State.InputBuffer, "right")
        elseif input.pressed(input.KEY_UP) or input.pressed(input.KEY_W) then
            table.insert(State.InputBuffer, "rotate")
        elseif input.pressed(input.BTN1) then
            table.insert(State.InputBuffer, "hard_drop")
        end

        -- Animation complete
        if State.AnimTimer <= 0 then
            finish_line_clear()
        end
        return
    end

    -- Normal gameplay
    State.MoveTimer = State.MoveTimer - dt
    State.RotateTimer = State.RotateTimer - dt
    State.SoftTimer = State.SoftTimer - dt

    -- Horizontal movement (held, gated by cooldown for repeat)
    if input.held(input.LEFT) and State.MoveTimer <= 0 then
        if not board.collides(State.Board, State.Cells, State.PieceX - 1, State.PieceY) then
            State.PieceX = State.PieceX - 1
            State.MoveTimer = MOVE_COOLDOWN
            sfx.play("move")
        end
    end
    if input.held(input.RIGHT) and State.MoveTimer <= 0 then
        if not board.collides(State.Board, State.Cells, State.PieceX + 1, State.PieceY) then
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
        if not board.collides(State.Board, State.Cells, State.PieceX, State.PieceY + 1) then
            State.PieceY = State.PieceY + 1
            State.Score = State.Score + 1
            State.SoftTimer = SOFT_COOLDOWN
            State.DropTimer = 0 -- reset gravity timer on soft drop
            sfx.play("drop")
        else
            lock_piece()
            return -- skip gravity for the newly spawned piece
        end
    end

    -- Hard drop
    if input.pressed(input.BTN1) then
        hard_drop()
        return -- skip gravity processing this frame
    end

    -- Gravity
    local interval = is_soft_dropping and math.min(scoring.drop_interval(State.Level), 0.05) or scoring.drop_interval(State.Level)
    State.DropTimer = State.DropTimer + dt
    if State.DropTimer >= interval then
        State.DropTimer = State.DropTimer - interval
        if not board.collides(State.Board, State.Cells, State.PieceX, State.PieceY + 1) then
            State.PieceY = State.PieceY + 1
        else
            lock_piece()
        end
    end
end

--------------------------------------------------------------------------------
-- _draw: rendering
--------------------------------------------------------------------------------
function _draw(dt)
    render.draw_background()

    if State.GameState == "title" then
        render.draw_title_screen()
    elseif State.GameState == "gameover" then
        render.draw_game_board()
        render.draw_game_over_screen()
    else
        render.draw_game_board()
        render.draw_right_panel()
    end
end
