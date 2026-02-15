class('UI').extends()

function UI:init()
	self.ammoIconX = 5
	self.ammoIconY = 5
	self.ammoTextX = 25
	self.ammoTextY = 8
end

-- UI richiamata ogni frame per disegnare elementi come testo, barre della salute, ecc.
function UI:draw(weapon)
	local gfx = playdate.graphics
	
	if weapon then
		self:drawAmmo(gfx, weapon)
		-- self:drawWeaponInfo(gfx, weapon)
	end
end

-- Draw ammo counter
function UI:drawAmmo(gfx, weapon)
	local ammo = weapon.Ammo or 0
	local ammoText = string.format("Ammo: %d", ammo)
	
	gfx.setColor(gfx.kColorBlack)
	gfx.drawText(ammoText, self.ammoTextX, self.ammoTextY)
end

-- Draw weapon name and state
function UI:drawWeaponInfo(gfx, weapon)
	local infoY = 35
	local weaponName = weapon.weaponType or "Unknown"
	local weaponState = weapon.weaponState or "idle"
	local damage = weapon.Damage or 0
	
	local stateColor = gfx.kColorWhite
	if weaponState == "firing" then
		stateColor = gfx.kColorWhite
	elseif weaponState == "winding" then
		stateColor = gfx.kColorWhite
	end
	
	gfx.setColor(gfx.kColorBlack)
	gfx.fillRect(5, infoY - 2, 150, 35)
	
	gfx.setColor(gfx.kColorWhite)
	gfx.drawRect(5, infoY - 2, 150, 35)
	gfx.drawText(weaponName, 10, infoY)
	gfx.drawText("State: " .. weaponState, 10, infoY + 12)
	gfx.drawText("Dmg: " .. damage, 10, infoY + 24)
end