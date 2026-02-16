import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/ui"
import "CoreLibs/crank"


import "Core/UI"
import "Core/Input"
import "Core/GameManager"
import "Core/AudioManager"
import "Game/Crossair"
import "Game/Enemy"
import "Game/Weapon"
import "Game/Dice"

local gfx = playdate.graphics
local screenWidth = playdate.display.getWidth()
local screenHeight = playdate.display.getHeight()

local enemies = {}
local gameManager = GameManager()
local audioManager = AudioManager()

-- Camera shake variables
local cameraShakeX = 0
local cameraShakeY = 0

local Crossair = Crossair()
local Input = Input()
-- Spawn system parameters (configurable)
local SpawnPointsAmount = 6 -- number of spawn points (horizon divisors)
local spawnAngleMin = -15
local spawnAngleMax = 15

local spawnN = 2 -- N: number of enemies per spawn (min 1)
local spawnT = 5 -- T: time between spawns in seconds
local spawnMinT = 0.2 -- minimum allowed spawn interval (seconds)

-- Scaling parameters
local N_ScaleTime = 10.0 -- every X seconds increase N
local N_ScaleValue = 1 -- increase value for N
local T_ScaleTime = 10 -- every X seconds modify T
local T_ScaleValue = -0.5 -- change in seconds to add to T each interval (can be negative)

--- ROAD
local roadScrollOffset = 0
local roadSpeed = 1.0
local cactusScales = {} -- Store random scales for each cactus position

-- Internal timers
local lastSpawnTime = playdate.getElapsedTime()
local lastNScaleTime = playdate.getElapsedTime()
local lastTScaleTime = playdate.getElapsedTime()

--- Enemy variables
local enemySpeed = 0.005
local enemyStartingHealth = 100

--- Weapon selection tracking
local needsWeaponRoll = false

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
local currentWeapon = Weapon.new(weaponTypes[currentWeaponIndex], Crossair)

local UI = UI()

local playerRotation = 0

function Init()
    local menu = playdate.getSystemMenu()
    playdate.startAccelerometer()

    -- Definiamo i valori dello "slider"
    -- local sliderOptions = {"1", "3", "5", "10", "15", "20", "25", "30", "35", "40", "45", "50", "55", "60", "65", "70", "75", "80", "85", "90", "95", "100"}
    -- local enemyHealthSliderOptions = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "10"}
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
    -- menu:addOptionsMenuItem("E..my H:",enemyHealthSliderOptions, 3, function(value)
    --     local numericValue = tonumber(value)
    --     enemyStartingHealth = numericValue
    --     print("Enemy health set to: " .. numericValue)
    --     end)
      -- Caricamento Immagine di Sfondo (versione 500px)
    backgroundImage = gfx.image.new("Sprites/BackgroundArt.png")
    
    if not backgroundImage then
        bgLoadError = "Img non caricata!"
    else
        local w, h = backgroundImage:getSize()
        bgLoadError = "Caricata: " .. w .. "x" .. h
    end
    -- Ensure menu music/UI are initialized without starting gameplay
    if gameManager and gameManager.onIdleEnter then
        pcall(function() gameManager:onIdleEnter() end)
    end
end


Init()


function updateWeaponState(newState)
    if currentWeapon.weaponState == newState then return end
    
    local oldState = currentWeapon.weaponState
    currentWeapon.weaponState = newState
    
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
        local occupied = {}
        for _, en in ipairs(enemies) do
            if en.spawnIndex then occupied[en.spawnIndex] = true end
        end

        local freeIndices = {}
        for idx = 1, #spawnPoints do
            if not occupied[idx] then table.insert(freeIndices, idx) end
        end

        for i = #freeIndices, 2, -1 do
            local j = math.random(1, i)
            freeIndices[i], freeIndices[j] = freeIndices[j], freeIndices[i]
        end

        local toSpawn = math.min(spawnN, #freeIndices)
        for i = 1, toSpawn do
            local idx = freeIndices[i]
            local angle = spawnPoints[idx]
            local e = Enemy(enemyStartingHealth, angle, enemySpeed, idx)
            table.insert(enemies, e)
        end

        lastSpawnTime = now
    end

    -- First, update all enemies (move them, etc.)
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        e:update(playerRotation, Crossair.x, Crossair.y, currentWeapon, gameManager)
    end

    -- Then, handle hit detection when firing
    -- Only process one shot per fire (prevents hitting multiple enemies by moving aim)
 if currentWeapon.weaponState == "firing" and currentWeapon.lastShotValid then
        -- For minigun, we need to be more careful about timing
        if currentWeapon.weaponType == "Minigun" then
            -- Only process if enough time has passed since last shot
            local now = playdate.getElapsedTime()
            if not currentWeapon.lastHitProcessTime or now - currentWeapon.lastHitProcessTime >= currentWeapon.FireRate_Current then
                currentWeapon.lastHitProcessTime = now
                
                -- CRITICAL FIX: Reset hit tracking on all enemies before checking hits
                for _, e in ipairs(enemies) do
                    e:resetHitTracking()
                end
                
                -- Find all enemies that are hit
                local hitEnemies = {}
                for _, e in ipairs(enemies) do
                    if e:checkHit(playerRotation, Crossair.x, Crossair.y, currentWeapon) then
                        table.insert(hitEnemies, e)
                    end
                end
                
                -- Apply hits based on weapon type
                if #hitEnemies > 0 then
                    -- Sort by distance (closest first)
                    table.sort(hitEnemies, function(a, b)
                        return a.distance < b.distance
                    end)
                    -- Hit only the closest one
                    hitEnemies[1]:applyHit(currentWeapon.Damage)
                end
            end
        else
            -- Original logic for other weapons
            if not currentWeapon.shotProcessed then
                currentWeapon.shotProcessed = true
                
                -- CRITICAL FIX: Reset hit tracking on all enemies before checking hits
                for _, e in ipairs(enemies) do
                    e:resetHitTracking()
                end
                
                local hitEnemies = {}
                for _, e in ipairs(enemies) do
                    if e:checkHit(playerRotation, Crossair.x, Crossair.y, currentWeapon) then
                        table.insert(hitEnemies, e)
                    end
                end
                
                if #hitEnemies > 0 then
                    if currentWeapon.weaponType == "Shotgun" then
                        for _, e in ipairs(hitEnemies) do
                            e:applyHit(currentWeapon.Damage)
                        end
                    else
                        table.sort(hitEnemies, function(a, b)
                            return a.distance < b.distance
                        end)
                        hitEnemies[1]:applyHit(currentWeapon.Damage)
                    end
                end
            end
        end
    end
    -- Clean up dead enemies
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        if e.isDead and e.deathTimer <= 0 then
            e:die()
            table.remove(enemies, i)
        elseif e.distance <= -0.2 then
            table.remove(enemies, i)
        end
    end
    
    -- Check if out of ammo
    if currentWeapon and currentWeapon.Ammo and currentWeapon.Ammo <= 0 and not needsWeaponRoll then
        needsWeaponRoll = true
        gameManager:setState("rolling")
    end
end

function DoAim()
    local h = Input:HorizontalValue()
    local v = Input:VertiacalValue()
    Crossair:move(h * 5, v * 5) -- move horizontally and verticaly based on input    
end

function playdate.update()
    -- update game state
    -- update weapon internals (accel/decay and firing timing)
    local now = playdate.getElapsedTime()


    if gameManager:isRunning() then
        -- handle input: crank (only during gameplay)
        local change = Input:getCrankChange()
        if currentWeapon and currentWeapon.onCrankChange then
            currentWeapon:onCrankChange(change)
        end
        
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
            gameManager:setState("rolling")
            gameManager:drawStateScreen(gfx)
            return
        end
    end
    
    -- Always update game manager logic (for time, shake detection, etc)
    gameManager:update(0.016)
    
    -- Stop all weapon sounds if game just entered game over state
    if gameManager:isGameOver() and currentWeapon and currentWeapon.stopAllSounds then
        currentWeapon:stopAllSounds()
    end

    -- Handle state transitions via crank button
    if playdate.buttonJustPressed(playdate.kButtonA) then
        if gameManager:isIdle() then
            -- Reset game state and enemy list before starting
            enemies = {}
            -- Reset spawn manager variables
            local now = playdate.getElapsedTime()
            lastSpawnTime = now
            lastNScaleTime = now
            lastTScaleTime = now
            spawnN = 2  -- Reset to 2 enemies per spawn
            spawnT = 5  -- Reset spawn interval
            needsWeaponRoll = false
            
            -- Start with random weapon and random ammo
            currentWeaponIndex = math.random(1, #weaponTypes)
            local randomAmmo = 100 -- default
            if weaponTypes[currentWeaponIndex] == "Minigun" then
                randomAmmo = math.random(40, 80)
            elseif weaponTypes[currentWeaponIndex] == "Shotgun" then
                randomAmmo = math.random(10, 16)
            elseif weaponTypes[currentWeaponIndex] == "Revolver" then
                randomAmmo = math.random(8, 14)
            end
            currentWeapon:setType(weaponTypes[currentWeaponIndex], randomAmmo)
            
            gameManager:setState("running")
        elseif gameManager:isRolling() then
            -- Apply rolling results and return to running state
            -- Only allow transition if dice have been rolled (RESULTS phase)
            -- AND it wasn't the same frame we triggered the roll (prevents skip)
            if gameManager.rollingPhase == "results" and not gameManager.rolledThisFrame then
                local newWeapon = gameManager.rolledWeapon
                local newAmmo = gameManager.rolledAmmo
                
                if newWeapon and currentWeapon.setType then
                    currentWeapon:setType(newWeapon, newAmmo)
                end
                
                needsWeaponRoll = false
                gameManager:setState("running")
            end
        elseif gameManager:isGameOver() then
            -- Complete reset when going back from game over
            enemies = {}
            needsWeaponRoll = false
            -- Reset spawn variables
            local now = playdate.getElapsedTime()
            lastSpawnTime = now
            lastNScaleTime = now
            lastTScaleTime = now
            spawnN = 2
            spawnT = 5
            
            -- Reset weapon to random selection with random ammo
            currentWeaponIndex = math.random(1, #weaponTypes)
            if currentWeapon and currentWeapon.stopAllSounds then
                currentWeapon:stopAllSounds()
            end
            local randomAmmo = 100 -- default
            if weaponTypes[currentWeaponIndex] == "Minigun" then
                randomAmmo = math.random(40, 80)
            elseif weaponTypes[currentWeaponIndex] == "Shotgun" then
                randomAmmo = math.random(10, 16)
            elseif weaponTypes[currentWeaponIndex] == "Revolver" then
                randomAmmo = math.random(8, 14)
            end
            currentWeapon:setType(weaponTypes[currentWeaponIndex], randomAmmo)
            
            gameManager:setState("idle")
        end
    end

    gfx.clear()

    -- Draw state-specific screens
    if gameManager:isIdle() or gameManager:isRolling() or gameManager:isGameOver() then
        gameManager:drawStateScreen(gfx)
    else
        -- Calculate camera shake offset from weapon (only during gameplay)
        cameraShakeX = 0
        cameraShakeY = 0
        if currentWeapon and currentWeapon.shakeIntensity and currentWeapon.shakeIntensity > 0 then
            local intensity = currentWeapon.shakeIntensity
            cameraShakeX = (math.random() - 0.5) * intensity * 2
            cameraShakeY = (math.random() - 0.5) * intensity * 2
        end
        
        -- Apply camera shake offset
        gfx.setDrawOffset(cameraShakeX, cameraShakeY)
        
        roadScrollOffset = (roadScrollOffset - roadSpeed) % 100
        -- Draw gameplay UI
        drawDesert()
        drawRoad()
        UI:draw(currentWeapon)
        Input.IsMovingForward()
        updateEnemies()
        DoAim()
        -- draw enemies
        drawEnemies()
        if currentWeapon and currentWeapon.draw then currentWeapon:draw() end
        Crossair:draw()
        --playdate.ui.crankIndicator:draw(1,1)
        
        -- Reset draw offset after gameplay drawing
        gfx.setDrawOffset(0, 0)
    end
end


-- Funzione per disegnare il deserto con immagine di sfondo
function drawDesert()
    -- Disegno Immagine di Sfondo
    if backgroundImage then
        backgroundImage:draw(0, 0)
    else
        -- Fallback: Sabbia ditherizzata
        gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer4x4)
        gfx.fillRect(0, 120, screenWidth, 120)
    end
end


function drawRoad()
    local centerX = 200
    local horizonY = 112
    local groundY = 240
    -- gfx.setColor(gfx.kColorWhite)
    local topW = 30
    local botW = 300
    -- gfx.fillPolygon(centerX - topW, horizonY, centerX + topW, horizonY, centerX + botW, groundY, centerX - botW, groundY)
    
    -- Disegna linee stradali e cactus integrati
    gfx.setColor(gfx.kColorBlack)
    for i = 0, 300 do
        local lineZ = (i * 0.08 + (roadScrollOffset / 100)) % 1.0
        local y = horizonY + (lineZ * lineZ) * (groundY - horizonY)
        local w = topW + (lineZ * lineZ) * (botW - topW)
        -- Disegna linea stradale
        gfx.drawLine(centerX - w, y, centerX + w, y)



        -- Disegna cactus ogni 10 tiles
        if i % 30 == 0 and i > 0 then
            -- Dimensione del cactus basata sulla profondità
            local cactusHeight = 10 + lineZ * 40
            local cactusWidth = 3 + lineZ * 8
            
            -- Posiziona i cactus sui bordi della strada
            local leftCactusX = centerX - w - cactusWidth * 2
            local rightCactusX = centerX + w + cactusWidth * 2
            
            -- Disegna cactus sinistro con sua random scale
            if leftCactusX > 0 and leftCactusX < screenWidth then
                local leftKey = "L" .. i  -- Unique key for left cactus
                if not cactusScales[leftKey] then
                    cactusScales[leftKey] = 0.6 + math.random() * 0.4
                end
                drawSingleCactus(leftCactusX, y, cactusHeight, cactusScales[leftKey])
            end
            
            -- Disegna cactus destro con sua random scale
            if rightCactusX > 0 and rightCactusX < screenWidth then
                local rightKey = "R" .. i  -- Unique key for right cactus
                if not cactusScales[rightKey] then
                    cactusScales[rightKey] = 0.6 + math.random() * 0.4
                end
                drawSingleCactus(rightCactusX, y, cactusHeight, cactusScales[rightKey])
            end
        end

    end
end



function drawSingleCactus(x, y, w, randomScale)
    -- Lazy-load cactus image once
    if not cactusImage then
        cactusImage = gfx.image.new("Sprites/Cactus")
    end

    if cactusImage then
        local imgW, imgH = cactusImage:getSize()
        local scale = 1.0
        if imgW and imgW > 0 then
            -- Map the provided width value `w` to a scale factor.
            -- `w` is a small value (depth-based); multiply by 2 to get a visible size.
            scale = (w * 2) / imgW
            -- Apply random scale (0.6 to 1.0)
            scale = scale * (randomScale or 1.0)
        end

        local scaledImage = cactusImage:scaledImage(scale)
        if scaledImage then
            local sw, sh = scaledImage:getSize()
            -- Draw so the bottom of the sprite sits on the given y (ground line)
            scaledImage:draw(x - sw / 2, y - sh)
        end
    end
end


function drawEnemies()
    for _, e in ipairs(enemies) do
        e:draw(playerRotation)
    end
end