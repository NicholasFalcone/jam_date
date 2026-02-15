class('Weapon').extends()

local gfx = playdate.graphics

-- Helper function to load sound samples safely
local function tryLoadSample(p)
	local ok, sp = pcall(function() return playdate.sound.sampleplayer.new(p) end)
	if ok then return sp end
	-- try with .wav suffix too
	ok, sp = pcall(function() return playdate.sound.sampleplayer.new(p..".wav") end)
	if ok then return sp end
	return nil
end

-- Base weapon class; specific weapons override parameters
function Weapon:init(typeName, ammo)
	self.weaponType = typeName or "Minigun"
	self.weaponState = "idle" -- "idle", "winding", "firing"
	self.windUpTime = 0
	self.maxWindUp = 0
	self.firingFrame = 0
	self.cooldownTime = 0
	self.maxCooldown = 0
	self.Ammo = ammo
	self.autoFire = false
	self:initByType(self.weaponType)
end

function Weapon:initByType(t, ammmo)
	if t == "Minigun" then
		self.maxWindUp = 25
		self.maxCooldown = 10
		self.autoFire = true
		-- Minigun specific params
		self.MinCrankSpeed = 1.5 -- minimum crank delta to count as forward shooting
		self.FireRate_Min = 0.2 -- initial time between shots (seconds)
		self.FireRate_Current = self.FireRate_Min
		self.FireRate_AccelerationSpeed = 1.0 -- every X seconds accelerate
		self.FireRate_AccelerationValue = 0.02 -- reduce time between shots by this
		self.FireRate_DecelerationSpeed = 1.0 -- every X seconds when stopped, decelerate
		self.FireRate_DecelerationValue = 0.03 -- increase time between shots by this
		self.FireRate_Max = 0.05 -- cap: minimum time between shots (fastest)
		self.Damage = 1
		self.isShooting = false
		self.lastAccelTime = playdate.getElapsedTime()
		self.lastDecelTime = playdate.getElapsedTime()
		self.lastShotTime = playdate.getElapsedTime()
		self.Minigun_sfxShot = tryLoadSample("sounds/minigun_shot")
	elseif t == "Revolver" then
		self.maxWindUp = 0
		self.maxCooldown = 30
		self.autoFire = false
		-- Revolver-specific parameters
		self.Damage = 3
		self.Revolver_ArcSize = 180 -- degrees required for each phase (cock + fire)
		self.Revolver_stage = 0 -- 0 = waiting for cock (CCW), 1 = cocked waiting for release (CW)
		self.Revolver_accum = 0 -- accumulated degrees in current phase
		self.Revolver_lastDir = 0 -- last crank direction seen
		self.Revolver_pendingFire = false -- request to show a single-frame firing state
		self.Revolver_fireTicks = 0 -- number of update ticks to keep `firing` state visible

		self.Revolver_sfxClick = tryLoadSample("sounds/revolver_click")
		self.Revolver_sfxShot = tryLoadSample("sounds/revolver_shot")
	elseif t == "Shotgun" then
		self.maxWindUp = 0
		self.maxCooldown = 45
		self.autoFire = false
		-- Shotgun-specific parameters
		self.Damage = 4
		self.Shotgun_ArcSize = 360 -- degrees required for a complete rotation to fire
		self.Shotgun_accum = 0 -- accumulated degrees in current rotation
		self.Shotgun_lastDir = 0 -- last crank direction seen
		self.Shotgun_AmmoCost = 2 -- ammo consumed per shot
		self.Shotgun_sfxShot = tryLoadSample("sounds/shotgun_shot")
	else
		self.maxWindUp = 0
		self.maxCooldown = 30
		self.autoFire = false
	end
	self.windUpTime = 0
	self.cooldownTime = self.maxCooldown
	self.firingFrame = 0
	self.Ammo = ammmo or 100
	self.weaponState = "idle"
end

function Weapon:update(now)
	now = now or playdate.getElapsedTime()
	if self.weaponType == "Minigun" then
		self:updateMinigun(now)
	elseif self.weaponType == "Revolver" then
		self:updateRevolver(now)
	elseif self.weaponType == "Shotgun" then
		self:updateCooldown()
	else
		self:updateCooldown()
	end
end

function Weapon:updateMinigun(now)
	if self.isShooting then
		-- accelerate fire rate over time
		if now - (self.lastAccelTime or 0) >= (self.FireRate_AccelerationSpeed or 1.0) then
			self.FireRate_Current = math.max(self.FireRate_Max, self.FireRate_Current - (self.FireRate_AccelerationValue or 0.01))
			self.lastAccelTime = now
		end
		-- attempt to fire based on current rate
		if now - (self.lastShotTime or 0) >= (self.FireRate_Current or 0.2) then
			self:fire(1) -- Minigun consumes 1 ammo per shot
			self.lastShotTime = now
		else
			if self.weaponState ~= "firing" then self:setState("winding") end
		end
	else
		-- decelerate fire rate when not shooting
		if now - (self.lastDecelTime or 0) >= (self.FireRate_DecelerationSpeed or 1.0) then
			self.FireRate_Current = math.min(self.FireRate_Min, self.FireRate_Current + (self.FireRate_DecelerationValue or 0.02))
			self.lastDecelTime = now
		end
		if self.weaponState == "firing" then
			self:setState("idle")
		end
	end
end

function Weapon:updateRevolver(now)
	if self.Revolver_pendingFire then
		self:fire(1) -- Revolver consumes 1 ammo per shot
		self.Revolver_pendingFire = false
	end
	if self.Revolver_fireTicks and self.Revolver_fireTicks > 0 then
		self.Revolver_fireTicks = math.max(0, self.Revolver_fireTicks - 1)
		if self.Revolver_fireTicks == 0 then
			if self.Revolver_stage == 0 then
				self:setState("idle")
			else
				self:setState("cocked")
			end
		end
	end
	self:updateCooldown()
end

function Weapon:onCrankChange(change)
	if self.weaponType == "Minigun" then
		self:onCrankChangeMinigun(change)
	elseif self.weaponType == "Revolver" then
		self:onCrankChangeRevolver(change)
	elseif self.weaponType == "Shotgun" then
		self:onCrankChangeShotgun(change)
	else
		self:onCrankChangeDefault(change)
	end
end

function Weapon:onCrankChangeMinigun(change)
	if change and change > 0 and math.abs(change) >= (self.MinCrankSpeed or 1.0) then
		self.isShooting = true
		self.lastDecelTime = playdate.getElapsedTime()
	else
		self.isShooting = false
	end
	if change and change > 0 then
		self:bumpFireFrame(change)
	end
end

function Weapon:onCrankChangeRevolver(change)
	if not change or change == 0 then return end
	local dir = 0
	if change > 0 then dir = 1 elseif change < 0 then dir = -1 end
	local absc = math.abs(change)
	
	if self.Revolver_stage == 0 then
		self:onCrankChangeRevolverCock(dir, absc)
	elseif self.Revolver_stage == 1 then
		self:onCrankChangeRevolverFire(dir, absc)
	end
end

function Weapon:onCrankChangeRevolverCock(dir, absc)
	if dir == -1 then
		if self.Revolver_lastDir == -1 or self.Revolver_lastDir == 0 then
			self.Revolver_accum = self.Revolver_accum + absc
		else
			self.Revolver_accum = absc
		end
		self.Revolver_lastDir = -1
		self:setState("winding")
		if self.Revolver_accum >= (self.Revolver_ArcSize or 180) then
			if self.Revolver_sfxClick then pcall(function() self.Revolver_sfxClick:play(1) end) end
			self:setState("cocked")
			self.Revolver_stage = 1
			self.Revolver_accum = 0
		end
	else
		self.Revolver_accum = 0
		self.Revolver_lastDir = dir
		self:setState("idle")
	end
end

function Weapon:onCrankChangeRevolverFire(dir, absc)
	if dir == 1 then
		if self.Revolver_lastDir == 1 or self.Revolver_lastDir == 0 then
			self.Revolver_accum = self.Revolver_accum + absc
		else
			self.Revolver_accum = absc
		end
		self.Revolver_lastDir = 1
		self:setState("winding")
		if self.Revolver_accum >= (self.Revolver_ArcSize or 180) then
			self.Revolver_pendingFire = true
			self:startCooldown()
			self.Revolver_stage = 0
			self.Revolver_accum = 0
		end
	else
		self.Revolver_accum = 0
		self.Revolver_lastDir = dir
		self:setState("cocked")
	end
end

function Weapon:onCrankChangeShotgun(change)
	if not self.Shotgun_accum then
		self.Shotgun_accum = 0
		self.Shotgun_lastDir = 0
	end
	if not change or change == 0 then return end
	local dir = 0
	if change > 0 then dir = 1 elseif change < 0 then dir = -1 end
	local absc = math.abs(change)
	
	if self:isOnCooldown() then
		self:setState("idle")
		return
	end
	
	if dir ~= (self.Shotgun_lastDir or 0) and (self.Shotgun_lastDir or 0) ~= 0 then
		self.Shotgun_accum = 0
	end
	self.Shotgun_lastDir = dir
	self.Shotgun_accum = (self.Shotgun_accum or 0) + absc
	self:setState("winding")
	
	if (self.Shotgun_accum or 0) >= (self.Shotgun_ArcSize or 360) then
		-- Fire (returns true if had ammo, but fires anyway even at 0 ammo)
		self:fire(2)
		-- Always start cooldown and reset on complete rotation
		self:startCooldown()
		self.Shotgun_accum = 0
		self.Shotgun_lastDir = 0
	end
	self:bumpFireFrame(change)
end

function Weapon:onCrankChangeDefault(change)
	if math.abs(change) > 1 then
		if self.maxWindUp > 0 then
			self:setState("winding")
			self.windUpTime = math.min(self.maxWindUp, self.windUpTime + 1)
			if self.windUpTime >= self.maxWindUp and self.cooldownTime <= 0 then
				self:setState("firing")
				self:startCooldown()
			end
		else
			if self.cooldownTime <= 0 then
				self:setState("firing")
				self:startCooldown()
			end
		end
		self:bumpFireFrame(change)
	else
		if self.weaponState == "winding" then
			self.windUpTime = math.max(0, self.windUpTime - 2)
			if self.windUpTime == 0 then self:setState("idle") end
		else
			self:setState("idle")
			self.windUpTime = math.max(0, self.windUpTime - 1)
		end
	end
	self:updateCooldown()
end

function Weapon:setType(t)
	self.weaponType = t
	self:initByType(t)
end

-- Helper methods for weapon state management
function Weapon:setState(newState)
	self.weaponState = newState
end

function Weapon:consumeAmmo(amount)
	amount = amount or 1
	if (self.Ammo or 0) >= amount then
		self.Ammo = (self.Ammo or 0) - amount
		return true
	end
	return false
end

function Weapon:startCooldown()
	self.cooldownTime = self.maxCooldown
end

function Weapon:isOnCooldown()
	return self.cooldownTime > 0
end

function Weapon:updateCooldown()
	if self.cooldownTime > 0 then
		self.cooldownTime = math.max(0, self.cooldownTime - 1)
	end
end

function Weapon:triggerFire()
	self:setState("firing")
	self.firingFrame = self.firingFrame + 1
end

function Weapon:bumpFireFrame(change)
	if change and change ~= 0 then
		self.firingFrame = self.firingFrame + math.floor(math.abs(change)/2) + 1
	end
end

-- Central fire logic: handles ammo, sounds, and firing state
function Weapon:fire(ammoConsumption)
	ammoConsumption = ammoConsumption or 1
	local hadAmmo = false
	
	-- Check if we have enough ammo
	if (self.Ammo or 0) >= ammoConsumption then
		-- Enough ammo: consume requested amount
		self:consumeAmmo(ammoConsumption)
		hadAmmo = true
	elseif (self.Ammo or 0) >= 1 then
		-- Not enough: consume what we have
		self:consumeAmmo(self.Ammo)
		hadAmmo = true
	end
	-- If ammo == 0, still fire animation but hadAmmo = false (no damage)
	
	-- Store if this shot is valid (had ammo) for damage calculation
	self.lastShotValid = hadAmmo
	
	-- Play weapon sound if available
	self:playFireSound()
	
	-- Trigger firing state and visuals - ALWAYS, even with 0 ammo
	self:triggerFire()
	
	return hadAmmo  -- true if we had ammo to consume, false if we fired empty
end

-- Play weapon-specific fire sound
function Weapon:playFireSound()
	if self.weaponType == "Revolver" then
		if self.Revolver_sfxShot then
			pcall(function() self.Revolver_sfxShot:play(1) end)
		end
	elseif self.weaponType == "Shotgun" then
		-- Add shotgun sound here when available
		if self.Shotgun_sfxShot then
			pcall(function() self.Shotgun_sfxShot:play(1) end)
		end
	elseif self.weaponType == "Minigun" then
		-- Add minigun sound here when available
		if self.Minigun_sfxShot then
			pcall(function() self.Minigun_sfxShot:play(1) end)
		end
	end
end

function Weapon:draw()
	local cx = 200
	local cy = 220
	local w = 140
	local h = 48

	-- shadow / ground plate
	gfx.setColor(gfx.kColorBlack)
	gfx.fillRect(cx - w/2, cy - h/2 + 6, w, h)

	-- dispatch to weapon-specific draw
	if self.weaponType == "Minigun" then
		self:drawMinigun(cx, cy)
	elseif self.weaponType == "Revolver" then
		self:drawRevolver(cx, cy)
	elseif self.weaponType == "Shotgun" then
		self:drawShotgun(cx, cy)
	else
		self:drawDefault(cx, cy)
	end
end

function Weapon:drawFlash(x, y)
	gfx.setColor(gfx.kColorWhite)
	gfx.fillCircleAtPoint(x, y, 6)
	gfx.setColor(gfx.kColorBlack)
	gfx.fillCircleAtPoint(x, y, 3)
end

function Weapon:drawMinigun(cx, cy)
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(cx - 30, cy - 18, 60, 30)
	local bx = cx + 40
	local by = cy - 6
	for i = 0, 3 do
		local ang = (self.firingFrame * 8 + i * 90) % 360
		local rx = bx + math.cos(math.rad(ang)) * 16
		local ry = by + math.sin(math.rad(ang)) * 4
		gfx.drawLine(bx, by, rx, ry)
	end
	if self.weaponState == "firing" then
		self:drawFlash(bx + 22, by)
	end
end

function Weapon:drawRevolver(cx, cy)
	local cylX = cx - 10
	local cylY = cy - 6
	gfx.setColor(gfx.kColorWhite)
	gfx.fillCircleAtPoint(cylX, cylY, 18)
	gfx.setColor(gfx.kColorBlack)
	gfx.fillCircleAtPoint(cylX, cylY, 10)
	
	local bx = cylX + 26
	local by = cylY - 4
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(bx, by, 40, 10)
	gfx.setColor(gfx.kColorBlack)
	gfx.fillRect(bx + 34, by + 2, 6, 6)
	
	local hx = cylX - 6
	local hy = cylY - 22
	if self.weaponState == "cocked" then
		gfx.fillRect(hx, hy - 6, 12, 12)
	else
		gfx.fillRect(hx, hy, 12, 8)
	end
	
	if self.weaponState == "firing" then
		self:drawFlash(bx + 42, by + 5)
	end
end

function Weapon:drawShotgun(cx, cy)
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(cx - 60, cy - 18, 110, 20)
	
	local pumpOffset = 0
	if self.weaponState == "winding" then
		pumpOffset = ((self.Shotgun_accum or 0) / (self.Shotgun_ArcSize or 360)) * 8
	end
	gfx.setColor(gfx.kColorBlack)
	gfx.fillRect(cx + 30 + pumpOffset, cy - 8, 14, 8)
	
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(cx + 44, cy - 14, 8, 12)
	if self.weaponState == "firing" then
		self:drawFlash(cx + 54, cy - 8)
	end
end

function Weapon:drawDefault(cx, cy)
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(cx - 40, cy - 16, 80, 24)
	if self.weaponState == "firing" then
		self:drawFlash(cx + 40, cy - 8)
	end
end

-- Factory helper
function Weapon.new(t)
	return Weapon(t, 100) -- default to 100 ammo for testing
end