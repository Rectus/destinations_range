--[[
	Ski pole entity script
	
	Copyright (c) 2017-2019 Rectus
	
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

local MathUtils = require "libraries.mathutils"

local POLE_VELOCITY_FACTOR = 120
local GRAB_MAX_DISTANCE = 38
local POLE_FORCE_MOVE_MAX_SPEED = 50
local POLE_FORCE_MOVE_MIN_DISTANCE = 1
local POLE_FORCE_MOVE_MAX_DISTANCE = 8
local GRAB_PULL_MIN_DISTANCE = 1
local POLE_DRAG_DIST = 8
local POLE_DRAG_DOT = -0.6
local POLE_DRAG_PULL_FACTOR = 0.01
local POLE_LIFT_FACTOR = 0.05
local MUZZLE_OFFSET = Vector(0, 0, -18)
local MUZZLE_ANGLES_OFFSET = QAngle(0, 0, 0)

local GRAB_PULL_PLAYER_SPEED = 16
local PUSH_TRACE_INTERVAL = 2
local ALIGN_INTERVAL = 2

local debugDraw = false

local GROUND_DRAG_CONSTANT = 50
local GROUND_DRAG_LINEAR = 4e-2
local SKI_DRAG_CONSTANT = 1e-1
local SKI_DRAG_LINEAR = 2e-4 -- 1e-3
local PLAYER_FULL_HEIGHT = 72
local PLAYER_HEIGHT_DRAG_FACTOR = 1.0
local SKI_TURN_MAX_SPEED = 180
local SKI_TURN_VEL_FACTOR = 0.01


local POLE_MAX_LENGTH = 110 -- 140 cm
local POLE_MIN_LENGTH = 0 -- 30 cm
local poleLength = 110


local isCarried = false
local playerEnt = nil
local handEnt = nil
local handID = 0
local handAttachment = nil
local poleAnim = nil
local compass = nil
local triggerHeld = false
local extended = false
local playerMoving = false

local playerPhys = nil
local grabEndpoint = nil
local playerMoved = false
local startVelocityAccumulate = 0 
	
local rumbleTime = 0
local rumbleFreq = 0
local rumbleInt = 0
local rumbleCount = 0

local triggerHintPanel = nil
local pauseHintPanel = nil
local lengthUpHintPanel = nil	
local lengthDownHintPanel = nil	

local ski0 = nil
local ski1 = nil
local skisEnabled = true

local turnSoundCounter = 0
local moveSoundLevel = 0
local moveSoundCounter = 0
local lastCarveLevel = 0
local carveSoundLevel = 0
local carveSoundCounter = 0
local skiDir = nil

local sprayParticle = nil
local skiParticleL = nil
local skiParticleR = nil

local animKeyvals = 
{
	targetname = "pole_anim";
	model = "models/props_slope/ski_pole_tool_animated.vmdl";
	targetname = "pole_anim";
	solid = 0
}

local compassKeyvals = 
{
	targetname = "pole_compass";
	model = "models/props_slope/ski_pole_tool_compass.vmdl";
	targetname = "pole_compass";
	vscripts = "compass";
	solid = 0
}


function Precache(context)
	PrecacheModel(animKeyvals.model, context)
	PrecacheModel(compassKeyvals.model, context)
	PrecacheModel("models/props_slope/ski.vmdl", context)
	PrecacheParticle("particles/tools/ski_pole_snow_spray.vpcf", context)
	PrecacheParticle("particles/tools/ski_carve_snow_spray.vpcf", context)
end


function Activate(activateType)

	if activateType == ACTIVATE_TYPE_ONRESTORE -- on game load
	then
		-- Hack to properly handle restoration from saves, 
		-- since variables written by Activate() on restore don't end up in the script scope.
		DoEntFireByInstanceHandle(thisEntity, "CallScriptFunction", "RestoreState", 0, thisEntity, thisEntity)
		
	else
		animKeyvals.origin = thisEntity:GetOrigin()
		animKeyvals.angles = thisEntity:GetAngles()
		poleAnim = SpawnEntityFromTableSynchronous("prop_dynamic", animKeyvals)
		poleAnim:SetParent(thisEntity, "")
		poleAnim:SetOrigin(thisEntity:GetOrigin())
		poleAnim:SetLocalAngles(0,0,0)
		
		poleLength = thisEntity:Attribute_GetFloatValue("poleLength", POLE_MAX_LENGTH)
		poleAnim:SetSequence("retracted")
		
		compassKeyvals.origin = thisEntity:GetOrigin()
		compassKeyvals.angles = thisEntity:GetAngles()	
		compass = SpawnEntityFromTableSynchronous("prop_dynamic", compassKeyvals)
		compass:SetParent(thisEntity, "compass")
		compass:SetLocalOrigin(Vector(0,0,0))
		
		CustomGameEventManager:RegisterListener("pause_panel_command", ToggleSkis)
	end
	g_VRScript.ScriptSystem_AddPerFrameUpdateFunction(Think)
end


function RestoreState()

	thisEntity:GetOrCreatePrivateScriptScope() -- Script scopes do not seem to be properly created on restore

	local children = thisEntity:GetChildren()
	for idx, child in pairs(children)
	do
		print(child:GetName())
		if child:GetName() == animKeyvals.targetname
		then
			poleAnim = child
		elseif child:GetName() == compassKeyvals.targetname
		then
			compass = child
		end
	end
	poleLength = thisEntity:Attribute_GetFloatValue("poleLength", POLE_MAX_LENGTH)
	poleAnim:SetSequence("retracted")
	CustomGameEventManager:RegisterListener("pause_panel_command", ToggleSkis)
	
end


function SetEquipped(this, pHand, nHandID, pHandAttachment, pPlayer)

	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	isCarried = true
	
	playerPhys = g_VRScript.playerPhysController
	
	if g_VRScript.pauseManager
	then
		g_VRScript.pauseManager:SetTeleportControlsAllowed(playerEnt, handID, false)
	else
		playerEnt:AllowTeleportFromHand(handID, false)
	end
	
	poleAnim:SetParent(handAttachment, "")
	poleAnim:SetOrigin(handAttachment:GetOrigin())
	poleAnim:SetLocalAngles(0,0,0)
	compass:SetParent(handAttachment, "compass")
	compass:SetOrigin(handAttachment:GetOrigin())
	
	skiDir = playerEnt:GetHMDAvatar():GetAngles():Left():Cross(Vector(0,0,-1))
	
	if g_VRScript.playerSettings then
		skisEnabled = g_VRScript.playerSettings:GetPlayerSetting(playerEnt, "show_skis")
	end
	
	debugDraw = g_VRScript.debugEnabled
	
	if not playerEnt.skiPoleHintsShown
	then
		SpawnHintPanels()
	end
	return true
end


function SetUnequipped()

	playerEnt:StopSound("Ski.Noise" .. moveSoundLevel)
	playerEnt:StopSound("Ski.Carve" .. carveSoundLevel)
	
	if g_VRScript.pauseManager
	then
		g_VRScript.pauseManager:SetTeleportControlsAllowed(playerEnt, handID, true)
	else
		playerEnt:AllowTeleportFromHand(handID, true)
	end
	
	poleAnim:SetSequence("retracted")
	extended = false
	
	if skiParticleL then
		ParticleManager:DestroyParticle(skiParticleL, false)
		skiParticleL = nil
	end
	
	if skiParticleR then
		ParticleManager:DestroyParticle(skiParticleR, false)
		skiParticleR = nil
	end
	
	if sprayParticle then
		ParticleManager:DestroyParticle(sprayParticle, false)
		sprayParticle = nil
	end
	
	playerPhys:RemoveDragConstraint(playerEnt, thisEntity)
	playerPhys:RemoveConstraint(playerEnt, thisEntity)
	
	if playerEnt.ActiveSkiContoller and playerEnt.ActiveSkiContoller == thisEntity
	then
		playerEnt.ActiveSkiContoller = nil
	end
	
	KillSkis()
	
	poleAnim:SetParent(thisEntity, "")
	poleAnim:SetLocalAngles(0,0,0)
	poleAnim:SetAbsOrigin(thisEntity:GetAbsOrigin())
	compass:SetParent(thisEntity, "compass")
	compass:SetAbsOrigin(thisEntity:GetAbsOrigin())
	
	playerEnt = nil
	handEnt = nil
	isCarried = false
	handAttachment = nil

	return true
end


function OnHandleInput(input)
	if not playerEnt
	then 
		return input
	end

	local IN_TRIGGER = (handID == 0 and IN_USE_HAND0 or IN_USE_HAND1)
	local IN_GRIP = (handID == 0 and IN_GRIP_HAND0 or IN_GRIP_HAND1)
	local IN_PAD = (handID == 0 and IN_PAD_HAND0 or IN_PAD_HAND1)
	local IN_PAD_UP = (handID == 0 and IN_PAD_UP_HAND0 or IN_PAD_UP_HAND1)
	local IN_PAD_DOWN = (handID == 0 and IN_PAD_DOWN_HAND0 or IN_PAD_DOWN_HAND1)
	
	if input.buttonsPressed:IsBitSet(IN_TRIGGER)
	then
		triggerHeld = true
		thisEntity:SetThink(TriggerThink, "trigger", 0.5)
		RumbleController(1, 0.4, 20)
	end		
	
	if input.buttonsReleased:IsBitSet(IN_TRIGGER) 
	then		
		triggerHeld = false
	end
	
	if playerEnt:GetVRControllerType() ~= VR_CONTROLLER_TYPE_VIVE or input.buttonsDown:IsBitSet(IN_PAD) 
	then
		if input.buttonsPressed:IsBitSet(IN_PAD_UP) 
		then
			handAttachment:EmitSound("Pole.Click")
			SetPoleLength(poleLength - 5)
			
		elseif input.buttonsPressed:IsBitSet(IN_PAD_DOWN) 
		then 
			handAttachment:EmitSound("Pole.Click")
			SetPoleLength(poleLength + 5)		
		end
	end

	return input
end


function SetPoleLength(length)
	
	poleLength = Clamp(length, POLE_MIN_LENGTH, POLE_MAX_LENGTH)

	if poleAnim
	then
		poleAnim:SetPoseParameter("pole_length", poleLength)
	end
	
	thisEntity:Attribute_SetFloatValue("poleLength", poleLength - 0.1)

	return poleLength
end

function SpawnHintPanels()

	local panelTable = 
	{
		origin = handAttachment:GetAttachmentOrigin(handAttachment:ScriptLookupAttachment("length_up_hint")),
		dialog_layout_name = "file://{resources}/layout/custom_destination/pole_length_up_hint.xml",
		width = "3",
		height = "0.6",
		panel_dpi = "96",
		interact_distance = "0",
		--horizontal_align = "2",
		vertical_align = "1",
		orientation = "1",
		angles = "0 90 0"
	}

	lengthUpHintPanel = SpawnEntityFromTableSynchronous("point_clientui_world_panel", panelTable)
	lengthUpHintPanel:SetParent(handAttachment, "length_up_hint")
	
	panelTable.origin = handAttachment:GetAttachmentOrigin(handAttachment:ScriptLookupAttachment("length_down_hint"))
	panelTable.dialog_layout_name = "file://{resources}/layout/custom_destination/pole_length_down_hint.xml"
	
	lengthDownHintPanel = SpawnEntityFromTableSynchronous("point_clientui_world_panel", panelTable)
	lengthDownHintPanel:SetParent(handAttachment, "length_down_hint")

	panelTable.width = "4.2"
	panelTable.horizontal_align = "2"
	panelTable.origin = handAttachment:GetAttachmentOrigin(handAttachment:ScriptLookupAttachment("trigger_hint"))
	panelTable.dialog_layout_name = "file://{resources}/layout/custom_destination/pole_trigger_hint.xml"
	
	triggerHintPanel = SpawnEntityFromTableSynchronous("point_clientui_world_panel", panelTable)
	triggerHintPanel:SetParent(handAttachment, "trigger_hint")
	
	panelTable.horizontal_align = nil
	panelTable.width = "6"
	panelTable.origin = handAttachment:GetAttachmentOrigin(handAttachment:ScriptLookupAttachment("pause_hint"))
	panelTable.dialog_layout_name = "file://{resources}/layout/custom_destination/pole_pause_hint.xml"
	
	pauseHintPanel = SpawnEntityFromTableSynchronous("point_clientui_world_panel", panelTable)
	pauseHintPanel:SetParent(handAttachment, "pause_hint")
end


function KillHintPanels()

	if triggerHintPanel and IsValidEntity(triggerHintPanel) then triggerHintPanel:Kill() end
	if pauseHintPanel and IsValidEntity(pauseHintPanel) then pauseHintPanel:Kill() end
	if lengthUpHintPanel and IsValidEntity(lengthUpHintPanel) then lengthUpHintPanel:Kill() end
	if lengthDownHintPanel and IsValidEntity(lengthDownHintPanel) then lengthDownHintPanel:Kill() end
	
	triggerHintPanel = nil
	pauseHintPanel = nil
	lengthUpHintPanel = nil	
	lengthDownHintPanel = nil	
end


function UpdateOnRemove()

	if isCarried
	then
		playerPhys:RemoveDragConstraint(playerEnt, thisEntity)
	end
	
	KillHintPanels()
end


function TriggerThink()

	if not triggerHeld
	then
		return nil
	end

	RumbleController(2, 0.3, 60)

	if extended
	then
		extended = false

		poleAnim:SetSequence("retracted") 
	else
		extended = true
		poleAnim:SetSequence("extended_pose")
		-- TODO Hack for the pose paramter not setting right
		thisEntity:SetThink(function() SetPoleLength(poleLength -0.1) end, "fix_pose", 0.2) 
		
		if triggerHintPanel
		then
			KillHintPanels()
			playerEnt.skiPoleHintsShown = true
		end
	end
	
	return nil
end


function GetAttachment()

	if not isCarried then return nil end

	return handAttachment
end


function GetUsingPlayer()

	if not isCarried then return nil end

	return playerEnt
end


function ToggleSkis(this, eventData)

	local player = GetPlayerFromUserID(eventData.id)

	if not playerEnt or player == playerEnt then return end

	if eventData.cmd ~= "show_skis" then return end

	skisEnabled = math.floor(eventData.val) == 1
	
	if not skisEnabled then KillSkis() end
end


function KillSkis()

	if ski0 and IsValidEntity(ski0)
	then
		ski0:Kill()
	end
	
	if ski1 and IsValidEntity(ski1)
	then
		ski1:Kill()
	end
	
	ski0 = nil
	ski1 = nil
end


function Think()

	if isCarried
	then
	
		local playerVel = playerPhys:GetVelocity(playerEnt)
		local playerSpeed = playerVel:Length()
		playerMoving = playerSpeed > 0

		if extended and (GetFrameCount() + 1) % PUSH_TRACE_INTERVAL == 0
		then
			TracePush(playerVel, playerSpeed)
		end
	
		if (GetFrameCount() + 1) % ALIGN_INTERVAL == 0
		then 
			UpdateSkis(playerVel, playerSpeed)
		end
	end
end


function UpdateSkis(playerVel, playerSpeed)
	
	if not playerEnt.ActiveSkiContoller or not IsValidEntity(playerEnt.ActiveSkiContoller)
	then
		playerEnt.ActiveSkiContoller = thisEntity
	
	elseif playerEnt.ActiveSkiContoller:GetOrCreatePrivateScriptScope().GetUsingPlayer
		and playerEnt.ActiveSkiContoller:GetPrivateScriptScope().GetUsingPlayer() ~= playerEnt
	then
		playerEnt.ActiveSkiContoller = thisEntity
	
	elseif playerEnt.ActiveSkiContoller ~= thisEntity
	then		
		KillSkis()
		return
	end

	
	local hand0Pos = nil
	local hand1Pos = nil
	
	local hmd = playerEnt:GetHMDAvatar()
	
	local hand0 = hmd:GetVRHand(0)
	local hand1 = hmd:GetVRHand(1)
	
	hand0Pos = hand0:GetOrigin()
	if VectorIsZero(hand0Pos)
	then
		hand0Pos = hmd:GetOrigin()
	end
	
	hand1Pos = hand1:GetOrigin()
	if VectorIsZero(hand1Pos)
	then
		hand1Pos = hmd:GetOrigin()
	end

	if not skiDir
	then
		-- The ski direction is orthogonal to the line between the hands on the xy plane.
		skiDir = (hand0Pos - hand1Pos):Cross(Vector(0, 0, 1)):Normalized()
	elseif playerMoving
	then
		local wantedSkiDir = (hand0Pos - hand1Pos):Cross(Vector(0, 0, 1)):Normalized()

		local diff = MathUtils.NormalizeAngle(AngleDiff(VectorToAngles(wantedSkiDir).y, VectorToAngles(skiDir).y))
		local turnDir = MathUtils.Sign(diff)
		local turnSpeed = Clamp(playerSpeed * SKI_TURN_VEL_FACTOR, 0, SKI_TURN_MAX_SPEED)
		local dotFactor = RemapValClamped(skiDir:Dot(wantedSkiDir), 0.8, 0.95, 1, 0)
		local turnYaw = min(turnDir * turnSpeed * ALIGN_INTERVAL, diff) * dotFactor
		skiDir = RotatePosition(Vector(0,0,0), QAngle(0, turnYaw, 0), skiDir)
	end

	if skisEnabled then
	
		if not ski0 or not IsValidEntity(ski0)
		then
			ski0 = SpawnSki()
		end
		
		if not ski1 or not IsValidEntity(ski1)
		then
			ski1 = SpawnSki()
		end
	end
	
	local skiDirOrth = skiDir:Cross(Vector(0,0,1))
	local playerAVOrigin = playerEnt:GetHMDAvatar():GetOrigin()
	local baseTraceEnd = playerEnt:GetHMDAnchor():GetOrigin().z
	local SKI_SEPARATION = 8
	local ON_GROUND_BUFFER = 8
	local heightFac = 0
	
	local traceTable = {
		startpos = playerAVOrigin;
		endpos = Vector(playerAVOrigin.x, playerAVOrigin.y, baseTraceEnd - 512);
		ignore = playerEnt;
		--mask = 33636363;
	}
	
	TraceLine(traceTable)

	if traceTable.hit
	then
		if traceTable.pos.z < (baseTraceEnd - ON_GROUND_BUFFER)		
		then
			heightFac = (baseTraceEnd - ON_GROUND_BUFFER - traceTable.pos.z) / 512
		end
	else
		heightFac = 1
	end

	local skiDragFactor = 0
	
	if playerVel and playerSpeed > 10
	then
		local velXY = Vector(playerVel.x, playerVel.y, 0):Normalized()
		skiDragFactor = velXY:Dot(skiDirOrth) * 8
	end
	
	local dragMagnitude = 0
	
	if playerPhys:TrySetDragConstraint(playerEnt, thisEntity)
	then
		local groundMoveDir = skiDir:Cross(traceTable.normal)
		local skiMoveDir = groundMoveDir:Cross(traceTable.normal)
		
		local playerHeightFac = ((playerEnt:GetCenter().z - playerEnt:GetHMDAnchor():GetOrigin().z) * 2) 
			/ PLAYER_FULL_HEIGHT * PLAYER_HEIGHT_DRAG_FACTOR

		local velNorm = playerVel:Normalized()
			
		local skiCoVelocity = playerVel:Dot(skiMoveDir)
		local groundCoVelocity = playerVel:Dot(groundMoveDir)
		local dragVector = (skiMoveDir * (SKI_DRAG_CONSTANT * velNorm:Dot(skiMoveDir) + SKI_DRAG_LINEAR * skiCoVelocity
			* abs(skiCoVelocity)) * playerHeightFac
			+ groundMoveDir * (GROUND_DRAG_CONSTANT * velNorm:Dot(groundMoveDir) + GROUND_DRAG_LINEAR * groundCoVelocity
			* abs(groundCoVelocity) )) 
	
		dragMagnitude = dragVector:Length()
	
		playerPhys:SetDrag(playerEnt, thisEntity, nil, nil, dragVector, nil)

	end
		
	if skisEnabled then
		local alignTop = Vector(playerAVOrigin.x, playerAVOrigin.y, playerEnt:GetHMDAnchor():GetOrigin().z + 48)
		
		AlignSki(ski0, alignTop + skiDirOrth * SKI_SEPARATION - skiDir * skiDragFactor, 
			skiDir, heightFac, traceTable.normal, playerVel)
			
		AlignSki(ski1, alignTop - skiDirOrth * SKI_SEPARATION + skiDir * skiDragFactor, 
			skiDir, heightFac, traceTable.normal, playerVel)
		
		if dragMagnitude > 20 and playerPhys:IsPlayerOnGround(playerEnt)
			and not g_VRScript.pauseManager:IsPaused(playerEnt) then
			
			if not skiParticleL then 
			skiParticleL = ParticleManager:CreateParticle("particles/tools/ski_carve_snow_spray.vpcf", 
					PATTACH_ABSORIGIN_FOLLOW, ski0)			
			end
			
			if not skiParticleR then 
			skiParticleR = ParticleManager:CreateParticle("particles/tools/ski_carve_snow_spray.vpcf", 
					PATTACH_ABSORIGIN_FOLLOW, ski1)			
			end
			
			local particleVel = traceTable.normal * min(playerSpeed * 0.2, 40)	
			-- Match the particles to the player speed at high velocieties
			particleVel = particleVel + playerVel * playerSpeed / (playerSpeed + 100)
			
			ParticleManager:SetParticleControl(skiParticleL, 1, particleVel)
			ParticleManager:SetParticleControl(skiParticleR, 1, particleVel)
			
		else
			if skiParticleL then
				ParticleManager:DestroyParticle(skiParticleL, false)
				skiParticleL = nil
			end
			
			if skiParticleR then
				ParticleManager:DestroyParticle(skiParticleR, false)
				skiParticleR = nil
			end
		end
	end
	
	UpdateSkiSound(playerVel, skiDir, dragMagnitude)
	
	return
end


function UpdateSkiSound(velocity, skiDir, dragMagnitude)

	local onGround = playerPhys:IsPlayerOnGround(playerEnt)
	local isPaused = g_VRScript.pauseManager:IsPaused(playerEnt)
	turnSoundCounter = turnSoundCounter - FrameTime() * ALIGN_INTERVAL

	if isPaused
	then
		for i = 1, 9 do 
			playerEnt:StopSound("Ski.Noise" .. i)
			playerEnt:StopSound("Ski.Carve" .. i)
		end
		moveSoundLevel = 0
		carveSoundLevel = 0
		velocity = Vector(0,0,0)
		dragMagnitude = 0
	end
	
	local oldLevel = moveSoundLevel		
	moveSoundLevel = PlayerMoveSoundLevel(playerEnt, velocity:Length())
	if not onGround
	then
		playerEnt:StopSound("Ski.Noise" .. oldLevel)
		--moveSoundLevel = 0
		moveSoundCounter = 0
	else
		moveSoundCounter = moveSoundCounter - FrameTime() *ALIGN_INTERVAL
		if moveSoundLevel ~= oldLevel or moveSoundCounter <= 0
		then
			
			playerEnt:StopSound("Ski.Noise" .. oldLevel)
			playerEnt:EmitSound("Ski.Noise" .. moveSoundLevel)
			moveSoundCounter = 3.5
			--moveSoundCounter = playerEnt:GetSoundDuration("Ski.Noise" .. moveSoundLevel, "")
		end
	end
	oldLevel = carveSoundLevel
	if dragMagnitude < 40 or abs(lastCarveLevel - dragMagnitude) > 200 or carveSoundCounter <= 0 then
		carveSoundLevel = PlayerCarveSoundLevel(playerEnt, dragMagnitude)
	end
	
	if not onGround
	then
		playerEnt:StopSound("Ski.Carve" .. oldLevel)
		carveSoundCounter = 0
	else
		carveSoundCounter = carveSoundCounter - FrameTime() *ALIGN_INTERVAL
		if carveSoundLevel ~= oldLevel or carveSoundCounter <= 0
		then
			lastCarveLevel = dragMagnitude
			playerEnt:StopSound("Ski.Carve" .. oldLevel)
			playerEnt:EmitSound("Ski.Carve" .. carveSoundLevel)
			carveSoundCounter = 1.5

		end
	end
end


function PlayerMoveSoundLevel(playerEnt, speed)
	if speed <= 0.1 then
		return 0
	elseif speed > 900 then
		return 9
	else 
		return math.floor(speed / 100) + 1
	end

end


function PlayerCarveSoundLevel(playerEnt, factor)
	if factor <= 40 then
		return 0
	elseif factor > 4500 then
		return 9
	else 
		return math.floor(factor / 500) + 1
	end

end


function AlignSki(ski, origin, skiDir, heightFac, groundNormal, playerVel)
	local baseTraceEnd = playerEnt:GetHMDAnchor():GetOrigin().z
	local skiDirOrth = skiDir:Cross(Vector(0,0,1))
	local skiNormal = nil
	local newOrigin = ski:GetAbsOrigin()
	
	if heightFac <= 0
	then
		local skiFront = SkiTrace(origin + skiDir * 24, baseTraceEnd - 24)
		local skiCenter = SkiTrace(Vector(origin.x, origin.y, baseTraceEnd + 4), baseTraceEnd - 8)
		local skiBack = SkiTrace(origin - skiDir * 24, baseTraceEnd - 16)
		
		-- Center vector if front and back form a bridge 
		local skiCenterCalc = skiBack + (skiFront - skiBack) / 2

		if skiCenterCalc.z > skiCenter.z
		then
			newOrigin = skiCenterCalc
			skiNormal = (skiCenterCalc - skiBack):Cross(skiDirOrth)
		else
			newOrigin = skiCenter
			skiNormal = (skiCenter - skiBack):Cross(skiDirOrth)
		end
		
		if debugDraw
		then
			DebugDrawLine(skiFront, skiBack, 255, 0, 255, true, FrameTime() *ALIGN_INTERVAL)
		end
	else
		newOrigin = Vector(origin.x, origin.y, baseTraceEnd)
		skiNormal = -SplineVectors(groundNormal, Vector(0, 0, 1), heightFac)
	end
	
	local ang = VectorToAngles(skiNormal:Cross(skiDirOrth))
	ski:SetAngles(ang.x, ang.y, ang.z)
	local t = RemapValClamped((newOrigin - ski:GetAbsOrigin()):Length(), 0, 4, 1, 0.5)
	ski:SetAbsOrigin(VectorLerp(t, ski:GetAbsOrigin(), newOrigin))
	--ski:SetVelocity(playerVel)
end 


function SkiTrace(start, endZ)
	local traceTable = {
		startpos = start;
		endpos = Vector(start.x, start.y, endZ);
		ignore = playerEnt;
		--mask = 33636363;
	}
	
	TraceLine(traceTable)
	
	if traceTable.hit
	then 
		return traceTable.pos 
	end
	
	return traceTable.endpos
end


function SpawnSki()
	local keyvals = 
	{
		targetname = "ski";
		model = "models/props_slope/ski.vmdl";
		solid = 0;
		ScriptedMovement = 1;
	}
	
	local ski = SpawnEntityFromTableSynchronous("prop_dynamic", keyvals)
	
	return ski
end


function IsTouchingGround()
	
	return playerMoved
end


function TracePush(playerVel, playerSpeed)

	local poleStart = poleAnim:ScriptLookupAttachment("pole_start")
	local poleEnd = poleAnim:ScriptLookupAttachment("pole_end")	

	local traceTable =
	{
		startpos = poleAnim:GetAttachmentOrigin(poleStart);
		endpos = poleAnim:GetAttachmentOrigin(poleEnd);
		ignore = playerEnt

	}
	if debugDraw then DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, FrameTime() * PUSH_TRACE_INTERVAL) end
	TraceLine(traceTable)
	
	if traceTable.hit 
	then
		if debugDraw then DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 255, 0, false, FrameTime() * PUSH_TRACE_INTERVAL) end
		
		if traceTable.enthit 
		then
			if traceTable.enthit == handEnt
			then
				return
			end

		end 
	
		playerPhys:AddConstraint(playerEnt, thisEntity, false)
		
		if not playerMoved
		then
			--StartSoundEvent("SkiPole.Hit", thisEntity.handEnt)
			RumbleController(2, 0.2, 1)
			grabEndpoint = traceTable.pos
			playerMoved = true
			sprayParticle = ParticleManager:CreateParticle("particles/tools/ski_pole_snow_spray.vpcf", 
				PATTACH_CUSTOMORIGIN, thisEntity)
			ParticleManager:SetParticleControl(sprayParticle, 0, traceTable.pos)
			return
		end
	
		local distanceVector = (grabEndpoint - traceTable.pos)
		if debugDraw then DebugDrawLine(grabEndpoint, traceTable.pos, 0, 0, 255, true, FrameTime()) end
		
		local pullDir = distanceVector:Normalized()
		
		local depth = (traceTable.pos - traceTable.endpos):Length()
		
		local distance = distanceVector:Length()
		--DebugDrawLine(traceTable.pos, thisEntity.grabEndpoint, 0, 255, 0, false, 0.5)
		
		local normal = (traceTable.startpos - traceTable.pos):Normalized()
		local coDirection = pullDir:Dot(normal)
		
		local dragFactor = (coDirection + 1) / 2

	
		-- If the pole is dragging along the ground in the opposite direction of the staking.
		if coDirection < 0 or distance > POLE_DRAG_DIST
		then
			
			grabEndpoint = traceTable.pos
			if coDirection < POLE_DRAG_DOT
			then
				dragFactor = dragFactor *  POLE_DRAG_PULL_FACTOR  * depth / GRAB_MAX_DISTANCE
				RumbleController(1, 0.4, 40)
			end
		end
		
		
		-- Allows the player to push away from walls
		local velChange = traceTable.normal * (depth + 16) * POLE_LIFT_FACTOR
		
	
		if distance > GRAB_PULL_MIN_DISTANCE
		then
			local distSqr = distance * distance
		
			if distSqr < GRAB_PULL_PLAYER_SPEED
			then 
				pullDir = pullDir * distSqr
			else
				pullDir = pullDir * GRAB_PULL_PLAYER_SPEED
			end
				
			velChange = velChange + pullDir * dragFactor
		end	

		velChange = velChange * POLE_VELOCITY_FACTOR * FrameTime()
		
		if playerMoving then
		
			--DebugDrawLine(traceTable.pos, traceTable.pos + pullVector, 255, 0, 0, true, 0.5)
			playerPhys:AddVelocity(playerEnt, velChange, true)
		
		else -- If the player is stopped, store force until there is enough to overcome the stop speed.
		
			if not startVelocityAccumulate then
				startVelocityAccumulate = velChange
			else
				startVelocityAccumulate = startVelocityAccumulate + velChange
			end 
			
			if startVelocityAccumulate:Length() > 35 then 
				
				playerPhys:AddVelocity(playerEnt, startVelocityAccumulate, true)
				startVelocityAccumulate = nil
			end
		end
		
		ParticleManager:SetParticleControl(sprayParticle, 0, traceTable.pos)		
		
		local particleVel = traceTable.normal * min(playerSpeed * 0.5, 60)
		
		-- Match the particles to the player speed at high velocieties
		particleVel = particleVel + playerVel * playerSpeed / (playerSpeed + 100)
	
		ParticleManager:SetParticleControl(sprayParticle, 1,  particleVel)
	
	
	else
		playerPhys:RemoveConstraint(playerEnt, thisEntity)
	
		if playerMoved
		then
			if sprayParticle then
				ParticleManager:DestroyParticle(sprayParticle, false)
				sprayParticle = nil
			end
		
			RumbleController(2, 0.1, 1)
			playerMoved = false
		end	
	end
end


function RumbleController(intensity, length, frequency)
	if handEnt
	then
		thisEntity:SetThink(RumbleThink, "rumble", 1 / frequency)	

		rumbleTime = length
		rumbleFreq = frequency
		rumbleInt = intensity
	end		
end


function RumbleThink()
	if not handEnt
	then
		return nil
	end

	local interval = 1 / rumbleFreq
	
	handEnt:FireHapticPulse(rumbleInt)
	
	if rumbleTime > interval
	then
		rumbleTime = rumbleTime - interval

		return interval
	else
		rumbleTime = 0
		return nil
	end	
end


