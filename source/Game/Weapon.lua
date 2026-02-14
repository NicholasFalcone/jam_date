class('Weapon').extends()

local gfx = playdate.graphics

-- Base weapon class; specific weapons override parameters
function Weapon:init(typeName)
	self.weaponType = typeName or "Minigun"
	self.weaponState = "idle" -- "idle", "winding", "firing"
	self.windUpTime = 0
	self.maxWindUp = 0
	self.firingFrame = 0
	self.cooldownTime = 0
	self.maxCooldown = 0
	self.autoFire = false
	self:initByType(self.weaponType)
end

function Weapon:initByType(t)
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
		-- try to load revolver sounds (tolerant if missing)
		local function tryLoadSample(p)
			local ok, sp = pcall(function() return playdate.sound.sampleplayer.new(p) end)
			if ok then return sp end
			-- try with .wav suffix too
			ok, sp = pcall(function() return playdate.sound.sampleplayer.new(p..".wav") end)
			if ok then return sp end
			return nil
		end
		self.Revolver_sfxClick = tryLoadSample("sounds/revolver_click")
		self.Revolver_sfxShot = tryLoadSample("sounds/revolver_shot")
	elseif t == "Shotgun" then
		self.maxWindUp = 0
		self.maxCooldown = 45
		self.autoFire = false
	else
		self.maxWindUp = 0
		self.maxCooldown = 30
		self.autoFire = false
	end
	self.windUpTime = 0
	self.cooldownTime = self.maxCooldown
	self.firingFrame = 0
	self.weaponState = "idle"
end


function Weapon:update(now)
	now = now or playdate.getElapsedTime()
	if self.weaponType == "Minigun" then
		if self.isShooting then
			-- accelerate fire rate over time
			if now - (self.lastAccelTime or 0) >= (self.FireRate_AccelerationSpeed or 1.0) then
				self.FireRate_Current = math.max(self.FireRate_Max, self.FireRate_Current - (self.FireRate_AccelerationValue or 0.01))
				self.lastAccelTime = now
			end
			-- attempt to fire based on current rate
			if now - (self.lastShotTime or 0) >= (self.FireRate_Current or 0.2) then
				self.weaponState = "firing"
				self.lastShotTime = now
				-- firingFrame increment for visuals
				self.firingFrame = self.firingFrame + 1
			else
				-- remain in winding/firing depending on state
				if self.weaponState ~= "firing" then self.weaponState = "winding" end
			end
		else
			-- decelerate fire rate when not shooting
			if now - (self.lastDecelTime or 0) >= (self.FireRate_DecelerationSpeed or 1.0) then
				self.FireRate_Current = math.min(self.FireRate_Min, self.FireRate_Current + (self.FireRate_DecelerationValue or 0.02))
				self.lastDecelTime = now
			end
			-- if not shooting, ensure state returns to idle
			if self.weaponState == "firing" then
				self.weaponState = "idle"
			end
		end
	else
		-- generic cooldown tick
		-- revolver: handle single-frame firing visibility
		if self.weaponType == "Revolver" then
			if self.Revolver_pendingFire then
				self.weaponState = "firing"
				self.Revolver_fireTicks = 1 -- keep firing visible for one frame (this frame -> enemies will be hit)
				self.Revolver_pendingFire = false
			end
			if self.Revolver_fireTicks and self.Revolver_fireTicks > 0 then
				-- decrement at next update cycle (so enemies see firing for exactly one frame)
				self.Revolver_fireTicks = math.max(0, self.Revolver_fireTicks - 1)
				if self.Revolver_fireTicks == 0 then
					-- after the single visible firing tick, return to idle or remain cocked depending on stage
					if self.Revolver_stage == 0 then
						self.weaponState = "idle"
					else
						self.weaponState = "cocked"
					end
				end
			end
			if self.cooldownTime > 0 then
				self.cooldownTime = math.max(0, self.cooldownTime - 1)
			end
		else
			if self.cooldownTime > 0 then
				self.cooldownTime = math.max(0, self.cooldownTime - 1)
			end
		end
	end
end

function Weapon:onCrankChange(change)
	-- handling crank input; Minigun counts only forward rotation above threshold
	if self.weaponType == "Minigun" then
		if change and change > 0 and math.abs(change) >= (self.MinCrankSpeed or 1.0) then
			-- forward rotation above threshold: consider shooting
			self.isShooting = true
			-- reset decel timer
			self.lastDecelTime = playdate.getElapsedTime()
		else
			-- backward rotation or too slow: stop shooting
			self.isShooting = false
		end
		-- firingFrame visual bump based on change magnitude
		if change and change > 0 then
			self.firingFrame = self.firingFrame + math.floor(change/2) + 1
		end
	elseif self.weaponType == "Revolver" then
		-- Revolver behavior: two-phase crank motion
		-- Phase 0: rotate CCW (negative change) by Revolver_ArcSize to "cock" (click)
		-- Phase 1: rotate CW (positive change) by Revolver_ArcSize to fire
		if not change or change == 0 then return end
		local dir = 0
		if change > 0 then dir = 1 elseif change < 0 then dir = -1 end
		local absc = math.abs(change)
		if self.Revolver_stage == 0 then
			-- waiting for CCW cock
			if dir == -1 then
				if self.Revolver_lastDir == -1 or self.Revolver_lastDir == 0 then
					self.Revolver_accum = self.Revolver_accum + absc
				else
					self.Revolver_accum = absc
				end
				self.Revolver_lastDir = -1
				self.weaponState = "winding"
				if self.Revolver_accum >= (self.Revolver_ArcSize or 180) then
						-- cocked: play click (if available), move to stage 1
						if self.weaponState ~= "cocked" then
							if self.Revolver_sfxClick then pcall(function() self.Revolver_sfxClick:play(1) end) end
						end
						self.weaponState = "cocked"
						self.Revolver_stage = 1
						self.Revolver_accum = 0
				end
			else
				-- changed direction before cocking: reset accumulation
				self.Revolver_accum = 0
				self.Revolver_lastDir = dir
				self.weaponState = "idle"
			end
		elseif self.Revolver_stage == 1 then
			-- cocked: waiting for CW release to fire
			if dir == 1 then
				if self.Revolver_lastDir == 1 or self.Revolver_lastDir == 0 then
					self.Revolver_accum = self.Revolver_accum + absc
				else
					self.Revolver_accum = absc
				end
				self.Revolver_lastDir = 1
				self.weaponState = "winding"
					if self.Revolver_accum >= (self.Revolver_ArcSize or 180) then
						-- request a single-frame fire event (visible to enemies in this frame)
						self.Revolver_pendingFire = true
						self.cooldownTime = self.maxCooldown
						self.Revolver_stage = 0
						self.Revolver_accum = 0
						self.firingFrame = self.firingFrame + 1
						if self.Revolver_sfxShot then pcall(function() self.Revolver_sfxShot:play(1) end) end
					end
			else
				-- reversed during release before completion -> reset release accumulation, remain cocked
				self.Revolver_accum = 0
				self.Revolver_lastDir = dir
				self.weaponState = "cocked"
			end
		end
	else
		-- simple handling for other weapons (existing behavior)
		if math.abs(change) > 1 then
			if self.maxWindUp > 0 then
				self.weaponState = "winding"
				self.windUpTime = math.min(self.maxWindUp, self.windUpTime + 1)
				if self.windUpTime >= self.maxWindUp and self.cooldownTime <= 0 then
					self.weaponState = "firing"
					self.cooldownTime = self.maxCooldown
				end
			else
				if self.cooldownTime <= 0 then
					self.weaponState = "firing"
					self.cooldownTime = self.maxCooldown
				end
			end
			self.firingFrame = self.firingFrame + math.floor(math.abs(change)/2) + 1
		else
			if self.weaponState == "winding" then
				self.windUpTime = math.max(0, self.windUpTime - 2)
				if self.windUpTime == 0 then self.weaponState = "idle" end
			else
				self.weaponState = "idle"
				self.windUpTime = math.max(0, self.windUpTime - 1)
			end
		end
		if self.cooldownTime > 0 then
			self.cooldownTime = self.cooldownTime - 1
		end
	end
end

function Weapon:setType(t)
	self.weaponType = t
	self:initByType(t)
end

function Weapon:draw()
	-- Simple FPS-style weapon drawn bottom-center of the screen.
	local cx = 200
	local cy = 220
	local w = 140
	local h = 48

	-- shadow / ground plate
	gfx.setColor(gfx.kColorBlack)
	gfx.fillRect(cx - w/2, cy - h/2 + 6, w, h)

	-- helper for muzzle flash
	local function drawFlash(x, y)
		gfx.setColor(gfx.kColorWhite)
		gfx.fillCircleAtPoint(x, y, 6)
		gfx.setColor(gfx.kColorBlack)
		gfx.fillCircleAtPoint(x, y, 3)
	end

	if self.weaponType == "Minigun" then
		-- body
		gfx.setColor(gfx.kColorWhite)
		gfx.fillRect(cx - 30, cy - 18, 60, 30)
		-- barrels (rotating visual using firingFrame)
		local bx = cx + 40
		local by = cy - 6
		for i = 0, 3 do
			local ang = (self.firingFrame * 8 + i * 90) % 360
			local rx = bx + math.cos(math.rad(ang)) * 16
			local ry = by + math.sin(math.rad(ang)) * 4
			gfx.drawLine(bx, by, rx, ry)
		end
		if self.weaponState == "firing" then
			drawFlash(bx + 22, by)
		end

	elseif self.weaponType == "Revolver" then
		-- cylinder
		local cylX = cx - 10
		local cylY = cy - 6
		gfx.setColor(gfx.kColorWhite)
		gfx.fillCircleAtPoint(cylX, cylY, 18)
		gfx.setColor(gfx.kColorBlack)
		gfx.fillCircleAtPoint(cylX, cylY, 10)
		-- barrel
		local bx = cylX + 26
		local by = cylY - 4
		gfx.setColor(gfx.kColorWhite)
		gfx.fillRect(bx, by, 40, 10)
		gfx.setColor(gfx.kColorBlack)
		gfx.fillRect(bx + 34, by + 2, 6, 6)
		-- hammer (simple rectangle rotated visually by moving up when cocked)
		local hx = cylX - 6
		local hy = cylY - 22
		if self.weaponState == "cocked" then
			gfx.fillRect(hx, hy - 6, 12, 12)
		else
			gfx.fillRect(hx, hy, 12, 8)
		end
		-- muzzle flash on firing
		if self.weaponState == "firing" then
			drawFlash(bx + 42, by + 5)
		end

	elseif self.weaponType == "Shotgun" then
		-- simple long barrel
		gfx.setColor(gfx.kColorWhite)
		gfx.fillRect(cx - 60, cy - 18, 110, 20)
		gfx.setColor(gfx.kColorBlack)
		gfx.fillRect(cx + 44, cy - 14, 8, 12)
		if self.weaponState == "firing" then
			drawFlash(cx + 54, cy - 8)
		end

	else
		-- default simple gun
		gfx.setColor(gfx.kColorWhite)
		gfx.fillRect(cx - 40, cy - 16, 80, 24)
		if self.weaponState == "firing" then
			drawFlash(cx + 40, cy - 8)
		end
	end
end

-- Factory helper
function Weapon.new(t)
	return Weapon(t)
end