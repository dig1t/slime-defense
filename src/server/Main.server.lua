local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local Workspace = game:GetService('Workspace')

local red = require(ReplicatedStorage.Packages.red)
local dLib = require(ReplicatedStorage.Packages.dLib)
local Util = dLib.import('Util')
local Ragdoll = dLib.import('Ragdoll')

local GameLogic = require(script.Parent.Game)
local cfg = require(script.Parent.Config)

local server = red.Server.new()

local RESPAWN_TIME = 2
local DEFAULT_CHARACTER = 'Default'

do -- Initialize
	server:loadModules(script.Parent.Modules:GetChildren())
	server:init() -- Start the server
	
	function server.error(err) -- Override default error handler
		error(err, 2)
	end
	
	Util.set(ReplicatedStorage, 'version', cfg.build)
	
	coroutine.wrap(GameLogic.init)()
end

local function spawnPlayer(player: Player): Model
	local spawnPoint = Util.tableRandom(cfg.spawns)
	local offset = spawnPoint:FindFirstChild('Offset') and spawnPoint.Offset.Value or { X = 4, Z = 4 }
	
	player:LoadCharacter()
	
	RunService.Heartbeat:Wait()
	
	player.Character:SetPrimaryPartCFrame(spawnPoint.CFrame * CFrame.new(
		math.random(-offset.X, offset.X),
		6,
		math.random(-offset.Z, offset.Z)
	))
	
	local spawnedTag = Instance.new('StringValue')
	spawnedTag.Name = 'Spawned'
	spawnedTag.Parent = player.Character
	
	server:localCall('WEAPON_EQUIP', player, {})
	
	return player.Character
end

-- Distracting accessories to remove
local ACCESSORY_CLASS_BLACKLIST = {
	Script = true;
	Sound = true;
	Fire = true;
	ParticleEmitter = true;
	Smoke = true;
	Sparkles = true;
}

local function characterAdded(player: Player, character: Model): nil
	if not character.Parent then
		character.AncestryChanged:Wait()
		
		if not character.Parent then
			return
		end
	end
	
	-- Remove blacklisted instances inside the accessory
	for _, obj in pairs(character:GetChildren()) do
		if obj:IsA('Accessory') and obj:FindFirstChild('Handle') then
			for _, child in pairs(obj.Handle:GetChildren()) do
				if ACCESSORY_CLASS_BLACKLIST[child.ClassName] then
					child:Destroy()
				end
			end
		end
	end
	
	coroutine.wrap(function()
		Ragdoll.setup(character)
	end)()
	
	local deathWatcher
	
	deathWatcher = character:WaitForChild('Humanoid').Died:Connect(function()
		deathWatcher:Disconnect()
		deathWatcher = nil
		
		coroutine.wrap(function()
			Ragdoll.playerDied(
				player,
				Workspace:FindFirstChild('World'),
				RESPAWN_TIME,
				character:FindFirstChild('keepRagdollInWorld') and character.keepRagdollInWorld.Value
			)
		end)()
		
		Util.yield(RESPAWN_TIME)
		
		if not player or not player.Parent then
			return
		end
		
		if character and character.Parent then
			local tool = character:FindFirstChildOfClass('Tool')
			
			if tool then
				tool.Parent = player:FindFirstChild('Backpack')
			end
			
			RunService.Stepped:Wait()
			character:Destroy()
		end
		
		-- Make sure the character wasn't loaded somewhere else
		if player.Character == character or not player.Character then
			spawnPlayer(player)
		end
	end)
end

local function playerAdded(player: Player): nil
	local profile = server:localCall('PROFILE_NEW', player)
	
	if not profile then
		return
	end
	
	player.CharacterAdded:Connect(function(character)
		characterAdded(player, character)
	end)
	
	player.NameDisplayDistance = 0
	player.HealthDisplayDistance = 0
	--player.CameraMinZoomDistance = 30
	--player.CameraMaxZoomDistance = 30
	
	if not player or not player.Parent then
		return
	end
	
	spawnPlayer(player)
	
	coroutine.wrap(function()
		repeat
			local start = os.clock()
			
			while os.clock() - start < cfg.saveInterval and player and player.Parent do
				Util.yield(60)
			end
			
			if player and player.Parent then
				server:localCall('PROFILE_SAVE', player)
			end
		until not player or not player.Parent
	end)()
end

-- Add players that joined before the connection was created
for _, player in pairs(Players:GetPlayers()) do
	playerAdded(player)
end

Players.PlayerAdded:Connect(playerAdded)

if cfg.saveData then
	Players.PlayerRemoving:Connect(function(player)
		server:localCall('PROFILE_SAVE', player, {
			removeLocal = true -- Remove profile from our local copy
		})
		
		server:localCall('FIRESEC_REMOVE_RESPONSES', player.UserId)
	end)
	
	-- Save player data before server shuts down
	game:BindToClose(function()
		for _, player in pairs(Players:GetChildren()) do
			server:localCall('PROFILE_SAVE', player, {
				removeLocal = true -- Remove profile from our local copy
			})
		end
	end)
end