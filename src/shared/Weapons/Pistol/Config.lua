local ReplicatedStorage = game:GetService('ReplicatedStorage')

script.Parent:WaitForChild('Server')
script.Parent:WaitForChild('Client')

return {
	tool = script.Parent;
	
	grip = CFrame.new(0, -.2, -.4, -1, 0, 0, 0, 1, 0, 0, 0, 1);
	
	state = {
		equip = 'WEAPON_EQUIP',
		unequip = 'WEAPON_UNEQUIP',
		reload = 'WEAPON_RELOAD',
		shoot = 'WEAPON_SHOOT',
		hold = 'WEAPON_HOLD'
	};
	
	hitscan = true;
	tracerRound = true;
	
	damage = 34;
	
	projectileReference = ReplicatedStorage.Resources.Objects.Bullet;
	projectileVelocity = 6;
	
	cursor = {
		normal = 4839441256,
		target = 4839441467,
		reload = 4839441295
	};
	
	cooldown = {
		WEAPON_SHOOT = .02,
		WEAPON_RELOAD = .02
	};
	
	sfx = {
		--WEAPON_EQUIP = { 4845326658 },
		WEAPON_SHOOT = { 1566260295 }
	};
	
	animations = {
		WEAPON_SHOOT = { 5065235925 },
		WEAPON_HOLD = { 5065234934 }
	};
}