local ReplicatedStorage = game:GetService('ReplicatedStorage')

local dLib = require(ReplicatedStorage.Packages.dLib)
local Util = dLib.import('Util')

local weapon = {}

weapon.name = 'weapon'
weapon.version = '1.0.0'
weapon.private = { -- Functions not available to clients
	
}

weapon.equip = function(player, payload)
	local newWeapon = ReplicatedStorage.Resources.WeaponModels:FindFirstChild(payload.weapon or 'Pistol')
	
	local humanoid = Util.getHumanoid(player)
	
	if not newWeapon or not humanoid then
		return
	end

	humanoid:UnequipTools()
	
	for _, tool in pairs(player.Backpack:GetChildren()) do
		tool:Destroy()
	end
	
	local equippedWeapon = newWeapon:Clone()
	
	for _, logic in pairs(ReplicatedStorage.Shared.Weapons[payload.weapon or 'Pistol']:GetChildren()) do
		logic:Clone().Parent = equippedWeapon
	end
	
	equippedWeapon.Parent = player.Backpack
	humanoid:EquipTool(equippedWeapon)
end

return weapon