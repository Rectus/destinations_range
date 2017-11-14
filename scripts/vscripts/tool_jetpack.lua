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




local THRUST_INTERVAL = 0.015
local MOVE_CAP_FACTOR = 0.7
local THRUST_VERTICAL_SPEED = 400
local THRUST_HORIZONTAL_SPEED = 300
local TRIGGER_IN_BOOST = 1.3
local GROUND_EFFECT_HEIGHT = 64
local GROUND_EFFECT_FACTOR = 0.5

local playerEnt = nil
local handEnt = nil
local handID = 0
local handAttachment = nil
local thrusting = false
local exhaust = 0

local rumbleTime = 0
local rumbleFreq = 0
local rumbleInt = 0

local sphere = nil
local pack = nil
local padMovement = false
local padVector = Vector(0,0,0)
local triggerValue = 0
local triggerPressed = false
local gripLocked = false
local lockedPanel = nil


local PACK_KEYVALS = {
	classname = "prop_dynamic"; 
	targetname = "jetpack_equipped";
	model = "models/tools/jetpack_equipped.vmdl";
	solid = 0
}

local SPHERE_KEYVALS = {
	classname = "prop_dynamic"; 
	targetname = "jetpack_navsphere";
	model = "models/tools/jetpack_navsphere.vmdl";
	solid = 0
}

function Precache(context)
	PrecacheParticle("particles/tools/jetpack_exhaust.vpcf", context)
end


function SetEquipped( self, pHand, nHandID, pHandAttachment, pPlayer )
	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment

	handAttachment:SetSingleMeshGroup("equipped")

	--sphere = SpawnEntityFromTableSynchronous(SPHERE_KEYVALS.classname, SPHERE_KEYVALS)
	--sphere:SetParent(handAttachment, "navsphere")
	--sphere:SetLocalOrigin(Vector(0,0,0))
	
	sphere = ParticleManager:CreateParticle("particles/tools/jetpack_navsphere.vpcf", 
			PATTACH_POINT_FOLLOW, handAttachment)
				
	ParticleManager:SetParticleControlEnt(sphere, 0, handAttachment,
			PATTACH_POINT_FOLLOW, "navsphere", Vector(0,0,0), true)

	pack = SpawnEntityFromTableSynchronous(PACK_KEYVALS.classname, PACK_KEYVALS)
	UpdatePackPos()
	EmitSoundOn("Jetpack.Loop", pack)
	
	exhaust = ParticleManager:CreateParticle("particles/tools/jetpack_exhaust.vpcf", 
			PATTACH_POINT_FOLLOW, pack)
				
	ParticleManager:SetParticleControlEnt(exhaust, 0, pack,
			PATTACH_POINT_FOLLOW, "nozzle", Vector(0,0,0), true)
	
	thisEntity:SetThink(JetpackThrust, "thrust")
	
	playerEnt:AllowTeleportFromHand(handID, false)
	
	return true
end

function SetUnequipped()

	playerEnt:AllowTeleportFromHand(handID, true)

	playerEnt = nil
	handEnt = nil
	handAttachment = nil
	
	if pack and IsValidEntity(pack)
	then
		ParticleManager:DestroyParticle(exhaust, false)
		StopSoundOn("Jetpack.Loop", pack)
		pack:Kill()		
	end
	pack = nil
	
	--if sphere and IsValidEntity(sphere)
	--then
		--sphere:Kill()
	--end
	ParticleManager:DestroyParticle(sphere, false)
	sphere = nil
	
	return true
end


function OnHandleInput( input )
	if not playerEnt
	then 
		return
	end

	-- Even uglier ternary operator
	local IN_TRIGGER = (handID == 0 and IN_USE_HAND0 or IN_USE_HAND1)
	local IN_GRIP = (handID == 0 and IN_GRIP_HAND0 or IN_GRIP_HAND1)
	local IN_PAD = (handID == 0 and IN_PAD_HAND0 or IN_PAD_HAND1)
	local IN_PAD_TOUCH = (handID == 0 and IN_PAD_TOUCH_HAND0 or IN_PAD_TOUCH_HAND1)	
	local IN_JOY_TOUCH = (handID == 0 and 42 or 43)
	local IN_JOY_PUSH = (handID == 0 and IN_PAD_TOUCH_HAND0 or IN_PAD_TOUCH_HAND1)


	if playerEnt:GetVRControllerType() == VR_CONTROLLER_TYPE_TOUCH then
			
		if input.buttonsPressed:IsBitSet(IN_JOY_PUSH)
		then
			ToggleGripLock()
		end
		
		if input.buttonsPressed:IsBitSet(IN_JOY_TOUCH)
		then
			input.buttonsPressed:ClearBit(IN_JOY_TOUCH)
			padMovement = true
			
		end
		
		if input.buttonsReleased:IsBitSet(IN_JOY_TOUCH) 
		then
			input.buttonsReleased:ClearBit(IN_JOY_TOUCH)
			padMovement = false
		end
		
	else -- Vive controller
	
		if input.buttonsPressed:IsBitSet(IN_PAD_TOUCH)
		then
			input.buttonsPressed:ClearBit(IN_PAD_TOUCH)
			padMovement = true
			
		end
		
		if input.buttonsReleased:IsBitSet(IN_PAD_TOUCH) 
		then
			input.buttonsReleased:ClearBit(IN_PAD_TOUCH)
			padMovement = false
		end
	
		-- Needed to disable teleports
		if input.buttonsDown:IsBitSet(IN_PAD) 
		then
			input.buttonsDown:ClearBit(IN_PAD)
		end	
		if input.buttonsDown:IsBitSet(IN_PAD_TOUCH) 
		then
			input.buttonsDown:ClearBit(IN_PAD_TOUCH)
		end
		
	end

	
	if input.buttonsPressed:IsBitSet(IN_TRIGGER)
	then
		input.buttonsPressed:ClearBit(IN_TRIGGER)
		triggerPressed = true
	end
	
	if input.buttonsReleased:IsBitSet(IN_TRIGGER) 
	then
		input.buttonsReleased:ClearBit(IN_TRIGGER)
		triggerPressed = false
	end
	
	if input.buttonsReleased:IsBitSet(IN_GRIP)
	then
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

	
	if padMovement
	then	
		padVector = Vector(input.trackpadX, input.trackpadY, 0)
	else
		padVector = Vector(0,0,0)
	end
	
	triggerValue = input.triggerValue

	return input;
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



function UpdatePackPos()

	if not playerEnt or not (pack and IsValidEntity(pack))
	then 
		return
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
	

	local packDir = (hand1Pos - hand0Pos):Cross(Vector(0, 0, 1)):Normalized()
	
	pack:SetAbsOrigin(hmd:GetOrigin() + packDir * 16 + Vector(0, 0, -12))
	pack:SetAbsAngles(0, VectorToAngles(packDir).y - 90, 0)

end


function JetpackThrust(self)

	if not handAttachment
	then 
		return
	end
	
	UpdatePackPos()
		
	if not thrusting and triggerValue > 0.2
	then
		StopSoundOn("drone_speed_dec", pack)
		EmitSoundOn("drone_speed_acc", pack)
		thrusting = true
	elseif thrusting and triggerValue <= 0.2
	then
		StopSoundOn("drone_speed_acc", pack)
		EmitSoundOn("drone_speed_dec", pack)
		thrusting = false
	end
	
	local sphereOrigin = handAttachment:GetAttachmentOrigin(handAttachment:ScriptLookupAttachment("navsphere"))
	
	if padMovement then
		if g_VRScript.fallController:TrySetDragConstraint(playerEnt, thisEntity) then
			g_VRScript.fallController:SetDrag(playerEnt, thisEntity, 1e-4, 2, nil, nil)
		end
	else
		g_VRScript.fallController:RemoveDragConstraint(playerEnt, thisEntity)
	end 
	
	if padMovement or triggerValue >0.01 then

	
		local toolForward = RotateOrientation(QAngle(0, handAttachment:GetAngles().y, 0), QAngle(0, 180, 0))
		local horizontalVec = RotatePosition(Vector(0,0,0), toolForward, padVector)
		
		--DebugDrawLine(handAttachment:GetOrigin(), handAttachment:GetOrigin() + padVector * 10, 255, 255, 0, false, 0.02)
		--DebugDrawLine(handAttachment:GetOrigin(), handAttachment:GetOrigin() + moveVector * 10, 0, 0, 255, false, 0.02)
		
		
		if horizontalVec:Length() > MOVE_CAP_FACTOR
		then
			horizontalVec = horizontalVec:Normalized() * MOVE_CAP_FACTOR
		end
		
		
		ParticleManager:SetParticleControl(sphere, 1, sphereOrigin + horizontalVec * 4)
		
		
		local verticalVector = Vector(0, 0,  triggerValue)
		
		if triggerPressed
		then
			verticalVector = verticalVector * TRIGGER_IN_BOOST
		end
		
		ParticleManager:SetParticleControl(sphere, 2, sphereOrigin + verticalVector * 4)
		
		local playerHeight = g_VRScript.fallController:TracePlayerHeight(playerEnt) 
		
		if playerHeight < GROUND_EFFECT_HEIGHT
		then
			verticalVector = verticalVector * (1 + GROUND_EFFECT_FACTOR * (1 - playerHeight / GROUND_EFFECT_HEIGHT))
		end
		
		local thrustVector = (horizontalVec * THRUST_HORIZONTAL_SPEED) + (verticalVector * THRUST_VERTICAL_SPEED)
		
		g_VRScript.fallController:AddVelocity(playerEnt, thrustVector * THRUST_INTERVAL)
		
	else
		ParticleManager:SetParticleControl(sphere, 1, sphereOrigin)
		ParticleManager:SetParticleControl(sphere, 2, sphereOrigin)
	end
	
	local dispVel = g_VRScript.fallController:GetVelocity(playerEnt) * (4 / THRUST_VERTICAL_SPEED)
	if dispVel:Length() > 4
	then
		dispVel = dispVel:Normalized() * 4
	end
	
	ParticleManager:SetParticleControl(sphere, 3, sphereOrigin + dispVel)
	
	return THRUST_INTERVAL
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


function RumbleController(self, intensity, length, frequency)
	if handEnt
	then
		if rumbleTime == 0
		then
			rumbleTime = length
			rumbleFreq = frequency
			rumbleInt = intensity
		end
		
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

