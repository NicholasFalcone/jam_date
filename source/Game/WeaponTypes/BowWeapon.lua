local gfx = playdate.graphics

-- Maps chargeProgress → crosshair bow frame 1-9
local function syncBowFrame(self)
	if not self.crosshair then return end
	if self.Bow_isCharged then
		self.crosshair.bowAnimFrame = 11
	else
		local ratio = math.min(1, (self.Bow_chargeProgress or 0) / (self.Bow_ChargeArc or 160))
		self.crosshair.bowAnimFrame = math.max(1, math.min(11, math.floor(ratio * 10) + 1))
	end
end

-- ── Reload-sound helpers ────────────────────────────────────────────────────
local function startReloadSound(self)
	if self.Bow_reloadPlaying then return end
	if self.Bow_sfxReload then
		pcall(function() self.Bow_sfxReload:play(1) end)
	end
	self.Bow_reloadPlaying = true
end

local function stopReloadSound(self)
	if not self.Bow_reloadPlaying then return end
	if self.Bow_sfxReload then
		pcall(function() self.Bow_sfxReload:stop() end)
	end
	self.Bow_reloadPlaying = false
end

local function resetReloadSound(self)
	stopReloadSound(self)
end
-- ───────────────────────────────────────────────────────────────────────────
local function triggerFire(self)
	resetReloadSound(self)                 -- bow released, reset reload position
	self:fire(self.Bow_AmmoCost or 1)
	local shootFrames = self.Bow_shootFrames
	local totalNumFrames = (shootFrames and #shootFrames) or 4
	self.Bow_fireTicks = totalNumFrames * 2
	self.Bow_fireFrameIndex = 1
	self.Bow_isCharged = false
	self.Bow_chargeProgress = 0
	self.Bow_lastMovementTime = playdate.getElapsedTime()
	self.Bow_lastCrankDelta = 0
	-- Reset crosshair animation back to frame 1
	if self.crosshair then
		self.crosshair.bowAnimFrame = 1
	end
end

local function configure(self)
	if self.crosshair and self.crosshair.resetAllFlags then
		self.crosshair:resetAllFlags()
	end
	self.maxWindUp = 0
	self.maxCooldown = 0
	self.autoFire = false
	self.Damage = 200
	self.Bow_chargeFrames = self:loadFrameSequence("Sprites/Gun viewmodel/Bow_Charge/Bow-Charge-", {1, 2, 3, 4, 5})
	self.Bow_shootFrames = self:loadFrameSequence("Sprites/Gun viewmodel/Bow_Shoot/Bow-Shoot-", {1, 2, 3, 4})
	self.Bow_idleFrameIndex = 1
	self.Bow_AmmoCost = 1
	self.Bow_ChargeArc = 160
	self.Bow_HoldStillDuration = 0.3
	self.Bow_StillThreshold = 1.25
	self.Bow_chargeProgress = 0
	self.Bow_isCharged = false
	self.Bow_fireTicks = 0
	self.Bow_lastMovementTime = playdate.getElapsedTime()
	self.Bow_lastCrankDelta = 0
	self.Bow_sfxShoot  = self.audioManager:loadSample("sounds/SFX_Bow_Shoot")
	self.Bow_sfxReload = self.audioManager:loadSample("sounds/SFX_Bow_Reloading")
	self.Bow_reloadOffset   = 0
	self.Bow_reloadPlaying  = false
	self.Bow_reloadPlayStart = nil
	self.hitboxScale = 1

	if self.crosshair then
		self.crosshair.hitRadius = 0
		self.crosshair.reticleScale = 0.5
		self.crosshair.bowActive = true
		self.crosshair.bowAnimFrame = 1
	end
end

local function update(self, now)
	if self.Bow_fireTicks and self.Bow_fireTicks > 0 then
		self:setState("firing")
		local shootFrames = self.Bow_shootFrames
		local totalNumFrames = (shootFrames and #shootFrames) or 4
		local totalTicks = totalNumFrames * 2
		local currentFrame = math.floor((totalTicks - self.Bow_fireTicks) / 2) + 1
		self.Bow_fireFrameIndex = math.max(1, math.min(totalNumFrames, currentFrame))
		self.Bow_fireTicks = self.Bow_fireTicks - 1
		return
	elseif self.weaponState == "firing" then
		self:setState("idle")
	end

	local stillThreshold = self.Bow_StillThreshold or 1.25
	local crankDelta = math.abs(self.Bow_lastCrankDelta or 0)

	if self.Bow_isCharged then
		if crankDelta <= stillThreshold and now - (self.Bow_lastMovementTime or now) >= (self.Bow_HoldStillDuration or 0.5) then
			triggerFire(self)
		else
			self:setState("cocked")
		end
	elseif (self.Bow_chargeProgress or 0) > 0 then
		self:setState("winding")
	else
		self:setState("idle")
	end

	self:updateCooldown()
end

local function onCrankChange(self, change)
	local now = playdate.getElapsedTime()
	self.Bow_lastCrankDelta = change or 0

	if self.weaponState == "firing" or (self.Bow_fireTicks and self.Bow_fireTicks > 0) then
		stopReloadSound(self)
		return
	end

	local threshold = self.Bow_StillThreshold or 1.25

	if change and change < -threshold then
		self.Bow_lastMovementTime = now

		if self.Bow_isCharged then
			self:setState("cocked")
			return
		end

		startReloadSound(self)  -- just play from start each stroke
		self.Bow_chargeProgress = math.min(self.Bow_ChargeArc or 180, (self.Bow_chargeProgress or 0) + math.abs(change))
		if self.Bow_chargeProgress >= (self.Bow_ChargeArc or 180) then
			self.Bow_isCharged = true
			self.Bow_chargeProgress = self.Bow_ChargeArc or 180
			self:setState("cocked")
			stopReloadSound(self)
		else
			self:setState("winding")
		end
	elseif change and change > threshold then
		self.Bow_lastMovementTime = now
		stopReloadSound(self)
		self.Bow_chargeProgress = math.max(0, (self.Bow_chargeProgress or 0) - math.abs(change) * 0.5)
		if self.Bow_chargeProgress <= 0 then
			self:setState("idle")
		else
			self:setState("winding")
		end
	else
		local idleTime = now - (self.Bow_lastMovementTime or now)
		if idleTime > 0.08 then
			stopReloadSound(self)
		end
	end

	syncBowFrame(self)
end
local function draw(self, cx, cy)
	local isFiring = (self.Bow_fireTicks and self.Bow_fireTicks > 0) or (self.weaponState == "firing")
	if isFiring then
		local shootFrames = self.Bow_shootFrames
		if shootFrames and #shootFrames > 0 then
			local shootIndex = math.max(1, math.min(#shootFrames, self.Bow_fireFrameIndex or 1))
			local shootFrame = shootFrames[shootIndex]
			if shootFrame and shootFrame.drawCentered then
				shootFrame:drawCentered(cx, cy)
			end
		end
		return
	end

	local chargeFrames = self.Bow_chargeFrames
	if chargeFrames and #chargeFrames > 0 then
		local progress = math.min(1, (self.Bow_chargeProgress or 0) / (self.Bow_ChargeArc or 180))
		if self.Bow_isCharged then
			progress = 1
		end

		local chargeIndex = self.Bow_idleFrameIndex or 1
		if progress > 0 then
			chargeIndex = math.floor(progress * (#chargeFrames - 1)) + 1
		end

		local chargeFrame = chargeFrames[math.max(1, math.min(#chargeFrames, chargeIndex))]
		if chargeFrame and chargeFrame.drawCentered then
			chargeFrame:drawCentered(cx, cy)
		end
		return
	end

	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(cx - 20, cy - 30, 40, 60)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(cx - 20, cy - 30, 40, 60)
end

local function playFireSound(self)
	if self.Bow_sfxShoot then
		pcall(function() self.Bow_sfxShoot:play(1) end)
	end
end

local function applyFireFeedback(self)
	self.shakeIntensity = 1.2
end

local function hasActiveFireState(self)
	return self.Bow_fireTicks and self.Bow_fireTicks > 0
end

local function stopAllSounds(self)
	resetReloadSound(self)
	if self.crosshair then
		self.crosshair.bowActive = false
		self.crosshair.bowAnimFrame = 1
	end
end

WeaponTypes.register({
	id = "Bow",
	startingAmmoMin = 6,
	startingAmmoMax = 12,
	hitMode = "all_once",
	rollAmmo = function(dieValue)
		return math.max(1, math.floor(dieValue * 0.75))
	end,
	configure = configure,
	update = update,
	onCrankChange = onCrankChange,
	draw = draw,
	playFireSound = playFireSound,
	applyFireFeedback = applyFireFeedback,
	hasActiveFireState = hasActiveFireState,
	stopAllSounds = stopAllSounds,
})