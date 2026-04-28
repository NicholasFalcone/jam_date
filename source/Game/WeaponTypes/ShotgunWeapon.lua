local function configure(self)
	self.maxWindUp = 0
	self.maxCooldown = 22
	self.autoFire = false
	self.Shotgun_reloadFrames = self:loadFrameSequence("Sprites/Gun viewmodel/SGN_Reload/SGN_Reload - ", {16, 17, 18, 19, 20, 21})
	self.Shotgun_shootFrames = self:loadFrameSequence("Sprites/Gun viewmodel/SGN_Shoot/SGN_Shoot - ", {13, 14, 15})
	self.Shotgun_idleFrameIndex = 1
	self.Damage = 200
	self.Shotgun_ArcSize = 360
	self.Shotgun_accum = 0
	self.Shotgun_lastDir = 0
	self.Shotgun_AmmoCost = 2
	self.Shotgun_fireTicks = 0
	self.Shotgun_sfxShot = self.audioManager:loadSample("sounds/shotgun_shot")
	self.Shotgun_sfxReload = self.audioManager:loadSample("sounds/SFX_ShotgunReload")

	if self.crosshair then
		self.crosshair.hitRadius = 15
		self.crosshair.reticleScale = 1
	end
end

local function update(self)
	if self.Shotgun_fireTicks and self.Shotgun_fireTicks > 0 then
		self:setState("firing")
		local shootFrames = self.Shotgun_shootFrames
		local totalNumFrames = (shootFrames and #shootFrames) or 3
		local totalTicks = totalNumFrames * 2
		local currentFrame = math.floor((totalTicks - self.Shotgun_fireTicks) / 2) + 1
		self.Shotgun_fireFrameIndex = math.max(1, math.min(totalNumFrames, currentFrame))
		self.Shotgun_fireTicks = self.Shotgun_fireTicks - 1
	elseif self.weaponState == "firing" then
		if self:isOnCooldown() then
			self:setState("reloading")
		else
			self:setState("idle")
		end
	end

	self:updateCooldown()

	if self.weaponState == "reloading" and not self:isOnCooldown() then
		self:setState("idle")
	end
end

local function onCrankChange(self, change)
	if not change or change <= 0 then
		self.Shotgun_accum = 0
		if self.weaponState ~= "firing" and not (self.cooldownTime and self.cooldownTime > 0) then
			self:setState("idle")
		end
		return
	end

	if self.weaponState == "firing" or (self.Shotgun_fireTicks and self.Shotgun_fireTicks > 0) then
		return
	end
	if self.cooldownTime and self.cooldownTime > 0 then
		return
	end

	self.Shotgun_accum = (self.Shotgun_accum or 0) + change
	self:setState("winding")

	if self.Shotgun_accum >= (self.Shotgun_ArcSize or 360) then
		self:fire(self.Shotgun_AmmoCost or 2)
		self.shotProcessed = false
		local shootFrames = self.Shotgun_shootFrames
		local totalNumFrames = (shootFrames and #shootFrames) or 3
		self.Shotgun_fireTicks = totalNumFrames * 2
		self.Shotgun_fireFrameIndex = 1
		self:startCooldown()
		if self.Shotgun_sfxReload then
			pcall(function() self.Shotgun_sfxReload:play(1) end)
		end
		self.Shotgun_accum = 0
	end
end

local function draw(self, cx, cy)
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
	if not reloadFrames or #reloadFrames == 0 then
		return
	end

	if self.weaponState == "idle" then
		local idleFrame = reloadFrames[self.Shotgun_idleFrameIndex or 1]
		if idleFrame and idleFrame.drawCentered then
			idleFrame:drawCentered(cx, cy)
		end
		return
	end

	if self.weaponState == "reloading" or self:isOnCooldown() then
		local total = self.maxCooldown or 1
		local progress = math.max(0, math.min(1, (total - (self.cooldownTime or 0)) / total))
		local index = math.floor(progress * (#reloadFrames - 1)) + 1
		local reloadFrame = reloadFrames[math.max(1, math.min(#reloadFrames, index))]
		if reloadFrame and reloadFrame.drawCentered then
			reloadFrame:drawCentered(cx, cy)
		end
		return
	end

	local fallback = reloadFrames[self.Shotgun_idleFrameIndex or 1]
	if fallback and fallback.drawCentered then
		fallback:drawCentered(cx, cy)
	end
end

local function playFireSound(self)
	if self.Shotgun_sfxShot then
		pcall(function() self.Shotgun_sfxShot:play(1) end)
	end
end

local function applyFireFeedback(self)
	self.shakeIntensity = 3.0
end

local function hasActiveFireState(self)
	return self.Shotgun_fireTicks and self.Shotgun_fireTicks > 0
end

WeaponTypes.register({
	id = "Shotgun",
	startingAmmoMin = 10,
	startingAmmoMax = 16,
	hitMode = "all_once",
	configure = configure,
	update = update,
	onCrankChange = onCrankChange,
	draw = draw,
	playFireSound = playFireSound,
	applyFireFeedback = applyFireFeedback,
	hasActiveFireState = hasActiveFireState,
})