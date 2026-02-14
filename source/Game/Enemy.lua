class('Enemy').extends()

local gfx = playdate.graphics

function Enemy:init(speed)
    self.angle = math.random(-15, 15)
    self.distance = 1.0
    self.isDead = false
    self.isHitted = false
    self.hitTimer = 0  -- Timer per l'effetto hit
    self.deathTimer = 0
    self.health = 3  -- Richiede 3 colpi per morire
    self.speed = 0.005
end


function Enemy:update(weaponState, playerRotation, crossX, crossY)
    if self.hitTimer > 0 then
        self.hitTimer -= 1
        if self.hitTimer <= 0 then
            self.isHitted = false
        end
    end

    if not self.isDead then
        self.distance -= 0.005
        if self.distance <= 0 then
            -- reached player, mark dead for removal
            self.isDead = true
        else
            if weaponState == "firing" then
                    -- compute enemy screen position and compare with crosshair
                    local horizonY = 120
                    local groundY = 240
                    local relAngle = (self.angle - playerRotation)
                    local ex = 200 + relAngle * 6
                    local scale = 1.0 - self.distance
                    local ey = horizonY + (scale * scale) * (groundY - horizonY)
                    local size = 10 + scale * 80

                    if crossX and crossY then
                        local dx = math.abs(ex - crossX)
                        local dy = math.abs(ey - crossY)
                        local hitThresholdX = math.max(8, size * 0.4)
                        local hitThresholdY = math.max(8, size * 0.4)
                        if dx <= hitThresholdX and dy <= hitThresholdY then
                            self:hit()
                        end
                    else
                        -- fallback to angle-based check if no crosshair provided
                        if math.abs(relAngle) < 5 then
                            self:hit()
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


function Enemy:hit()
    if not self.isHitted then
        self.isHitted = true
        self.hitTimer = 10  -- Mostra l'effetto per 10 frame (~0.16 sec)
        self.health -= 1
        if self.health <= 0 then
            self.isDead = true
            self.deathTimer = 10
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
    elseif self.isHitted then
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
    else
        local outlineW = 1
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(x - size/4 - outlineW, y - size - outlineW, size/2 + outlineW*2, size + outlineW)
        gfx.fillRect(x - size/2 - outlineW, y - size * 0.7 - outlineW, size + outlineW*2, size/5 + outlineW*2)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(x - size/4, y - size, size/2, size)
        gfx.fillRect(x - size/2, y - size * 0.7, size, size/5)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(x - size/8, y - size * 0.8, size/10)
        gfx.fillCircleAtPoint(x + size/8, y - size * 0.8, size/10)
    end
end