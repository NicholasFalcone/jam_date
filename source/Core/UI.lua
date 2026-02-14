class('UI').extends()

function UI:init()
end

-- UI richiamata ogni frame per disegnare elementi come testo, barre della salute, ecc.
function UI:draw()
    local gfx = playdate.graphics
    gfx.drawText("Hello!", 5, 220)
end