class('Weapon').extends()

local gfx = playdate.graphics
local audioManager = AudioManager()

-- Base weapon class; specific weapons override parameters
function Weapon:init(typeName, ammo, crosshair)
	self.weaponType = typeName or "Minigun"
	self.weaponState = "idle" -- "idle", "winding", "firing"
	self.windUpTime = 0
	self.maxWindUp = 0
	self.firingFrame = 0
	self.cooldownTime = 0
	self.maxCooldown = 0
	self.Ammo = ammo
	self.autoFire = false
	self.crosshair = crosshair
	self.shakeIntensity = 0  -- Camera shake intensity
	self.shakeDecay = 0.8    -- How quickly shake decays
	self:initByType(self.weaponType)
end

function Weapon:initByType(t, ammo)
	if t == "Minigun" then
		self.lastHitProcessTime = 0
		self.maxWindUp = 25
		self.maxCooldown = 10
		self.autoFire = true
		self.Minigun_frames = self:loadMinigunFrames()
		self.Minigun_idleFrameIndex = 1
		-- Minigun specific params
		self.MinCrankSpeed = 5 -- minimum crank delta to count as forward shooting
		self.FireRate_Min = 1 -- initial time between shots (seconds)
		self.FireRate_Current = self.FireRate_Min
		self.FireRate_AccelerationSpeed = 0.4-- every X seconds accelerate
		self.FireRate_AccelerationValue = 0.1 -- reduce time between shots by this
		self.FireRate_DecelerationSpeed = 0.5 -- every X seconds when stopped, decelerate
		self.FireRate_DecelerationValue = 0.1 -- increase time between shots by this
		self.FireRate_Max = 0.1 -- cap: minimum time between shots (fastest)
		self.Damage = 25
		self.isShooting = false
		self.lastAccelTime = playdate.getElapsedTime()
		self.lastDecelTime = playdate.getElapsedTime()
		self.lastShotTime = playdate.getElapsedTime()
		self.Minigun_sfxShot = audioManager:loadSample("sounds/minigun_shot")
		self.Minigun_sfxRotation = audioManager:loadSample("sounds/SFX_MinigunRotation_loop")
		self.Minigun_rotationPlaying = false
		-- Set crosshair hit radius
		if self.crosshair then
			self.crosshair.hitRadius = 0  -- Minigun: precise targeting
		end
	elseif t == "Revolver" then
		self.maxWindUp = 0
		self.maxCooldown = 0
		self.autoFire = false
		self.Revolver_reloadFrames = self:loadRevolverReloadFrames()
		self.Revolver_shootFrames = self:loadRevolverShootFrames()
		self.Revolver_idleFrameIndex = 1
		-- Revolver-specific parameters
		self.Damage = 100
		self.Revolver_ArcSize = 120 -- degrees required for each phase (cock + fire)
		self.Revolver_stage = 0 -- 0 = waiting for cock (CCW), 1 = cocked waiting for release (CW)
		self.Revolver_accum = 0 -- accumulated degrees in current phase
		self.Revolver_lastDir = 0 -- last crank direction seen
		self.Revolver_pendingFire = false -- request to show a single-frame firing state
		self.Revolver_fireTicks = 0 -- number of update ticks to keep `firing` state visible

		self.Revolver_sfxClick = audioManager:loadSample("sounds/revolver_click")
		self.Revolver_sfxShot = audioManager:loadSample("sounds/revolver_shot")
		-- Set crosshair hit radius
		if self.crosshair then
			self.crosshair.hitRadius = 0  -- Revolver: precise targeting
		end
	elseif t == "Shotgun" then
		self.maxWindUp = 0
		self.maxCooldown = 22
		self.autoFire = false
		self.Shotgun_reloadFrames = self:loadShotgunReloadFrames()
		self.Shotgun_shootFrames = self:loadShotgunShootFrames()
		self.Shotgun_idleFrameIndex = 1
		-- Shotgun-specific parameters
		self.Damage = 100
		self.Shotgun_ArcSize = 360 -- degrees required for a complete rotation to fire
		self.Shotgun_accum = 0 -- accumulated degrees in current rotation
		self.Shotgun_lastDir = 0 -- last crank direction seen
		self.Shotgun_AmmoCost = 2 -- ammo consumed per shot
		self.Shotgun_fireTicks = 0
		self.Shotgun_sfxShot = audioManager:loadSample("sounds/shotgun_shot")
		self.Shotgun_sfxReload = audioManager:loadSample("sounds/SFX_ShotgunReload")
		-- Set crosshair hit radius for area damage
		if self.crosshair then
			self.crosshair.hitRadius = 15  -- Shotgun: area of effect damage
		end
	else
		self.maxWindUp = 0
		self.maxCooldown = 30
		self.autoFire = false
	end
	self.windUpTime = 0
	self.cooldownTime = self.maxCooldown
	self.firingFrame = 0
	self.Ammo = ammo or self.Ammo or 100
	self.weaponState = "idle"
end

function Weapon:update(now)
	now = now or playdate.getElapsedTime()
	
	-- Decay camera shake over time
	if self.shakeIntensity and self.shakeIntensity > 0 then
		self.shakeIntensity = self.shakeIntensity * (self.shakeDecay or 0.8)
		if self.shakeIntensity < 0.1 then
			self.shakeIntensity = 0
		end
	end
	
	if self.weaponType == "Minigun" then
		self:updateMinigun(now)
	elseif self.weaponType == "Revolver" then
		self:updateRevolver(now)
	elseif self.weaponType == "Shotgun" then
		self:updateShotgun()
	else
		self:updateCooldown()
	end
end

function Weapon:updateMinigun(now)
	if self.isShooting then
		-- Start rotation sound loop if not already playing
		if not self.Minigun_rotationPlaying and self.Minigun_sfxRotation then
			pcall(function() self.Minigun_sfxRotation:play(0) end) -- 0 = infinite loop
			self.Minigun_rotationPlaying = true
		end
		
		-- Add shake immediately when cranking, build up quickly to max
		self.shakeIntensity = math.min(self.shakeIntensity + 0.15, 1.5)  -- Faster buildup, max at 1.5
		
		-- accelerate fire rate over time
		if now - (self.lastAccelTime or 0) >= (self.FireRate_AccelerationSpeed or 1.0) then
			self.FireRate_Current = math.max(self.FireRate_Max, self.FireRate_Current - (self.FireRate_AccelerationValue or 0.01))
			self.lastAccelTime = now
		end
		
		-- attempt to fire based on current rate
		if now - (self.lastShotTime or 0) >= (self.FireRate_Current or 0.2) then
			-- CRITICAL FIX: Call fire but DON'T reset shotProcessed here
			-- The fire() function already sets shotProcessed = false
			self:fire(1) -- Minigun consumes 1 ammo per shot
			self.lastShotTime = now
			-- REMOVE the self.shotProcessed = false line from here
		else
			if self.weaponState ~= "firing" then self:setState("winding") end
		end
	else
		-- decelerate fire rate when not shooting
		-- Stop rotation sound if playing
		if self.Minigun_rotationPlaying and self.Minigun_sfxRotation then
			pcall(function() self.Minigun_sfxRotation:stop() end)
			self.Minigun_rotationPlaying = false
		end
		
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
        -- ADD THIS LINE
        self.shotProcessed = false
		self.Revolver_pendingFire = false
		local shootFrames = self.Revolver_shootFrames
		local totalNumFrames = (shootFrames and #shootFrames) or 3
		self.Revolver_fireTicks = totalNumFrames * 2 -- 2 internal ticks per animation frame
		self.Revolver_fireFrameIndex = 1
		self:setState("firing")
	end

	if self.Revolver_fireTicks and self.Revolver_fireTicks > 0 then
		self:setState("firing")
		local shootFrames = self.Revolver_shootFrames
		local totalNumFrames = (shootFrames and #shootFrames) or 3
		local totalTicks = totalNumFrames * 2
		
		-- Calculate frame index: stays on each sprite for 2 ticks
		local currentFrame = math.floor((totalTicks - self.Revolver_fireTicks) / 2) + 1
		self.Revolver_fireFrameIndex = math.max(1, math.min(totalNumFrames, currentFrame))
		
		self.Revolver_fireTicks = self.Revolver_fireTicks - 1
	elseif self.weaponState == "firing" then
		-- Animation completely finished
		if self.Revolver_stage == 1 then
			self:setState("cocked")
		else
			self:setState("idle")
		end
	end
	self:updateCooldown()
end

function Weapon:updateShotgun()
	-- Handle firing animation ticks
	if self.Shotgun_fireTicks and self.Shotgun_fireTicks > 0 then
		self:setState("firing")
		local shootFrames = self.Shotgun_shootFrames
		local totalNumFrames = (shootFrames and #shootFrames) or 3
		local totalTicks = totalNumFrames * 2 -- 2 internal ticks per animation frame

		local currentFrame = math.floor((totalTicks - self.Shotgun_fireTicks) / 2) + 1
		self.Shotgun_fireFrameIndex = math.max(1, math.min(totalNumFrames, currentFrame))

		self.Shotgun_fireTicks = self.Shotgun_fireTicks - 1
	elseif self.weaponState == "firing" then
		-- Firing animation finished: transition to reloading if cooldown is active
		if self:isOnCooldown() then
			self:setState("reloading")
		else
			self:setState("idle")
		end
	end

	-- Update cooldown timer
	self:updateCooldown()

	-- If we were explicitly reloading, exit to idle when cooldown finishes
	if self.weaponState == "reloading" and not self:isOnCooldown() then
		self:setState("idle")
	end
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
	-- Stringent guard: don't allow ANY state change if we are in the middle of firing
	if self.weaponState == "firing" or (self.Revolver_fireTicks and self.Revolver_fireTicks > 0) then 
		return 
	end

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
		
		if self.Revolver_accum >= (self.Revolver_ArcSize or 120) then
			if self.Revolver_sfxClick then pcall(function() self.Revolver_sfxClick:play(1) end) end
			self:setState("cocked")
			local excess = self.Revolver_accum - (self.Revolver_ArcSize or 120)
			self.Revolver_stage = 1
			self.Revolver_accum = excess
		else
			self:setState("winding")
		end
	else
		-- Ignore opposite direction
		return
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
		
		if self.Revolver_accum >= (self.Revolver_ArcSize or 120) then
			self.Revolver_pendingFire = true
			self:startCooldown()
			local excess = self.Revolver_accum - (self.Revolver_ArcSize or 120)
			self.Revolver_stage = 0
			self.Revolver_accum = excess
			-- State will be set to "firing" by update loop
		else
			self:setState("winding")
		end
	else
		-- Ignore opposite direction
		return
	end
end

function Weapon:onCrankChangeShotgun(change)
	-- Crank stopped or moving backwards: reset accumulator
	if not change or change <= 0 then 
		self.Shotgun_accum = 0
		
		-- Keep current state (reloading or idle)
		if self.weaponState ~= "firing" then
			if not (self.cooldownTime and self.cooldownTime > 0) then
				self:setState("idle")
			end
		end
		return 
	end

	-- Don't allow winding if currently cooling down or in firing animation
	if self.weaponState == "firing" or (self.Shotgun_fireTicks and self.Shotgun_fireTicks > 0) then 
		return 
	end
	if self.cooldownTime and self.cooldownTime > 0 then
		return
	end

	-- Accumulate crank motion and show winding state
	self.Shotgun_accum = (self.Shotgun_accum or 0) + change
	self:setState("winding")

	if self.Shotgun_accum >= (self.Shotgun_ArcSize or 360) then
		-- Fire: consume ammo and play shot animation
		self:fire(2)
		self.shotProcessed = false
		local shootFrames = self.Shotgun_shootFrames
		local totalNumFrames = (shootFrames and #shootFrames) or 3
		self.Shotgun_fireTicks = totalNumFrames * 2
		self.Shotgun_fireFrameIndex = 1
		-- Start cooldown immediately (reload animation will play after firing animation)
		self:startCooldown()
		if self.Shotgun_sfxReload then
			pcall(function() self.Shotgun_sfxReload:play(1) end)
		end
		self.Shotgun_accum = 0
	end
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

function Weapon:setType(t, ammo)
	-- Stop minigun rotation sound if it's playing before switching weapons
	if self.weaponType == "Minigun" and self.Minigun_rotationPlaying and self.Minigun_sfxRotation then
		pcall(function() self.Minigun_sfxRotation:stop() end)
		self.Minigun_rotationPlaying = false
	end
	
	self.weaponType = t
	self:initByType(t, ammo)
end

-- Helper methods for weapon state management
function Weapon:setState(newState)
	-- Fundamental lock: if we are in the middle of a firing animation, 
	-- do not allow ANY other state change (like winding or idle)
	if self.weaponState == "firing" and newState ~= "firing" then
		local hasTicks = false
		if self.weaponType == "Revolver" then
			hasTicks = (self.Revolver_fireTicks and self.Revolver_fireTicks > 0)
		elseif self.weaponType == "Shotgun" then
			hasTicks = (self.Shotgun_fireTicks and self.Shotgun_fireTicks > 0)
		end
		
		if hasTicks then return end
	end
	
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
	
	-- ADD THIS LINE - marks that this shot hasn't been processed yet
	self.shotProcessed = false
	
	-- Play weapon sound if available
	self:playFireSound()
	
	-- Trigger camera shake based on weapon type
	if hadAmmo then
		if self.weaponType == "Shotgun" then
			self.shakeIntensity = 3.0  -- Strong shake for shotgun
		elseif self.weaponType == "Revolver" then
			self.shakeIntensity = 2.0  -- Medium shake for revolver
		-- Minigun shake is handled in updateMinigun, not here
		end
	end
	
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

-- Stop all looping weapon sounds (especially minigun rotation)
function Weapon:stopAllSounds()
	if self.weaponType == "Minigun" then
		if self.Minigun_rotationPlaying and self.Minigun_sfxRotation then
			pcall(function() self.Minigun_sfxRotation:stop() end)
			self.Minigun_rotationPlaying = false
		end
		self.isShooting = false
	end
end

function Weapon:draw()
	local cx = 200
	local cy = 220
	local w = 140
	local h = 48

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
	if self.Minigun_frames and #self.Minigun_frames > 0 then
		local frameIndex = self.Minigun_idleFrameIndex or 1
		if self.weaponState ~= "idle" then
			frameIndex = (self.firingFrame % #self.Minigun_frames) + 1
		end
		local frame = self.Minigun_frames[frameIndex]
		if frame and frame.drawCentered then
			frame:drawCentered(cx, cy)
		end
	end
	if self.weaponState == "firing" then
		self:drawFlash(cx + 54, cy - 8)
	end
end

function Weapon:drawRevolver(cx, cy)
	local isFiring = (self.Revolver_pendingFire == true) or (self.Revolver_fireTicks and self.Revolver_fireTicks > 0) or (self.weaponState == "firing")
	if isFiring then
		local shootFrames = self.Revolver_shootFrames
		if shootFrames and #shootFrames > 0 then
			local shootIndex = math.max(1, math.min(#shootFrames, self.Revolver_fireFrameIndex or 1))
			local shootFrame = shootFrames[shootIndex]
			if shootFrame and shootFrame.drawCentered then
				shootFrame:drawCentered(cx, cy)
			end
		end
		return
	end

	local reloadFrames = self.Revolver_reloadFrames
	if reloadFrames and #reloadFrames > 0 then
		local reloadIndex = self.Revolver_idleFrameIndex or 1
		if self.weaponState ~= "idle" then
			if self.Revolver_stage == 0 then
				reloadIndex = self:getRevolverReloadFrameIndex(reloadFrames)
			else
				reloadIndex = #reloadFrames
			end
		end
		local reloadFrame = reloadFrames[reloadIndex]
		if reloadFrame and reloadFrame.drawCentered then
			reloadFrame:drawCentered(cx, cy)
		end
	end
end

function Weapon:drawShotgun(cx, cy)
	-- Firing animation takes precedence
	local isFiring = (self.Shotgun_fireTicks and self.Shotgun_fireTicks > 0) or (self.weaponState == "firing")
	if isFiring then
		local shootFrames = self.Shotgun_shootFrames
		if shootFrames and #shootFrames > 0 then
			local shootIndex = math.max(1, math.min(#shootFrames, self.Shotgun_fireFrameIndex or 1))
			local shootFrame = shootFrames[shootIndex]
			if shootFrame and shootFrame.drawCentered then
				shootFrame:drawCentered(cx, cy)
			end
		end
		return
	end

	local reloadFrames = self.Shotgun_reloadFrames
	if reloadFrames and #reloadFrames > 0 then
		-- Idle: single-frame (index stored in Shotgun_idleFrameIndex)
		if self.weaponState == "idle" then
			local idx = self.Shotgun_idleFrameIndex or 1
			local idleFrame = reloadFrames[idx]
			if idleFrame and idleFrame.drawCentered then idleFrame:drawCentered(cx, cy) end
			return
		end

		-- If we're reloading or on cooldown, map reload frames to cooldown progress
		if self.weaponState == "reloading" or self:isOnCooldown() then
			local total = self.maxCooldown or 1
			local progress = math.max(0, math.min(1, (total - (self.cooldownTime or 0)) / total))
			local idx = math.floor(progress * (#reloadFrames - 1)) + 1
			local reloadFrame = reloadFrames[math.max(1, math.min(#reloadFrames, idx))]
			if reloadFrame and reloadFrame.drawCentered then reloadFrame:drawCentered(cx, cy) end
			return
		end

		-- Fallback: show first reload frame
		local fallback = reloadFrames[self.Shotgun_idleFrameIndex or 1]
		if fallback and fallback.drawCentered then fallback:drawCentered(cx, cy) end
	end
end

function Weapon:drawDefault(cx, cy)
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(cx - 40, cy - 16, 80, 24)
	if self.weaponState == "firing" then
		self:drawFlash(cx + 40, cy - 8)
	end
end

function Weapon:loadMinigunFrames()
	local frames = {}
	local basePath = "Sprites/Gun viewmodel/Minigun_rotation/Minigun_rotation - "
	local frameNumbers = {21, 22, 23, 26, 27, 28}
	for _, n in ipairs(frameNumbers) do
		local img = gfx.image.new(basePath .. tostring(n))
		if img then
			table.insert(frames, img)
		end
	end
	return frames
end

function Weapon:loadRevolverReloadFrames()
	local frames = {}
	local basePath = "Sprites/Gun viewmodel/REV_reload/REV_reload - "
	local frameNumbers = {1, 2, 3, 4, 5, 6, 7, 8}
	for _, n in ipairs(frameNumbers) do
		local img = gfx.image.new(basePath .. tostring(n))
		if img then
			table.insert(frames, img)
		end
	end
	return frames
end

function Weapon:loadRevolverShootFrames()
	local frames = {}
	local basePath = "Sprites/Gun viewmodel/REV_Shoot/REV_Shoot - "
	local frameNumbers = {9, 10, 11}
	for _, n in ipairs(frameNumbers) do
		local img = gfx.image.new(basePath .. tostring(n))
		if img then
			table.insert(frames, img)
		end
	end
	return frames
end

function Weapon:loadShotgunReloadFrames()
	local frames = {}
	local basePath = "Sprites/Gun viewmodel/SGN_Reload/SGN_Reload - "
	local frameNumbers = {16, 17, 18, 19, 20, 21}
	for _, n in ipairs(frameNumbers) do
		local img = gfx.image.new(basePath .. tostring(n))
		if img then
			table.insert(frames, img)
		end
	end
	return frames
end

function Weapon:loadShotgunShootFrames()
	local frames = {}
	local basePath = "Sprites/Gun viewmodel/SGN_Shoot/SGN_Shoot - "
	local frameNumbers = {13, 14, 15}
	for _, n in ipairs(frameNumbers) do
		local img = gfx.image.new(basePath .. tostring(n))
		if img then
			table.insert(frames, img)
		end
	end
	return frames
end

function Weapon:getRevolverReloadFrameIndex(frames)
	if not frames or #frames == 0 then return 1 end
	local arc = self.Revolver_ArcSize or 180
	local accum = self.Revolver_accum or 0
	local progress = math.max(0, math.min(1, accum / arc))
	local index = math.floor(progress * (#frames - 1)) + 1
	return math.max(1, math.min(#frames, index))
end

function Weapon:getShotgunReloadFrameIndex(frames)
	if not frames or #frames == 0 then return 1 end
	local arc = self.Shotgun_ArcSize or 150
	local accum = self.Shotgun_accum or 0
	local progress = math.max(0, math.min(1, accum / arc))
	local index = math.floor(progress * (#frames - 1)) + 1
	return math.max(1, math.min(#frames, index))
end

-- Factory helper
function Weapon.new(t, crosshair)
	return Weapon(t, 20, crosshair) -- default to 20 ammo for testing
end