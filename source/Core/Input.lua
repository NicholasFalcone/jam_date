class('Input').extends()

function Input:Init()
    
end

function Input:update()
    
end

function Input:HorizontalValue()
    local h = 0
    if playdate.buttonIsPressed(playdate.kButtonLeft) then 
        h = -1
    elseif playdate.buttonIsPressed(playdate.kButtonRight) then 
        h = 1 
    end
    return h
end

function Input:VertiacalValue()
    local v = 0
    if playdate.buttonIsPressed(playdate.kButtonUp) then 
        v = -1
    elseif playdate.buttonIsPressed(playdate.kButtonDown) then 
        v = 1 
    end
    return v
end