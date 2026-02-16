class('Dice').extends()

local gfx = playdate.graphics

local DICE_SIZE = 40
local DICE_HALF = DICE_SIZE / 2
local DICE_QUARTER = math.floor(DICE_SIZE * 0.25)
local DICE_EIGHTH = math.floor(DICE_SIZE * 0.125)
local DICE_DOT_R = math.max(2, math.floor(DICE_SIZE * 0.08))

local DOT_POSITIONS = {
    [1] = {{0, 0}},
    [2] = {{-DICE_QUARTER, -DICE_QUARTER}, {DICE_QUARTER, DICE_QUARTER}},
    [3] = {{-DICE_QUARTER, -DICE_QUARTER}, {0, 0}, {DICE_QUARTER, DICE_QUARTER}},
    [4] = {{-DICE_QUARTER, -DICE_QUARTER}, {-DICE_QUARTER, DICE_QUARTER}, {DICE_QUARTER, -DICE_QUARTER}, {DICE_QUARTER, DICE_QUARTER}},
    [5] = {{-DICE_QUARTER, -DICE_QUARTER}, {-DICE_QUARTER, DICE_QUARTER}, {0, 0}, {DICE_QUARTER, -DICE_QUARTER}, {DICE_QUARTER, DICE_QUARTER}},
    [6] = {{-DICE_QUARTER, -DICE_EIGHTH*3}, {-DICE_QUARTER, 0}, {-DICE_QUARTER, DICE_EIGHTH*3}, {DICE_QUARTER, -DICE_EIGHTH*3}, {DICE_QUARTER, 0}, {DICE_QUARTER, DICE_EIGHTH*3}}
}

local diceFont = gfx.font.new("font/Asheville-Sans-14-Bold")

function Dice:init()
    self.value = 1
end


function Dice:roll()
    self.value = math.random(1, 6)
end

function Dice:draw(x, y, black, showValue, dotsOnly)
    local size = DICE_SIZE
    local halfSize = DICE_HALF

    -- sanitize value
    local v = math.floor(tonumber(self.value) or 1)
    if v < 1 then v = 1 end
    if v > 6 then v = 6 end

    -- Draw dice background and border (skip if dotsOnly mode)
    if not dotsOnly then
        if black then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(x - halfSize, y - halfSize, size, size)
            gfx.setColor(gfx.kColorWhite)
            gfx.drawRect(x - halfSize, y - halfSize, size, size)
        else
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRect(x - halfSize, y - halfSize, size, size)
            gfx.setColor(gfx.kColorBlack)
            gfx.drawRect(x - halfSize, y - halfSize, size, size)
        end
    end

    -- compute dot offsets relative to size
    -- set dot color opposite to background
    if black then
        gfx.setColor(gfx.kColorWhite)
    else
        gfx.setColor(gfx.kColorBlack)
    end

    local positions = DOT_POSITIONS[v]
    for _, pos in ipairs(positions) do
        local px = x + pos[1]
        local py = y + pos[2]
        gfx.fillCircleAtPoint(px, py, DICE_DOT_R)
    end
    -- optionally draw numeric value under the die
    if showValue then
        if diceFont then gfx.setFont(diceFont) end
        -- choose text color opposite background for visibility
        if black then gfx.setColor(gfx.kColorWhite) else gfx.setColor(gfx.kColorBlack) end
        gfx.drawTextAligned(tostring(v), x, y + halfSize + 6, kTextAlignment.center)
    end
end