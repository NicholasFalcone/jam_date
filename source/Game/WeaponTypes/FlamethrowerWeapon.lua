local gfx = playdate.graphics

local function drawFrameWithOffset(frame, cx, cy, offsetX, offsetY)
	if frame and frame.drawCentered then
		frame:drawCentered(cx + (offsetX or 0), cy + (offsetY or 0))
	end
end

local function getRandomVelocity(self)
	local minVelocity = self.Flamethrower_MinVelocity or 0.18
	local maxVelocity = self.Flamethrower_MaxVelocity or 0.42
	local magnitude = minVelocity + math.random() * (maxVelocity - minVelocity)
	if math.random(0, 1) == 0 then
		return -magnitude
	end
	return magnitude
end

local function randomizeDrift(self, now)
	self.Flamethrower_SystemVelocity = getRandomVelocity(self)
	self.Flamethrower_NextDriftChangeTime = (now or playdate.getElapsedTime()) + 0.25 + math.random() * 0.55
end

local function resetPressure(self, now)
	self.Flamethrower_PressurePosition = 0.5
	self.Flamethrower_lastUpdateTime = now or playdate.getElapsedTime()
	self.Flamethrower_isFiring = false
	randomizeDrift(self, now)
end

local function isStable(self)
	local position = self.Flamethrower_PressurePosition or 0.5
	return position >= (self.Flamethrower_TargetMin or 0.42) and position <= (self.Flamethrower_TargetMax or 0.58)
end

local function configure(self)
	self.maxWindUp = 0
	self.maxCooldown = 0
	self.autoFire = true
	self.Damage = 10
	self.Flamethrower_frames = self:loadFrameSequence("Sprites/Gun viewmodel/FLAME/FLAME - ", {0, 1, 2})
	self.Flamethrower_particleFrames = self:loadFrameSequence("Sprites/Gun viewmodel/FLAME_Particle/FLAME_Particle - ", {1, 2, 3, 4})
	self.Flamethrower_idleFrameIndex = 1
	self.Flamethrower_offsetX = 96
	self.Flamethrower_offsetY = -139
	self.Flamethrower_particleOffsetX = 176
	self.Flamethrower_particleOffsetY = -6
	self.lastHitProcessTime = 0
	self.lastShotTime = playdate.getElapsedTime()
	self.Flamethrower_AmmoCost = 1
	self.Flamethrower_FireRate = 0.12
	self.Flamethrower_TargetMin = 0.42
	self.Flamethrower_TargetMax = 0.58
	self.Flamethrower_CrankInfluence = 0.002
	self.Flamethrower_CrankDeadzone = 1.5
	self.Flamethrower_MaxCrankStep = 8
	self.Flamethrower_MinVelocity = 0.18
	self.Flamethrower_MaxVelocity = 0.42
	self.Flamethrower_PressurePosition = 0.5
	self.Flamethrower_SystemVelocity = 0
	self.Flamethrower_NextDriftChangeTime = 0
	self.Flamethrower_lastUpdateTime = playdate.getElapsedTime()
	self.Flamethrower_isFiring = false
	resetPressure(self, playdate.getElapsedTime())

	if self.crosshair then
		self.crosshair.hitRadius = 0
		self.crosshair.reticleScale = 1
	end
end

local function update(self, now)
	local lastUpdate = self.Flamethrower_lastUpdateTime or now
	local deltaTime = now - lastUpdate
	if deltaTime < 0 then
		deltaTime = 0
	end
	if deltaTime > 0.05 then
		deltaTime = 0.05
	end
	self.Flamethrower_lastUpdateTime = now

	if now >= (self.Flamethrower_NextDriftChangeTime or 0) then
		randomizeDrift(self, now)
	end

	self.Flamethrower_PressurePosition = (self.Flamethrower_PressurePosition or 0.5) + ((self.Flamethrower_SystemVelocity or 0) * deltaTime)

	if self.Flamethrower_PressurePosition <= 0 then
		self.Flamethrower_PressurePosition = 0
		self.Flamethrower_SystemVelocity = math.abs(getRandomVelocity(self))
	elseif self.Flamethrower_PressurePosition >= 1 then
		self.Flamethrower_PressurePosition = 1
		self.Flamethrower_SystemVelocity = -math.abs(getRandomVelocity(self))
	end

	local hasAmmo = (self.Ammo or 0) > 0
	self.Flamethrower_isFiring = isStable(self) and hasAmmo

	if self.Flamethrower_isFiring then
		self.shakeIntensity = math.min((self.shakeIntensity or 0) + 0.08, 1.4)
		if now - (self.lastShotTime or 0) >= (self.Flamethrower_FireRate or 0.12) then
			self:fire(self.Flamethrower_AmmoCost or 1)
			self.lastShotTime = now
		else
			self:setState("firing")
		end
	elseif math.abs((self.Flamethrower_PressurePosition or 0.5) - 0.5) <= 0.2 then
		self:setState("winding")
	else
		self:setState("idle")
	end

	self:updateCooldown()
end

local function onCrankChange(self, change)
	if not change or change == 0 then
		return
	end
	if math.abs(change) <= (self.Flamethrower_CrankDeadzone or 0) then
		return
	end

	local maxStep = self.Flamethrower_MaxCrankStep or 8
	local cappedChange = math.max(-maxStep, math.min(maxStep, change))
	local influence = cappedChange * (self.Flamethrower_CrankInfluence or 0.002)
	self.Flamethrower_PressurePosition = (self.Flamethrower_PressurePosition or 0.5) - influence

	if self.Flamethrower_PressurePosition < 0 then
		self.Flamethrower_PressurePosition = 0
	elseif self.Flamethrower_PressurePosition > 1 then
		self.Flamethrower_PressurePosition = 1
	end

	if math.abs(change) > 0.5 then
		self:setState("winding")
	end

	if (self.Flamethrower_SystemVelocity or 0) > 0 and change > 0 then
		self.shakeIntensity = math.min((self.shakeIntensity or 0) + 0.03, 0.8)
	elseif (self.Flamethrower_SystemVelocity or 0) < 0 and change < 0 then
		self.shakeIntensity = math.min((self.shakeIntensity or 0) + 0.03, 0.8)
	end
end

local function draw(self, cx, cy)
	local flameFrames = self.Flamethrower_frames
	if flameFrames and #flameFrames > 0 then
		local frameIndex = self.Flamethrower_idleFrameIndex or 1
		if self.weaponState ~= "idle" then
			if self.Flamethrower_isFiring then
				frameIndex = (self.firingFrame % #flameFrames) + 1
			else
				local pressure = self.Flamethrower_PressurePosition or 0.5
				frameIndex = math.floor(pressure * (#flameFrames - 1)) + 1
			end
		end

		local flameFrame = flameFrames[math.max(1, math.min(#flameFrames, frameIndex))]
		drawFrameWithOffset(flameFrame, cx, cy, self.Flamethrower_offsetX, self.Flamethrower_offsetY)
	end

	if self.weaponState == "firing" then
		local particleFrames = self.Flamethrower_particleFrames
		if particleFrames and #particleFrames > 0 then
			local particleIndex = (self.firingFrame % #particleFrames) + 1
			local particleFrame = particleFrames[math.max(1, math.min(#particleFrames, particleIndex))]
			drawFrameWithOffset(particleFrame, cx, cy, self.Flamethrower_particleOffsetX, self.Flamethrower_particleOffsetY)
		end
	end

	local barX = cx + 74
	local barY = cy - 72
	local barW = 18
	local barH = 92
	local targetMin = math.floor((self.Flamethrower_TargetMin or 0.42) * barH)
	local targetMax = math.floor((self.Flamethrower_TargetMax or 0.58) * barH)
	local cursorY = barY + math.floor((self.Flamethrower_PressurePosition or 0.5) * barH)

	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(barX, barY, barW, barH)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(barX, barY, barW, barH)
	gfx.fillRect(barX + 1, barY + 1, barW - 2, math.max(0, targetMin - 1))
	gfx.fillRect(barX + 1, barY + targetMax, barW - 2, math.max(0, barH - targetMax - 1))
	gfx.drawLine(barX - 2, barY + targetMin, barX + barW + 1, barY + targetMin)
	gfx.drawLine(barX - 2, barY + targetMax, barX + barW + 1, barY + targetMax)
	gfx.fillRect(barX - 5, cursorY - 2, barW + 10, 4)

	if (self.Flamethrower_SystemVelocity or 0) > 0 then
		gfx.drawLine(barX + barW + 8, barY + 12, barX + barW + 14, barY + 20)
		gfx.drawLine(barX + barW + 20, barY + 12, barX + barW + 14, barY + 20)
	elseif (self.Flamethrower_SystemVelocity or 0) < 0 then
		gfx.drawLine(barX + barW + 8, barY + 20, barX + barW + 14, barY + 12)
		gfx.drawLine(barX + barW + 20, barY + 20, barX + barW + 14, barY + 12)
	end

	if self.weaponState == "firing" then
		self:drawFlash(cx + 52, cy - 12)
	end
end

local function applyFireFeedback(self)
	self.shakeIntensity = math.max(self.shakeIntensity or 0, 1.1)
end

local function hasActiveFireState(self)
	return self.Flamethrower_isFiring == true
end

local function stopAllSounds(self)
	self.Flamethrower_isFiring = false
end

WeaponTypes.register({
	id = "Flamethrower",
	startingAmmoMin = 24,
	startingAmmoMax = 40,
	hitMode = "all_timed",
	rollAmmo = function(dieValue)
		return dieValue * 2
	end,
	configure = configure,
	update = update,
	onCrankChange = onCrankChange,
	draw = draw,
	applyFireFeedback = applyFireFeedback,
	hasActiveFireState = hasActiveFireState,
	stopAllSounds = stopAllSounds,
})