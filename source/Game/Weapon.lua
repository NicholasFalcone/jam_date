class('Weapon').extends()

import "Core/AudioManager"
import "Game/WeaponTypes"
import "Game/WeaponTypes/MinigunWeapon"
import "Game/WeaponTypes/RevolverWeapon"
import "Game/WeaponTypes/ShotgunWeapon"
import "Game/WeaponTypes/MolotovWeapon"
import "Game/WeaponTypes/BowWeapon"
import "Game/WeaponTypes/FlamethrowerWeapon"

local gfx = playdate.graphics
local audioManager = AudioManager()

function Weapon:init(typeName, ammo, crosshair)
	self.crosshair = crosshair
	self.audioManager = audioManager
	self.shakeDecay = 0.8
	self.weaponType = nil
	self.definition = nil
	self.Ammo = ammo
	self:setType(typeName or WeaponTypes.getDefaultId(), ammo)
end

function Weapon:getDefinition(typeName)
	return WeaponTypes.getById(typeName or self.weaponType)
end

function Weapon:resetBaseState(ammo)
	self.weaponState = "idle"
	self.windUpTime = 0
	self.maxWindUp = 0
	self.firingFrame = 0
	self.cooldownTime = 0
	self.maxCooldown = 0
	self.autoFire = false
	self.hitboxScale = 1
	self.shakeIntensity = 0
	self.lastShotValid = false
	self.shotProcessed = true
	self.lastHitProcessTime = 0
	self.isShooting = false

	if self.crosshair then
		self.crosshair.hitRadius = 0
		self.crosshair.reticleScale = 1
	end

	if ammo ~= nil then
		self.Ammo = ammo
	elseif self.Ammo == nil then
		self.Ammo = 100
	end
end

function Weapon:configureType(typeName, ammo)
	self.weaponType = typeName or WeaponTypes.getDefaultId()
	self.definition = self:getDefinition(self.weaponType)
	self:resetBaseState(ammo)

	if self.definition and self.definition.configure then
		self.definition.configure(self, ammo)
	end

	self.cooldownTime = self.maxCooldown or 0
	self.firingFrame = 0
	self.Ammo = ammo or self.Ammo or 100
	self.weaponState = "idle"
end

function Weapon:update(now)
	now = now or playdate.getElapsedTime()

	if self.shakeIntensity and self.shakeIntensity > 0 then
		self.shakeIntensity = self.shakeIntensity * (self.shakeDecay or 0.8)
		if self.shakeIntensity < 0.1 then
			self.shakeIntensity = 0
		end
	end

	local definition = self:getDefinition()
	if definition and definition.update then
		definition.update(self, now)
	else
		self:updateCooldown()
	end
end

function Weapon:onCrankChange(change)
	local definition = self:getDefinition()
	if definition and definition.onCrankChange then
		definition.onCrankChange(self, change)
	else
		self:onCrankChangeDefault(change)
	end
end

function Weapon:onCrankChangeDefault(change)
	if math.abs(change) > 1 then
		if self.maxWindUp > 0 then
			self:setState("winding")
			self.windUpTime = math.min(self.maxWindUp, self.windUpTime + 1)
			if self.windUpTime >= self.maxWindUp and self.cooldownTime <= 0 then
				self:setState("firing")
				self:startCooldown()
			end
		else
			if self.cooldownTime <= 0 then
				self:setState("firing")
				self:startCooldown()
			end
		end
		self:bumpFireFrame(change)
	else
		if self.weaponState == "winding" then
			self.windUpTime = math.max(0, self.windUpTime - 2)
			if self.windUpTime == 0 then
				self:setState("idle")
			end
		else
			self:setState("idle")
			self.windUpTime = math.max(0, self.windUpTime - 1)
		end
	end

	self:updateCooldown()
end

function Weapon:setType(typeName, ammo)
	self:stopAllSounds()
	self:configureType(typeName, ammo)
end

function Weapon:setState(newState)
	local definition = self:getDefinition()
	if self.weaponState == "firing" and newState ~= "firing" then
		if definition and definition.hasActiveFireState and definition.hasActiveFireState(self) then
			return
		end
	end

	self.weaponState = newState
end

function Weapon:consumeAmmo(amount)
	amount = amount or 1
	if (self.Ammo or 0) >= amount then
		self.Ammo = (self.Ammo or 0) - amount
		return true
	end
	return false
end

function Weapon:startCooldown()
	self.cooldownTime = self.maxCooldown
end

function Weapon:isOnCooldown()
	return self.cooldownTime > 0
end

function Weapon:updateCooldown()
	if self.cooldownTime > 0 then
		self.cooldownTime = math.max(0, self.cooldownTime - 1)
	end
end

function Weapon:triggerFire()
	self:setState("firing")
	self.firingFrame = self.firingFrame + 1
end

function Weapon:bumpFireFrame(change)
	if change and change ~= 0 then
		self.firingFrame = self.firingFrame + math.floor(math.abs(change) / 2) + 1
	end
end

function Weapon:fire(ammoConsumption)
	ammoConsumption = ammoConsumption or 1
	local hadAmmo = false

	if (self.Ammo or 0) >= ammoConsumption then
		self:consumeAmmo(ammoConsumption)
		hadAmmo = true
	elseif (self.Ammo or 0) >= 1 then
		self:consumeAmmo(self.Ammo)
		hadAmmo = true
	end

	self.lastShotValid = hadAmmo
	self.shotProcessed = false
	self:playFireSound()

	if hadAmmo then
		local definition = self:getDefinition()
		if definition and definition.applyFireFeedback then
			definition.applyFireFeedback(self)
		end
	end

	self:triggerFire()
	return hadAmmo
end

function Weapon:playFireSound()
	local definition = self:getDefinition()
	if definition and definition.playFireSound then
		definition.playFireSound(self)
	end
end

function Weapon:stopAllSounds()
	local definition = self:getDefinition()
	if definition and definition.stopAllSounds then
		definition.stopAllSounds(self)
	end
end

function Weapon:draw()
	local definition = self:getDefinition()
	local cx = 200
	local cy = 220

	if definition and definition.draw then
		definition.draw(self, cx, cy)
	else
		self:drawDefault(cx, cy)
	end
end

function Weapon:drawFlash(x, y)
	gfx.setColor(gfx.kColorWhite)
	gfx.fillCircleAtPoint(x, y, 6)
	gfx.setColor(gfx.kColorBlack)
	gfx.fillCircleAtPoint(x, y, 3)
end

function Weapon:drawDefault(cx, cy)
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(cx - 40, cy - 16, 80, 24)
	if self.weaponState == "firing" then
		self:drawFlash(cx + 40, cy - 8)
	end
end

function Weapon:loadFrameSequence(basePath, frameNumbers)
	local frames = {}
	for _, frameNumber in ipairs(frameNumbers) do
		local image = gfx.image.new(basePath .. tostring(frameNumber))
		if image then
			table.insert(frames, image)
		end
	end
	return frames
end

function Weapon.new(typeName, crosshair)
	return Weapon(typeName, 20, crosshair)
end