class('Crossair').extends()

function Crossair:init()
    self.x = 400 / 2
    self.y = 240 / 2
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
end