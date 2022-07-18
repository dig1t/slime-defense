local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')
local Workspace = game:GetService('Workspace')

local dLib = require(ReplicatedStorage.Packages.dLib)
local Util = dLib.import('Util')

local LowGrav = require(ReplicatedStorage.Shared.Resources.LowGrav)
local Monster = require(script.Monster)

local spawnLocations = Workspace.World.MonsterSpawns:GetChildren()

local Logic = {}

local WAVE_WAIT_TIME = 2
local WAVE_MAX_DURATION = 60

local function getClosestSpawn(player: Player): BasePart
	local closestSpawn = spawnLocations[1]
	local closestSpawnDistance = 999999999
	
	local root = player.Character and player.Character.HumanoidRootPart
	
	if not root then
		return closestSpawn
	end
	
	for _, spawnPart in pairs(spawnLocations) do
		local distance = Util.getDistance(root, spawnPart)
		
		if distance < closestSpawnDistance then
			closestSpawn = spawnPart
			closestSpawnDistance = distance
		end
	end
	
	return closestSpawn
end


local function getRandomLocation(spawnPart: Part): CFrame
	return spawnPart.CFrame * CFrame.new(
		math.random(-spawnPart.Size.X / 2, spawnPart.Size.X / 2),
		6,
		math.random(-spawnPart.Size.Z / 2, spawnPart.Size.Z / 2)
	)
end

function Logic.startWave(): nil
	Util.yield(WAVE_WAIT_TIME)
	
	local monstersAlive = 0
	local waveStartTime = os.clock()
	
	for _, player in pairs(Players:GetPlayers()) do
		local monstersToSpawn = math.random(6, 8)
		local closestSpawn = getClosestSpawn(player)
		
		for _ = 1, monstersToSpawn do
			local monster = Monster.new(
				Util.tableRandom(ReplicatedStorage.Resources.MonsterModels),
				getRandomLocation(closestSpawn)
			)
			
			monstersAlive += 1
			
			monster:died(function()
				monstersAlive -= 1
			end)
			
			Util.yield(math.random(100, 900) / 1000)
		end
	end
	
	-- Wait until all mobs died or 60 seconds have passed
	repeat
		Util.yield()
	until monstersAlive < 1 or os.clock() - waveStartTime > WAVE_MAX_DURATION
	
	Logic.startWave()
end

function Logic.init(): nil
	print('game init')
	
	for _, jumppad in pairs(Workspace.World.Pads:GetChildren()) do
		if jumppad:FindFirstChild('Pad') then
			jumppad.Pad.Touched:Connect(function(part)
				local humanoid = Util.getHumanoid(part.Parent)
				
				if not humanoid or (humanoid.Parent:FindFirstChild('Jumping') and humanoid.Parent.Jumping.Value) then
					return
				end
				
				humanoid.Jump = true
				
				Util.set(humanoid.Parent, 'Jumping', true)
				
				LowGrav.set(humanoid.Parent, 1.6)
				
				Util.yield(.2)
				
				LowGrav.remove(humanoid.Parent)
				
				Util.set(humanoid.Parent, 'Jumping', false)
			end)
		end
	end
	
	Logic.startWave()
end

return Logic