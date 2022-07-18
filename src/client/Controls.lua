local ReplicatedStorage = game:GetService('ReplicatedStorage')
local UserInput = game:GetService('UserInputService')

local red = require(ReplicatedStorage.Packages.red)

local store = red.Store.new()

local Controls = {}

function Controls:setSpeed(speed)
	store:dispatch({
		type = 'CHARACTER_SPEED',
		payload = {
			speed = speed
		}
	})
end

function Controls:constructor()
	self.connections = {}
	
	UserInput.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			self:setSpeed('run')
		end
	end)
	
	UserInput.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			self:setSpeed('walk')
		end
	end)
end

return Controls