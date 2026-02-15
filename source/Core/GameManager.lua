class('GameManager').extends()

import "Game/Dice"
import "Core/AudioManager"
import "Core/UI"

-- Game states
local GAME_STATE = {
	IDLE = "idle",           -- Main menu / waiting to start
	RUNNING = "running",     -- Active gameplay
	ROLLING = "rolling",     -- Dice rolling for ammo/weapon
	GAME_OVER = "gameOver",  -- Player defeated
	PAUSED = "paused"        -- Game paused
}

local audioManager = AudioManager()

function GameManager:init()
	self.currentState = GAME_STATE.IDLE
	self.score = 0
	self.waveCount = 0
	self.timeAlive = 0
	self.enemiesDefeated = 0
	self.playerHealth = 100
	self.maxPlayerHealth = 100
	
	-- Rolling state variables
	self.weaponDice = nil     -- White dice for weapon selection
	self.ammoDice = {}       -- 4 black dice for ammo amount
	self.rolledWeapon = nil  -- Result: weapon type (1-2 = Minigun, 3-4 = Revolver, 5-6 = Shotgun)
	self.rolledAmmo = 0      -- Result: total ammo from 4 dice

	-- UI is managed by GameManager for non-gameplay screens (menu / howto / credits)
	-- main.lua can keep its own UI instance for in-game HUD.
	self.ui = UI()
	self.ui:setScreen("menu")
end

function GameManager:update(deltaTime)
	if self.currentState == GAME_STATE.RUNNING then
		self.timeAlive = self.timeAlive + (deltaTime or 0.016)
	end
end

function GameManager:setState(newState)
	if newState == self.currentState then return end

	-- IMPORTANT: main.lua currently starts the game on *any* A press while IDLE.
	-- We cannot change main.lua, so we gate the transition here and only allow
	-- starting when the UI is on the menu and the selection is "Play".
	if self.currentState == GAME_STATE.IDLE and newState == GAME_STATE.RUNNING then
		if self.ui and self.ui.canStart and not self.ui:canStart() then
			return
		end
	end
	
	local oldState = self.currentState
	self.currentState = newState
	
	-- Handle state transitions
	if newState == GAME_STATE.IDLE then
		self:onIdleEnter()
	elseif newState == GAME_STATE.RUNNING then
		self:onRunningEnter()
	elseif newState == GAME_STATE.ROLLING then
		self:onRollingEnter()
	elseif newState == GAME_STATE.GAME_OVER then
		self:onGameOverEnter()
	elseif newState == GAME_STATE.PAUSED then
		self:onPausedEnter()
	end
end

function GameManager:getState()
	return self.currentState
end

function GameManager:isRunning()
	return self.currentState == GAME_STATE.RUNNING
end

function GameManager:isGameOver()
	return self.currentState == GAME_STATE.GAME_OVER
end

function GameManager:isIdle()
	return self.currentState == GAME_STATE.IDLE
end

function GameManager:isPaused()
	return self.currentState == GAME_STATE.PAUSED
end

function GameManager:isRolling()
	return self.currentState == GAME_STATE.ROLLING
end

local music = nil

-- State callbacks
function GameManager:onIdleEnter()
	-- Reset game variables for new run
	self.score = 0
	self.waveCount = 0
	self.timeAlive = 0
	self.enemiesDefeated = 0
	self.playerHealth = self.maxPlayerHealth
	print("Running state entered.")
	if self.ui and self.ui.setScreen then
		self.ui:setScreen("menu")
	end
	if music then music:stop() end -- Stop menu music
	music = audioManager:loadSample("sounds/Music_Menu") -- Example of loading a sound sample for the idle state
	if music then 
		music:play(0) 
	else 
		print("Failed to load menu music")
	end -- Loop indefinitely
end

function GameManager:onRunningEnter()
	-- Game started
	self.timeAlive = 0
	self.waveCount = 1
	print("Running state entered.")
	if music then music:stop() end -- Stop menu music
	music = audioManager:loadSample("sounds/Music_Game") -- Example of loading a sound sample for the idle state
	if music then 
		music:play(0) 
	else
		print("Failed to load game music")
	end -- Loop indefinitely
end

function GameManager:onRollingEnter()
	-- Rolling state entered - initialize dice
	-- Create weapon dice (white)
	self.weaponDice = Dice()
	self.weaponDice:roll()
	
	-- Create 4 ammo dice (black)
	self.ammoDice = {}
	for i = 1, 4 do
		local dice = Dice()
		dice:roll()
		table.insert(self.ammoDice, dice)
	end
	
	-- Calculate results
	self:calculateRollingResults()
end

function GameManager:onGameOverEnter()
	-- Player died - game over
end

function GameManager:onPausedEnter()
	-- Game paused
end

-- Calculate rolling results
function GameManager:calculateRollingResults()
	-- Weapon dice: 1-2 Minigun, 3-4 Revolver, 5-6 Shotgun
	local weaponRoll = self.weaponDice.value
	if weaponRoll <= 2 then
		self.rolledWeapon = "Minigun"
	elseif weaponRoll <= 4 then
		self.rolledWeapon = "Revolver"
	else
		self.rolledWeapon = "Shotgun"
	end
	
	-- Ammo dice: sum of 4 black dice
	self.rolledAmmo = 0
	for _, die in ipairs(self.ammoDice) do
        if weaponRoll <= 2 then
            self.rolledAmmo = self.rolledAmmo + (die.value * 5) -- Minigun gets dice * multi ammo
        else
            self.rolledAmmo = self.rolledAmmo + die.value
        end
    end
end

-- Score management
function GameManager:addScore(points)
	self.score = self.score + points
end

function GameManager:addEnemyDefeated()
	self.enemiesDefeated = self.enemiesDefeated + 1
	self:addScore(10) -- 10 points per enemy
end

-- Health management
function GameManager:takeDamage(amount)
	self.playerHealth = math.max(0, self.playerHealth - amount)
	if self.playerHealth <= 0 then
		self:setState(GAME_STATE.GAME_OVER)
	end
end

-- Wave management
function GameManager:nextWave()
	self.waveCount = self.waveCount + 1
	self:addScore(100 * self.waveCount) -- Bonus for surviving wave
end

-- Draw UI
function GameManager:drawStateScreen(gfx)
	if self.currentState == GAME_STATE.IDLE then
		self:drawIdleScreen(gfx)
	elseif self.currentState == GAME_STATE.ROLLING then
        self:drawRollingScreen(gfx)
	elseif self.currentState == GAME_STATE.GAME_OVER then
        self:drawGameOverScreen(gfx)
	end
end

function GameManager:drawIdleScreen(gfx)
	-- Clear and set white background
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(0, 0, 400, 240)
	gfx.setColor(gfx.kColorBlack)

	-- If UI exists, use it for the menu flow.
	if self.ui then
		local action = self.ui:update()
		if action == "howto" then
			self.ui:setScreen("howto")
		elseif action == "credits" then
			self.ui:setScreen("credits")
		elseif action == "back" then
			self.ui:setScreen("menu")
		end

		self.ui:draw(nil)
		return
	end

	-- Fallback (in case UI failed to load)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawText("JAM DATE", 5, 50)
	gfx.drawText("Press A Button to START", 5, 100)
	gfx.drawText("Use DPAD to aim", 5, 130)
	gfx.drawText("Rotate CRANK to shoot", 5, 160)
	gfx.drawText("Press B to switch weapon", 5, 190)
end

function GameManager:drawGameOverScreen(gfx)
	-- Clear and set white background
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(0, 0, 400, 240)
	
	-- Draw text in black
	gfx.setColor(gfx.kColorBlack)
	gfx.drawText("GAME OVER", 10, 30)
	gfx.drawText("Score: " .. self.score, 10, 70)
	gfx.drawText("Enemies: " .. self.enemiesDefeated, 10, 100)
	gfx.drawText("Time: " .. string.format("%.1f", self.timeAlive) .. "s", 10, 130)
	gfx.drawText("Press A to restart", 10, 180)
end

function GameManager:drawRollingScreen(gfx)
	-- Clear and set black background
	gfx.setColor(gfx.kColorBlack)
	
	-- Draw title
	gfx.setColor(gfx.kColorWhite)
	gfx.drawText("ROLL FOR AMMO & WEAPON", 30, 10)
	
	-- Draw white die for weapon selection (left side, higher)
	if self.weaponDice then
		self.weaponDice:draw(80, 70, false, false) -- white die
	end
	
	-- Draw 4 black dice for ammo (right side, lower)
	if self.ammoDice and #self.ammoDice == 4 then
		local baseX = 260
		local baseY = 60
		local spacing = 45
		
		-- Draw dice in a 2x2 grid
		self.ammoDice[1]:draw(baseX, baseY, true, false)                          -- top-left
		self.ammoDice[2]:draw(baseX + spacing, baseY, true, false)                -- top-right
		self.ammoDice[3]:draw(baseX, baseY + spacing, true, false)                -- bottom-left
		self.ammoDice[4]:draw(baseX + spacing, baseY + spacing, true, false)      -- bottom-right
	end
	
	-- Draw separator line
	gfx.setColor(gfx.kColorWhite)
	gfx.drawLine(0, 160, 400, 160)
	
	-- Draw text results
	gfx.setColor(gfx.kColorWhite)
	local weaponText = "Weapon: " .. (self.rolledWeapon or "?")
	local ammoText = "Ammo: " .. self.rolledAmmo
	
	gfx.drawText(weaponText, 50, 175)
	gfx.drawText(ammoText, 50, 200)
	gfx.drawText("Press A to continue", 60, 220)
end

-- Exports for state constants
function GameManager.getStateConstants()
	return GAME_STATE
end

return GAME_STATE
