local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')
local Workspace = game:GetService('Workspace')

local dLib = require(ReplicatedStorage.Packages.dLib)
local Util = dLib.import('Util')

local LowGrav = require(ReplicatedStorage.Shared.Resources.LowGrav)

local Monster, methods = {}, {}
methods.__index = methods

local MonsterContainer = Instance.new('Folder')
MonsterContainer.Name = 'Monsters'
MonsterContainer.Parent = Workspace

local animationIds = {
	walk = 'rbxassetid://10267840996',
	idle = 'rbxassetid://10267920602'
}

local sounds = {
	hurt = 'rbxassetid://6916371803',
	attack = 'rbxassetid://344167846',
	moving = 'rbxassetid://9119990452'
}

local MIN_FOLLOW_DISTANCE = 100

function Monster.getRandomPosition(origin)
	return origin + Vector3.new(
		math.random(8, 13) * (math.random(1, 2) == 1 and 1 or -1),
		0,
		math.random(8, 13) * (math.random(1, 2) == 1 and 1 or -1)
	)
end

function Monster.getClosestPlayer(root: BasePart)
	local target
	
	for _, player in pairs(Players:GetPlayers()) do
		if (player.Character and player.Character.PrimaryPart) and (
			-- No target, set player as initial target
			not target or (
				-- Set player as target if player is closer than the current target
				target and (root.Position - player.Character.PrimaryPart.Position).Magnitude < target[2]
			)
		) then
			target = {
				player.Character.PrimaryPart.Position,
				(root.Position - player.Character.PrimaryPart.Position).Magnitude
			}
		end
	end
	
	return target or {}
end

function methods:died(fn): nil
	assert(typeof(fn) == 'function', 'Callback must be a function')
	
	self.diedConnections[#self.diedConnections + 1] = fn
end

function methods:kill(): nil
	if self.humanoid and self.humanoid.Parent then
		self.humanoid.Health = 0
	end
end

function methods:playAnimation(state: string): nil
	if state == self.currentState or not self.animations[state] then
		return
	end
	
	self:stopAnimation()
	
	self.currentState = state
	self.currentTrack = self.animations[state]
	
	if self.currentTrack then
		self.currentTrackLooper = self.currentTrack.Stopped:Connect(function()
			if self.currentTrack then
				self.currentTrack:Play()
			end
		end)
		
		self.currentTrack:Play()
	end
end

function methods:stopAnimation(): nil
	self.currentState = nil
	
	if self.currentTrackLooper and self.currentTrackLooper.Connected then
		self.currentTrackLooper:Disconnect()
		self.currentTrackLooper = nil
	end
	
	if self.currentTrack and self.currentTrack.IsPlaying then
		self.currentTrack:Stop()
		self.currentTrack = nil
	end
end

function methods:targetWatch(): nil
	-- If missing humanoid somehow, destroy the monster
	if not self.humanoid or not self.humanoid.Parent then
		self.monster:Destroy()
		return
	end
	
	local originalPosition = self.monster.PrimaryPart.Position
	local randomWalkPoint = Monster.getRandomPosition(originalPosition)
	
	local targetingPlayer
	
	-- Fixes stuck monsters. Sometimes the random point points to a wall.
	coroutine.wrap(function()
		local prevPos = randomWalkPoint
		
		while self.monster.PrimaryPart and self.humanoid.Parent do
			if prevPos == randomWalkPoint then
				randomWalkPoint = Monster.getRandomPosition(originalPosition)
			end
			
			prevPos = randomWalkPoint
			
			self.humanoid.Jump = true -- Make the slime hop!
			
			Util.yield(math.random(300, 500) / 100)
		end
	end)()
	
	coroutine.wrap(function()
		repeat
			Util.yield()
			
			if self.humanoid.Parent then
				local closestPlayer = Monster.getClosestPlayer(self.monster.PrimaryPart)
				local playerOrigin, distance = closestPlayer[1], closestPlayer[2]
				
				-- If self.monster stops following a target, set a new origin.
				-- So the self.monster doesn't walk back to its original spawn position
				if playerOrigin and distance > MIN_FOLLOW_DISTANCE and targetingPlayer then
					originalPosition = self.monster.PrimaryPart.Position
					randomWalkPoint = originalPosition
				end
				
				targetingPlayer = playerOrigin and distance <= MIN_FOLLOW_DISTANCE
				
				-- If target is under 3 studs away, set new random position
				if (
					Vector3.new(randomWalkPoint.X, 0, randomWalkPoint.Z) -
						Vector3.new(self.monster.PrimaryPart.Position.X, 0, self.monster.PrimaryPart.Position.Z)
					).Magnitude < 3 then
					randomWalkPoint = Monster.getRandomPosition(originalPosition)
				end
				
				self.humanoid:MoveTo((
					playerOrigin and distance < MIN_FOLLOW_DISTANCE
				) and playerOrigin or randomWalkPoint)
				
				self.humanoid.WalkSpeed = targetingPlayer and 16.2 or 3
			end
		until (
			not self.monster.PrimaryPart or not self.humanoid.Parent
		)
	end)()
end

function Monster.new(model: Model, spawnOrigin: CFrame): Model
	local self = setmetatable({}, methods)
	
	self.connections = {}
	self.diedConnections = {}
	
	self.monster = model:Clone()
	self.humanoid = self.monster:FindFirstChild('Humanoid')
	
	local gui = ReplicatedStorage.Resources.MonsterHealth:Clone()
	gui.Parent = self.monster.Head
	gui.Enabled = true
	
	self.humanoid.NameDisplayDistance = 0
	self.humanoid.HealthDisplayDistance = Enum.HumanoidDisplayDistanceType.None
	self.humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	self.humanoid.Health = self.humanoid.MaxHealth
	
	for _, part in pairs(self.monster:GetDescendants()) do
		if part:IsA('BasePart') and not part:FindFirstChildOfClass('Attachment') then
			Util.weld(part, self.monster:FindFirstChild('Head'))
		end
	end
	
	self.monster:SetPrimaryPartCFrame(spawnOrigin)
	self.monster.Parent = MonsterContainer
	
	LowGrav.set(self.monster, .38)
	
	self.animations = Util.map(animationIds, function(id, state)
		local animation = Instance.new('Animation')
		animation.Name = state
		animation.AnimationId = id
		animation.Parent = self.monster
		
		Util.yield(.1)
		-- Return the track to add to the table
		return self.humanoid:LoadAnimation(animation), state
	end)
	
	self.sounds = Util.map(sounds, function(id, state)
		local sound = Instance.new('Sound')
		sound.Name = state
		sound.SoundId = id
		sound.Parent = self.monster.PrimaryPart
		
		if state == 'moving' then
			sound.Looped = true
			sound:Play()
		end
		
		return sound, state
	end)
	
	Util.yield(.1)
	
	self.connections[#self.connections + 1] = self.humanoid.Died:Connect(function()
		for _, fn in pairs(self.diedConnections) do
			fn()
		end
		
		self.diedConnections = {}
		
		for _, connection in pairs(self.connections) do
			connection:Disconnect()
		end
	end)
	
	self.connections[#self.connections + 1] = self.humanoid.Running:Connect(function(speed: number): nil
		if speed > .4 then
			self:playAnimation('walk')
			--setAnimationSpeed(speed / self.humanoid.WalkSpeed)
		else
			self:playAnimation('idle')
		end
	end)
	
	self.connections[#self.connections + 1] = self.humanoid.HealthChanged:Connect(function()
		gui.Outline.Bar:TweenSize(
			UDim2.new(self.humanoid.Health / self.humanoid.MaxHealth, 0, 1, 0),
			Enum.EasingDirection.In,
			Enum.EasingStyle.Linear,
			.2,
			true
		)
		
		self.sounds.hurt:Play()
	end)
	
	self.connections[#self.connections + 1] = Util.onPlayerTouch(self.monster.Slime, function(player)
		if not self.attackCooldown then
			local humanoid = Util.getHumanoid(player)
			
			if humanoid then
				humanoid:TakeDamage(24)
				self.sounds.attack:Play()
				
				self.attackCooldown = true
				
				Util.yield(2)
				
				self.attackCooldown = false
			end
		end
	end)
	
	self:died(function()
		self:playAnimation('idle')
		
		Util.yield(1.4)
		
		gui:Destroy()
		self.monster:Destroy()
	end)
	
	--[[for _, logic in pairs(ReplicatedStorage.Shared.MonsterScripts:GetChildren()) do
		logic:Clone().Parent = self.monster
	end]]
	
	self:targetWatch()
	
	Util.yield()
	self:playAnimation('idle')
	
	return self
end

return Monster