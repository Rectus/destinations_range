--[[
	Ski pole entity script
	
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
local PUSH_TRACE_INTERVAL = 0.04

local ALIGN_INTERVAL = 0.022
local debugDraw = false

local GROUND_DRAG_CONSTANT = 50
local GROUND_DRAG_LINEAR = 4e-2
local SKI_DRAG_CONSTANT = 1e-1
local SKI_DRAG_LINEAR = 2e-4 -- 1e-3
local PLAYER_FULL_HEIGHT = 72
local PLAYER_HEIGHT_DRAG_FACTOR = 1.0


local POLE_MAX_LENGTH = 140
local POLE_MIN_LENGTH = 30
local poleLength = POLE_MAX_LENGTH


local isCarried = false
local playerEnt = nil
local handEnt = nil
local handID = 0
local handAttachment = nil
local poleAnim = nil
local compass = nil
local triggerHeld = false
local extended = false
local gripLocked = false
local lockedPanel = nil

local playerPhys = nil
local grabEndpoint = nil
local playerMoved = false
local startVelocityAccumulate = 0 
	
local rumbleTime = 0
local rumbleFreq = 0
local rumbleInt = 0
local rumbleCount = 0

local pauseButtonIn = false

local gripHintPanel = nil
local triggerHintPanel = nil
local pauseHintPanel = nil
local teleportHintPanel = nil
local lockHintPanel = nil

local ski0 = nil
local ski1 = nil
local skisEnabled = true

local turnSoundCounter = 0
local moveSoundLevel = 0
local moveSoundCounter = 0
local lastCarveLevel = 0
local carveSoundLevel = 0
local carveSoundCounter = 0
local previousSkiDir = nil

local sprayParticle = nil
local skiParticleL = nil
local skiParticleR = nil

local animKeyvals = 
{
	targetname = "pole_anim";
	model = "models/props_slope/ski_pole_tool_animated.vmdl";
	solid = 0
}

local compassKeyvals = 
{
	targetname = "pole_compass";
	model = "models/props_slope/ski_pole_tool_compass.vmdl";
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

function Activate()

	animKeyvals.origin = thisEntity:GetOrigin()
	animKeyvals.angles = thisEntity:GetAngles()
	poleAnim = SpawnEntityFromTableSynchronous("prop_dynamic", animKeyvals)
	poleAnim:SetParent(thisEntity, "")
	poleAnim:SetOrigin(thisEntity:GetOrigin())
	poleAnim:SetLocalAngles(0,0,0)
	
	DoEntFireByInstanceHandle(poleAnim, "SetAnimationNoReset", "retracted", 0 , nil, nil)
	DoEntFireByInstanceHandle(poleAnim, "SetDefaultAnimation", "retracted", 0 , nil, nil)
	
	compassKeyvals.origin = thisEntity:GetOrigin()
	compassKeyvals.angles = thisEntity:GetAngles()	
	compass = SpawnEntityFromTableSynchronous("prop_dynamic", compassKeyvals)
	compass:SetParent(thisEntity, "compass")
	compass:SetLocalOrigin(Vector(0,0,0))
	
	CustomGameEventManager:RegisterListener("pause_panel_toggle_skis", ToggleSkis)

end

function SetEquipped( self, pHand, nHandID, pHandAttachment, pPlayer )
	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	isCarried = true
	gripLocked = false
	
	poleAnim:SetParent(handAttachment, "")
	poleAnim:SetOrigin(handAttachment:GetOrigin())
	poleAnim:SetLocalAngles(0,0,0)
	compass:SetParent(handAttachment, "compass")
	compass:SetOrigin(handAttachment:GetOrigin())
	--compass:SetAngles(0,0,0)
	
	
	if extended
	then
		Enable()
	else
		Disable()
	end
	poleAnim:SetPoseParameter("pole_length", poleLength)

	playerPhys = g_VRScript.fallController
	thisEntity:SetThink(TracePush, "trace", PUSH_TRACE_INTERVAL)
	thisEntity:SetThink(UpdateSkis, "update_ski", 0)
	
	if not GameRules.skiPoleHintsSpawned
	then
		SpawnHintPanels()
		GameRules.skiPoleHintsSpawned = true	
	end
	return true
end



function SetUnequipped()

	Disable()
	playerEnt:StopSound("Ski.Noise" .. moveSoundLevel)
	playerEnt:StopSound("Ski.Carve" .. carveSoundLevel)
	
	if extended
	then
		extended = false
		Disable()
		DoEntFireByInstanceHandle(poleAnim, "SetAnimationNoReset", "retracted", 0 , nil, nil)
		DoEntFireByInstanceHandle(poleAnim, "SetDefaultAnimation", "retracted", 0 , nil, nil)
	end
	
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
	
	local playerScope = playerEnt:GetOrCreatePrivateScriptScope()
	if playerScope.ActiveSkiContoller and playerScope.ActiveSkiContoller == thisEntity
	then
		playerScope.ActiveSkiContoller = nil
	end
	
	playerEnt = nil
	handEnt = nil
	isCarried = false
	
	--local angles = thisEntity:GetAngles()
	poleAnim:SetParent(thisEntity, "")
	--poleAnim:SetAngles(angles.x, angles.y, angles.z)
	poleAnim:SetLocalAngles(0,0,0)
	poleAnim:SetOrigin(thisEntity:GetOrigin())
	compass:SetParent(thisEntity, "compass")
	compass:SetOrigin(thisEntity:GetOrigin())
	
	return true
end


function OnHandleInput(input)
	if not playerEnt
	then 
		return
	end

	local IN_TRIGGER = (handID == 0 and IN_USE_HAND0 or IN_USE_HAND1)
	local IN_GRIP = (handID == 0 and IN_GRIP_HAND0 or IN_GRIP_HAND1)
	local IN_PAD = (handID == 0 and IN_PAD_HAND0 or IN_PAD_HAND1)
	

	if playerEnt:GetVRControllerType() == VR_CONTROLLER_TYPE_TOUCH then
		
		local IN_GRIP_HOLD = (handID == 0 and IN_PAD_HAND0 or IN_PAD_HAND1)
		local IN_GRIP_TOUCH = (handID == 0 and IN_GRIP_HAND0 or IN_GRIP_HAND1)
		local IN_JOY_PUSH = (handID == 0 and IN_PAD_TOUCH_HAND0 or IN_PAD_TOUCH_HAND1)
		local IN_JOY_TOUCH = (handID == 0 and 42 or 43)
		
		if input.buttonsPressed:IsBitSet(IN_JOY_PUSH)
		then
			ToggleGripLock()
		end
		
	else
		if input.buttonsPressed:IsBitSet(IN_PAD) and input.trackpadY > 0
		then	
			ToggleGripLock()
			input.buttonsPressed:ClearBit(IN_PAD)
		end
		
		if input.buttonsDown:IsBitSet(IN_PAD) and input.trackpadY > 0
		then	
			input.buttonsDown:ClearBit(IN_PAD)
		end
		
		if input.buttonsReleased:IsBitSet(IN_PAD) and input.trackpadY > 0
		then
			input.buttonsReleased:ClearBit(IN_PAD)
		end
	end
	
	

	
	if input.buttonsPressed:IsBitSet(IN_TRIGGER)
	then
		triggerHeld = true
		thisEntity:SetThink(TriggerThink, "trigger", 0.5)
		RumbleController(1, 0.4, 20)
		
		input.buttonsPressed:ClearBit(IN_TRIGGER)
	end		
	
	if input.buttonsReleased:IsBitSet(IN_TRIGGER) 
	then
		
		triggerHeld = false
		input.buttonsReleased:ClearBit(IN_TRIGGER)
	end
	
	
	--[[if input.buttonsPressed:IsBitSet(IN_PAD)
	then
		if input.trackpadY > 0
		then
			pauseButtonIn = true
			input.buttonsPressed:ClearBit(IN_PAD)
		end
	end
	
	if input.buttonsDown:IsBitSet(IN_PAD) and pauseButtonIn
	then	
		input.buttonsDown:ClearBit(IN_PAD)
	end
	
	if input.buttonsReleased:IsBitSet(IN_PAD) and pauseButtonIn
	then
		--GameRules:GetGameModeEntity().SkiMode:TogglePause(playerEnt)
	
		pauseButtonIn = false
		input.buttonsReleased:ClearBit(IN_PAD)
	end]]
	
	
	if input.buttonsPressed:IsBitSet(IN_GRIP)
	then
		input.buttonsPressed:ClearBit(IN_GRIP)
		

	end
	
	if input.buttonsReleased:IsBitSet(IN_GRIP)
	then
		input.buttonsReleased:ClearBit(IN_GRIP)
		
		if not gripLocked then
		
			thisEntity:ForceDropTool()
			
		else
			if IsValidEntity(lockedPanel) then
				lockedPanel:Kill()
			end
		
			local panelTable = 
			{
				origin = handAttachment:GetAttachmentOrigin(handAttachment:ScriptLookupAttachment("lock_message")),
				dialog_layout_name = "file://{resources}/layout/custom_destination/pole_locked.xml",
				width = "4",
				height = "0.6",
				panel_dpi = "96",
				interact_distance = "0",
				horizontal_align = "1",
				vertical_align = "1",
				orientation = "0",
				angles = "0 0 0"
			}
			lockedPanel = SpawnEntityFromTableSynchronous("point_clientui_world_panel", panelTable)
			lockedPanel:SetParent(handAttachment, "lock_message")
			lockedPanel:SetLocalAngles(0,0,0)
			DoEntFireByInstanceHandle(lockedPanel, "Kill", "", 2, thisEntity, thisEntity)
			EmitSoundOn("Pole.Fail", handAttachment)
		end
	end

	return input
end


function ToggleGripLock()

	local panelTable = 
	{
		origin = handAttachment:GetAttachmentOrigin(handAttachment:ScriptLookupAttachment("lock_message")),
		dialog_layout_name = "file://{resources}/layout/custom_destination/pole_locked.xml",
		width = "4",
		height = "0.6",
		panel_dpi = "96",
		interact_distance = "0",
		horizontal_align = "1",
		vertical_align = "1",
		orientation = "0",
		angles = "0 0 0"
	}
	
	if IsValidEntity(lockedPanel) then
		lockedPanel:Kill()
	end
	

	if gripLocked then
		gripLocked = false
		
		panelTable.dialog_layout_name = "file://{resources}/layout/custom_destination/pole_unlocked.xml"
		lockedPanel = SpawnEntityFromTableSynchronous("point_clientui_world_panel", panelTable)
		lockedPanel:SetParent(handAttachment, "lock_message")
		lockedPanel:SetLocalAngles(0,0,0)
		DoEntFireByInstanceHandle(lockedPanel, "Kill", "", 2, thisEntity, thisEntity)
		
		EmitSoundOn("Pole.Click", handAttachment)
	else
		gripLocked = true
		
		
		lockedPanel = SpawnEntityFromTableSynchronous("point_clientui_world_panel", panelTable)
		lockedPanel:SetParent(handAttachment, "lock_message")
		lockedPanel:SetLocalAngles(0,0,0)
		DoEntFireByInstanceHandle(lockedPanel, "Kill", "", 2, thisEntity, thisEntity)
		
		EmitSoundOn("Pole.Click", handAttachment)
	end
end


function SetPoleLength(length)
	
	if length > POLE_MAX_LENGTH
	then
		poleLength = POLE_MAX_LENGTH
		
	elseif length < POLE_MIN_LENGTH
	then
		poleLength = POLE_MIN_LENGTH
	else
		poleLength = length
	end

	if poleAnim
	then
		poleAnim:SetPoseParameter("pole_length", poleLength)
	end

	return poleLength
end

function SpawnHintPanels()

	local panelTable = 
	{
		origin = handAttachment:GetAttachmentOrigin(handAttachment:ScriptLookupAttachment("grip_hint")),
		dialog_layout_name = "file://{resources}/layout/custom_destination/pole_grip_hint.xml",
		width = "4",
		height = "0.6",
		panel_dpi = "96",
		interact_distance = "0",
		horizontal_align = "2",
		vertical_align = "1",
		orientation = "1",
		angles = "0 90 0"
	}
	
	if playerEnt:GetVRControllerType() == VR_CONTROLLER_TYPE_TOUCH then
		panelTable.dialog_layout_name = "file://{resources}/layout/custom_destination/pole_grip_hint_oculus.xml"
	end
	
	gripHintPanel = SpawnEntityFromTableSynchronous("point_clientui_world_panel", panelTable)
	gripHintPanel:SetParent(handAttachment, "grip_hint")
	
	panelTable.origin = handAttachment:GetAttachmentOrigin(handAttachment:ScriptLookupAttachment("trigger_hint"))
	panelTable.dialog_layout_name = "file://{resources}/layout/custom_destination/pole_trigger_hint.xml"
	
	triggerHintPanel = SpawnEntityFromTableSynchronous("point_clientui_world_panel", panelTable)
	triggerHintPanel:SetParent(handAttachment, "trigger_hint")
	
	panelTable.horizontal_align = nil
	
	panelTable.origin = handAttachment:GetAttachmentOrigin(handAttachment:ScriptLookupAttachment("pause_hint"))
	panelTable.dialog_layout_name = "file://{resources}/layout/custom_destination/pole_pause_hint.xml"
	
	pauseHintPanel = SpawnEntityFromTableSynchronous("point_clientui_world_panel", panelTable)
	pauseHintPanel:SetParent(handAttachment, "pause_hint")
	
	panelTable.origin = handAttachment:GetAttachmentOrigin(handAttachment:ScriptLookupAttachment("teleport_hint"))
	panelTable.dialog_layout_name = "file://{resources}/layout/custom_destination/pole_teleport_hint.xml"
	
	teleportHintPanel = SpawnEntityFromTableSynchronous("point_clientui_world_panel", panelTable)
	teleportHintPanel:SetParent(handAttachment, "teleport_hint")
	
	panelTable.origin = handAttachment:GetAttachmentOrigin(handAttachment:ScriptLookupAttachment("lock_hint"))
	panelTable.dialog_layout_name = "file://{resources}/layout/custom_destination/pole_lock_hint.xml"
	
	lockHintPanel = SpawnEntityFromTableSynchronous("point_clientui_world_panel", panelTable)
	lockHintPanel:SetParent(handAttachment, "lock_hint")
	
end


function KillHintPanels()

	if gripHintPanel and IsValidEntity(gripHintPanel) then gripHintPanel:Kill() end
	if triggerHintPanel and IsValidEntity(triggerHintPanel) then triggerHintPanel:Kill() end
	if pauseHintPanel and IsValidEntity(pauseHintPanel) then pauseHintPanel:Kill() end
	if teleportHintPanel and IsValidEntity(teleportHintPanel) then teleportHintPanel:Kill() end
	if lockHintPanel and IsValidEntity(lockHintPanel) then lockHintPanel:Kill() end
	
	gripHintPanel = nil
	triggerHintPanel = nil
	pauseHintPanel = nil
	teleportHintPanel = nil
	lockHintPanel = nil
	
end

function UpdateOnRemove()

	

	if isCarried
	then
		playerPhys:RemoveDragConstraint(playerEnt, thisEntity)
	end
	
	if gripHintPanel
	then
		KillHintPanels()
	end
end



function TriggerThink()
	if not triggerHeld
	then
		return
	end
	
	if gripHintPanel
	then
		KillHintPanels()
		--GameRules:GetGameModeEntity().SkiMode.players[playerEnt].hintsSpawned = true
	end

	RumbleController(2, 0.3, 60)

	if extended
	then
		extended = false
		Disable()
		DoEntFireByInstanceHandle(poleAnim, "SetAnimationNoReset", "retracted", 0 , nil, nil)
		DoEntFireByInstanceHandle(poleAnim, "SetDefaultAnimation", "retracted", 0 , nil, nil)
	else
		extended = true
		Enable()
		DoEntFireByInstanceHandle(poleAnim, "SetAnimationNoReset", "extended", 0 , nil, nil)
		DoEntFireByInstanceHandle(poleAnim, "SetDefaultAnimation", "extended", 0 , nil, nil)
		poleAnim:SetPoseParameter("pole_length", poleLength)
	end
end



function Enable()
	enabled = true
end


function Disable()
	enabled = false
end


function GetAttachment()
	return handAttachment
end


function ToggleSkis(self, eventData)
	local player = GetPlayerFromUserID(eventData.id)

	if  playerEnt and player == playerEnt
	then
		skisEnabled = not skisEnabled
		
	end
end


function KillSkis()
	if IsValidEntity(ski0)
	then
		ski0:Kill()
	end
	
	if IsValidEntity(ski1)
	then
		ski1:Kill()
	end
	
	ski0 = nil
	ski1 = nil
end

function UpdateSkis()
	if not isCarried
	then
		KillSkis()
		
		return nil
	end
	
	local playerScope = playerEnt:GetOrCreatePrivateScriptScope()
	if not playerScope.ActiveSkiContoller or not IsValidEntity(playerScope.ActiveSkiContoller)
	then
		playerScope.ActiveSkiContoller = thisEntity
		
	elseif playerScope.ActiveSkiContoller ~= thisEntity
	then
		
		KillSkis()
	
		return ALIGN_INTERVAL
	end
	
	local hand0Pos = nil
	local hand1Pos = nil
	
	local hmd = playerEnt:GetHMDAvatar()
	
	local hand0 = hmd:GetVRHand(0)
	local hand1 = hmd:GetVRHand(1)
	
	hand0Pos = hand0:GetOrigin()
	if hand0Pos:Length() == 0
	then
		hand0Pos = hmd:GetOrigin()
	end
	
	hand1Pos = hand1:GetOrigin()
	if hand1Pos:Length() == 0
	then
		hand1Pos = hmd:GetOrigin()
	end

	-- The ski direction is orthogonal to the line between the hands on the xy plane.
	local skiDir = (hand0Pos - hand1Pos):Cross(Vector(0, 0, 1)):Normalized()

	if not skisEnabled then
	
		KillSkis()
	
	else

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
	local velocity = playerPhys:GetVelocity(playerEnt)
	local speed = velocity:Length()
	
	if velocity and speed > 10
	then
		local velXY = Vector(velocity.x, velocity.y, 0):Normalized()
		skiDragFactor = velXY:Dot(skiDirOrth) * 8
	end
	
	local dragMagnitude = 0
	
	if playerPhys:TrySetDragConstraint(playerEnt, thisEntity)
	then
		local groundMoveDir = skiDir:Cross(traceTable.normal)
		local skiMoveDir = groundMoveDir:Cross(traceTable.normal)
		
		local playerHeightFac = ((playerEnt:GetCenter().z - playerEnt:GetHMDAnchor():GetOrigin().z) * 2) 
			/ PLAYER_FULL_HEIGHT * PLAYER_HEIGHT_DRAG_FACTOR

		local velNorm = velocity:Normalized()
			
		local skiCoVelocity = velocity:Dot(skiMoveDir)
		local groundCoVelocity = velocity:Dot(groundMoveDir)
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
			skiDir, heightFac, traceTable.normal)
			
		AlignSki(ski1, alignTop - skiDirOrth * SKI_SEPARATION + skiDir * skiDragFactor, 
			skiDir, heightFac, traceTable.normal)
		
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
			
			local particleVel = traceTable.normal * min(speed * 0.2, 40)	
			-- Match the particles to the player speed at high velocieties
			particleVel = particleVel + velocity * speed / (speed + 100)
			
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
	
	UpdateSkiSound(velocity, skiDir, dragMagnitude)
	
	return ALIGN_INTERVAL
end


function sign(x)
	return x > 0 and 1 or x < 0 and -1 or 1
end



function UpdateSkiSound(velocity, skiDir, dragMagnitude)

	local onGround = playerPhys:IsPlayerOnGround(playerEnt)
	local isPaused = g_VRScript.pauseManager:IsPaused(playerEnt)
	turnSoundCounter = turnSoundCounter - ALIGN_INTERVAL

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
		
	--[[if not idle and not isPaused
	then
		local velXY = Vector(velocity.x, velocity.y, 0):Normalized()
		local skiDirXY = Vector(skiDir.x, skiDir.y, 0):Normalized()
	
		if turnSoundCounter <= 0 and onGround and velocity:Length() > 150
			and abs(skiDirXY:Dot(velXY)) < 0.98 
			and (previousSkiDir == nil or previousSkiDir:Dot(skiDirXY) < 0.5) 
		then
			turnSoundCounter = 1.0
			playerEnt:EmitSound("Ski.Turn")
			previousSkiDir = skiDirXY

		end
	end]]
	
	local oldLevel = moveSoundLevel		
	moveSoundLevel = PlayerMoveSoundLevel(playerEnt, velocity:Length())
	if not onGround
	then
		playerEnt:StopSound("Ski.Noise" .. oldLevel)
		--moveSoundLevel = 0
		moveSoundCounter = 0
	else
		moveSoundCounter = moveSoundCounter - ALIGN_INTERVAL
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
		carveSoundCounter = carveSoundCounter - ALIGN_INTERVAL
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


function AlignSki(ski, origin, skiDir, heightFac, groundNormal)
	local baseTraceEnd = playerEnt:GetHMDAnchor():GetOrigin().z
	local skiDirOrth = skiDir:Cross(Vector(0,0,1))
	local skiNormal = nil
	
	if heightFac <= 0
	then
		local skiFront = SkiTrace(origin + skiDir * 24, baseTraceEnd - 24)
		local skiCenter = SkiTrace(Vector(origin.x, origin.y, baseTraceEnd + 4), baseTraceEnd - 8)
		local skiBack = SkiTrace(origin - skiDir * 24, baseTraceEnd - 16)
		
		-- Center vector if front and back form a bridge 
		local skiCenterCalc = skiBack + (skiFront - skiBack) / 2

		if skiCenterCalc.z > skiCenter.z
		then
			ski:SetOrigin(skiCenterCalc)
			skiNormal = (skiCenterCalc - skiBack):Cross(skiDirOrth)
		else
			ski:SetOrigin(skiCenter)
			skiNormal = (skiCenter - skiBack):Cross(skiDirOrth)
		end
		
		if debugDraw
		then
			DebugDrawLine(skiFront, skiBack, 255, 0, 255, true, ALIGN_INTERVAL)
		end
	else
		ski:SetOrigin(Vector(origin.x, origin.y, baseTraceEnd))
		skiNormal = -SplineVectors(groundNormal, Vector(0, 0, 1), heightFac)
	end

	local ang = VectorToAngles(skiNormal:Cross(skiDirOrth))
	ski:SetAngles(ang.x, ang.y, ang.z)
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
		solid = 0
	}
	
	local ski = SpawnEntityFromTableSynchronous("prop_dynamic", keyvals)
	
	return ski
end


function IsTouchingGround()
	
	return playerMoved
end



function TracePush()

	if not isCarried
	then
		return nil
	end

	if not extended
	then
		return PUSH_TRACE_INTERVAL
	end
	
	local poleStart = poleAnim:ScriptLookupAttachment("pole_start")
	local poleEnd = poleAnim:ScriptLookupAttachment("pole_end")	

	local traceTable =
	{
		startpos = poleAnim:GetAttachmentOrigin(poleStart);
		endpos = poleAnim:GetAttachmentOrigin(poleEnd);
		ignore = playerEnt

	}
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, 0.5)
	TraceLine(traceTable)
	
	if traceTable.hit 
	then
		--DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 255, 0, false, 0.5)
		
		
		if traceTable.enthit 
		then
			if traceTable.enthit == handEnt
			then
				return PUSH_TRACE_INTERVAL
			end

		end 
	
		if not playerMoved
		then
			--StartSoundEvent("SkiPole.Hit", self.handEnt)
			RumbleController(2, 0.2, 1)
			grabEndpoint = traceTable.pos
			playerMoved = true
			sprayParticle = ParticleManager:CreateParticle("particles/tools/ski_pole_snow_spray.vpcf", 
				PATTACH_CUSTOMORIGIN, thisEntity)
			ParticleManager:SetParticleControl(sprayParticle, 0, traceTable.pos)
			return PUSH_TRACE_INTERVAL
		end
	
		local distanceVector = (grabEndpoint - traceTable.pos)
		--DebugDrawLine(traceTable.pos, traceTable.pos + distanceVector, 0, 0, 255, true, 0.5)
		
		local pullVector = distanceVector:Normalized()
		
		local depth = (traceTable.pos - traceTable.endpos):Length()
		
		local distance = distanceVector:Length()
		--DebugDrawLine(traceTable.pos, self.grabEndpoint, 0, 255, 0, false, 0.5)
		
		local normal = (traceTable.startpos - traceTable.pos):Normalized()
		local coDirection = pullVector:Dot(normal)
		
		local dragFactor = (coDirection + 1) / 2
		
		-- At low speeds, directly move the player to keep the pole in the same position. 
		--[[if playerPhys:GetVelocity(playerEnt):Length() < POLE_FORCE_MOVE_MAX_SPEED and
			distance < POLE_FORCE_MOVE_MAX_DISTANCE and distance > POLE_FORCE_MOVE_MIN_DISTANCE and
			coDirection > POLE_DRAG_DOT
		then
			local controller = playerEnt:GetOrCreatePrivateScriptScope().ActiveSkiContoller
			if not controller or not IsValidEntity(controller) or
				controller == thisEntity or not controller:GetPrivateScriptScope():IsTouchingGround()
			then
				playerPhys:AddVelocity(playerEnt, distanceVector * 1)
				--playerPhys:MovePlayer(playerEnt, distanceVector, false)
				--playerPhys:StickFrame(playerEnt)
			end
		end]]
	
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
		local pushVector = traceTable.normal * (depth + 16) * POLE_LIFT_FACTOR
		
	
		if distance > GRAB_PULL_MIN_DISTANCE
		then
			local distSqr = distance * distance
		
			if distSqr < GRAB_PULL_PLAYER_SPEED
			then 
				pullVector = pullVector * distSqr
			else
				pullVector = pullVector * GRAB_PULL_PLAYER_SPEED
			end
				
			pushVector = pushVector + pullVector * dragFactor
		end	
		
		local playerVel = playerPhys:GetVelocity(playerEnt)
		local playerSpeed = playerVel:Length()
		
		if playerSpeed > 0 then
		
			--DebugDrawLine(traceTable.pos, traceTable.pos + pullVector, 255, 0, 0, true, 0.5)
			playerPhys:AddVelocity(playerEnt, pushVector)
		
		else -- If the player is stopped, store force until there is enough to overcome the stop speed.
		
			if not startVelocityAccumulate then
				startVelocityAccumulate = pushVector
			else
				startVelocityAccumulate = startVelocityAccumulate + pushVector
			end 
			
			if startVelocityAccumulate:Length() > 35 then 
				
				playerPhys:AddVelocity(playerEnt, startVelocityAccumulate)
				startVelocityAccumulate = nil
			end
		end
		
		ParticleManager:SetParticleControl(sprayParticle, 0, traceTable.pos)
		--ParticleManager:SetParticleControlForward(sprayParticle, 0, traceTable.normal)
		
		
		local particleVel = traceTable.normal * min(playerSpeed * 0.5, 60)
		
		-- Match the particles to the player speed at high velocieties
		particleVel = particleVel + playerVel * playerSpeed / (playerSpeed + 100)
	
		ParticleManager:SetParticleControl(sprayParticle, 1,  particleVel)
	
	
	else
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
	
	return PUSH_TRACE_INTERVAL
end


function sign(x)
	return x > 0 and 1 or x < 0 and -1 or 1
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


