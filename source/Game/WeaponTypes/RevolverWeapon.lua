local function getReloadFrameIndex(self, frames)
	if not frames or #frames == 0 then
		return 1
	end

	local arc = self.Revolver_ArcSize or 180
	local accum = self.Revolver_accum or 0
	local progress = math.max(0, math.min(1, accum / arc))
	local index = math.floor(progress * (#frames - 1)) + 1
	return math.max(1, math.min(#frames, index))
end

local function configure(self)
	self.maxWindUp = 0
	self.maxCooldown = 0
	self.autoFire = false
	self.Revolver_reloadFrames = self:loadFrameSequence("Sprites/Gun viewmodel/REV_reload/REV_reload - ", {1, 2, 3, 4, 5, 6, 7, 8})
	self.Revolver_shootFrames = self:loadFrameSequence("Sprites/Gun viewmodel/REV_Shoot/REV_Shoot - ", {9, 10, 11})
	self.Revolver_idleFrameIndex = 1
	self.Damage = 100
	self.Revolver_ArcSize = 90
	self.Revolver_stage = 0
	self.Revolver_accum = 0
	self.Revolver_lastDir = 0
	self.Revolver_pendingFire = false
	self.Revolver_fireTicks = 0
	self.Revolver_sfxClick = self.audioManager:loadSample("sounds/revolver_click")
	self.Revolver_sfxShot = self.audioManager:loadSample("sounds/revolver_shot")

	if self.crosshair then
		self.crosshair.hitRadius = 0
		self.crosshair.reticleScale = 1
	end
end

local function update(self)
	if self.Revolver_pendingFire then
		self:fire(1)
		self.shotProcessed = false
		self.Revolver_pendingFire = false
		local shootFrames = self.Revolver_shootFrames
		local totalNumFrames = (shootFrames and #shootFrames) or 3
		self.Revolver_fireTicks = totalNumFrames * 2
		self.Revolver_fireFrameIndex = 1
		self:setState("firing")
	end

	if self.Revolver_fireTicks and self.Revolver_fireTicks > 0 then
		self:setState("firing")
		local shootFrames = self.Revolver_shootFrames
		local totalNumFrames = (shootFrames and #shootFrames) or 3
		local totalTicks = totalNumFrames * 2
		local currentFrame = math.floor((totalTicks - self.Revolver_fireTicks) / 2) + 1
		self.Revolver_fireFrameIndex = math.max(1, math.min(totalNumFrames, currentFrame))
		self.Revolver_fireTicks = self.Revolver_fireTicks - 1
	elseif self.weaponState == "firing" then
		if self.Revolver_stage == 1 then
			self:setState("cocked")
		else
			self:setState("idle")
		end
	end

	self:updateCooldown()
end

local function onCrankChangeCock(self, dir, absoluteChange)
	if dir ~= -1 then
		return
	end

	if self.Revolver_lastDir == -1 or self.Revolver_lastDir == 0 then
		self.Revolver_accum = self.Revolver_accum + absoluteChange
	else
		self.Revolver_accum = absoluteChange
	end
	self.Revolver_lastDir = -1

	if self.Revolver_accum >= (self.Revolver_ArcSize or 120) then
		if self.Revolver_sfxClick then
			pcall(function() self.Revolver_sfxClick:play(1) end)
		end
		self:setState("cocked")
		local excess = self.Revolver_accum - (self.Revolver_ArcSize or 120)
		self.Revolver_stage = 1
		self.Revolver_accum = excess
	else
		self:setState("winding")
	end
end

local function onCrankChangeFire(self, dir, absoluteChange)
	if dir ~= 1 then
		return
	end

	if self.Revolver_lastDir == 1 or self.Revolver_lastDir == 0 then
		self.Revolver_accum = self.Revolver_accum + absoluteChange
	else
		self.Revolver_accum = absoluteChange
	end
	self.Revolver_lastDir = 1

	if self.Revolver_accum >= (self.Revolver_ArcSize or 120) then
		self.Revolver_pendingFire = true
		self:startCooldown()
		local excess = self.Revolver_accum - (self.Revolver_ArcSize or 120)
		self.Revolver_stage = 0
		self.Revolver_accum = excess
	else
		self:setState("winding")
	end
end

local function onCrankChange(self, change)
	if not change or change == 0 then
		return
	end

	if self.weaponState == "firing" or (self.Revolver_fireTicks and self.Revolver_fireTicks > 0) then
		return
	end

	local dir = 0
	if change > 0 then
		dir = 1
	elseif change < 0 then
		dir = -1
	end

	local absoluteChange = math.abs(change)
	if self.Revolver_stage == 0 then
		onCrankChangeCock(self, dir, absoluteChange)
	elseif self.Revolver_stage == 1 then
		onCrankChangeFire(self, dir, absoluteChange)
	end
end

local function draw(self, cx, cy)
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
				reloadIndex = getReloadFrameIndex(self, reloadFrames)
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

local function playFireSound(self)
	if self.Revolver_sfxShot then
		pcall(function() self.Revolver_sfxShot:play(1) end)
	end
end

local function applyFireFeedback(self)
	self.shakeIntensity = 2.0
end

local function hasActiveFireState(self)
	return (self.Revolver_pendingFire == true) or (self.Revolver_fireTicks and self.Revolver_fireTicks > 0)
end

WeaponTypes.register({
	id = "Revolver",
	startingAmmoMin = 8,
	startingAmmoMax = 14,
	hitMode = "closest_once",
	configure = configure,
	update = update,
	onCrankChange = onCrankChange,
	draw = draw,
	playFireSound = playFireSound,
	applyFireFeedback = applyFireFeedback,
	hasActiveFireState = hasActiveFireState,
})