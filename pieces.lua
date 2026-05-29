-- pieces.lua — Tetromino definitions and piece data
-- Exports: get_cells(type, rot), get_piece_color(type), PIECE_COLORS

--------------------------------------------------------------------------------
-- Piece type index → color
--------------------------------------------------------------------------------
local PIECE_COLORS = {
    gfx.COLOR_BLUE,        -- 1: I
    gfx.COLOR_YELLOW,      -- 2: O
    gfx.COLOR_DARK_PURPLE, -- 3: T
    gfx.COLOR_GREEN,       -- 4: S
    gfx.COLOR_RED,         -- 5: Z
    gfx.COLOR_INDIGO,      -- 6: J
    gfx.COLOR_ORANGE       -- 7: L
}

--------------------------------------------------------------------------------
-- Tetromino shapes: all 4 rotation states pre-defined per piece type.
-- SHAPES[type][rot] returns cells as {{x,y}, …} where rot is 1..4.
-- Each state is a distinct shape — no rotation math at runtime.
--------------------------------------------------------------------------------
local SHAPES = {
    -- I piece
    {
        {{-1, 0}, {0, 0}, {1, 0}, {2, 0}}, -- rot 1: horizontal
        {{0, -1}, {0, 0}, {0, 1}, {0, 2}}, -- rot 2: vertical
        {{-1, 0}, {0, 0}, {1, 0}, {2, 0}}, -- rot 3: horizontal (flipped)
        {{0, -1}, {0, 0}, {0, 1}, {0, 2}}  -- rot 4: vertical
    },
    -- O piece (all rotations identical)
    {
        {{0, 0}, {1, 0}, {0, 1}, {1, 1}},
        {{0, 0}, {1, 0}, {0, 1}, {1, 1}},
        {{0, 0}, {1, 0}, {0, 1}, {1, 1}},
        {{0, 0}, {1, 0}, {0, 1}, {1, 1}}
    },
    -- T piece
    {
        {{-1, 0}, {0, 0}, {1, 0}, {0, -1}}, -- rot 1: T upright
        {{0, -1}, {0, 0}, {0, 1}, {-1, 0}}, -- rot 2: pointing left
        {{-1, 0}, {0, 0}, {1, 0}, {0, 1}},  -- rot 3: T inverted
        {{0, -1}, {0, 0}, {0, 1}, {1, 0}}   -- rot 4: pointing right
    },
    -- S piece
    {
        {{0, 0}, {1, 0}, {-1, 1}, {0, 1}},  -- rot 1: horizontal
        {{-1, -1}, {-1, 0}, {0, 0}, {0, 1}}, -- rot 2: vertical
        {{0, 0}, {1, 0}, {-1, 1}, {0, 1}},  -- rot 3: horizontal
        {{-1, -1}, {-1, 0}, {0, 0}, {0, 1}} -- rot 4: vertical
    },
    -- Z piece
    {
        {{-1, 0}, {0, 0}, {0, 1}, {1, 1}},  -- rot 1: horizontal
        {{0, -1}, {0, 0}, {-1, 0}, {-1, 1}}, -- rot 2: vertical
        {{-1, 0}, {0, 0}, {0, 1}, {1, 1}},  -- rot 3: horizontal
        {{0, -1}, {0, 0}, {-1, 0}, {-1, 1}} -- rot 4: vertical
    },
    -- J piece
    {
        {{-1, 0}, {0, 0}, {1, 0}, {-1, -1}}, -- rot 1: J upright
        {{0, -1}, {0, 0}, {0, 1}, {-1, 1}},  -- rot 2: pointing left
        {{-1, 0}, {0, 0}, {1, 0}, {1, 1}},   -- rot 3: J inverted
        {{0, -1}, {0, 0}, {0, 1}, {1, -1}}   -- rot 4: pointing right
    },
    -- L piece
    {
        {{-1, 0}, {0, 0}, {1, 0}, {1, -1}},  -- rot 1: L upright
        {{0, -1}, {0, 0}, {0, 1}, {-1, -1}}, -- rot 2: pointing left
        {{-1, 0}, {0, 0}, {1, 0}, {-1, 1}},  -- rot 3: L inverted
        {{0, -1}, {0, 0}, {0, 1}, {1, 1}}    -- rot 4: pointing right
    }
}

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------
local M = {}

M.PIECE_COLORS = PIECE_COLORS

function M.get_cells(type, rot)
    return SHAPES[type][rot]
end

function M.get_piece_color(type)
    return PIECE_COLORS[type]
end

return M
