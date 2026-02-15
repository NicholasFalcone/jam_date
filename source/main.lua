import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/ui"
import "CoreLibs/crank"


import "Core/UI"
import "Core/Input"
import "Game/Crossair"
import "Game/Enemy"
import "Game/Weapon"
import "Game/Dice"

local gfx = playdate.graphics

local enemies = {}

local Crossair = Crossair()
local Input = Input()
-- Spawn system parameters (configurable)
local SpawnPointsAmount = 6 -- number of spawn points (horizon divisors)
local spawnAngleMin = -15
local spawnAngleMax = 15

local spawnN = 1 -- N: number of enemies per spawn (min 1)
local spawnT = 2.0 -- T: time between spawns in seconds
local spawnMinT = 0.25 -- minimum allowed spawn interval (seconds)

-- Scaling parameters
local N_ScaleTime = 15.0 -- every X seconds increase N
local N_ScaleValue = 1 -- increase value for N
local T_ScaleTime = 20.0 -- every X seconds modify T
local T_ScaleValue = 0.0 -- change in seconds to add to T each interval (can be negative)

-- Internal timers
local lastSpawnTime = playdate.getElapsedTime()
local lastNScaleTime = playdate.getElapsedTime()
local lastTScaleTime = playdate.getElapsedTime()

--- Enemy variables
local enemySpeed = 0.005
local enemyStartingHealth = 3

--- Dices
local dice1 = Dice()
local dice2 = Dice()
local dice3 = Dice()

--- Inputs

--- 

---Weapon

local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function computeSpawnPoints()
    local points = {}
    local count = math.max(1, SpawnPointsAmount)
    for i = 1, count do
        local t = i / (count + 1)
        local angle = spawnAngleMin + t * (spawnAngleMax - spawnAngleMin)
        table.insert(points, angle)
    end
    return points
end

local spawnPoints = computeSpawnPoints()

local weaponTypes = {"Minigun", "Revolver", "Shotgun"}
local currentWeaponIndex = 1
local currentWeapon = Weapon.new(weaponTypes[currentWeaponIndex])

local UI = UI()

local playerRotation = 0

function Init()
    local menu = playdate.getSystemMenu()

    -- Definiamo i valori dello "slider"
    local sliderOptions = {"1", "3", "5", "10", "15", "20", "25", "30", "35", "40", "45", "50", "55", "60", "65", "70", "75", "80", "85", "90", "95", "100"}
    local enemyHealthSliderOptions = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "10"}
    --- Spawning menu item variables
    -- menu:addOptionsMenuItem("N_STm:", sliderOptions, N_ScaleTime, function(value)
    --     local numericValue = tonumber(value)
    --     N_ScaleTime = numericValue
    --     end)
    -- menu:addOptionsMenuItem("N_SVle:",sliderOptions, N_ScaleValue, function(value)
    --     local numericValue = tonumber(value)
    --     N_ScaleValue = numericValue
    --     end)
    -- menu:addOptionsMenuItem("T_STm:",sliderOptions, T_ScaleTime, function(value)
    --     local numericValue = tonumber(value)
    --     T_ScaleTime = numericValue
    --     end)
    -- menu:addOptionsMenuItem("T_SVle:",sliderOptions, T_ScaleValue, function(value)
    --     local numericValue = tonumber(value)
    --     T_ScaleValue = numericValue
    --     end)

    --- Enemy menu item variables
    menu:addOptionsMenuItem("E..my H:",enemyHealthSliderOptions, enemyStartingHealth, function(value)
        local numericValue = tonumber(value)
        enemyStartingHealth = numericValue
        end)

end


Init()


function updateWeaponState(newState)
    if currentWeapon.weaponState == newState then return end
    
    local oldState = currentWeapon.weaponState
    currentWeapon.weaponState = newState
    
    -- -- Gestione Suoni
    -- if oldState == "winding" and sfxLoading then sfxLoading:stop() end
    -- if oldState == "firing" and sfxShooting then sfxShooting:stop() end
    
    -- if newState == "winding" and sfxLoading then sfxLoading:play(0) end
    -- if newState == "firing" and sfxShooting then sfxShooting:play(0) end
end

function updateEnemies()
    local now = playdate.getElapsedTime()

    -- scaling for N
    if N_ScaleTime > 0 and now - lastNScaleTime >= N_ScaleTime then
        spawnN = clamp(spawnN + N_ScaleValue, 1, #spawnPoints)
        lastNScaleTime = now
    end

    -- scaling for T
    if T_ScaleTime > 0 and now - lastTScaleTime >= T_ScaleTime then
        spawnT = math.max(spawnMinT, spawnT + T_ScaleValue)
        lastTScaleTime = now
    end

    -- spawn based on elapsed seconds
    if now - lastSpawnTime >= spawnT then
        -- determine free spawn indices
        local occupied = {}
        for _, en in ipairs(enemies) do
            if en.spawnIndex then occupied[en.spawnIndex] = true end
        end

        local freeIndices = {}
        for idx = 1, #spawnPoints do
            if not occupied[idx] then table.insert(freeIndices, idx) end
        end

        -- shuffle freeIndices
        for i = #freeIndices, 2, -1 do
            local j = math.random(1, i)
            freeIndices[i], freeIndices[j] = freeIndices[j], freeIndices[i]
        end

        local toSpawn = math.min(spawnN, #freeIndices)
        for i = 1, toSpawn do
            local idx = freeIndices[i]
            local angle = spawnPoints[idx]
            local e = Enemy()
            e.angle = angle
            e.spawnIndex = idx
            table.insert(enemies, e)
        end

        lastSpawnTime = now
    end

    -- update existing enemies and cleanup
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        e:update(currentWeapon.weaponState, playerRotation, Crossair.x, Crossair.y)
        if e.isDead and e.deathTimer <= 0 then
            e:die()
            table.remove(enemies, i)
        elseif e.distance <= 0 then
            table.remove(enemies, i)
        end
    end
end

function spawnEnemy()
    -- simple single spawn (kept for compatibility)
    local pts = computeSpawnPoints()
    local idx = math.random(1, #pts)
    local e = Enemy()
    e.angle = pts[idx]
    e.spawnIndex = idx
    e.speed = enemySpeed
    e.health = enemyStartingHealth
    table.insert(enemies, e)
end



function DoAim()
    local h = Input:HorizontalValue()
    local v = Input:VertiacalValue()
    Crossair:move(h * 5, v * 5) -- move horizontally and verticaly based on input    
end

function playdate.update()
    -- update game state
    -- handle input: crank
    local change = Input:getCrankChange()
    if currentWeapon and currentWeapon.onCrankChange then
        currentWeapon:onCrankChange(change)
    end

    -- update weapon internals (accel/decay and firing timing)
    local now = playdate.getElapsedTime()
    if currentWeapon and currentWeapon.update then
        currentWeapon:update(now)
    end

    -- weapon switch (button B)
    if playdate.buttonJustPressed(playdate.kButtonB) then
        currentWeaponIndex = (currentWeaponIndex % #weaponTypes) + 1
        local newType = weaponTypes[currentWeaponIndex]
        if currentWeapon and currentWeapon.setType then
            print("Change weapon to " .. newType)
            currentWeapon:setType(newType, 100) -- reset ammo to 100 on switch for testing
        else
            print ("Switching weapon to " .. newType)
            currentWeapon = Weapon.new(newType)
        end
    end
    --- testing dice roll with button A
    if playdate.buttonJustPressed(playdate.kButtonA) then
        rollDice()
    end


    updateEnemies()
    DoAim()
    gfx.clear()
    UI:draw(currentWeapon)
    Input.IsMovingForward()

    -- draw enemies
    drawDice()
    drawEnemies()
    if currentWeapon and currentWeapon.draw then currentWeapon:draw() end
    Crossair:draw()
    playdate.ui.crankIndicator:draw(1,1)
end

function drawEnemies()
    for _, e in ipairs(enemies) do
        e:draw(playerRotation)
    end
end



function rollDice()
    dice1:roll()
    dice2:roll()
    dice3:roll()
end 

function drawDice()
    dice1:draw(50, 50, false)
    dice2:draw(100, 50, true)
    dice3:draw(150, 50, true)
end

