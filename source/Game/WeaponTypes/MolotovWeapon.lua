local gfx = playdate.graphics

local function resetShakeProgress(self)
	self.Molotov_shakesCompleted = 0
	self.Molotov_currentShakeArc = 0
	self.Molotov_lastDir = 0
end

local function triggerFire(self)
	self:fire(self.Molotov_AmmoCost or 1)
	self.Molotov_fireTicks = 10
	self:startCooldown()
	resetShakeProgress(self)
end

local function configure(self)
	self.maxWindUp = 0
	self.maxCooldown = 20
	self.autoFire = false
	self.Damage = 200
	self.Molotov_shakeFrames = self:loadFrameSequence("Sprites/Gun viewmodel/Molotov_shake/Molotov", {1, 2})
	self.Molotov_ShakeCountRequired = 6
	self.Molotov_MinShakeArc = 15
	self.Molotov_AmmoCost = 1
	self.Molotov_HitRadius = 28
	self.Molotov_ReticleScale = 1.5
	self.Molotov_ProjectileSpeedY = 5
	self.Molotov_ProjectileSpawnY = 220
	self.Molotov_shakesCompleted = 0
	self.Molotov_currentShakeArc = 0
	self.Molotov_lastDir = 0
	self.Molotov_fireTicks = 0
	self.Molotov_sfxShot = self.audioManager:loadSample("sounds/shotgun_shot")

	if self.crosshair then
		self.crosshair.hitRadius = self.Molotov_HitRadius
		self.crosshair.reticleScale = self.Molotov_ReticleScale
	end
end

local function update(self)
	if self.Molotov_fireTicks and self.Molotov_fireTicks > 0 then
		self:setState("firing")
		self.Molotov_fireTicks = self.Molotov_fireTicks - 1
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
	if not change or change == 0 then
		return
	end
	if self.weaponState == "firing" or (self.Molotov_fireTicks and self.Molotov_fireTicks > 0) then
		return
	end
	if self.cooldownTime and self.cooldownTime > 0 then
		return
	end

	local dir = 0
	if change > 0 then
		dir = 1
	elseif change < 0 then
		dir = -1
	end

	local absoluteChange = math.abs(change)
	if dir == 0 then
		return
	end

	if self.Molotov_lastDir == 0 then
		self.Molotov_lastDir = dir
		self.Molotov_currentShakeArc = absoluteChange
		self:setState("winding")
		return
	end

	if dir == self.Molotov_lastDir then
		self.Molotov_currentShakeArc = (self.Molotov_currentShakeArc or 0) + absoluteChange
		self:setState("winding")
		return
	end

	if (self.Molotov_currentShakeArc or 0) >= (self.Molotov_MinShakeArc or 15) then
		self.Molotov_shakesCompleted = (self.Molotov_shakesCompleted or 0) + 1
	end

	self.Molotov_lastDir = dir
	self.Molotov_currentShakeArc = absoluteChange
	self:setState("winding")

	if (self.Molotov_shakesCompleted or 0) >= (self.Molotov_ShakeCountRequired or 6) then
		triggerFire(self)
	end
end

local function draw(self, cx, cy)
	local shakesCompleted = self.Molotov_shakesCompleted or 0
	local shakeTarget = self.Molotov_ShakeCountRequired or 1
	local arcProgress = 0
	if (self.Molotov_MinShakeArc or 0) > 0 then
		arcProgress = math.min(1, (self.Molotov_currentShakeArc or 0) / self.Molotov_MinShakeArc)
	end
	local progress = math.min(1, (shakesCompleted + arcProgress) / shakeTarget)

	local shakeFrames = self.Molotov_shakeFrames
	if shakeFrames and #shakeFrames > 0 then
		local frameIndex = 1
		if #shakeFrames > 1 then
			if self.Molotov_lastDir and self.Molotov_lastDir < 0 then
				frameIndex = 2
			elseif self.weaponState == "winding" and progress > 0 then
				frameIndex = ((math.floor(shakesCompleted) % #shakeFrames) + 1)
			end
		end

		local frame = shakeFrames[math.max(1, math.min(#shakeFrames, frameIndex))]
		if frame and frame.drawCentered then
			frame:drawCentered(cx, cy)
		end
	else
		local bodyX = cx - 12
		local bodyY = cy - 28

		gfx.setColor(gfx.kColorWhite)
		gfx.fillRoundRect(bodyX, bodyY, 24, 34, 6)
		gfx.fillRect(cx - 5, cy - 38, 10, 10)
		gfx.setColor(gfx.kColorBlack)
		gfx.drawRoundRect(bodyX, bodyY, 24, 34, 6)
		gfx.drawRect(cx - 5, cy - 38, 10, 10)
		gfx.drawLine(cx - 2, cy - 41, cx + 5, cy - 48)
	end

	local fillHeight = math.floor(24 * progress)
	if fillHeight > 0 then
		gfx.fillRect(cx - 7, cy + 28 - fillHeight, 14, fillHeight)
	end

	local indicatorWidth = 50
	local indicatorX = cx - math.floor(indicatorWidth / 2)
	local indicatorY = cy + 18
	gfx.drawRect(indicatorX, indicatorY, indicatorWidth, 6)
	if progress > 0 then
		gfx.fillRect(indicatorX + 1, indicatorY + 1, math.floor((indicatorWidth - 2) * progress), 4)
	end

	if self.weaponState == "firing" then
		self:drawFlash(cx + 14, cy - 42)
	end
end

local function playFireSound(self)
	if self.Molotov_sfxShot then
		pcall(function() self.Molotov_sfxShot:play(1) end)
	end
end

local function applyFireFeedback(self)
	self.shakeIntensity = 2.5
end

local function hasActiveFireState(self)
	return self.Molotov_fireTicks and self.Molotov_fireTicks > 0
end

WeaponTypes.register({
	id = "Molotov",
	startingAmmoMin = 4,
	startingAmmoMax = 8,
	hitMode = "projectile_once",
	rollAmmo = function(dieValue)
		return math.ceil(dieValue / 2)
	end,
	configure = configure,
	update = update,
	onCrankChange = onCrankChange,
	draw = draw,
	playFireSound = playFireSound,
	applyFireFeedback = applyFireFeedback,
	hasActiveFireState = hasActiveFireState,
})