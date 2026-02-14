class('Weapon').extends()

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
		if self.cooldownTime > 0 then
			self.cooldownTime = math.max(0, self.cooldownTime - 1)
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
	else
		-- simple handling for other weapons
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
	-- optional: draw weapon UI based on type/state (left as placeholder)
end

-- Factory helper
function Weapon.new(t)
	return Weapon(t)
end