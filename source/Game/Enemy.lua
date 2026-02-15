class('Enemy').extends()

local gfx = playdate.graphics

local audioManager = AudioManager()

function Enemy:init(_health, _angle, _speed, _spawnIndex)
    self.angle = _angle or math.random(-15, 15)
    self.distance = 1.0
    self.isDead = false
    self.isHitted = false
    self.hitTimer = 0  -- Timer per l'effetto hit
    self.deathTimer = 0
    self.health = _health  -- Richiede 3 colpi per morire
    self.speed = _speed or 0.005
    self.spawnIndex = _spawnIndex
    self.SFX_Death = audioManager:loadSample("sounds/SFX_EnemyDeath")
    self.SFX_Hit = audioManager:loadSample("sounds/SFX_EnemyHit")
    self.enemyGoalPosition = 0.1 --- Offset from 0 to trigger player damage (reaching the "ground")
    -- Load enemy sprite
    self.sprite = gfx.image.new("Sprites/Enemies/Enemy_01")
end

function Enemy:update(playerRotation, crossX, crossY, weapon, gameManager)
    if self.hitTimer > 0 then
        self.hitTimer -= 1
        if self.hitTimer <= 0 then
            self.isHitted = false
        end
    end

    if not self.isDead then
        self.distance -= 0.005
        if self.distance <= self.enemyGoalPosition then
            -- reached player, trigger game over
            if gameManager then
                gameManager:takeDamage(100)
            end
            self.isDead = true
        else
            if weapon.weaponState == "firing" then
                    -- compute enemy screen position and compare with crosshair
                    local horizonY = 120
                    local groundY = 240
                    local relAngle = (self.angle - playerRotation)
                    local ex = 200 + relAngle * 6
                    local scale = 1.0 - self.distance
                    local ey = horizonY + (scale * scale) * (groundY - horizonY)
                    local size = 10 + scale * 80

                    if crossX and crossY then
                        -- Center hit detection on the actual enemy position (upper part of the body)
                        local ey_center = ey - size / 2
                        local dx = math.abs(ex - crossX)
                        local dy = math.abs(ey_center - crossY)
                        -- Larger hitbox to cover the entire enemy sprite
                        local hitThresholdX = math.max(12, size * 0.5)
                        local hitThresholdY = math.max(16, size * 0.6)
                        -- Only take damage if weapon has ammo (lastShotValid)
                        if dx <= hitThresholdX and dy <= hitThresholdY and (weapon and weapon.lastShotValid) then
                            self:hit(weapon.Damage)
                        end
                    else
                        -- fallback to angle-based check if no crosshair provided
                        if math.abs(relAngle) < 5 then
                            self:hit(weapon.Damage)
                        end
                    end
                end
        end
    else
        if self.deathTimer > 0 then
            self.deathTimer -= 1
        end
    end
end

function Enemy:hit(dmg)
    if not self.isHitted then
        self.isHitted = true
        self.hitTimer = 3  -- Mostra l'effetto per 10 frame (~0.16 sec)
        self.health -= dmg
        if self.SFX_Hit then
            pcall(function() self.SFX_Hit:play(1) end)
        end
        print("Enemy HIT! Health remaining: " .. self.health)
        if self.health <= 0 then
            self.isDead = true
            self.deathTimer = 10
            if self.SFX_Death then
                pcall(function() self.SFX_Death:play(1) end)
            end
            print("Enemy DIED")
        end
    end
end

function Enemy:die()
    -- placeholder for any death logic (sound, particles)
end


function Enemy:draw(playerRotation)
    local horizonY = 120
    local groundY = 240

    local relAngle = (self.angle - (playerRotation or 0))
    local x = 200 + relAngle * 6
    local scale = 1.0 - self.distance
    local y = horizonY + (scale * scale) * (groundY - horizonY)
    local size = 10 + scale * 80

    if self.isDead then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillCircleAtPoint(x, y - size/2, size * 1.5)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(x, y - size/2, size)
    else
        -- Draw sprite scaled based on distance
        if self.sprite then
            local scaledWidth = math.floor(self.sprite.width * scale)
            local scaledHeight = math.floor(self.sprite.height * scale)
            local scaledImage = self.sprite:scaledImage(scale)
            scaledImage:draw(x - scaledWidth/2, y - scaledHeight/2)
        end
        
        -- Show hit effect on top of sprite
        if self.isHitted then
            -- Effetto sangue (splash)
            gfx.setColor(gfx.kColorWhite)
            for i = 0, 7 do
                local angle = math.rad(i * 45 + math.random(-10, 10))
                local len = size * 0.3 + math.random(0, math.max(1, math.floor(size * 0.2)))
                local startX = x + math.cos(angle) * size * 0.3
                local startY = (y - size/2) + math.sin(angle) * size * 0.3
                local endX = startX + math.cos(angle) * len
                local endY = startY + math.sin(angle) * len
                gfx.drawLine(startX, startY, endX, endY)
            end
            for i = 1, 5 do
                local maxOffset = math.max(1, math.floor(size/2))
                local dropX = x + math.random(-maxOffset, maxOffset)
                local dropY = (y - size/2) + math.random(-maxOffset, maxOffset)
                gfx.fillCircleAtPoint(dropX, dropY, 1 + math.random(0, 2))
            end
        end
    end
end