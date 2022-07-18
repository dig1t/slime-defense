local ReplicatedStorage = game:GetService('ReplicatedStorage')
local DataStore = game:GetService('DataStoreService')
local HTTP = game:GetService('HttpService')
local Players = game:GetService('Players')

local dLib = require(ReplicatedStorage.Packages.dLib)
local red = require(ReplicatedStorage.Packages.red)
local Util = dLib.import('Util')

local cfg = require(script.Parent.Parent.Config)

local profileState = red.State.new()
local store = red.Store.new()

local function getDatabaseName(id)
	return 'profiles_' .. cfg.dbVersion .. '_' .. id
end

local profile = {}

profile.name = 'profile'
profile.version = '1.0.0'
profile.private = {
	'PROFILE_CALL',
	'PROFILE_NEW',
	'PROFILE_SAVE',
	'PROFILE_RESET',
	'PROFILE_UPDATE',
	'PROFILE_SET',
	'PROFILE_UNSET',
	'PROFILE_ALL_SET',
	'PROFILE_ADD',
	'PROFILE_GET_PLAYERS'
}

------------------------------
-- profile system

--[[
	@desc fetches a user's profile state
	@param object player - player
	@return player profile
]]--
profile.call = function(player, payload)
	if not player then
		return
	end
	
	return profileState:get(player.UserId)
	
	--[[for i, profile in pairs(profileState:get(true)) do
		if profile.id == player.UserId then
			-- DO NOT ADD .payload WHEN CALLING,
			-- IT DOES NOT RETURN AS AN ACTION
			return profile -- Only return state
		end
	end]]
end

--[[
	@desc sets up a new player's profile
	@param object player - player
	@return player profile
]]--
profile.new = function(player)
	assert(
		player and (typeof(player) == 'Instance' and player:IsA('Player')),
		'profile.new - Missing player'
	)
	
	-- profile setup
	local playerProfile = cfg.defaultProfile(player)
	local newPlayer = true
	
	if cfg.saveData and player.UserId > 0 then
		local backupDB = DataStore:GetOrderedDataStore(getDatabaseName(player.UserId))
		local profileDB = DataStore:GetDataStore(getDatabaseName(player.UserId))
		
		local lastBackupVersion
		
		do
			local success, res, tries = Util.attempt(function()
				local fetch = backupDB:GetSortedAsync(false, 1):GetCurrentPage()
				
				if fetch then
					return fetch[1] and fetch[1].value
				end
			end, 3, 2)
			
			if success and res then
				lastBackupVersion = res
			end
			
			if success and tries > 1 then
				warn('Server - Took ' .. tries .. ' tries to get save version for player: ' .. player.UserId)
			end
			
			if not success then
				playerProfile.dontSave = true
				warn('Server - Could not retrieve save version for player: ' .. player.UserId)
			end
		end
		
		if lastBackupVersion then
			local success, res, tries = Util.attempt(function()
				local fetch = profileDB:GetAsync(lastBackupVersion)
				
				if fetch then
					return HTTP:JSONDecode(fetch)
				end
			end, 3, 2) -- Attempt to get data 3 times every 2 seconds
			
			if success and res then
				-- Add any tables that were missing from the saved profile
				-- Example: the developers added a trading system and now the profile
				-- does not have a trade_history table. The below loop will insert
				-- a blank trade_history table from the default profile constructor
				-- cfg.defaultProfile()
				for k, v in pairs(playerProfile) do
					if res[k] == nil then
						res[k] = v
					end
				end
				
				playerProfile = res
				newPlayer = nil
			end
			
			if success and tries > 1 then
				warn('Server - Took ' .. tries .. ' tries to get data for player: ' .. player.UserId)
			end
			
			if not success then
				playerProfile.dontSave = true
				warn('Server - Could not get data for player: ' .. player.UserId)
			end
		end
	end
	
	if playerProfile.banned then
		return player:Kick('You are banned from the game')
	end
	
	--[[if not newPlayer then
		local inventoryGet = store:get({
			type = 'SHOP_GET_INVENTORY',
			player = player,
			payload = {
				inventory_version = playerProfile.inventory_version
			}
		})
		
		playerProfile.inventoryErr = inventoryGet.err and true or nil
		playerProfile.inventory = inventoryGet.payload
	end]]
	
	playerProfile.entity = player
	playerProfile.username = player.Name
	playerProfile.isAdmin = false
	playerProfile.userLevel = Util.getUserLevel(player)
	playerProfile.spectating = true -- Sets to false once player leaves splash screen
	
	playerProfile.session_start = Util.unix()
	playerProfile.session_rounds = 0
	
	profileState:push(player.UserId, playerProfile)
	
	return playerProfile
end

--[[
	@desc save the user's profile to the game's database
	@param object player - player
]]--
profile.save = function(player, payload)
	assert(
		player and (typeof(player) == 'Instance' and player:IsA('Player')),
		'profile.save - Missing player'
	)
	
	local playerProfile = profileState:get(player.UserId) -- Get the profile from memory
	--local inventoryVersion = payload and payload.inventoryVersion
	
	if not playerProfile then
		return
	end
	
	local saved = false
	
	if not playerProfile.dontSave and cfg.saveData and player.UserId > 0 then
		local profileCopy = Util.extend({}, playerProfile) 
		
		--[[if not inventoryVersion then
			-- Begin inventory saving
			local inventorySave = store:get({
				type = 'SHOP_SAVE_INVENTORY',
				player = player,
				payload = {
					inventory = profileCopy.inventory
				}
			})
			
			if inventorySave.success then
				if not inventorySave.err and inventorySave.payload.version then
					inventoryVersion = inventorySave.payload.version
				end
				
				if inventorySave.err then
					-- log error
					return
				end
			else
				return
			end
		end]]
		
		--profileCopy.inventory_version = inventoryVersion or profileCopy.inventory_version
		-- End inventory saving
		
		-- Calculate total play time
		local sessionTimePlayed = Util.unix() - profileCopy.session_start
		profileCopy.total_time = (profileCopy.total_time or 0) + sessionTimePlayed
		profileCopy.session_start = nil
		profileCopy.last_seen = Util.unix()
		
		-- Add up rounds played in session to sum of rounds played
		profileCopy.rounds_played = profileCopy.rounds_played + profileCopy.session_rounds
		
		-- Keys that should not be saved
		for _, v in pairs(cfg.ignoreProfileSave) do
			if profileCopy[v] ~= nil then
				profileCopy[v] = nil
			end
		end
		
		local backupDB = DataStore:GetOrderedDataStore(getDatabaseName(player.UserId))
		local profileDB = DataStore:GetDataStore(getDatabaseName(player.UserId))
		
		do -- Save new profile version
			local newVersion = os.time()
			
			local success, res, tries = Util.attempt(function()
				profileDB:SetAsync(newVersion, HTTP:JSONEncode(profileCopy))
			end, 3, 2) -- Attempt to save data 3 times every 2 seconds
			
			if success then -- Set a new version record in the backup database
				if tries > 1 then
					warn('Server - Took ', tries, ' tries to save data version for player: ' .. player.UserId)
				end
				
				-- Save new record of the newly saved profile version
				-- This will be retrieved next time the player joins
				-- Then it will be used to fetch the version from profileDB
				Util.attempt(function()
					backupDB:SetAsync(newVersion, newVersion)
				end, 3, 2) -- Attempt to save data 3 times every 2 seconds
			end
			
			saved = success
			
			if not success then
				profileState:set(function(state)
					if state[player.UserId] then
						state[player.UserId].dontSave = true
					end
					
					return state
				end)
				
				warn('Server - Could not save data for player: ' .. player.UserId)
			end
		end
	end
	
	-- If player left, delete their profile from the profile state
	if payload and payload.removeLocal then
		profileState:remove(player.UserId)
	end
	
	return {
		type = 'PROFILE_SAVE',
		payload = {
			saved = saved
		}
	}
end

--[[
	@desc permanently wipes a player's saved data including inventory but not purchase history
	@param object player - player
]]--
--[[
profile.reset = function(player)
	local profileFetch = profileState:get(player.UserId) -- Get the profile from memory
	
	if not profileFetch then
		return
	end
	
	local profile = cfg.defaultProfile(player)
	
	profile.entity = player
	profile.username = player.Name
	profile.isAdmin = profileFetch.isAdmin
	profile.userLevel = Util.getUserLevel(player)
	profile.spectating = profileFetch.spectating -- Sets to false once player leaves splash screen
	
	-- Backup developer product purchase history to the new profile
	profile.purchases = profileFetch.purchases
	profile.unsaved = profileFetch.unsaved
	
	profile.session_start = Util.unix()
	
	profileState:set({
		[player.UserId] = profile
	})
end
]]

--[[
	@desc returns a table or an item in a table from a user's profile
	@param object player - player
	@param string payload - values to get
	@return table with values retrieved, the key of each value is the given path
]]
profile.get = function(player, payload)
	assert(
		player and (typeof(player) == 'Instance' and player:IsA('Player')),
		'profile.unset - Missing player'
	)
	
	if not payload then
		return {
			type = 'PROFILE_GET',
			err = 'Missing payload'
		}
	end
	
	local playerProfile = profileState:get(player.UserId)
	local data = {}
	
	if not playerProfile then
		return {
			type = 'PROFILE_GET',
			err = 'Could not retrieve from profile'
		}
	end
	
	for _, pathStr in pairs(payload) do
		local path = Util.split(pathStr, '.', true)
		local res = playerProfile
		
		-- Dig through nest until the last nest level is reached
		for i, childName in ipairs(path) do
			local numberIndex = tonumber(childName)
			
			if numberIndex then
				childName = numberIndex
			end
			
			if res[childName] and i ~= #path then
				res = res[childName]
			elseif i == #path and res[childName] ~= nil then
				-- Change the value if end of the path was reached
				data[pathStr] = res[childName]
			end
		end
	end
	
	return {
		type = 'PROFILE_GET',
		payload = data
	}
end

profile.get_leaderboard_stats = function(id)
	local playerProfile = profileState:get(id)
	
	if playerProfile then
		return {
			type = 'PROFILE_GET_LEADERBOARD_STATS',
			payload = {
				id = id,
				username = playerProfile.username,
				userLevel = playerProfile.userLevel,
				stats = {
					coins = playerProfile.stats.coins,
					level = playerProfile.stats.level,
					points = playerProfile.stats.points
				}
			}
		}
	end
end

profile.get_leaderboard = function()
	--[[local list = Util.map(Players:GetPlayers(), function(player)
		return profile.get_leaderboard_stats(player.UserId).payload
	end)]]
	
	local list = Util.map(profileState:get(true), function(_, id)
		return profile.get_leaderboard_stats(id).payload
	end)
	
	return {
		type = 'PROFILE_GET_LEADERBOARD',
		payload = list
	}
end

--[[
	@desc updates a user's leaderstats and dispatches PROFILE_UPDATE to the user
	@desc as well as a PLAYER_UPDATE to all users for the player list ui
	@param object player - player
]]--
profile.update = function(player, payload)
	local playerProfile = profileState:get(player.UserId)
	
	if not playerProfile then
		return
	end
	
	local res = Util.extend(payload and { updatedKeys = payload.updatedKeys } or {}, playerProfile)
	
	if res.updatedKeys then
		local playerUpdate = {
			id = player.UserId,
			stats = #res.updatedKeys == 0 and res.stats or {}
		}
		
		if res.updatedKeys['stats.coins'] then
			playerUpdate.stats.coins = res.stats.coins
		end
		
		if res.updatedKeys['stats.points'] then
			playerUpdate.stats.points = res.stats.points
		end
		
		-- Dispatch to all players so PlayerList updates player stats
		store:dispatch(true, {
			type = 'PLAYER_UPDATE',
			payload = playerUpdate,
		})
	end
	
	-- Dispatch to player so their local stats are updated
	store:dispatch(player, {
		type = 'PROFILE_UPDATE',
		payload = res,
	})
end

--[[
	@desc set a stat
	@param object player - player
	@param string payload - values to set
]]--
profile.set = function(player, payload)
	assert(
		player and (typeof(player) == 'Instance' and player:IsA('Player')),
		'profile.set - Missing player'
	)
	
	local updatedKeys = {}
	
	local success = pcall(function()
		profileState:set(function(state)
			-- Make sure the user has a profile
			if not state[player.UserId] then
				return state
			end
			
			for pathStr, value in pairs(payload) do
				if pathStr ~= 'noEvent' then
					local path = Util.split(pathStr, '.', true)
					local res = state[player.UserId]
					
					-- Dig through nest until the last nest level is reached
					for i, childName in ipairs(path) do
						local numberIndex = tonumber(childName)
						
						if numberIndex then
							childName = numberIndex
						elseif childName == '++' then
							childName = #res + 1
						end
						
						if res[childName] and i ~= #path then
							res = res[childName]
						elseif i == #path then
							-- Change the value if end of the path was reached
							res[childName] = value
							updatedKeys[pathStr] = true
						else
							res = nil -- Make table object instead of breaking the loop?
							break
						end
					end
					
					if not res then
						break
					end
				end
			end
			
			return state
		end)
	end)
	
	if not payload.noEvent and success then
		profile.update(player, {
			updatedKeys = updatedKeys
		})
	end
end

--[[
	@desc unset a stat
	@param object player - player
	@param string payload - values to set
]]--
profile.unset = function(player, payload)
	assert(
		player and (typeof(player) == 'Instance' and player:IsA('Player')),
		'profile.unset - Missing player'
	)
	
	local removedKeys = {}
	
	local success = pcall(function()
		profileState:set(function(state)
			-- Make sure the user has a profile
			if not state[player.UserId] then
				return state
			end
			
			for _, pathStr in pairs(payload) do
				local path = Util.split(pathStr, '.', true)
				local res = state[player.UserId]
				
				-- Dig through nest until the last nest level is reached
				for i, childName in ipairs(path) do
					local numberIndex = tonumber(childName)
					
					if numberIndex then
						childName = numberIndex
					end
					
					if res[childName] and i ~= #path then
						res = res[childName]
					elseif i == #path then
						-- Change the value if end of the path was reached
						res[childName] = nil
						removedKeys[pathStr] = true
					else
						res = nil
						break
					end
				end
				
				if not res then
					break
				end
			end
			
			return state
		end)
	end)
	
	if success then
		profile.update(player, {
			updatedKeys = removedKeys
		})
	end
	
	return {
		type = 'PROFILE_UNSET',
		payload = {
			removedKeys = removedKeys
		}
	}
end

--[[
	@desc returns all player not spectating
	@param boolean payload.getPlaying - return list for players playing a game (optional)
	@return profile list
]]--
profile.get_players = function()
	local res = {}
	
	for id, p in pairs(profileState:get(true)) do
		if not p.spectating then
			res[#res + 1] = Players:GetPlayerByUserId(id)
		end
	end
	
	return {
		type = 'PROFILE_GET_PLAYERS',
		payload = res
	}
end

--[[
	@desc inserts into a nested table within a profile
	@param object player - player
	@param string values - changes to make to user profiles
]]--
profile.insert_value = function(player, payload)
	assert(
		player and (typeof(player) == 'Instance' and player:IsA('Player')),
		'profile.add - Missing player'
	)
	
	local updatedKeys = {}
	
	local success, err = pcall(function()
		profileState:set(function(state)
			-- Make sure the user has a profile
			if not state[player.UserId] then
				return state
			end
			
			for pathStr, value in pairs(payload) do
				assert(typeof(value) == 'number', 'PROFILE_ADD - Value must be a number')
				
				local path = Util.split(pathStr, '.', true)
				local res = state[player.UserId]
				
				-- Dig through nest until the last nest level is reached
				for i, childName in ipairs(path) do
					if res[childName] and i ~= #path then
						res = res[childName]
					elseif i == #path then
						res[childName][#res[childName] + 1] = value
						updatedKeys[pathStr] = true
					else
						res = nil -- Make table object instead of breaking the loop?
						break
					end
				end
			end
			
			return state
		end)
	end)
	
	if success then
		profile.update(player, {
			updatedKeys = updatedKeys
		})
	end
	
	return {
		type = 'PROFILE_INSERT',
		err = not success and err or nil,
		payload = success and {
			insertedKeys = Util.map(updatedKeys, function(value, key)
				return payload[key]
			end)
		} or nil
	}
end

--[[
	@desc removes a value inside a nested table within a profile
	@param object player - player
	@param string values - changes to make to user profiles
]]--
profile.remove_value = function(player, payload)
	assert(
		player and (typeof(player) == 'Instance' and player:IsA('Player')),
		'profile.add - Missing player'
	)
	
	local updatedKeys = {}
	
	local success, err = pcall(function()
		profileState:set(function(state)
			-- Make sure the user has a profile
			if not state[player.UserId] then
				return state
			end
			
			for pathStr, value in pairs(payload) do
				assert(typeof(value) == 'number', 'PROFILE_ADD - Value must be a number')
				
				local path = Util.split(pathStr, '.', true)
				local res = state[player.UserId]
				
				-- Dig through nest until the last nest level is reached
				for i, childName in ipairs(path) do
					if res[childName] and i ~= #path then
						res = res[childName]
					elseif i == #path then
						local index = Util.indexOf(res[childName], value)
						
						if index > 0 then
							res[childName][index] = nil
							updatedKeys[pathStr] = true
						end
					else
						res = nil -- Make table object instead of breaking the loop?
						break
					end
				end
			end
			
			return state
		end)
	end)
	
	if success then
		profile.update(player, {
			updatedKeys = updatedKeys
		})
	end
	
	return {
		type = 'PROFILE_UNSET_VALUE',
		err = not success and err or nil,
		payload = success and {
			removedValues = Util.map(updatedKeys, function(value, key)
				return true, payload[key]
			end)
		} or nil
	}
end

--[[
	@desc add a stat
	@param object player - player
	@param string values - changes to make to user profiles
]]--
profile.add = function(player, payload)
	assert(
		player and (typeof(player) == 'Instance' and player:IsA('Player')),
		'profile.add - Missing player'
	)
	
	local updatedKeys = {}
	
	local success, err = pcall(function()
		profileState:set(function(state)
			-- Make sure the user has a profile
			if not state[player.UserId] then
				return state
			end
			
			for pathStr, value in pairs(payload) do
				assert(typeof(value) == 'number', 'PROFILE_ADD - Value must be a number')
				
				local path = Util.split(pathStr, '.', true)
				local res = state[player.UserId]
				
				-- Dig through nest until the last nest level is reached
				for i, childName in ipairs(path) do
					if res[childName] and i ~= #path then
						res = res[childName]
					elseif i == #path then
						-- Change the value if it was found, else set with new value
						-- Confirm the value is a number
						local newNumber = res[childName] ~= nil and tonumber(res[childName]) and (res[childName] + value) or value
						
						if (path[1] == 'stats' and newNumber >= 0) or path[1] ~= 'stats' then
							res[childName] = newNumber
							updatedKeys[pathStr] = true
						end
					else
						res = nil -- Make table object instead of breaking the loop?
						break
					end
				end
			end
			
			return state
		end)
	end)
	
	if success then
		profile.update(player, {
			updatedKeys = updatedKeys
		})
	end
	
	return {
		type = 'PROFILE_ADD',
		err = not success and err or nil,
		payload = success and {
			updatedKeys = updatedKeys
		} or nil
	}
end

--[[
	@desc sets a stat for all player profiles
	@param string values - changes to make to user profiles
	@param boolean playing - run if users are playing a game or not (optional)
]]--
profile.all_set = function(payload)
	assert(payload.values, 'PROFILE_ALL_SET - Must have values in payload')
	
	for _, player in pairs(profile.get_players()) do
		profile.set(player, payload.values)
	end
end

return profile