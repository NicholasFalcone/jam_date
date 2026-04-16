local gfx = playdate.graphics

local function triggerFire(self)
	self:fire(self.Bow_AmmoCost or 1)
	self.Bow_fireTicks = 4
	self.Bow_isCharged = false
	self.Bow_chargeProgress = 0
	self.Bow_lastMovementTime = playdate.getElapsedTime()
	self.Bow_lastCrankDelta = 0
end

local function configure(self)
	self.maxWindUp = 0
	self.maxCooldown = 0
	self.autoFire = false
	self.Damage = 90
	self.Bow_AmmoCost = 1
	self.Bow_ChargeArc = 180
	self.Bow_HoldStillDuration = 0.5
	self.Bow_StillThreshold = 1.25
	self.Bow_chargeProgress = 0
	self.Bow_isCharged = false
	self.Bow_fireTicks = 0
	self.Bow_lastMovementTime = playdate.getElapsedTime()
	self.Bow_lastCrankDelta = 0
	self.Bow_sfxShot = self.audioManager:loadSample("sounds/revolver_shot")
	self.hitboxScale = 0.7

	if self.crosshair then
		self.crosshair.hitRadius = 0
		self.crosshair.reticleScale = 0.75
	end
end

local function update(self, now)
	if self.Bow_fireTicks and self.Bow_fireTicks > 0 then
		self:setState("firing")
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
		return
	end

	local threshold = self.Bow_StillThreshold or 1.25
	if not change or math.abs(change) <= threshold then
		return
	end

	self.Bow_lastMovementTime = now

	if self.Bow_isCharged then
		self:setState("cocked")
		return
	end

	if change < -threshold then
		self.Bow_chargeProgress = math.min(self.Bow_ChargeArc or 180, (self.Bow_chargeProgress or 0) + math.abs(change))
		if self.Bow_chargeProgress >= (self.Bow_ChargeArc or 180) then
			self.Bow_isCharged = true
			self.Bow_chargeProgress = self.Bow_ChargeArc or 180
			self:setState("cocked")
		else
			self:setState("winding")
		end
	else
		self.Bow_chargeProgress = math.max(0, (self.Bow_chargeProgress or 0) - math.abs(change) * 0.5)
		if self.Bow_chargeProgress <= 0 then
			self:setState("idle")
		else
			self:setState("winding")
		end
	end
end

local function draw(self, cx, cy)
	local gripX = cx - 12
	local gripY = cy - 30
	local progress = math.min(1, (self.Bow_chargeProgress or 0) / (self.Bow_ChargeArc or 180))
	if self.Bow_isCharged then
		progress = 1
	end

	local stringRestOffset = 6
	local stringPullDistance = 20
	local topX = gripX - 8
	local topY = gripY - 18
	local bottomX = gripX - 8
	local bottomY = gripY + 22
	local stringX = gripX + stringRestOffset - math.floor(progress * stringPullDistance)
	local stringY = gripY + 2

	gfx.setColor(gfx.kColorBlack)
	gfx.setLineWidth(2)
	gfx.drawLine(gripX, gripY - 4, gripX, gripY + 8)
	gfx.drawLine(topX, topY, gripX, gripY - 4)
	gfx.drawLine(gripX, gripY + 8, bottomX, bottomY)
	gfx.drawLine(topX, topY, stringX, stringY)
	gfx.drawLine(stringX, stringY, bottomX, bottomY)
	gfx.drawLine(stringX - 6, stringY, stringX + 16, stringY)
	gfx.drawLine(stringX + 12, stringY - 4, stringX + 16, stringY)
	gfx.drawLine(stringX + 12, stringY + 4, stringX + 16, stringY)
	gfx.setLineWidth(1)

	local indicatorWidth = 50
	local indicatorX = cx - math.floor(indicatorWidth / 2)
	local indicatorY = cy + 18
	gfx.drawRect(indicatorX, indicatorY, indicatorWidth, 6)
	if progress > 0 then
		gfx.fillRect(indicatorX + 1, indicatorY + 1, math.floor((indicatorWidth - 2) * progress), 4)
	end

	if self.weaponState == "firing" then
		self:drawFlash(stringX + 12, stringY)
	end
end

local function playFireSound(self)
	if self.Bow_sfxShot then
		pcall(function() self.Bow_sfxShot:play(1) end)
	end
end

local function applyFireFeedback(self)
	self.shakeIntensity = 1.2
end

local function hasActiveFireState(self)
	return self.Bow_fireTicks and self.Bow_fireTicks > 0
end

WeaponTypes.register({
	id = "Bow",
	startingAmmoMin = 6,
	startingAmmoMax = 12,
	hitMode = "all_once",
	configure = configure,
	update = update,
	onCrankChange = onCrankChange,
	draw = draw,
	playFireSound = playFireSound,
	applyFireFeedback = applyFireFeedback,
	hasActiveFireState = hasActiveFireState,
})