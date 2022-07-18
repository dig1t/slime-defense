local ReplicatedStorage = game:GetService('ReplicatedStorage')

local dLib = require(ReplicatedStorage.Packages.dLib)
local Util = dLib.import('Util')

local Views = Util.map(
	script:GetChildren(),
	function(module)
		local uiClass = module:IsA('ModuleScript') and require(module) or nil
		
		if not uiClass or not typeof(uiClass) == 'table' then
			return
		end
		
		uiClass.__index = uiClass
		
		local build = setmetatable({
			
		}, uiClass)
		
		if build.constructor then
			build:constructor()
		end
		
		return build, module.Name
	end
)

local Controls = Views.Controls

