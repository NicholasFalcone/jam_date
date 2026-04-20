class('Crossair').extends()

local gfx = playdate.graphics

function Crossair:init()
    self.x = 400 / 2
    self.y = 240 / 2
    self.hitRadius    = 0   -- set by weapon type (shotgun uses > 0)
    self.reticleScale = 1

    -- Standard reticles
    self.shotgunReticle = gfx.image.new("Sprites/Crossair_shotgun")
    self.normalReticle  = gfx.image.new("Sprites/Crossair")

    -- Bow animated reticle frames (Bow_Crossair_Anim/Crossair_bow1 … Crossair_bow9)
    self.bowFrames = {}
    for i = 1, 11 do
        local img = gfx.image.new("Sprites/Bow_Crossair_Anim/Crossair_bow" .. tostring(i))
        if img then
            self.bowFrames[i] = img
        end
    end
    self.bowActive    = false   -- true only while the Bow weapon is equipped
    self.bowAnimFrame = 1       -- current draw frame (1 = idle, 9 = fully drawn)

    -- Cache normal reticle dimensions for boundary clamping
    local rw, rh = self.normalReticle:getSize()
    self.reticleWidth  = rw
    self.reticleHeight = rh
end

-- ─── Reticle selection ──────────────────────────────────────────────────────

function Crossair:getActiveReticle()
    -- Bow: return the current animation frame
    if self.bowActive then
        -- Clamp to however many frames actually loaded
        local maxFrame = #self.bowFrames
        if maxFrame > 0 then
            local idx = math.max(1, math.min(maxFrame, self.bowAnimFrame))
            return self.bowFrames[idx], 1
        end
    end

    -- Shotgun: large circle reticle
    if self.hitRadius and self.hitRadius > 0 then
        return self.shotgunReticle, self.reticleScale or 1
    end

    -- Default
    return self.normalReticle, self.reticleScale or 1
end

function Crossair:getActiveReticleSize()
    local reticle, scale = self:getActiveReticle()
    if reticle then
        local rw, rh = reticle:getSize()
        return rw * scale, rh * scale
    end
    return self.reticleWidth, self.reticleHeight
end

-- ─── Bow frame control (called by BowWeapon) ────────────────────────────────

--- windRatio: 0.0 (idle) → 1.0 (fully drawn)
function Crossair:setBowWindRatio(ratio)
    -- Map [0, 1] → frame [1, 9]
    local frame = math.floor(ratio * 10) + 1
    self.bowAnimFrame = math.max(1, math.min(11, frame))
end

function Crossair:resetBowAnim()
    self.bowAnimFrame = 1
end

-- ─── Movement ────────────────────────────────────────────────────────────────

function Crossair:move(x, y)
    self.x += x
    self.y += y

    local activeWidth, activeHeight = self:getActiveReticleSize()
    local minX = activeWidth  / 2
    local maxX = 400 - activeWidth  / 2
    local minY = activeHeight / 2
    local maxY = 240 - activeHeight / 2

    self.x = math.max(minX, math.min(self.x, maxX))
    self.y = math.max(minY, math.min(self.y, maxY))
end

function Crossair:resetToCenter()
    self.x = 400 / 2
    self.y = 240 / 2
end

-- ─── Draw ────────────────────────────────────────────────────────────────────

function Crossair:draw()
    local reticle, scale = self:getActiveReticle()

    if reticle then
        local rw, rh = reticle:getSize()
        local scaledWidth  = rw * scale
        local scaledHeight = rh * scale
        local dx = math.floor(self.x - (scaledWidth  / 2) + 0.5)
        local dy = math.floor(self.y - (scaledHeight / 2) + 0.5)

        if scale ~= 1 and reticle.drawScaled then
            reticle:drawScaled(dx, dy, scale, scale)
        else
            reticle:draw(dx, dy)
        end
    end

    -- Small central dot
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(self.x, self.y, 2)
end
