local ReplicatedStorage = game:GetService('ReplicatedStorage')

local dLib = require(ReplicatedStorage.Packages.dLib)
local Util = dLib.import('Util')
local WeaponClient = dLib.import('WeaponClient')

local Config = require(script.Parent:WaitForChild('Config'))

local weapon = WeaponClient.new(Config)

weapon:setInput('primary', {
	InputBegan = function(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2
	end;
})

weapon:setInputCooldown('primary', Config.cooldown.WEAPON_RELOAD)

-- This condition must be true so WeaponClient can fire an onInput event
weapon:setInputCondition('primary', function()
	-- Make sure the user is alive, the weapon handle exists, and the weapon is equipped
	return Util.isAlive(weapon.localHumanoid) and weapon.handle.Parent
end)

weapon:onInput('primary', function()
	local actionId = Util.randomString(4)
	
	weapon.currentActionId = actionId
	
	weapon:setCursor(Config.cursor.reload)
	
	if weapon:inCooldown('primary') then
		-- In a separate thread, wait for the cooldown to end to switch the cursor back
		coroutine.wrap(function()
			Util.yield(Config.cooldown.WEAPON_RELOAD or Config.cooldown.WEAPON_SHOOT)
			
			if weapon.currentActionId == actionId then
				weapon:setCursor(Config.cursor.normal)
			end
		end)()
	end
	
	weapon:shoot()
	
	weapon:playAnimation('WEAPON_SHOOT')
	
	if weapon.currentActionId == actionId and weapon.equipped then
		weapon:playAnimation('WEAPON_HOLD', true)
	end
end)