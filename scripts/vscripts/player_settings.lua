
CPlayerSettingsManager = class(
	{
		settingsList = nil;
		defaultSettings = nil;
	}, 
	
	{
	},
	nil
)


function CPlayerSettingsManager.constructor(self, defaultSettings, defaultMapSettings)
	self.defaultSettings = {}
	self.settingsList = {}
	
	for key, val in pairs(defaultSettings)
	do
		local setVal, dataType = self:CheckValue(val)
		self.defaultSettings[key] = {val = setVal, type = dataType, DEFAULT = true} 
	end
	
	if defaultMapSettings
	then
		for key, val in pairs(defaultMapSettings)
		do
			local setVal, dataType = self:CheckValue(val)
			self.defaultSettings[key] = {val = setVal, type = dataType, DEFAULT = true, MAP_SETTING = true} 
		end
	end
end


function CPlayerSettingsManager:AddPlayerSettings(playerID, settings)
	local settings = settings or nil
	if not playerID then return end
	
	if not settings
	then
		self.settingsList[playerID] = vlua.clone(self.defaultSettings)
	else
		self.settingsList[playerID] = vlua.tableadd(vlua.clone(self.defaultSettings), settings)
	end
end


function CPlayerSettingsManager:SetPlayerSetting(playerID, setting, value, isMapSetting)

	isMapSetting = isMapSetting or false

	local datatype

	if self.settingsList[playerID] and self.settingsList[playerID][setting]
	then
		datatype = self.settingsList[playerID][setting].type
	end

	local value, datatype = self:CheckValue(value, datatype)
	
	if not datatype then return nil end

	if not self.settingsList[playerID]
	then
		self:AddPlayerSettings(playerID, {[setting] = {val = value, type = datatype}})
	else
		self.settingsList[playerID][setting] = {val = value, type = datatype, MAP_SETTING = isMapSetting}
	end
	
	return value
end


function CPlayerSettingsManager:RemovePlayerSetting(playerID, setting)
	if self.settingsList[playerID]
	then
		self.settingsList[playerID][setting] = vlua.clone(self.defaultSettings[setting]) 
	else
		self.settingsList[playerID][setting] = nil
	end
end


function CPlayerSettingsManager:GetPlayerSetting(playerID, setting)

	if not self.settingsList[playerID]
	then
		self:AddPlayerSettings(playerID)
	end
	
	if self.settingsList[playerID][setting]
	then
		return self.settingsList[playerID][setting].val

	end
	return nil
end


function CPlayerSettingsManager:SyncAllSettingsToClient(playerID, client)
	if not self.settingsList[playerID]
	then
		self:AddPlayerSettings(playerID)
	end
	
	local settingsData = {playerID = client:GetUserID()}
	
	for setting, data in pairs(self.settingsList[playerID])
	do
		settingsData[setting] = self:ConvertToSafeValue(data.val, data.type)
	end
	
	CustomGameEventManager:Send_ServerToPlayer(client, "sync_player_settings", settingsData)
end


function CPlayerSettingsManager:CheckValue(value, settingType)
	
	local dataType = type(value) 
	local checkType = settingType or dataType
	
	if checkType == "number" or checkType == "int" or checkType == "float"
	then
		if settingType == "int"
		then
			return math.floor(tonumber(value)), "int"
		else
			return tonumber(value), "float"
		end
		
	elseif checkType == "boolean"
	then
		if dataType == "number" 
		then 
			return math.floor(value) ~= 0, "boolean"
		end
		
		return value and true or false, "boolean"
	
	elseif checkType == "string"
	then
		return tostring(value), "string"
	
	elseif checkType == "table"
	then
		if value["value"]
		then
			return self:CheckValue(value["value"], value["type"])
		else
			local retval = {}
			
			for idx, subval in pairs(value)
			do
				retval[idx] = self:CheckValue(subval)
			end
			
			if #retval == 0 then return nil end
			
			return retval, "table"
		end
	else
		-- Ignore anything we don't know how to parse
		return nil
	end
end


function CPlayerSettingsManager:ConvertToSafeValue(value, settingType)
	if settingType == "boolean"
	then
		return value and 1 or 0
	else
		return value
	end
end

-- TODO - Implement serialization and save/load




