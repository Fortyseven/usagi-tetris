-- render.lua — All rendering functions
-- Exports: draw_background(), draw_game_board(), draw_right_panel(),
--          draw_title_screen(), draw_game_over_screen()
local board = require("board")
local pieces = require("pieces")

--------------------------------------------------------------------------------
-- Layout constants
--------------------------------------------------------------------------------
local CELL = 8
local BOARD_X = 6
local BOARD_Y = 8
local BOARD_PX_W = board.BOARD_W * CELL
local BOARD_PX_H = board.VISIBLE_H * CELL
local PANEL_X = BOARD_X + BOARD_PX_W + 10
local HOLO = gfx.COLOR_BLUE

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------
local M = {}

--------------------------------------------------------------------------------
-- Draw: background (starfield + scanlines)
--------------------------------------------------------------------------------
function M.draw_background()
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
            local in_board = x >= BOARD_X and x < BOARD_X + BOARD_PX_W and y >= BOARD_Y and y < BOARD_Y + BOARD_PX_H
            if not in_board then
                gfx.px(x, y, gfx.COLOR_DARK_BLUE)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Draw: game board (holographic style)
--------------------------------------------------------------------------------
function M.draw_game_board()
    -- Board background (slightly lighter than space)
    gfx.rect_fill(BOARD_X - 1, BOARD_Y - 1, BOARD_PX_W + 2, BOARD_PX_H + 2, gfx.COLOR_BLACK)

    -- Holographic grid lines (dim) — visible rows only
    for col = 0, board.BOARD_W do
        local x = BOARD_X + col * CELL
        gfx.line(x, BOARD_Y, x, BOARD_Y + BOARD_PX_H, gfx.COLOR_DARK_GRAY)
    end
    for row = 0, board.VISIBLE_H do
        local y = BOARD_Y + row * CELL
        gfx.line(BOARD_X, y, BOARD_X + BOARD_PX_W, y, gfx.COLOR_DARK_GRAY)
    end

    -- Locked cells (visible rows only, offset by hidden rows)
    -- During animation, apply slide offset and scanline wipe effect
    if State.Animating then
        local progress = 1.0 - (State.AnimTimer / State.AnimDuration) -- 0→1 over animation

        -- Draw cells above cleared rows with smooth slide
        for col = 1, board.BOARD_W do
            for row = board.HIDDEN_ROWS + 1, board.BOARD_H do
                -- Skip if this row is being cleared
                local is_cleared = false
                for _, cr in ipairs(State.AnimFullRows) do
                    if row == cr then
                        is_cleared = true
                        break
                    end
                end
                if is_cleared then
                    goto continue_row
                end

                if State.Board[col][row] then
                    local slide_offset = board.get_slide_offset(row, State.AnimFullRows)
                    local slide_y = progress * slide_offset * CELL
                    local x = BOARD_X + (col - 1) * CELL
                    local y = BOARD_Y + (row - 1 - board.HIDDEN_ROWS) * CELL + slide_y
                    gfx.rect_fill(x + 1, y + 1, CELL - 2, CELL - 2, State.Board[col][row])
                    -- Highlight edge for 3D effect
                    gfx.px(x + 1, y + 1, gfx.COLOR_LIGHT_GRAY)
                    gfx.px(x + 1, y + 2, gfx.COLOR_LIGHT_GRAY)
                    gfx.px(x + 2, y + 1, gfx.COLOR_LIGHT_GRAY)
                end
                ::continue_row::
            end
        end

        -- Draw holographic scanline wipe on cleared rows
        for _, row in ipairs(State.AnimFullRows) do
            local screen_y = BOARD_Y + (row - 1 - board.HIDDEN_ROWS) * CELL
            -- Scanline beam sweeps from top to bottom of the cleared row
            local beam_width = progress * BOARD_PX_W
            if beam_width > 0 then
                -- Bright holographic beam
                gfx.rect_fill(BOARD_X, screen_y, beam_width, CELL, gfx.COLOR_WHITE)
                -- Blue glow trail
                local trail_width = beam_width * 0.5
                if trail_width > 0 then
                    gfx.rect_fill(BOARD_X, screen_y, trail_width, CELL, HOLO)
                end
            end
        end
    else
        for col = 1, board.BOARD_W do
            for row = board.HIDDEN_ROWS + 1, board.BOARD_H do
                if State.Board[col][row] then
                    local x = BOARD_X + (col - 1) * CELL
                    local y = BOARD_Y + (row - 1 - board.HIDDEN_ROWS) * CELL
                    gfx.rect_fill(x + 1, y + 1, CELL - 2, CELL - 2, State.Board[col][row])
                    -- Highlight edge for 3D effect
                    gfx.px(x + 1, y + 1, gfx.COLOR_LIGHT_GRAY)
                    gfx.px(x + 1, y + 2, gfx.COLOR_LIGHT_GRAY)
                    gfx.px(x + 2, y + 1, gfx.COLOR_LIGHT_GRAY)
                end
            end
        end
    end

    -- Ghost piece (only during gameplay, not during animation, visible rows only)
    if State.GameState == "playing" and State.Cells and not State.Animating then
        local gy = board.ghost_y(State.Board, State.Cells, State.PieceX, State.PieceY)
        if gy ~= State.PieceY then
            for i = 1, #State.Cells do
                local c = State.Cells[i]
                local br_row = gy + c[2] + 1 -- board row (1-indexed)
                if br_row > board.HIDDEN_ROWS then -- only draw visible cells
                    local gx = BOARD_X + (State.PieceX + c[1]) * CELL
                    local gy_px = BOARD_Y + (br_row - 1 - board.HIDDEN_ROWS) * CELL
                    gfx.rect(gx + 1, gy_px + 1, CELL - 2, CELL - 2, gfx.COLOR_BLUE)
                end
            end
        end
    end

    -- Active piece (visible rows only, not during animation)
    if State.GameState == "playing" and State.Cells and not State.Animating then
        local color = pieces.get_piece_color(State.Type)
        for i = 1, #State.Cells do
            local c = State.Cells[i]
            local br_row = State.PieceY + c[2] + 1 -- board row (1-indexed)
            if br_row > board.HIDDEN_ROWS then -- only draw visible cells
                local x = BOARD_X + (State.PieceX + c[1]) * CELL
                local y = BOARD_Y + (br_row - 1 - board.HIDDEN_ROWS) * CELL
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
function M.draw_right_panel()
    local x = PANEL_X
    local y = BOARD_Y

    -- Panel background
    gfx.rect_fill(x - 2, y - 2, 100, BOARD_PX_H + 4, gfx.COLOR_BLACK)
    gfx.rect(x - 2, y - 2, 100, BOARD_PX_H + 4, gfx.COLOR_DARK_GRAY)

    -- "NEXT" label
    gfx.text("NEXT", x + 4, y, HOLO)

    -- Next piece preview (small grid)
    local preview_cells = pieces.get_cells(State.NextType, 1)
    local preview_color = pieces.get_piece_color(State.NextType)
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

    -- "HOLD" label
    local hold_y = y + 40
    gfx.text("HOLD", x + 4, hold_y, HOLO)

    -- Hold piece preview (small grid, same style as NEXT)
    if State.HoldType then
        local hold_cells = pieces.get_cells(State.HoldType, 1)
        local hold_color = pieces.get_piece_color(State.HoldType)
        local h_min_x, h_max_x, h_min_y, h_max_y = 0, 0, 0, 0
        for i = 1, #hold_cells do
            local c = hold_cells[i]
            if c[1] < h_min_x then
                h_min_x = c[1]
            end
            if c[1] > h_max_x then
                h_max_x = c[1]
            end
            if c[2] < h_min_y then
                h_min_y = c[2]
            end
            if c[2] > h_max_y then
                h_max_y = c[2]
            end
        end
        local hpw = (h_max_x - h_min_x + 1) * 6
        local hpx_offset = x + 4 + (80 - hpw) / 2
        local hpy_offset = hold_y + 10

        for i = 1, #hold_cells do
            local c = hold_cells[i]
            local hcx = hpx_offset + (c[1] - h_min_x) * 6
            local hcy = hpy_offset + (c[2] - h_min_y) * 6
            gfx.rect_fill(hcx, hcy, 5, 5, hold_color)
        end
    else
        -- Empty hold bin — dim placeholder
        gfx.text("---", x + 4 + 30, hold_y + 14, gfx.COLOR_DARK_GRAY)
    end

    -- SCORE
    local score_y = y + 80
    gfx.text("SCORE", x + 4, score_y, gfx.COLOR_LIGHT_GRAY)
    gfx.text(string.format("%06d", State.Score), x + 4, score_y + 10, gfx.COLOR_WHITE)

    -- LEVEL
    local level_y = y + 110
    gfx.text("LEVEL", x + 4, level_y, gfx.COLOR_LIGHT_GRAY)
    gfx.text(tostring(State.Level), x + 4, level_y + 10, gfx.COLOR_YELLOW)

    -- LINES
    local lines_y = y + 140
    gfx.text("LINES", x + 4, lines_y, gfx.COLOR_LIGHT_GRAY)
    gfx.text(tostring(State.Lines), x + 4, lines_y + 10, gfx.COLOR_GREEN)

    -- Controls reference
    local ctrl_y = y + 170
    gfx.text("CONTROLS", x + 4, ctrl_y, HOLO)
    gfx.text("< > MOVE", x + 4, ctrl_y + 10, gfx.COLOR_DARK_GRAY)
    gfx.text("^ ROTATE", x + 4, ctrl_y + 20, gfx.COLOR_DARK_GRAY)
    gfx.text("v SOFT", x + 4, ctrl_y + 30, gfx.COLOR_DARK_GRAY)
    gfx.text("Z DROP", x + 4, ctrl_y + 40, gfx.COLOR_DARK_GRAY)
    gfx.text("SHIFT HOLD", x + 4, ctrl_y + 50, gfx.COLOR_DARK_GRAY)
end

--------------------------------------------------------------------------------
-- Draw: title screen
--------------------------------------------------------------------------------
function M.draw_title_screen()
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
    local demo_cells = pieces.get_cells(demo_type, 1)
    local demo_color = pieces.get_piece_color(demo_type)
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
function M.draw_game_over_screen()
    -- Semi-transparent overlay
    gfx.rect_fill(0, 0, usagi.GAME_W, usagi.GAME_H, gfx.COLOR_BLACK)

    -- Re-draw board dimly in background
    M.draw_game_board()

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

return M
