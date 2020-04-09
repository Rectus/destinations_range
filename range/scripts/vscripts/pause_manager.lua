
require("player_settings")
require("quick_inventory")
require("player_comfort")

CPauseManager = class(
	{
		players = nil;
		thinkEnt = nil;
		spawnItems = nil;
		playerConnectData = {};
		quickLocomotion = false;
		playerSettings = nil;
		mapCommands = nil;
		debugFramerate = false;
		itemSpawnMode = 2;
	},
	{
		DEFAULT_SETTINGS =
		{
			locomotion_mode = {value = 0, type = "int"};
			show_skis = true;
			quick_loco_slide_factor = 1.0;
			comfort_grid = {value = 0, type = "int"};
			comfort_vignette = false;
			custom_quick_inv = false;
			player_gravity = 1.0;
			player_physics_collisionmode = {value = 2, type = "int"};
			player_physics_physmode = {value = 2, type = "int"};
			player_physics_movemode = {value = 0, type = "int"};
			player_physics_forced_movement = true;
			quick_loco_slide_mode = 0;
			quick_loco_grab_mode = 1;
			quick_loco_turn_mode = 1;
			quick_loco_turn_increment = 45;
			quick_loco_turn_speed = 1.0;
			quick_loco_ring_vert = 0;
		};
	},
	nil
)


function CPauseManager.constructor(self, spawnItems, mapDefaultSettings, mapCommands)
	self.spawnItems = spawnItems
	self.mapCommands = mapCommands
	self.players = {}
	self.thinkEnt = SpawnEntityFromTableSynchronous("logic_script",
		{targetname = "pause_think_ent", vscripts = "player_pause_ent"})

	self.playerSettings = CPlayerSettingsManager(self.DEFAULT_SETTINGS, mapDefaultSettings)
	g_VRScript.playerSettings = self.playerSettings
end


function CPauseManager:Init()

	-- Make sure the phyiscs script can be found on outdated map scripts
	if g_VRScript.fallController
	then
		g_VRScript.playerPhysController = g_VRScript.fallController
	end

	self.thinkEnt:GetPrivateScriptScope().EnableThink(self)

	CustomGameEventManager:RegisterListener("pause_panel_command", function(_, data) self:OnCommand(data) end)
	CustomGameEventManager:RegisterListener("pause_panel_spawn_item", function(_, data) self:SpawnItem(data) end)
	CustomGameEventManager:RegisterListener("pause_panel_registered", function(_, data) self:OnPausePanelRegistered(data) end)
	ListenToGameEvent("player_disconnect", self.OnPlayerDisconnect, self)
end


function CPauseManager:DoPrecache(context)
	PrecacheModel("particles/ui/locomotion_ring.vpcf", context)
	PrecacheModel("models/editor/axis_helper.vmdl", context)
	PrecacheParticle("particles/ui/comfort_grid.vpcf", context)
	PrecacheParticle("particles/ui/comfort_vignette.vpcf", context)

	for i, item in ipairs(self.spawnItems) do

		if item.keyvals.vscripts
		then
			local scope = {}
			setmetatable(scope, {__index = getfenv(0)})
			pcall(DoIncludeScript, item.keyvals.vscripts, scope)
			if scope.Precache then pcall(scope.Precache, context) end
		end

		PrecacheModel(item.keyvals.model, context)

		if item.quickInvModel then
			PrecacheModel(item.quickInvModel, context)
		end

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


function CPauseManager:ListenPlayerConnect()
	ListenToGameEvent("player_connect", self.OnPlayerConnect, self)
	ListenToGameEvent("player_info", self.OnPlayerConnect, self)
end


function CPauseManager:EnableQuickLocomotion()
	self.quickLocomotion = true
end


-- Used to disable teleport and quick locomotion for tools
function CPauseManager:SetTeleportControlsAllowed(player, handID, allowed)
	if self.players[player]
	then
		if self.players[player].handTeleport[handID] ~= allowed
		then
			self.players[player].handTeleport[handID] = allowed
			local type = math.floor(g_VRScript.playerSettings:GetPlayerSetting(player, "locomotion_mode") or 0)
			player:AllowTeleportFromHand(handID, allowed and type == 0)
		end
	end
end


function CPauseManager:IsTeleportControlsAllowed(player, handID)
	if self.players[player]
	then
		return self.players[player].handTeleport[handID]
	end
	return true
end


function CPauseManager:IsPlayerAllowedToSpawnItems(player)
	if self.players[player]
	then
		if self.itemSpawnMode == 2 then
			return true
		elseif self.itemSpawnMode == 1 and self.players[player].isHost then
			return true
		else
			return false
		end
	end
	return false
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
		pausePanelRegisterTime = nil;
		showPausePanel = false;
		playerdata = data;
		quickLocomotion = nil;
		handTeleport = {};
		quickInv = nil;
		quickInvEnabled = false;
		comfort = nil;
		isHost = (player == Entities:GetLocalPlayer());
	}
	self.players[player].handTeleport[0] = true
	self.players[player].handTeleport[1] = true

	--self.playerSettings:AddPlayerSettings(playerID)
end


function CPauseManager:Think()
	local playerList = Entities:FindAllByClassname("player")

	for _, player in pairs(playerList)
	do
		if not self.players[player]
		then
			self:AddPlayer(player)
		end

		-- Timeout on registering pause panel in case the game event wwas sent before the client spawned the panel.
		if self.players[player].pausePanelRegisterTime ~= nil
			and self.players[player].pausePanelRegisterTime + 5 < Time() then

			Warning("Timeout on registering pause panel for player " .. player:GetUserID())
			self:RegisterPausePanel(player)
		end

		-- Update teleport settings in case something changed it
		local moveType = math.floor(g_VRScript.playerSettings:GetPlayerSetting(player, "locomotion_mode") or 0)
		player:AllowTeleportFromHand(0, self.players[player].handTeleport[0] and moveType == 0)
		player:AllowTeleportFromHand(1, self.players[player].handTeleport[1] and moveType == 0)


		if self.players[player].paused
		then

			if not (player:IsVRDashboardShowing() or player:IsContentBrowserShowing())
			then
				self.players[player].paused = false
				self:Unpause(player)
			elseif not self.players[player].showPausePanel and player:IsContentBrowserShowing() then
				self.players[player].showPausePanel = true
				self:Pause(player)
			end
		else

			if player:IsVRDashboardShowing() or player:IsContentBrowserShowing()
			then
				self.players[player].paused = true
				self.players[player].showPausePanel = player:IsContentBrowserShowing()
				self:Pause(player)
			end

		end

		if self.quickLocomotion
		then
			if not self.players[player].quickLocomotion
			then
				self.players[player].quickLocomotion = CQuickLocomotion(player, self.playerSettings:GetPlayerSetting(player, "locomotion_mode"), g_VRScript.playerPhysController, self.playerSettings)
			end

			self.players[player].quickLocomotion:Think(self.players[player].handTeleport, self.players[player].paused)
		end

		if self.players[player].quickInvEnabled
		then
			if not self.players[player].quickInv
			then
				self.players[player].quickInv = CQuickInventory(player, self.spawnItems)
			end
		end

		if self.players[player].quickInv
		then
			if self.itemSpawnMode < 1
			or (not self.players[player].isHost and self.itemSpawnMode < 2) then
				self.players[player].quickInv:Think(false)
			else
				self.players[player].quickInv:Think(self.players[player].quickInvEnabled)
			end


		end

		if self.players[player].comfort
		then
			self.players[player].comfort:Think()
		end
	end

	if self.debugFramerate and GetFrameCount() % 60 == 0
	then
		CustomGameEventManager:Send_ServerToAllClients("debug_framerate_val", {val = 1 / FrameTime()})
	end
end


function CPauseManager:Pause(player, spawnPausePanel)

	if not self.players[player]
	then
		self:AddPlayer(player)
	end

	if g_VRScript.playerPhysController
	then
		g_VRScript.playerPhysController:SetPaused(player, true)
	end

	if not self.players[player].showPausePanel then
		return
	end

	local baseAngles = QAngle(0, player:GetHMDAvatar():GetAngles().y, 0)
	local origin = player:GetHMDAvatar():GetCenter() +
			RotatePosition(Vector(0,0,0), baseAngles, Vector(41.5, -0.2, 12))
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

	local entList =
	{
		{
			classname = "info_target_instructor_hint",
			targetname = "pause_panel_origin",
			origin = origin,
			angles = angles
		},
		{
			classname = "point_clientui_world_panel",
			origin = origin,
			targetname = "pause_panel",
			dialog_layout_name = "file://{resources}/layout/custom_destination/pause_panel.xml",
			width = "45",
			height = "24",
			panel_dpi = "32",
			interact_distance = "128",
			horizontal_align = "1",
			vertical_align = "1",
			orientation = "0",
			angles = angles
		}
	}

	SpawnEntityListFromTableAsynchronous(entList, function(entList) self:SpawnPausePanelCallback(player, entList) end)

end


function CPauseManager:SpawnPausePanelCallback(player, entList)

	for _, ent in pairs(entList) do
		if ent:GetName() == "pause_panel" then
			self.players[player].pausePanel = ent
		else
			self.players[player].pausePanelTarget = ent
		end
	end

	self.players[player].pausePanel:SetParent(self.players[player].pausePanelTarget, "")
	self:RegisterPausePanel(player)
end


function CPauseManager:RegisterPausePanel(player)

	local hasPlayerPhys = g_VRScript.playerPhysController ~= nil and 1 or 0
	local hasQuickLoco = (hasPlayerPhys and self.quickLocomotion) and 1 or 0
	local host = self.players[player].isHost and 1 or 0

	CustomGameEventManager:Send_ServerToPlayer(player, "pause_panel_register",
		{
			id = player:GetUserID(),
			panel = self.players[player].pausePanel:GetEntityIndex(),
			playerPhys = hasPlayerPhys,
			quickLoco = hasQuickLoco, isHost = host
		}
	)

	self.players[player].pausePanelRegisterTime = Time()
end


function CPauseManager:OnPausePanelRegistered(data)

	local player = GetPlayerFromUserID(data.id)
	local panel = EntIndexToHScript(data.panel)

	if not player or not IsValidEntity(player) then
		Warning("Pause Manager: Pause panel registered to invalid player.")
		return
	end

	if not panel or not IsValidEntity(panel) then
		Warning("Pause Manager: Invalid pause panel entity registered for player " .. player:GetUserID())
		return
	end

	self.players[player].pausePanelRegisterTime = nil

	CustomGameEventManager:Send_ServerToPlayer(player, "pause_panel_add_map_commands",
		{id = player:GetUserID(), commands = self.mapCommands})

	self:PopulateItems(player, self.players[player].pausePanel)

	self.playerSettings:SyncAllSettingsToClient(player, player)
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

	if g_VRScript.playerPhysController then
		g_VRScript.playerPhysController:SetPaused(player, false)
	end

	if self.players[player].pausePanel ~= nil then
		CustomGameEventManager:Send_ServerToPlayer(player, "pause_panel_set_visible",
			{panel = self.players[player].pausePanel:GetEntityIndex(), visible = 0})
	end
end


function CPauseManager:IsPaused(player)

	if self.players[player] then
		return self.players[player].paused
	end
	return false
end


function CPauseManager:GetPlayerData(player)

	if self.players[player] then
		return self.players[player].playerdata
	end
	return nil
end

-- TODO reset panel if no player physics
function CPauseManager:TeleportPlayer(player, destination, onGround)
	local manager = g_VRScript.pauseManager --Hack for not having self here
	if not player then return end

	local localPausePanelOrigin = nil

	if manager.players[player] and manager.players[player].pausePanel then
		localPausePanelOrigin = manager.players[player].pausePanel:GetAbsOrigin() - player:GetHMDAnchor():GetAbsOrigin()
	end

	if g_VRScript.playerPhysController then
		g_VRScript.playerPhysController:SetVelocity(player, Vector(0,0,0))
		g_VRScript.playerPhysController:SetPlayerPosition(player, destination:GetAbsOrigin(), onGround, true)
	else
		local localPlayerOrigin = player:GetHMDAnchor():GetAbsOrigin() - player:GetAbsOrigin()
		player:GetHMDAnchor():SetAbsOrigin(destination:GetAbsOrigin()
			+ Vector(localPlayerOrigin.x, localPlayerOrigin.y, 0))
	end

	EmitSoundOnClient("Slope.UITeleport", player)

	manager:OnTeleported(player)
end


function CPauseManager:OnCommand(data)
	local player = GetPlayerFromUserID(data.id)
	local panel = EntIndexToHScript(data.panel)


	-- Commands without player settings.

	if data.cmd == "host_item_spawn_mode"
	then
		local player = GetPlayerFromUserID(data.id)
		if self.players[player].isHost then
			self.itemSpawnMode = math.floor(data.val)
			GameRules:SetPlayersCanSpawnAnyItems(self.itemSpawnMode > 1)
			GameRules:SetPlayersCanSpawnTools(self.itemSpawnMode > 1)
		end

	elseif data.cmd == "force_reload_pause_panel"
	then
		local player = GetPlayerFromUserID(data.id)
		self.players[player].pausePanel:Kill()
		self.players[player].pausePanel = nil
		self:Pause(player)

	elseif data.cmd == "teleport_start"
	then
		local player = GetPlayerFromUserID(data.id)
		local destination = Entities:FindByClassname(nil, "info_player_start")
		if destination then
			self:TeleportPlayer(player, destination, true)
		end
	elseif data.cmd == "debug_draw"
	then
		local enabled = math.floor(data.val) == 1
		if g_VRScript.playerPhysController
		then
			g_VRScript.playerPhysController:SetDebugDraw(enabled)
		end
		g_VRScript.debugEnabled = enabled
		CustomGameEventManager:Send_ServerToAllClients("sync_player_settings", {playerID = -1, debug_draw = math.floor(data.val)})

	elseif data.cmd == "debug_framerate"
	then
		local enabled = math.floor(data.val) == 1

		self.debugFramerate = enabled
		CustomGameEventManager:Send_ServerToAllClients("sync_player_settings", {playerID = -1, debug_framerate = math.floor(data.val)})

	elseif data.cmd == "player_phys_think_interval"
	then
		local value = math.floor(data.val)
		g_VRScript.playerPhysController:SetThinkInterval(value)
		CustomGameEventManager:Send_ServerToAllClients("sync_player_settings", {playerID = -1, player_phys_think_interval = value})

	elseif data.cmd == "player_phys_move_interval"
	then
		local value = math.floor(data.val)
		g_VRScript.playerPhysController:SetFrameInterval(value)
		CustomGameEventManager:Send_ServerToAllClients("sync_player_settings", {playerID = -1, player_phys_move_interval = value})

	elseif data.cmd == "player_phys_allow_direct_frame"
	then
		local value = math.floor(data.val) == 1
		g_VRScript.playerPhysController:SetAllowDirectEveryFrame(value)
		CustomGameEventManager:Send_ServerToAllClients("player_phys_allow_direct_frame",
			{playerID = -1, player_phys_allow_direct_frame = math.floor(data.val)})

	else
		if not player then return end

		-- Store any player settings received even we don't handle them directly
		local parsedVal = g_VRScript.playerSettings:SetPlayerSetting(player, data.cmd, data.val)

		if data.cmd == "locomotion_mode"
		then
			local allowed = parsedVal == 0

			player:AllowTeleportFromHand(0, self.players[player].handTeleport[0] and allowed)
			player:AllowTeleportFromHand(1, self.players[player].handTeleport[1] and allowed)

		elseif data.cmd == "custom_quick_inv"
		then
			local isEnabled = parsedVal

			player:SetInventoryEnabledForHand(0, not isEnabled)
			player:SetInventoryEnabledForHand(1, not isEnabled)
			self.players[player].quickInvEnabled = isEnabled

		elseif data.cmd == "custom_inv_add"
		then
			if not self.players[player].quickInv
			then
				self.players[player].quickInv = CQuickInventory(player, self.spawnItems)
			end

			self.players[player].quickInv:AddItem(parsedVal)

		elseif data.cmd == "custom_inv_remove"
		then
			if not self.players[player].quickInv
			then
				self.players[player].quickInv = CQuickInventory(player, self.spawnItems)
			end

			self.players[player].quickInv:RemoveItem(parsedVal)

		elseif data.cmd == "comfort_grid"
		then
			if not self.players[player].comfort
			then
				self.players[player].comfort = CPlayerComfort(player)
			end

			self.players[player].comfort:SetGrid(parsedVal)

		elseif data.cmd == "comfort_vignette"
		then
			if not self.players[player].comfort
			then
				self.players[player].comfort = CPlayerComfort(player)
			end

			self.players[player].comfort:SetVignette(parsedVal)
		end
	end

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

	if self.itemSpawnMode < 1
	or (not self.players[player].isHost and self.itemSpawnMode < 2) then
		print("Player " .. player:GetUserID() .. " attempted to spawn an item with spawning disabled.")
		EmitSoundOnClient("cache_finder_no_target", player)
		return
	end

	print("Spawning item ID: " .. data.itemID)

	local item = self.spawnItems[data.itemID]

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
