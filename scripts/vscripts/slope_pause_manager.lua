

CPauseManager = class(
	{
		players = nil;
		thinkEnt = nil;
		spawnItems = nil;
		playerConnectData = {}
	}, 	
	{
		THINK_INTERVAL = 0.022
	},
	nil
)

function CPauseManager.constructor(self, spawnItems)
	self.spawnItems = spawnItems
	self.players = {}
	self.thinkEnt = SpawnEntityFromTableSynchronous("logic_script", 
		{targetname = "pause_think_ent", vscripts = "player_pause_ent"})
end


function CPauseManager:Init()
	
	self.thinkEnt:GetPrivateScriptScope().EnableThink(self, self.THINK_INTERVAL)
	
	CustomGameEventManager:RegisterListener("pause_panel_teleport", self.TeleportPlayerTop)
	CustomGameEventManager:RegisterListener("pause_panel_spawn_item", self.SpawnItem)
	CustomGameEventManager:RegisterListener("pause_panel_teleport_slalom", self.TeleportPlayerSlalom)
	ListenToGameEvent("player_disconnect", self.OnPlayerDisconnect, self)
end


function CPauseManager:DoPrecache(context)
	for i, item in ipairs(self.spawnItems) do
	
		if item.keyvals.vscripts 
		then
			local scope = {} 
			setmetatable(scope, {__index = getfenv(0)})
			DoIncludeScript(item.keyvals.vscripts, scope)
			if scope.Precache then scope.Precache(context) end
		end
		
		PrecacheModel(item.keyvals.model, context)
		
		if item.modelPrecache then
			for j, model in ipairs(item.modelPrecache) do
	
				PrecacheModel(model, context)
			end
		end
		
		if item.particlePrecache then
			for j, particle in ipairs(item.particlePrecache) do
	
				PrecacheParticle(particle, context)
			end
		end
	end
end


function CPauseManager:Think()
	local playerList = Entities:FindAllByClassname("player")

	for _, player in pairs(playerList)
	do
		if not self.players[player] then
			self:AddPlayer(player)
		end
		
		if self.players[player].paused then
		
			if not (player:IsVRDashboardShowing() or player:IsContentBrowserShowing()) then
				self.players[player].paused = false
				self:Unpause(player)
			end
		else
				
			if player:IsVRDashboardShowing() or player:IsContentBrowserShowing() then
				self.players[player].paused = true
				self:Pause(player)
			end
		
		end 
	end
end


function CPauseManager:AddPlayer(player)

	local data = {}
	
	if self.playerConnectData[player:GetUserID()]
	then
		data = self.playerConnectData[player:GetUserID()]
	end

	self.players[player] =
	{
		paused = false;
		pausePanel = nil;
		playerdata = data
	}
end

function CPauseManager:ListenPlayerConnect()
	ListenToGameEvent("player_connect", self.OnPlayerConnect, self)
	ListenToGameEvent("player_info", self.OnPlayerConnect, self)
	
end

function CPauseManager:OnPlayerConnect(data)

	--[[ Data format
	{
		"name"		"string"	// player name		
		"index"		"byte"		// player slot (entity index-1)
		"userid"	"short"		// user ID on server (unique on server)
		"networkid" "string" // player network (i.e steam) id
		"address"	"string"	// ip:port
		"bot"		"bool"		// is a bot or not
		"xuid"		"uint64"	// steamid
	}]]

	if not self.playerConnectData[data.userid] then self.playerConnectData[data.userid] = {} end

	self.playerConnectData[data.userid] = vlua.tableadd(self.playerConnectData[data.userid], data)
	local player = GetPlayerFromUserID(data.userid)
	if player and self.players[player]
	then
		self.players[player].playerdata = self.playerConnectData[data.userid]
	end
end


-- Clean up player data on disconnect
function CPauseManager:OnPlayerDisconnect(data)

	--[[ Data format
	{
		"userid"	"short"		// user ID on server
		"reason"	"short"	// see networkdisconnect enum protobuf
		"name"		"string"	// player name
		"networkid"	"string"	// player network (i.e steam) id
		"PlayerID"	"short"
		"xuid"		"uint64"	// steamid
	}]]

	local player = GetPlayerFromUserID(data.userid)
	if player and self.players[player]
	then
	
		if self.players[player].pausePanel and IsValidEntity(self.players[player].pausePanel)
		then
			self.players[player].pausePanel:Kill()
		end
		
		if self.players[player].pausePanelTarget and IsValidEntity(self.players[player].pausePanelTarget)
		then
			self.players[player].pausePanelTarget:Kill()
		end
	
		self.players[player].playerdata = nil
		self.players[player] = nil
	end
	self.playerConnectData[data.userid] = nil
end

function CPauseManager:Pause(player)

	if not self.players[player] then
		self:AddPlayer(player)
	end
	
	local baseAngles = QAngle(0, player:GetHMDAvatar():GetAngles().y, 0)
	local origin = player:GetHMDAvatar():GetCenter() + 
			RotatePosition(Vector(0,0,0), baseAngles, Vector(40, 0, 12))
	local angles = RotateOrientation(baseAngles, QAngle(0, -90, 105))
	
	if self.players[player].pausePanel and IsValidEntity(self.players[player].pausePanel)
		and IsValidEntity(self.players[player].pausePanelTarget)
	then
		self.players[player].pausePanelTarget:SetAbsOrigin(origin)
		self.players[player].pausePanelTarget:SetAngles(angles.x, angles.y, angles.z)
		CustomGameEventManager:Send_ServerToPlayer(player, "pause_panel_set_visible", 
			{panel = self.players[player].pausePanel:GetEntityIndex(), visible = 1})
	else
		self:SpawnPausePanel(player, origin, angles)
	end
end


function CPauseManager:SpawnPausePanel(player, origin, angles)

	self.players[player].pausePanelTarget = SpawnEntityFromTableSynchronous("info_target_instructor_hint", 
		{origin = origin, angles = angles})

	local keyvals =
	{
		origin = origin,
		targetname = "pause_panel",
		dialog_layout_name = "file://{resources}/layout/custom_destination/pause_panel.xml",
		width = "44",
		height = "24",
		panel_dpi = "32",
		interact_distance = "128",
		horizontal_align = "1",
		vertical_align = "1",
		orientation = "0",
		angles = angles
	}
	self.players[player].pausePanel = SpawnEntityFromTableSynchronous("point_clientui_world_panel", keyvals)
	self.players[player].pausePanel:SetParent(self.players[player].pausePanelTarget, "")
	
	CustomGameEventManager:Send_ServerToPlayer(player, "pause_panel_register", 
		{id = player:GetUserID(), panel = self.players[player].pausePanel:GetEntityIndex()})
		
	self:PopulateItems(player, self.players[player].pausePanel)
end


function CPauseManager:PopulateItems(player, panel)
	for i, item in ipairs(self.spawnItems) do
	
		local data =
		{
			item = i,
			img = item.img,
			name = item.name,
			panel = panel:GetEntityIndex()
		}
	
		CustomGameEventManager:Send_ServerToPlayer(player, "pause_panel_add_item", data)
	end
end


function CPauseManager:Unpause(player)

	if not self.players[player] then
		self:AddPlayer(player)
	end
	
	CustomGameEventManager:Send_ServerToPlayer(player, "pause_panel_set_visible", 
		{panel = self.players[player].pausePanel:GetEntityIndex(), visible = 0})

end


function CPauseManager:IsPaused(playerEnt)

	if self.players[playerEnt] then
		return self.players[playerEnt].paused
	end
	return false
end

function CPauseManager:GetPlayerData(player)

	if self.players[player] then
		return self.players[player].playerdata
	end
	return nil
end


function CPauseManager:TeleportPlayerTop(data)
	local player = GetPlayerFromUserID(data.id)
	local destination = Entities:FindByName(nil, "teleport_dest_top")
	CPauseManager:TeleportPlayer(player, destination, true)	
end

function CPauseManager:TeleportPlayerSlalom(data)
	local player = GetPlayerFromUserID(data.id)
	local destination = Entities:FindByName(nil, "teleport_dest_slalom")
	CPauseManager:TeleportPlayer(player, destination, true)	
end


function CPauseManager:TeleportPlayer(player, destination, onGround)	
	local manager = g_VRScript.pauseManager --Hack for not having self here
	
	local localPausePanelOrigin = nil
	
	if manager.players[player] and manager.players[player].pausePanel then
		localPausePanelOrigin = manager.players[player].pausePanel:GetAbsOrigin() - player:GetHMDAnchor():GetAbsOrigin()
	end
		
	if g_VRScript.playerPhysController then
		g_VRScript.playerPhysController:SetPlayerPosition(player, destination:GetAbsOrigin(), onGround, true)
	else
		local localPlayerOrigin = player:GetHMDAnchor():GetAbsOrigin() - player:GetAbsOrigin()
		player:GetHMDAnchor():SetAbsOrigin(destination:GetAbsOrigin()
			+ Vector(localPlayerOrigin.x, localPlayerOrigin.y, 0))
	end
	
	EmitSoundOnClient("Slope.UITeleport", player)
	
	manager:OnTeleported(player)	
end


function CPauseManager:OnTeleported(player)

	local baseAngles = QAngle(0, player:GetHMDAvatar():GetAngles().y, 0)
	local origin = player:GetHMDAvatar():GetCenter() + 
			RotatePosition(Vector(0,0,0), baseAngles, Vector(40, 0, 12))
	local angles = RotateOrientation(baseAngles, QAngle(0, -90, 105))
	
	if self.players[player].pausePanel and IsValidEntity(self.players[player].pausePanel)
		and IsValidEntity(self.players[player].pausePanelTarget)
	then
		self.players[player].pausePanelTarget:SetAbsOrigin(origin)
		self.players[player].pausePanelTarget:SetAngles(angles.x, angles.y, angles.z)
	end
end


function CPauseManager:SpawnItem(data)
	local player = GetPlayerFromUserID(data.id)
	local panel = EntIndexToHScript(data.panel)
	local manager = g_VRScript.pauseManager --Hack for not having self here
	
	print("Spawning item ID: " .. data.itemID)
	
	local item = manager.spawnItems[data.itemID]
	
	if not IsValidEntity(player) or not IsValidEntity(panel) then
		return
	end
	
	local handID = CPauseManager:GetClosestHandID(player, panel:GetOrigin()) -- Assume the closest hand to the panel clicked the button
	
	local keyvals = vlua.clone(item.keyvals)

	keyvals.origin = player:GetHMDAvatar():GetVRHand(handID):GetOrigin()
	keyvals.angles = player:GetHMDAvatar():GetAngles()
		
	if item.isTool then
		local ent = SpawnEntityFromTableSynchronous("prop_destinations_tool", keyvals)
	
		player:EquipPropTool(ent, handID)
		
		EmitSoundOn("default_equip", player:GetHMDAvatar():GetVRHand(handID))
		
	else
		SpawnEntityFromTableSynchronous("prop_destinations_physics", keyvals)
	end
	
end



function CPauseManager:GetClosestHandID(player, origin)
	
	local hand0 = player:GetHMDAvatar():GetVRHand(0)
	local hand1 = player:GetHMDAvatar():GetVRHand(1)
	
	if (hand0:GetOrigin() - origin):Length() < (hand1:GetOrigin() - origin):Length() then
		return 0
	else
		return 1
	end
end


