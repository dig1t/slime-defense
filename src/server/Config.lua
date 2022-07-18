local Workspace = game:GetService('Workspace')

local cfg = {}

cfg.build = game.PlaceVersion

cfg.dbVersion = '1.0.0'

cfg.dev = false --RunService:IsStudio()

cfg.saveData = false
cfg.saveInterval = 60 * 4

cfg.spawns = Workspace.World.Spawns

-- Keys to ignore when saving
cfg.ignoreProfileSave = {
	'spectating',
	'accent_color',
	'_lastBackup',
	'inventory',
	'session_rounds'
}

-- Profile table that gets saved
cfg.defaultProfile = function(player)
	return {
		id = player.UserId;
		
		-- Analytics
		total_time = 0;
		
		stats = {
			coins = 100;
			kills = 0;
			points = 0;
			xp = 0;
			level = 1;
		};
		
		-- Developer product purchase saves
		purchases = {};
		
		-- Purchases that failed to save are stored here
		-- They will not run the action they were intended to do
		unsaved = {};
		
		spectating = false;
	}
end

return cfg