local Workspace = game:GetService('Workspace')

local LowGrav = {}

function LowGrav.calcMass(character: Model): number
	local mass = 0
	
	for _, obj in pairs(character:GetDescendants()) do
		if obj:IsA('BasePart') then
			mass += obj:GetMass()
		end
	end
	
	return mass
end

function LowGrav.setup(character: Model)
	local attachmnet = Instance.new('Attachment')
	attachmnet.Parent = character.PrimaryPart
	
	local force = Instance.new('VectorForce')
	force.Attachment0 = attachmnet
	force.Parent = character
	
	return force
end

function LowGrav.set(character: Model, amount: number?): nil
	local force = character:FindFirstChild('VectorForce')
	
	if not force then
		force = LowGrav.setup(character)
	end
	
	force.Force = Vector3.new(
		0,
		(Workspace.Gravity * LowGrav.calcMass(character)) * (amount or 1),
		0
	)
end

function LowGrav.setForce(character: Model, vector: Vector3): nil
	local force = character:FindFirstChild('VectorForce')
	
	if not force then
		force = LowGrav.setup(character)
	end
	
	force.Force = vector
end

function LowGrav.remove(character: Model): nil
	local force = character:FindFirstChild('VectorForce')
	
	if force then
		force:Destroy()
	end
end

return LowGrav