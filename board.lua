-- board.lua — Grid management, collision detection, line clears
-- Exports: new_board(), collides(), ghost_y(), place_piece(),
--          find_full_lines(), apply_line_clears(), get_slide_offset()
--------------------------------------------------------------------------------
-- Board dimensions
--------------------------------------------------------------------------------
local BOARD_W = 10
local BOARD_H = 22 -- 20 visible + 2 hidden rows at top
local HIDDEN_ROWS = 2
local VISIBLE_H = BOARD_H - HIDDEN_ROWS -- 20

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------
local M = {}

M.BOARD_W = BOARD_W
M.BOARD_H = BOARD_H
M.HIDDEN_ROWS = HIDDEN_ROWS
M.VISIBLE_H = VISIBLE_H

--------------------------------------------------------------------------------
-- Create an empty board (1-indexed: board[col][row])
--------------------------------------------------------------------------------
function M.new_board()
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
-- Check if piece cells collide with board boundaries or locked cells
-- board is 1-indexed: board[col][row], col 1..BOARD_W, row 1..BOARD_H
--------------------------------------------------------------------------------
function M.collides(board, cells, cx, cy)
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
-- Find ghost piece Y (lowest non-colliding position)
--------------------------------------------------------------------------------
function M.ghost_y(board, cells, cx, cy)
    local gy = cy
    while not M.collides(board, cells, cx, gy + 1) do
        gy = gy + 1
    end
    return gy
end

--------------------------------------------------------------------------------
-- Place piece onto board (bake cells into board with color)
--------------------------------------------------------------------------------
function M.place_piece(board, cells, cx, cy, color)
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
-- Identify full lines (does NOT modify board)
-- Returns a sorted table of row indices (highest first) that are full
--------------------------------------------------------------------------------
function M.find_full_lines(board)
    local full_rows = {}
    for row = BOARD_H, HIDDEN_ROWS + 1, -1 do
        local full = true
        for col = 1, BOARD_W do
            if not board[col][row] then
                full = false
                break
            end
        end
        if full then
            table.insert(full_rows, row)
        end
    end
    return full_rows
end

--------------------------------------------------------------------------------
-- Apply line clears to board (shift rows down)
-- full_rows is a table of row indices that should be removed
--------------------------------------------------------------------------------
function M.apply_line_clears(board, full_rows)
    -- Process from bottom to top (full_rows is already sorted highest first, so reverse)
    for i = #full_rows, 1, -1 do
        local row = full_rows[i]
        -- Shift everything above down by one
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

--------------------------------------------------------------------------------
-- Compute slide offset for a given board row during animation
-- Returns how many cells down this row should be shifted visually
--------------------------------------------------------------------------------
function M.get_slide_offset(row, full_rows)
    local offset = 0
    for i = 1, #full_rows do
        if row < full_rows[i] then
            offset = offset + 1
        end
    end
    return offset
end

return M
