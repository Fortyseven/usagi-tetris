-- scoring.lua — Score calculation, level progression, drop speed curve
-- Exports: drop_interval(level), calculate_score(lines_cleared, level),
--          calculate_new_level(lines), SCORE_TABLE, LINES_PER_LEVEL, MAX_LEVEL

--------------------------------------------------------------------------------
-- Scoring constants
--------------------------------------------------------------------------------
local SCORE_TABLE = {0, 40, 100, 300, 1200}
local LINES_PER_LEVEL = 10
local MAX_LEVEL = 15

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------
local M = {}

M.SCORE_TABLE = SCORE_TABLE
M.LINES_PER_LEVEL = LINES_PER_LEVEL
M.MAX_LEVEL = MAX_LEVEL

--------------------------------------------------------------------------------
-- Drop interval in seconds based on level
-- Curve: fast at high levels, floored at 0.05s
--------------------------------------------------------------------------------
function M.drop_interval(level)
    local t = 0.8 - (util.clamp(level, 1, MAX_LEVEL) - 1) * 0.05
    return math.max(t, 0.05)
end

--------------------------------------------------------------------------------
-- Calculate score points for clearing lines at a given level
--------------------------------------------------------------------------------
function M.calculate_score(lines_cleared, level)
    return SCORE_TABLE[lines_cleared] * level
end

--------------------------------------------------------------------------------
-- Calculate new level from total lines cleared
--------------------------------------------------------------------------------
function M.calculate_new_level(lines)
    return math.floor(lines / LINES_PER_LEVEL) + 1
end

return M
