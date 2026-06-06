local gfx = playdate.graphics

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
	self.Flamethrower_particles = {}
	self.Flamethrower_particleSpawnTimer = 0
	self.Flamethrower_sfxFlame    = self.audioManager:loadSample("sounds/SFX_Flame")
	self.Flamethrower_flameVol    = 0
	self.Flamethrower_flamePlaying = false
	resetPressure(self, playdate.getElapsedTime())

	if self.crosshair then
		self.crosshair.hitRadius = 0
		self.crosshair.reticleScale = 1
		self.crosshair.flamethrowerActive = true
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

	-- Spawn new particles when firing
	self.Flamethrower_particleSpawnTimer = (self.Flamethrower_particleSpawnTimer or 0) + 1
	if self.Flamethrower_isFiring and self.Flamethrower_particleSpawnTimer >= 2 then
		self.Flamethrower_particleSpawnTimer = 0
		-- spawn 2 overlapping puffs for density
		for _ = 1, 2 do
			table.insert(self.Flamethrower_particles, {
				ox = math.random(-6, 6),
				oy = math.random(-4, 4),
				dx = math.random(-40, 40) * 0.1,
				dy = -math.random(15, 30) * 0.1,
				frameIndex = 1,
				frameTick  = 0,
			})
		end
	end

	-- Advance and cull particles (each frame lasts 5 ticks → full life = 20 ticks)
	local alive = {}
	for _, p in ipairs(self.Flamethrower_particles or {}) do
		p.ox = p.ox + p.dx
		p.oy = p.oy + p.dy
		p.frameTick = p.frameTick + 1
		if p.frameTick >= 5 then
			p.frameTick = 0
			p.frameIndex = p.frameIndex + 1
		end
		if p.frameIndex <= 4 then
			table.insert(alive, p)
		end
	end
	self.Flamethrower_particles = alive

	-- ── Flame sound with fade in / fade out ───────────────────────────────
	local sfx = self.Flamethrower_sfxFlame
	if self.Flamethrower_isFiring then
		if not self.Flamethrower_flamePlaying then
			self.Flamethrower_flameVol = 0
			if sfx then
				pcall(function()
					sfx:setVolume(0)
					sfx:play(0)   -- 0 = loop indefinitely
				end)
			end
			self.Flamethrower_flamePlaying = true
		end
		-- fade in: +0.08 per tick → full volume in ~13 ticks
		self.Flamethrower_flameVol = math.min(1.0, (self.Flamethrower_flameVol or 0) + 0.08)
		if sfx then pcall(function() sfx:setVolume(self.Flamethrower_flameVol) end) end
	else
		if self.Flamethrower_flamePlaying then
			-- fade out: -0.08 per tick
			self.Flamethrower_flameVol = math.max(0.0, (self.Flamethrower_flameVol or 0) - 0.08)
			if sfx then pcall(function() sfx:setVolume(self.Flamethrower_flameVol) end) end
			if self.Flamethrower_flameVol <= 0 then
				if sfx then pcall(function() sfx:stop() end) end
				self.Flamethrower_flamePlaying = false
			end
		end
	end
	-- ──────────────────────────────────────────────────────────────────────
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
		if flameFrame and flameFrame.drawCentered then
			flameFrame:drawCentered(cx, cy)
		end
	end

	-- Draw live particles (continues briefly after stopping, naturally fading out)
	local particleFrames = self.Flamethrower_particleFrames
	if particleFrames and #particleFrames > 0 then
		for _, p in ipairs(self.Flamethrower_particles or {}) do
			local fi = math.max(1, math.min(#particleFrames, p.frameIndex))
			local pf = particleFrames[fi]
			if pf and pf.drawCentered then
				pf:drawCentered(200 + math.floor(p.ox), 160 + math.floor(p.oy))
			end
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
	if self.Flamethrower_sfxFlame then
		pcall(function() self.Flamethrower_sfxFlame:stop() end)
	end
	self.Flamethrower_flamePlaying = false
	self.Flamethrower_flameVol    = 0
	if self.crosshair then
		self.crosshair.flamethrowerActive = false
	end
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