import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

import "Core/UI"
import "Game/Crossair"
import "Game/Enemy"
import "Game/Weapon"

local gfx = playdate.graphics

local screenWidth = 400
local screenHeight = 240

local enemies = {}
local spawnTimer = 0
local spawnRate = 60

local currentWeapon = Weapon()

local UI = UI()

local playerRotation = 0

function Init()
    
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
    spawnTimer += 1
    if spawnTimer >= spawnRate then
        spawnEnemy()
        spawnTimer = 0
    end

    for i = #enemies, 1, -1 do
        local e = enemies[i]
        e:update(currentWeapon.weaponState, playerRotation)
        if e.isDead and e.deathTimer <= 0 then
            e:die()
            table.remove(enemies, i)
        elseif e.distance <= 0 then
            table.remove(enemies, i)
        end
    end
end

function spawnEnemy()
    table.insert(enemies, Enemy())
end


function playdate.update()
    -- update game state
    updateEnemies()

    gfx.clear()
    UI:draw()

    -- draw enemies
    for _, e in ipairs(enemies) do
        e:draw(playerRotation)
    end
end

