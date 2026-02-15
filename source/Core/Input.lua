class('Input').extends()

function Input:Init()
    
end

function Input:update()
    
end

function Input:getCrankChange()
    local change = playdate.getCrankChange()
    return change
end

local ticksPerRevolution = 6

function Input:IsMovingForward()
    local crankTicks = playdate.getCrankTicks(ticksPerRevolution)
    if crankTicks == 1 then
        return true
    elseif crankTicks == -1 then
        return false
    end
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