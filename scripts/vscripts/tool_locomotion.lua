--[[
	Locomotion tool script.
	
	Copyright (c) 2017 Rectus
	
	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:
	
	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.
	
	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
]]--

DoIncludeScript("component_grapple", thisEntity:GetPrivateScriptScope())

local MOVE_THINK_INTERVAL = 0.022
local GRAB_MAX_DISTANCE = 2
local GRAB_MOVE_INTERVAL = 0.022
local PAD_MOVE_INTERVAL = 0.022
local MOVE_CAP_FACTOR = 0.7
local MOVE_SPEED = 150
local MOVE_SPEED_RUN_FACTOR = 2
local AIR_CONTROL_FACTOR = 0.5


local GRAB_TRACE_INTERVAL = 0.02
local ROTATION_ANGLE_MAX_RATE = 10
local MIN_ROTATE_DISTANCE = 4

local FLY_HOVER_THRUST = 300
local THRUST_VERTICAL_SPEED = 400
local TRIGGER_IN_BOOST = 1.3
local GROUND_EFFECT_HEIGHT = 64
local GROUND_EFFECT_FACTOR = 0.5
local JETPACK_PAD_FACTOR = 3

local SCREEN_UPDATE_INTERVAL = 0.1

local UI_UP = 1
local UI_DOWN = 2
local UI_LEFT = 4
local UI_RIGHT = 8
local UI_ENTER = 16

local CONFIG_TYPE_PAD = 1
local CONFIG_TYPE_TRIGGER = 2
local CONFIG_TYPE_ROTATE = 3
local CONFIG_TYPE_TARGET = 4

local PAD_MODE_DISABLED = 0
local PAD_MODE_TELEPORT = 1
local PAD_MODE_TOUCH = 2
local PAD_MODE_PUSH = 3
local PAD_MODE_DUAL_SPEED = 4

local TRIGGER_MODE_DISABLED = 0
local TRIGGER_MODE_SURFACE_GRAB = 1
local TRIGGER_MODE_AIR_GRAB = 2
local TRIGGER_MODE_AIR_GRAB_GROUND = 3
local TRIGGER_MODE_GRAPPLE = 4
local TRIGGER_MODE_JETPACK = 5
local TRIGGER_MODE_FLY = 6

local ROTATE_MODE_DISABLED = 0
local ROTATE_MODE_ONE_HAND_YAW = 1
local ROTATE_MODE_TWO_HAND_YAW = 2

local TARGET_MODE_HAND = 1
local TARGET_MODE_HAND_NORMAL = 2
local TARGET_MODE_HEAD = 3

local padMode = PAD_MODE_DUAL_SPEED
local triggerMode = TRIGGER_MODE_GRAPPLE
local rotateMode = ROTATE_MODE_TWO_HAND_YAW
local targetMode = TARGET_MODE_HAND


local isCarried = false
local playerEnt = nil
local handEnt = nil
local otherHandObj = nil
local handID = 0
local handAttachment = nil
local isPaused = false

local grabEndpoint = nil
local playerMoved = false


local rumbleTime = 0
local rumbleFreq = 0
local rumbleInt = 0

local isGrabbing = false
local grabIn = false
local grabAngles = nil
local lastGrabAngles = {}
local grabAnchorAngles = nil
local grabEnt = nil
local entGrabbed = false
local startRotateVec = nil
local startAngles = nil
local padTouch = false
local padIn = false
local padVector = Vector(0,0,0)
local teleportPassthrough = false
local triggerValue = 0
local jetpackThrusting = false
local triggerIn = false

local originEnt = nil
local grapple = nil
local strap = nil
local handleScreen = nil
local configScreen = nil
local holoEmitterParticle = -1
local gravEmitterParticle = -1

local pickupTime = 0
local PICKUP_TRIGGER_DELAY = 0.5

local grappleKeyvals = 
{
	classname = "prop_dynamic";
	model = "models/tools/locomotion_tool_grapple.vmdl";
	--DefaultAnim = "idle"
}

local strapKeyvals = 
{
	classname = "prop_dynamic";
	model = "models/tools/locomotion_tool_strap.vmdl";
	--DefaultAnim = "idle";
	Collisions = "Not Solid"
}


local handleScreenKeyvals = {
	classname = "point_clientui_world_panel";
	dialog_layout_name = "file://{resources}/layout/custom_destination/locomotion_tool_handle_display.xml";
	panel_dpi = 50;
	width = 1.0;
	height = 1.7;
	ignore_input = 1;
	horizontal_align = "0";
	vertical_align = "0";
	orientation = "0";
}
	
local configScreenKeyvals = {
	classname = "point_clientui_world_panel";
	dialog_layout_name = "file://{resources}/layout/custom_destination/locomotion_tool_config_display.xml";
	panel_dpi = 75;
	width = 9;
	height = 12;
	ignore_input = 0;
	interact_distance = 32;
	horizontal_align = "1";
	vertical_align = "1";
	orientation = "0";
}

	
function Precache(context)
	PrecacheModel(grappleKeyvals.model, context)
	PrecacheModel(strapKeyvals.model, context)
	PrecacheParticle("particles/tools/grapple_wire.vpcf", context)
	PrecacheParticle("particles/tools/grapple_wire_retract.vpcf", context)
	PrecacheParticle("particles/item_laser_pointer.vpcf", context)
end


function Activate()
	thisEntity:SetSequence("idle")

	grapple = SpawnEntityFromTableSynchronous(grappleKeyvals.classname, grappleKeyvals)
	grapple:SetParent(thisEntity, "")
	grapple:SetLocalOrigin(Vector(0,0,0))
	grapple:SetLocalAngles(0,0,0)
	
	strap = SpawnEntityFromTableSynchronous(strapKeyvals.classname, strapKeyvals)
	strap:SetParent(thisEntity, "")
	strap:SetLocalOrigin(Vector(0,0,0))
	strap:SetLocalAngles(0,0,0)
	
	CustomGameEventManager:RegisterListener("locomotion_tool_config", ApplyConfig)
end


function SetEquipped(self, pHand, nHandID, pHandAttachment, pPlayer)
	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	isCarried = true
	otherHandObj = nil
	pickupTime = Time()
	
	if not originEnt
	then
		
		-- Parenting an entity to the hand gives a less janky position than using the tool or attachment. 
		originEnt = SpawnEntityFromTableSynchronous("info_target", {origin = thisEntity:GetOrigin()})
		originEnt:SetParent(handEnt, "")
	end
	
	if not IsValidEntity(grapple) then
		grapple = SpawnEntityFromTableSynchronous(grappleKeyvals.classname, grappleKeyvals)
	end
	grapple:SetParent(handAttachment, "")
	grapple:SetLocalOrigin(Vector(0,0,0))
	grapple:SetLocalAngles(0,0,0)
	
	if not IsValidEntity(strap) then
		strap = SpawnEntityFromTableSynchronous(strapKeyvals.classname, strapKeyvals)
	end
	strap:SetParent(handAttachment, "")
	strap:SetLocalOrigin(Vector(0,0,0))
	strap:SetLocalAngles(0,0,0)
	
	if not handleScreen or not IsValidEntity(handleScreen)
	then
		handleScreen = SpawnEntityFromTableSynchronous(handleScreenKeyvals.classname, handleScreenKeyvals)
		handleScreen:SetParent(handAttachment, "handle_screen")
		handleScreen:SetLocalOrigin(Vector(0,0,0))
		handleScreen:SetLocalAngles(0, 0, 0)
	end
	
	if triggerMode == TRIGGER_MODE_GRAPPLE then
		EnableGrapple(grapple, playerEnt, thisEntity, handAttachment, g_VRScript.playerPhysController)
	end
	
	playerEnt:AllowTeleportFromHand(handID, teleportPassthrough)
	
	local paintColor = thisEntity:GetRenderColor()
	handAttachment:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	handAttachment:SetSequence("idle")
	
	if (triggerMode == TRIGGER_MODE_FLY or triggerMode == TRIGGER_MODE_JETPACK) then
		EnableGravEffects()
	end
	
	EmitSoundOn("cache_finder_equip", handAttachment)
	
	thisEntity:SetThink(UpdateScreen, "handle_screen")
	thisEntity:SetThink(MoveThink, "move_think")
	
	return true
end


function SetUnequipped()
	if grabIn
	then
		ReleaseHold()
		grabIn = false
	end
	
	playerEnt:AllowTeleportFromHand(handID, true)
	
	if triggerMode == TRIGGER_MODE_GRAPPLE then
		DisableGrapple()
	end
	
	if handleScreen and IsValidEntity(handleScreen) then	
		handleScreen:Kill()
	end
	handleScreen = nil
	
	if configScreen and IsValidEntity(configScreen) then
		configScreen:Kill()		
	end
	configScreen = nil
	
	if IsValidEntity(strap) then
		strap:SetParent(thisEntity, "")
		strap:SetLocalOrigin(Vector(0,0,0))
		strap:SetLocalAngles(0,0,0)
	end
	
	if IsValidEntity(grapple) then
		grapple:SetParent(thisEntity, "")
		grapple:SetLocalOrigin(Vector(0,0,0))
		grapple:SetLocalAngles(0,0,0)	
	end
	
	if jetpackThrusting then
		StopSoundOn("drone_speed_dec", grapple)
		StopSoundOn("drone_speed_acc", grapple)
		jetpackThrusting = false
	end
	
	g_VRScript.playerPhysController:RemoveDragConstraint(playerEnt, thisEntity)
	DisableGravEffects()
	
	
	playerEnt = nil
	handEnt = nil
	isCarried = false
	
	local paintColor = handAttachment:GetRenderColor()
	thisEntity:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	return true
end


function UpdateScreen()

	if not isCarried then
		return nil
	end
	
	if playerEnt:IsContentBrowserShowing() then
		
		if not configScreen or not IsValidEntity(configScreen) then
			configScreen = SpawnEntityFromTableSynchronous(configScreenKeyvals.classname, configScreenKeyvals)
			configScreen:SetParent(handAttachment, "holo_screen")
			configScreen:SetLocalOrigin(Vector(0,0,0))
			configScreen:SetLocalAngles(0, 0, 0)
			
			CustomGameEventManager:Send_ServerToAllClients("locomotion_tool_sync_selection", 
				{
					id = configScreen:GetEntityIndex(), 
					trigger = triggerMode, 
					pad = padMode, 
					rotate = rotateMode, 
					target = targetMode
				})
		end
		
		if holoEmitterParticle < 0 then
			holoEmitterParticle = ParticleManager:CreateParticle("particles/tools/locomotion_tool_holoemitter.vpcf", 
				PATTACH_POINT_FOLLOW, handAttachment)
			ParticleManager:SetParticleControlEnt(holoEmitterParticle, 0, handAttachment, 
				PATTACH_POINT_FOLLOW, "holo_screen_emit", Vector(0,0,0), true)
		end
		
		
		if not isPaused then
			CustomGameEventManager:Send_ServerToAllClients("locomotion_tool_set_visible", 
				{id = configScreen:GetEntityIndex(); visible = 1})
		end
		
		isPaused = true
	else
		if isPaused then
			if configScreen and IsValidEntity(configScreen) then
				CustomGameEventManager:Send_ServerToAllClients("locomotion_tool_set_visible", 
					{id = configScreen:GetEntityIndex(); visible = 0})
			end
		end
		
		if holoEmitterParticle >= 0 then
			ParticleManager:DestroyParticle(holoEmitterParticle, true)
			holoEmitterParticle = -1
		end
		
		isPaused = false
	end

	if not handleScreen or not IsValidEntity(handleScreen) then
		return SCREEN_UPDATE_INTERVAL
	end


	local time = LocalTime()
	--local playerSpeed = math.floor(g_VRScript.playerPhysController:GetVelocity(playerEnt):Length())
	local playerSpeed = handEnt:GetVelocity():Length() * 0.0254
	local playerAlt = g_VRScript.playerPhysController:GetPlayerHeight(playerEnt) * 0.0254

	CustomGameEventManager:Send_ServerToAllClients("locomotion_tool_update_display", 
		{
			id = handleScreen:GetEntityIndex(); 
			hours = time.Hours;
			minutes = time.Minutes;
			speed = playerSpeed;
			altitude = playerAlt
		})
		
	return SCREEN_UPDATE_INTERVAL
end


function OnHandleInput(input)
	if not playerEnt
	then 
		return
	end

	-- Even uglier ternary operator
	local IN_TRIGGER = (handID == 0 and IN_USE_HAND0 or IN_USE_HAND1)
	local IN_GRIP = (handID == 0 and IN_GRIP_HAND0 or IN_GRIP_HAND1)
	local IN_PAD = (handID == 0 and IN_PAD_HAND0 or IN_PAD_HAND1)
	local IN_PAD_TOUCH = (handID == 0 and IN_PAD_TOUCH_HAND0 or IN_PAD_TOUCH_HAND1)

	
	if input.buttonsPressed:IsBitSet(IN_TRIGGER)
	then
		input.buttonsPressed:ClearBit(IN_TRIGGER)
		if Time() > pickupTime + PICKUP_TRIGGER_DELAY
		then
			OnTriggerPressed()
			triggerIn = true
		end
	end
	
	if input.buttonsReleased:IsBitSet(IN_TRIGGER) 
	then
		input.buttonsReleased:ClearBit(IN_TRIGGER)
		OnTriggerUnpressed()
		triggerIn = false
	end
	
	if input.buttonsPressed:IsBitSet(IN_GRIP)
	then
		input.buttonsPressed:ClearBit(IN_GRIP)
	end
	
	if input.buttonsDown:IsBitSet(IN_GRIP)
	then
		input.buttonsDown:ClearBit(IN_GRIP)
	end
	
	
	if input.buttonsReleased:IsBitSet(IN_GRIP)
	then
		input.buttonsReleased:ClearBit(IN_GRIP)
		thisEntity:ForceDropTool();
	end

	if input.buttonsPressed:IsBitSet(IN_PAD)
	then
		playerEnt:AllowTeleportFromHand(handID, teleportPassthrough and not playerEnt:IsContentBrowserShowing())
	
		if not teleportPassthrough and not playerEnt:IsContentBrowserShowing() then
			input.buttonsPressed:ClearBit(IN_PAD)
		end
		padIn = true
		SetGrappleRappel(true)
		
		if playerEnt:IsContentBrowserShowing() then
			local uiMask = 0
			local uiDir = false
			
			if input.trackpadX > 0.4 then
				uiMask = uiMask + UI_RIGHT
				uiDir = true
			elseif input.trackpadX < -0.4 then
				uiMask = uiMask + UI_LEFT
				uiDir = true
			end
			
			if input.trackpadY > 0.4 then
				uiMask = uiMask + UI_UP
				uiDir = true
			elseif input.trackpadY < -0.4 then
				uiMask = uiMask + UI_DOWN
				uiDir = true
			end
			
			if uiDir then
				StartSoundEvent("LocomotionTool_UI_Cursor", handAttachment)
			else
				StartSoundEvent("LocomotionTool_UI_Select", handAttachment)
				uiMask = UI_ENTER
			end
			
			if uiMask > 0 then
				CustomGameEventManager:Send_ServerToAllClients("locomotion_tool_ui_command", 
					{id = configScreen:GetEntityIndex(); command = uiMask})
			end
		end
	end
	
	if input.buttonsReleased:IsBitSet(IN_PAD) 
	then
		if not teleportPassthrough and not playerEnt:IsContentBrowserShowing() then
			input.buttonsReleased:ClearBit(IN_PAD)
		end
		padIn = false
		SetGrappleRappel(false)
	end
	
	if input.buttonsPressed:IsBitSet(IN_PAD_TOUCH)
	then
		if not teleportPassthrough and not playerEnt:IsContentBrowserShowing() then
			input.buttonsPressed:ClearBit(IN_PAD_TOUCH)
		end
		padTouch = true
		
	end
	
	if input.buttonsReleased:IsBitSet(IN_PAD_TOUCH) 
	then
		if not teleportPassthrough and not playerEnt:IsContentBrowserShowing() then
			input.buttonsReleased:ClearBit(IN_PAD_TOUCH)
		end
		padTouch = false
	end

	-- Needed to disable teleports
	if input.buttonsDown:IsBitSet(IN_PAD) 
	then
		if not teleportPassthrough then
			input.buttonsDown:ClearBit(IN_PAD)
		end
	end	
	if input.buttonsDown:IsBitSet(IN_PAD_TOUCH) 
	then
		if not teleportPassthrough then
			input.buttonsDown:ClearBit(IN_PAD_TOUCH)
		end
	end
	
	if padTouch
	then	
		padVector = Vector(input.trackpadY, -input.trackpadX, 0)
	end

	triggerValue = input.triggerValue

	return input;
end


function OnTriggerPressed()

	grabAngles = nil

	if triggerMode == TRIGGER_MODE_SURFACE_GRAB then
	
		grabIn = true
		
		if TraceGrab()
		then
			isGrabbing = true
			g_VRScript.playerPhysController:AddConstraint(playerEnt, thisEntity, true)
			thisEntity:SetThink(GrabMoveFrame, "grab_move")
		end
		
	elseif triggerMode == TRIGGER_MODE_AIR_GRAB or triggerMode == TRIGGER_MODE_AIR_GRAB_GROUND then
		
		
		thisEntity:SetThink(GrabMoveFrame, "grab_move")
		grabIn = true
		isGrabbing = TraceGrab()
		
		g_VRScript.playerPhysController:AddConstraint(playerEnt, thisEntity, isGrabbing)

	elseif triggerMode == TRIGGER_MODE_GRAPPLE then
		LaunchGrapple()
		
	elseif triggerMode == TRIGGER_MODE_FLY or triggerMode == TRIGGER_MODE_JETPACK then
		thisEntity:SetThink(FlyThrust, "jetpack")
		
	end
end


function OnTriggerUnpressed()

	if triggerMode == TRIGGER_MODE_SURFACE_GRAB 
		or triggerMode == TRIGGER_MODE_AIR_GRAB or triggerMode == TRIGGER_MODE_AIR_GRAB_GROUND then
		
		grapple:SetPoseParameter("claw_open", 1)
		
		if grabIn
		then
			ReleaseHold()
			grabIn = false
		end
		
	elseif triggerMode == TRIGGER_MODE_GRAPPLE then
		ReleaseGrappleButton()
	end
end


function ReleaseHold()
	startRotateVec = nil
	startAngles = nil
	RumbleController(2, 0.1, 100)
	grapple:SetSequence("idle")
	g_VRScript.playerPhysController:RemoveConstraint(playerEnt, thisEntity)
	g_VRScript.playerPhysController:SetVelocity(playerEnt, -GetPhysVelocity(thisEntity))
	
	if grabEnt and IsValidEntity(grabEnt) then
		grabEnt:Kill()
	end
	grabEnt = nil
end


function ApplyConfig(eventSourceIndex, data)
	if data.panel and EntIndexToHScript(data.panel) == configScreen then
		
		if data.conf == CONFIG_TYPE_PAD then
			padMode = data.val	
			teleportPassthrough = (padMode == PAD_MODE_TELEPORT)
		end
		
		if data.conf == CONFIG_TYPE_TRIGGER then
		
			if triggerMode == TRIGGER_MODE_GRAPPLE and data.val ~= TRIGGER_MODE_GRAPPLE then
				DisableGrapple()
			end
			
			if triggerMode ~= TRIGGER_MODE_GRAPPLE and data.val == TRIGGER_MODE_GRAPPLE then
				EnableGrapple(grapple, playerEnt, thisEntity, handAttachment, g_VRScript.playerPhysController)
			end
			
			if (triggerMode ~= TRIGGER_MODE_FLY and triggerMode ~= TRIGGER_MODE_JETPACK) and
				(data.val == TRIGGER_MODE_FLY or data.val == TRIGGER_MODE_JETPACK) then
				EnableGravEffects()
				
			elseif (data.val~= TRIGGER_MODE_FLY and data.val ~= TRIGGER_MODE_JETPACK) then
				DisableGravEffects()
			end
		
			triggerMode = data.val
		end
		
		if data.conf == CONFIG_TYPE_ROTATE then
			rotateMode = data.val
		end
		
		if data.conf == CONFIG_TYPE_TARGET then
			targetMode = data.val
		end
	end
end


function MoveThink()
	if not isCarried then
		return nil
	end
	
	if padMode == PAD_MODE_DUAL_SPEED or padMode == PAD_MODE_TOUCH or padMode == PAD_MODE_PUSH then
		PadMove()
	end


	return MOVE_THINK_INTERVAL
end


function PadMove()

	if not padTouch or grabIn or not g_VRScript.playerPhysController:IsActive(playerEnt, thisEntity)
		or (padMode == PAD_MODE_PUSH and not padIn) then

		return
	end
	local forwardAng = nil
	
	if targetMode == TARGET_MODE_HAND or targetMode == TARGET_MODE_HAND_NORMAL then
		local idx = handAttachment:ScriptLookupAttachment("pad_move")
		local moveAngVec = handAttachment:GetAttachmentAngles(idx)
		forwardAng = QAngle(moveAngVec.x, moveAngVec.y, moveAngVec.z)
	else
		forwardAng = playerEnt:GetHMDAvatar():GetAngles()
	end
	local moveVector = nil
	
	if targetMode == TARGET_MODE_HAND_NORMAL then
		local forwardVec = forwardAng:Forward()
		local normVec = Vector(forwardVec.x, forwardVec.y, 0):Normalized()
		moveVector = RotatePosition(Vector(0,0,0), VectorToAngles(normVec), padVector)
	else
		moveVector = RotatePosition(Vector(0,0,0), forwardAng, padVector)
	end
	
	--DebugDrawLine(handAttachment:GetOrigin(), handAttachment:GetOrigin() + padVector * 10, 255, 255, 0, true, 0.02)
	--DebugDrawLine(handAttachment:GetOrigin(), handAttachment:GetOrigin() + moveVector * 10, 0, 0, 255, true, 0.02)
	
	moveVector = Vector(moveVector.x, moveVector.y, 0)
	
	
	
	-- Cap the movement speed along the outer ring
	if moveVector:Length() > MOVE_CAP_FACTOR
	then
		moveVector = moveVector:Normalized() * MOVE_CAP_FACTOR
	end
	
	local speed = MOVE_SPEED * PAD_MOVE_INTERVAL
	
	if padMode ~= PAD_MODE_DUAL_SPEED or padIn then
		speed = speed * MOVE_SPEED_RUN_FACTOR
	end
	
	if g_VRScript.playerPhysController:IsPlayerOnGround(playerEnt)
	then
		g_VRScript.playerPhysController:MovePlayer(playerEnt, moveVector * speed, true, true)
	else
		local multiplier = 1
		
		if triggerMode == TRIGGER_MODE_JETPACK then 
			multiplier = JETPACK_PAD_FACTOR
		end
	
		g_VRScript.playerPhysController:AddVelocity(playerEnt, moveVector * speed * multiplier * AIR_CONTROL_FACTOR, false)
	end
end


function GetPlayerEnt()
	return playerEnt
end

function GetOriginEnt()
	return originEnt
end


function GetGrabStatus(self)
	return grabIn
end

function FindTool(handID)
	local tool = Entities:FindByClassname(nil, "prop_destinations_tool")
	while tool 
	do
		if tool ~= thisEntity
		then
			local scope = tool:GetPrivateScriptScope()
			if scope.GetPlayerEnt and scope.GetPlayerEnt() == playerEnt
			then
				return tool
			end		
		end
		tool = Entities:FindByClassname(tool, "prop_destinations_tool")
	end
	
	return nil	 
end


function TraceGrab()

	local idx = handAttachment:ScriptLookupAttachment("grapple_spot")
	local grabPos = handAttachment:GetAttachmentOrigin(idx)
	local grabAngVec = handAttachment:GetAttachmentAngles(idx)
	local grabAng = QAngle(grabAngVec.x, grabAngVec.y, grabAngVec.z)

	grabEndpoint = grabPos

	local traceTable =
	{
		startpos = grabPos;
		endpos = grabPos + grabAng:Forward() * 2;
		ignore = playerEnt;
		--mask = 33636363; -- Hopefully TRACE_MASK_PLAYER_SOLID	
		min = Vector(-1.5, -1.5, -1.5);
		max = Vector(1.5, 1.5, 1.5)
	}

	TraceHull(traceTable)
	
	--DebugDrawBox(traceTable.startpos, traceTable.min, traceTable.max, 0, 255, 0, 0, 2)
	
	if traceTable.hit 
	then
		--DebugDrawBox(traceTable.pos, traceTable.min, traceTable.max, 0, 0, 255, 0, 2)		
		
		if traceTable.enthit and traceTable.enthit:GetEntityIndex() > 0
		then
			entGrabbed = true
			
			if not grabEnt or not IsValidEntity(grabEnt)
			then
				grabEnt = SpawnEntityFromTableSynchronous("info_target", {origin = traceTable.pos})
			end
			grabEnt:SetParent(traceTable.enthit, "")
			grabEnt:SetAbsOrigin(traceTable.pos)
		else
			entGrabbed = false
		end
		
		
		if entGrabbed then
			local impactParticle = ParticleManager:CreateParticle("particles/tools/grapple_grab_ent.vpcf", 
				PATTACH_CUSTOMORIGIN, thisEntity)
			ParticleManager:SetParticleControl(impactParticle, 0, grabPos + grabAng:Forward() * 2)
			ParticleManager:SetParticleControlForward(impactParticle, 0, -grabAng:Forward())
		else
			local impactParticle = ParticleManager:CreateParticle("particles/tools/grapple_grab_world.vpcf", 
				PATTACH_CUSTOMORIGIN, thisEntity)
			ParticleManager:SetParticleControl(impactParticle, 0, grabPos + grabAng:Forward() * 2)
			ParticleManager:SetParticleControlForward(impactParticle, 0, -grabAng:Forward())
		end
		
		grapple:SetPoseParameter("claw_open", 0.3)
		EmitSoundOn("Grapple_Grab", grapple)
		RumbleController(2, 0.2, 100)
		return true
	else
		entGrabbed = false
	end
	grapple:SetPoseParameter("claw_open", 0)
	EmitSoundOn("Grapple_Miss", grapple)
	RumbleController(2, 0.1, 200)
	return false
end


function GrabMoveFrame()

	if not grabIn
	then
		return nil
	end
	
	if not g_VRScript.playerPhysController:IsActive(playerEnt, thisEntity)
	then
		return GRAB_MOVE_INTERVAL
	end
	
	local idx = handAttachment:ScriptLookupAttachment("grapple_spot")
	local pullPos = handAttachment:GetAttachmentOrigin(idx)
	
	if entGrabbed
	then
		if not IsValidEntity(grabEnt) or IsParentedTo(grabEnt, playerEnt)
		then
			ReleaseHold()
			grabIn = false
			return
		end
	
		grabEndpoint = grabEnt:GetAbsOrigin()
	end

	local pullVector = (grabEndpoint - pullPos)
	
	local rotMoveVec = GrabRotateFrame()
	

	if triggerMode == TRIGGER_MODE_AIR_GRAB_GROUND and not g_VRScript.playerPhysController:IsPlayerOnGround(playerEnt)
	then
		local vec = rotMoveVec + pullVector 
		g_VRScript.playerPhysController:AddVelocity(playerEnt, Vector(vec.x, vec.y, 0))
	else
		local grounded = (triggerMode == TRIGGER_MODE_AIR_GRAB_GROUND and not isGrabbing)
		g_VRScript.playerPhysController:MovePlayer(playerEnt, rotMoveVec + pullVector, false, grounded)
	end
	
		
	return GRAB_MOVE_INTERVAL
end


function GrabRotateFrame()
	if not grabIn or rotateMode == ROTATE_MODE_DISABLED
	then
		
		return Vector(0,0,0)
	end
	
	if not g_VRScript.playerPhysController:IsActive(playerEnt, thisEntity) or playerEnt:IsContentBrowserShowing()
	then
		return Vector(0,0,0)
	end
	
	if rotateMode == ROTATE_MODE_ONE_HAND_YAW then
		
		if not isGrabbing and triggerMode == TRIGGER_MODE_SURFACE_GRAB then return Vector(0,0,0) end
	
		local anchorAng = QAngle(0, playerEnt:GetHMDAnchor():GetAngles().y, 0)
		
		local idx = handAttachment:ScriptLookupAttachment("grapple_spot")
		local handAngVec = handAttachment:GetAttachmentAngles(idx)
		local handAngFwd = QAngle(handAngVec.x, handAngVec.y, handAngVec.z):Forward()
		local handAng = VectorToAngles(handAngFwd:Cross(Vector(0,0,1)):Cross(Vector(0,0,1)))
		
		if not grabAngles then
			grabAngles = handAng	
		else
			local rotDelta = RotationDelta(handAng, grabAngles)
			
			if abs(rotDelta.y) > 0.5
			then
				handEnt:FireHapticPulse(0)
			end
			

			if abs(rotDelta.y) < 0.2 then 
				rotDelta = QAngle(0,0,0)
			else
				rotDelta = QAngle(0, rotDelta.y  * 0.5, 0)
			end
			
			local endRot = RotateOrientation(anchorAng, rotDelta)
			playerEnt:GetHMDAnchor():SetAngles(endRot.x, endRot.y, endRot.z)
			
			local idx = handAttachment:ScriptLookupAttachment("grapple_spot")
			
			local moveVector = RotatePosition(handAttachment:GetAttachmentOrigin(idx), 
				QAngle(0, rotDelta.y, 0), playerEnt:GetHMDAnchor():GetOrigin())
			return moveVector - playerEnt:GetHMDAnchor():GetOrigin()
		end
	
	
	else --Two handed
	
		if not otherHandObj or otherHandObj:IsNull() or otherHandObj:GetPrivateScriptScope():GetPlayerEnt() ~= playerEnt
		then
			otherHandObj = FindTool((handID == 0 and 1 or 0))
		end
		
		if otherHandObj ~= nil
		then
			local otherHandScope = otherHandObj:GetPrivateScriptScope()
		
			if otherHandScope ~= nil and otherHandScope.GetGrabStatus and otherHandScope:GetGrabStatus()
			then
				local origin2D = Vector(originEnt:GetOrigin().x, originEnt:GetOrigin().y, 0)
				local otherOrigin2D = Vector(otherHandScope:GetOriginEnt():GetOrigin().x, 
					otherHandScope:GetOriginEnt():GetOrigin().y, 0)
				--DebugDrawLine(originEnt:GetOrigin(), otherHandScope:GetOriginEnt():GetOrigin(), 255, 0, 0, false, 0.02)
				
				local rotateVector = otherOrigin2D - origin2D 
				
				if rotateVector:Length() > MIN_ROTATE_DISTANCE
				then
					if not startRotateVec
					then
						startRotateVec = rotateVector
						startAngles = playerEnt:GetHMDAnchor():GetAngles()
					end
						
					local rotateOrigin = origin2D + rotateVector * 0.5
		
					local rotAng = NormalizeAngle((VectorToAngles(startRotateVec).y - VectorToAngles(rotateVector).y)) / 5
					
					if abs(rotAng) < 0.1
					then
						rotAng = 0
					elseif rotAng > ROTATION_ANGLE_MAX_RATE
					then
						rotAng = ROTATION_ANGLE_MAX_RATE
					elseif rotAng < -ROTATION_ANGLE_MAX_RATE
					then
						rotAng = -ROTATION_ANGLE_MAX_RATE
					end
					
					if abs(rotAng) > 0.5
					then
						handEnt:FireHapticPulse(0)
						playerEnt:GetHMDAvatar():GetVRHand((handID == 0 and 1 or 0)):FireHapticPulse(0)
					end
					
					local rotation = QAngle(0, rotAng, 0)
		
					local playerAng = playerEnt:GetHMDAnchor():GetAngles()
					local endRot = RotateOrientation(playerAng, rotation)
					playerEnt:GetHMDAnchor():SetAngles(endRot.x, endRot.y, endRot.z)
					local moveVector = RotatePosition(rotateOrigin, rotation, playerEnt:GetHMDAnchor():GetOrigin())
					--playerEnt:GetHMDAnchor():SetOrigin(moveVector)
					--g_VRScript.playerPhysController:MovePlayer(playerEnt, moveVector - playerEnt:GetHMDAnchor():GetOrigin())
					return moveVector - playerEnt:GetHMDAnchor():GetOrigin()
				end
				
			else
				startRotateVec = nil
			end
		end
	end
	
	return Vector(0,0,0)
end


function EnableGravEffects()
	grapple:SetSequence("emit")	
	
	EmitSoundOn("LocomotionTool_GravityEmitterLoop", grapple)
	gravEmitterParticle = ParticleManager:CreateParticle("particles/tools/locomotion_tool_gravemitter.vpcf", 
		PATTACH_POINT_FOLLOW, handAttachment)
	ParticleManager:SetParticleControlEnt(gravEmitterParticle, 0, grapple, 
		PATTACH_POINT_FOLLOW, "energy_ball", Vector(0,0,0), true)
	ParticleManager:SetParticleControlEnt(gravEmitterParticle, 1, grapple, 
		PATTACH_POINT_FOLLOW, "claw1", Vector(0,0,0), true)
	ParticleManager:SetParticleControlEnt(gravEmitterParticle, 2, grapple, 
		PATTACH_POINT_FOLLOW, "claw2", Vector(0,0,0), true)
	ParticleManager:SetParticleControlEnt(gravEmitterParticle, 3, grapple, 
		PATTACH_POINT_FOLLOW, "claw3", Vector(0,0,0), true)
	ParticleManager:SetParticleControlEnt(gravEmitterParticle, 4, grapple, 
		PATTACH_POINT_FOLLOW, "emitter1", Vector(0,0,0), true)
	ParticleManager:SetParticleControlEnt(gravEmitterParticle, 5, grapple, 
		PATTACH_POINT_FOLLOW, "emitter2", Vector(0,0,0), true)
	ParticleManager:SetParticleControlEnt(gravEmitterParticle, 6, grapple, 
		PATTACH_POINT_FOLLOW, "emitter3", Vector(0,0,0), true)
end


function DisableGravEffects()
	grapple:SetSequence("idle")
	StopSoundOn("LocomotionTool_GravityEmitterLoop", grapple)
	
	if gravEmitterParticle > -1 then
		ParticleManager:DestroyParticle(gravEmitterParticle, false)
		gravEmitterParticle = -1
	end
end


function FlyThrust()

	if not isCarried
	then 
		jetpackThrusting = false
		return
	end
	
	if triggerMode ~= TRIGGER_MODE_FLY and triggerMode ~= TRIGGER_MODE_JETPACK 
	then 
		g_VRScript.playerPhysController:RemoveDragConstraint(playerEnt, thisEntity)
		jetpackThrusting = false
		return
	end
	
		
	if not jetpackThrusting and triggerValue > 0.2
	then
		StopSoundOn("drone_speed_dec", grapple)
		EmitSoundOn("drone_speed_acc", grapple)
		jetpackThrusting = true
	elseif jetpackThrusting and triggerValue <= 0.2
	then
		StopSoundOn("drone_speed_acc", grapple)
		EmitSoundOn("drone_speed_dec", grapple)
		jetpackThrusting = false
	end
	
	
	if padTouch and not g_VRScript.playerPhysController:IsPlayerOnGround(playerEnt) then
		if g_VRScript.playerPhysController:TrySetDragConstraint(playerEnt, thisEntity) then
			g_VRScript.playerPhysController:SetDrag(playerEnt, thisEntity, 1e-4, 2, nil, nil)
		end
	else
		g_VRScript.playerPhysController:RemoveDragConstraint(playerEnt, thisEntity)
	end 
	
	if triggerValue > 0.05 then
	
		if triggerMode == TRIGGER_MODE_JETPACK then
	
			local verticalVector = Vector(0, 0, triggerValue)
			
			if triggerIn
			then
				verticalVector = verticalVector * TRIGGER_IN_BOOST
			end
			
			local playerHeight = g_VRScript.playerPhysController:TracePlayerHeight(playerEnt) 
			
			if playerHeight < GROUND_EFFECT_HEIGHT
			then
				verticalVector = verticalVector * (1 + GROUND_EFFECT_FACTOR * (1 - playerHeight / GROUND_EFFECT_HEIGHT))
			end
			
			g_VRScript.playerPhysController:AddVelocity(playerEnt, verticalVector * THRUST_VERTICAL_SPEED * MOVE_THINK_INTERVAL)
			
		elseif triggerMode == TRIGGER_MODE_FLY then
		
			local forwardAng = nil
		
			if targetMode == TARGET_MODE_HAND then
				local idx = handAttachment:ScriptLookupAttachment("pad_move")
				local moveAngVec = handAttachment:GetAttachmentAngles(idx)
				forwardAng = QAngle(moveAngVec.x, moveAngVec.y, moveAngVec.z)
			else
				forwardAng = playerEnt:GetHMDAvatar():GetAngles()
			end
	
			local thrustVector = forwardAng:Forward()
			
			if triggerIn
			then
				thrustVector = thrustVector * TRIGGER_IN_BOOST
			end
			
			local playerHeight = g_VRScript.playerPhysController:TracePlayerHeight(playerEnt) 
			
			if playerHeight < GROUND_EFFECT_HEIGHT
			then
				thrustVector.z = thrustVector.z * (1 + GROUND_EFFECT_FACTOR * (1 - playerHeight / GROUND_EFFECT_HEIGHT))
			end
			
			local hoverThrust = Vector(0, 0, FLY_HOVER_THRUST)
			
			g_VRScript.playerPhysController:AddVelocity(playerEnt, 
				(thrustVector * THRUST_VERTICAL_SPEED + hoverThrust) * MOVE_THINK_INTERVAL)

		end
	end
	
	return MOVE_THINK_INTERVAL
end




function NormalizeAngle(angle)
	if angle > 180
	then 
		return angle - 360
	elseif angle < -180
	then
		return angle + 360
	end
	
	return angle
end


function RumbleController(intensity, length, frequency)
	if handEnt
	then
		rumbleTime = length
		rumbleFreq = frequency
		rumbleInt = intensity
		
		handEnt:FireHapticPulse(rumbleInt)
		local interval = 1 / rumbleFreq
		thisEntity:SetThink(RumblePulse, "rumble", interval)
	end
end


function RumblePulse()
	if handEnt
	then	
		handEnt:FireHapticPulse(rumbleInt)
		
		local interval = 1 / rumbleFreq
		
		rumbleTime = rumbleTime - interval
		if rumbleTime < interval
		then
			rumbleTime = 0
			return nil
		end
	
		return interval
	end
	
	rumbleTime = 0
	return nil
end


function IsParentedTo(entity, testEnt)
	local parent = entity:GetMoveParent()
	
	while parent
	do
		if parent == testEnt
		then
			return true
		end
		parent = parent:GetMoveParent()
	end
	return false
end


