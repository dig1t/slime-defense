local ReplicatedStorage = game:GetService('ReplicatedStorage')

local dLib = require(ReplicatedStorage.Packages.dLib)
local Util = dLib.import('Util')
local WeaponServer = dLib.import('WeaponServer')

local Config = require(script.Parent:WaitForChild('Config'))
local weapon = WeaponServer.new(Config)

weapon:bind('WEAPON_SHOOT', function(payload)
	weapon:shoot({
		target = payload.target,
		callback = function(result)
			local humanoid = Util.getHumanoid(result.Instance.Parent)
			
			if humanoid then
				humanoid.Health = humanoid.Health - Config.damage
			end
		end
	})
end)