class('Crossair').extends()

function Crossair:init()
    self.x = 400 / 2
    self.y = 240 / 2
    self.hitRadius = 0  -- Default no radius, will be set by weapon type
end

function Crossair:move(x, y)
    self.x += x
    self.y += y
end

function Crossair:draw()
    local gfx = playdate.graphics

    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(self.x - 10, self.y, self.x + 10, self.y)
    gfx.drawLine(self.x, self.y - 10, self.x, self.y + 10)
    
    -- Draw hit radius circle if > 0
    if self.hitRadius and self.hitRadius > 0 then
        gfx.drawCircleAtPoint(self.x, self.y, self.hitRadius)
    end
end