local ReplicatedStorage = game:GetService('ReplicatedStorage')

local dLib = require(ReplicatedStorage.Packages.dLib)
local Util = dLib.import('Util')

local character = {}

character.name = 'character'
character.version = '1.0.0'
character.private = { -- Functions not available to clients
	
}

-- We set our speeds on the server, don't let the client choose
local speeds = {
	run = 24,
	walk = 16
}

character.speed = function(player, payload)
	local humanoid = Util.getHumanoid(player)
	
	if not humanoid or not payload or not speeds[payload.speed] then
		return
	end
	
	humanoid.WalkSpeed = speeds[payload.speed]
end

return character