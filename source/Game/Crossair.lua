class('Crossair').extends()


function Crossair:init()
    
end

function Crossair:draw(x, y)
    local gfx = playdate.graphics
    
    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(x - 10, y, x + 10, y)
    gfx.drawLine(x, y - 10, x, y + 10)
end