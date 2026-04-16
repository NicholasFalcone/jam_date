local function configure(self)
	self.lastHitProcessTime = 0
	self.maxWindUp = 25
	self.maxCooldown = 10
	self.autoFire = true
	self.Minigun_frames = self:loadFrameSequence("Sprites/Gun viewmodel/Minigun_rotation/Minigun_rotation - ", {21, 22, 23, 26, 27, 28})
	self.Minigun_idleFrameIndex = 1
	self.MinCrankSpeed = 4
	self.FireRate_Min = 0.6
	self.FireRate_Current = self.FireRate_Min
	self.FireRate_AccelerationSpeed = 0.2
	self.FireRate_AccelerationValue = 0.1
	self.FireRate_DecelerationSpeed = 0.5
	self.FireRate_DecelerationValue = 0.1
	self.FireRate_Max = 0.1
	self.Damage = 20
	self.isShooting = false
	self.lastAccelTime = playdate.getElapsedTime()
	self.lastDecelTime = playdate.getElapsedTime()
	self.lastShotTime = playdate.getElapsedTime()
	self.Minigun_sfxShot = self.audioManager:loadSample("sounds/minigun_shot")
	self.Minigun_sfxRotation = self.audioManager:loadSample("sounds/SFX_MinigunRotation_loop")
	self.Minigun_rotationPlaying = false

	if self.crosshair then
		self.crosshair.hitRadius = 0
		self.crosshair.reticleScale = 1
	end
end

local function update(self, now)
	if self.isShooting then
		if not self.Minigun_rotationPlaying and self.Minigun_sfxRotation then
			pcall(function() self.Minigun_sfxRotation:play(0) end)
			self.Minigun_rotationPlaying = true
		end

		self.shakeIntensity = math.min((self.shakeIntensity or 0) + 0.15, 1.5)

		if now - (self.lastAccelTime or 0) >= (self.FireRate_AccelerationSpeed or 1.0) then
			self.FireRate_Current = math.max(self.FireRate_Max, self.FireRate_Current - (self.FireRate_AccelerationValue or 0.01))
			self.lastAccelTime = now
		end

		if now - (self.lastShotTime or 0) >= (self.FireRate_Current or 0.2) then
			self:fire(1)
			self.lastShotTime = now
		elseif self.weaponState ~= "firing" then
			self:setState("winding")
		end
	else
		if self.Minigun_rotationPlaying and self.Minigun_sfxRotation then
			pcall(function() self.Minigun_sfxRotation:stop() end)
			self.Minigun_rotationPlaying = false
		end

		if now - (self.lastDecelTime or 0) >= (self.FireRate_DecelerationSpeed or 1.0) then
			self.FireRate_Current = math.min(self.FireRate_Min, self.FireRate_Current + (self.FireRate_DecelerationValue or 0.02))
			self.lastDecelTime = now
		end

		if self.weaponState == "firing" then
			self:setState("idle")
		end
	end
end

local function onCrankChange(self, change)
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

local function draw(self, cx, cy)
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

local function playFireSound(self)
	if self.Minigun_sfxShot then
		pcall(function() self.Minigun_sfxShot:play(1) end)
	end
end

local function stopAllSounds(self)
	if self.Minigun_rotationPlaying and self.Minigun_sfxRotation then
		pcall(function() self.Minigun_sfxRotation:stop() end)
		self.Minigun_rotationPlaying = false
	end
	self.isShooting = false
end

WeaponTypes.register({
	id = "Minigun",
	startingAmmoMin = 40,
	startingAmmoMax = 80,
	hitMode = "closest_timed",
	rollAmmo = function(dieValue)
		return dieValue * 3
	end,
	configure = configure,
	update = update,
	onCrankChange = onCrankChange,
	draw = draw,
	playFireSound = playFireSound,
	stopAllSounds = stopAllSounds,
})