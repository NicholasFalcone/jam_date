class('Dice').extends()

local gfx = playdate.graphics

function Dice:init()
    self.value = 1
end


function Dice:roll()
    self.value = math.random(1, 6)
end

function Dice:draw(x, y, black, showValue)
    local size = 40
    local halfSize = size / 2

    -- sanitize value
    local v = math.floor(tonumber(self.value) or 1)
    if v < 1 then v = 1 end
    if v > 6 then v = 6 end

    -- Draw dice background and border
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

    -- compute dot offsets relative to size
    local quarter = math.floor(size * 0.25)
    local eighth = math.floor(size * 0.125)
    local dotR = math.max(2, math.floor(size * 0.08))

    local dotPositions = {
        [1] = {{0, 0}},
        [2] = {{-quarter, -quarter}, {quarter, quarter}},
        [3] = {{-quarter, -quarter}, {0, 0}, {quarter, quarter}},
        [4] = {{-quarter, -quarter}, {-quarter, quarter}, {quarter, -quarter}, {quarter, quarter}},
        [5] = {{-quarter, -quarter}, {-quarter, quarter}, {0, 0}, {quarter, -quarter}, {quarter, quarter}},
        [6] = {{-quarter, -eighth*3}, {-quarter, 0}, {-quarter, eighth*3}, {quarter, -eighth*3}, {quarter, 0}, {quarter, eighth*3}}
    }
    -- set dot color opposite to background
    if black then
        gfx.setColor(gfx.kColorWhite)
    else
        gfx.setColor(gfx.kColorBlack)
    end

    local positions = dotPositions[v]
    for _, pos in ipairs(positions) do
        local px = x + pos[1]
        local py = y + pos[2]
        gfx.fillCircleAtPoint(px, py, dotR)
    end
    -- optionally draw numeric value under the die
    if showValue then
        local font = gfx.font.new('font/Asheville-Sans-14-Bold')
        if font then gfx.setFont(font) end
        -- choose text color opposite background for visibility
        if black then gfx.setColor(gfx.kColorWhite) else gfx.setColor(gfx.kColorBlack) end
        gfx.drawTextAligned(tostring(v), x, y + halfSize + 6, kTextAlignment.center)
    end
end