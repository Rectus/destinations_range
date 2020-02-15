--[[
	Suction cup script.
	
	Copyright (c) 2016 Rectus
	
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

local GRAB_MAX_DISTANCE = 3
local GRAB_PULL_MIN_DISTANCE = 0.1
local GRAB_MOVE_INTERVAL = 0.01
local MUZZLE_OFFSET = Vector(0, 0, -0.2)
local MUZZLE_ANGLES_OFFSET = QAngle(90, 0, 0) 

local GRAB_PULL_PLAYER_SPEED = 8
local GRAB_PULL_PLAYER_EASE_DISTANCE = 16
local GRAB_TRACE_INTERVAL = 0.008
local RELEASE_DISTANCE = 8

local CARRY_OFFSET = Vector(3.5, 0, -3)
local CARRY_ANGLES = QAngle(0, 90, 0)

local isCarried = false
local playerEnt = nil
local handEnt = nil
local grabbedEnt = nil
local grabEndpoint = nil
local playerMoved = false
local propAttached = nil
local physProp = nil
local physConstraint = nil
local handID = 0
local handAttachment = nil

local rumbleTime = 0
local rumbleFreq = 0
local rumbleInt = 0

local isTargeting = false
local targetFound = false
local isGrabbing = false
local grabAngles = nil

local pulledEntities = {"prop_physics"; "prop_physics_override"; "simple_physics_prop"; "func_physbox";
	"prop_destinations_physics"; "prop_destinations_tool"}
local excludedEntities = {"player"}


-- Dynamic prop visible when attached, since the physics prop can't be frozen in place.
local attachedKeyvals = {
	classname = "prop_dynamic";
	targetname = "suction_cup_anim";
	model = "models/weapons/suction_cup.vmdl";
	solid = 0
}


local constraintKeyvals = {
	classname = "phys_genericconstraint";
	targetname = "";
	attach1 = "";
	attach2 = "";
	
	linear_motion_x = "JOINT_MOTION_LOCKED";
	linear_frequency_x = 10;
	linear_damping_ratio_x = 0.8;
	
	linear_motion_y = "JOINT_MOTION_LOCKED";
	linear_frequency_y = 10;
	linear_damping_ratio_y = 0.8;
	
	linear_motion_z = "JOINT_MOTION_LOCKED";
	linear_frequency_z = 10;
	linear_damping_ratio_z = 0.8;
	
	angular_motion_x = "JOINT_MOTION_LOCKED";
	angular_frequency_x = 20;
	angular_damping_ratio_x = 10;
	
	angular_motion_y = "JOINT_MOTION_LOCKED";
	angular_frequency_y = 20;
	angular_damping_ratio_y = 10;
	
	angular_motion_z = "JOINT_MOTION_LOCKED";
	angular_frequency_z = 20;
	angular_damping_ratio_z = 10;
}
constraintKeyvals["spawnflags#0"] = "1"


local viewKeyvals = {
	classname = "prop_destinations_physics";
}


function Precache(context)

	PrecacheModel(attachedKeyvals.model, context)
	PrecacheSoundFile("soundevents/soundevents_addon.vsndevts", context)
end


function SetEquipped( this, pHand, nHandID, pHandAttachment, pPlayer )
	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	isCarried = true
	
	SpawnProps()
	handAttachment:AddEffects(32)
	
	thisEntity:SetThink(TraceGrab, "trace_grab", 0.5)
	targetFound = false
	isTargeting = true
	
	local paintColor = thisEntity:GetRenderColor()
	handAttachment:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	physProp:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	propAttached:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	return true
end


function SpawnProps()
	
	viewKeyvals.model = thisEntity:GetModelName()
	viewKeyvals.angles = handAttachment:GetAngles()
	viewKeyvals.origin = handAttachment:GetAbsOrigin()
	
	physProp = SpawnEntityFromTableSynchronous(viewKeyvals.classname, viewKeyvals)
	physProp:EnableUse(false)
	
	attachedKeyvals.model = thisEntity:GetModelName()
	attachedKeyvals.origin = handAttachment:GetAbsOrigin()
	attachedKeyvals.angles = handAttachment:GetAngles()
	propAttached = SpawnEntityFromTableSynchronous(attachedKeyvals.classname, attachedKeyvals)
	propAttached:SetParent(handAttachment, "")
	propAttached:AddEffects(32)	
	
	propAttached:SetEntityName(DoUniqueString("suction_cup_ent"))	
	physProp:SetEntityName(DoUniqueString("suction_cup_phys"))
	
	constraintKeyvals.origin = handAttachment:GetAbsOrigin()
	constraintKeyvals.attach2 = propAttached:GetName()
	constraintKeyvals.attach1 = physProp:GetName()

	physConstraint = SpawnEntityFromTableSynchronous(constraintKeyvals.classname, constraintKeyvals)
end


function SetUnequipped()
	if isGrabbing
	then
		ReleaseHold()
	end
	
	local paintColor = handAttachment:GetRenderColor()
	thisEntity:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	if physConstraint and IsValidEntity(physConstraint) then physConstraint:Destroy() end
	if propAttached and IsValidEntity(propAttached) then propAttached:Destroy() end
	if physProp and IsValidEntity(physProp) then physProp:Destroy() end
	
	physConstraint = nil
	physProp = nil
	propAttached = nil
	
	playerEnt = nil
	handEnt = nil
	isCarried = false
	isTargeting = false
	
	return true
end


function OnHandleInput( input )
	if not playerEnt
	then 
		return
	end

	local IN_TRIGGER = (handID == 0 and IN_USE_HAND0 or IN_USE_HAND1)

	if input.buttonsPressed:IsBitSet(IN_TRIGGER)
	then
		OnTriggerPressed()
	end
	
	if input.buttonsReleased:IsBitSet(IN_TRIGGER) 
	then
		OnTriggerUnpressed()
	end

	return input;
end


function OnTriggerPressed()
	
	if isGrabbing
	then
		ReleaseHold()
		RumbleController(1, 0.1, 40)
	else
		--physProp:SetSingleMeshGroup("no_phys")	
		physProp:SetAbsOrigin(handAttachment:GetAbsOrigin())
	end
	isTargeting = false

end


function OnTriggerUnpressed()
	if not isGrabbing
	then
		thisEntity:SetThink(TraceGrab, "trace_grab", 0.5)
		targetFound = false
		isTargeting = true
		--physProp:SetSingleMeshGroup("on")
	end
end



function ReleaseHold()
	isGrabbing = false

	
	StartSoundEvent("Suctioncup.Release", handAttachment)
	RumbleController(2, 0.4, 20)
	
	if physProp and IsValidEntity(physProp)
	then
		propAttached:AddEffects(32)	
		physProp:RemoveEffects(32)	
		propAttached:SetParent(handAttachment, "")
		propAttached:SetAbsOrigin(handAttachment:GetOrigin())
		physProp:SetAbsOrigin(handAttachment:GetOrigin())
		local ang = handAttachment:GetAngles()
		propAttached:SetAngles(ang.x, ang.y, ang.z)
	end
	
	if grabbedEnt and IsValidEntity(grabbedEnt)
	then
		grabbedEnt:SetParent(nil, "")
		grabbedEnt = nil
	end
	
	if playerMoved
	then
		playerMoved = false
		g_VRScript.playerPhysController:RemoveConstraint(playerEnt, thisEntity)
	end
end


function TraceGrab()
	if not isTargeting
	then 
		return nil
	end

	local traceTable =
	{
		startpos = GetGrabPos();
		endpos = GetGrabPos() + RotatePosition(Vector(0,0,0), 
				RotateOrientation(physProp:GetAngles(), MUZZLE_ANGLES_OFFSET), Vector(GRAB_MAX_DISTANCE, 0, 0));
		ignore = playerEnt

	}
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, 0.1)
	TraceLine(traceTable)
	
	if traceTable.hit 
	then
		--DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 255, 0, false, 0.2)
		
		grabbedEnt = nil
		
		if traceTable.enthit 
		then
			if traceTable.enthit == thisEntity or traceTable.enthit == handAttachment
				or traceTable.enthit == propAttached or traceTable.enthit == physProp
			then
				grabbedEnt = nil
				targetFound = false
				return GRAB_TRACE_INTERVAL
			end
		
			for _, entClass in ipairs(excludedEntities)
			do
				if traceTable.enthit:GetClassname() == entClass
				then
					grabbedEnt = nil
					targetFound = false
					return GRAB_TRACE_INTERVAL
				end
			end
		
			for _, entClass in ipairs(pulledEntities)
			do
				if traceTable.enthit:GetClassname() == entClass and traceTable.enthit:GetMoveParent() == nil
				then
					grabbedEnt = traceTable.enthit
				end
			end
		end
		
		grabEndpoint = traceTable.pos
		targetFound = true
		isTargeting = false
		isGrabbing = true
		StartSoundEvent("Suctioncup.Attach", handAttachment)
		RumbleController(2, 0.15, 30)
	
		if grabbedEnt
		then
			grabbedEnt:SetOrigin(grabbedEnt:GetOrigin() + (traceTable.startpos - traceTable.pos))
			grabbedEnt:SetParent(handAttachment, "")
		else
			playerMoved = true
			g_VRScript.playerPhysController:AddConstraint(playerEnt, thisEntity, true)

			thisEntity:SetThink(GrabMoveFrame, "grab_move")

			physProp:AddEffects(32)	
			propAttached:RemoveEffects(32)				
			
			propAttached:SetParent(nil, "")
			propAttached:SetOrigin(grabEndpoint + RotatePosition(Vector(0,0,0), 
				RotateOrientation(physProp:GetAngles(), CARRY_ANGLES), Vector(0, 0, 0)))
			
			local fixupAngle = QAngle(90, 0, 0)
			local normalAngles = RotateOrientation(VectorToAngles(traceTable.normal), fixupAngle)
			local yaw = MathUtils.TransformMatrix(physProp):GetInverse():GetOrientation().y
			local orientation = RotateOrientation(normalAngles, QAngle(0, AngleDiff(normalAngles.y, yaw), 0))
			propAttached:SetAngles(orientation.x, orientation.y, orientation.z)
		end	
		
		return nil
	end
	
	grabbedEnt = nil
	targetFound = false
	return GRAB_TRACE_INTERVAL
end



function GrabMoveFrame()
	if not isGrabbing
	then
		return nil
	end
	
	if not g_VRScript.playerPhysController:IsActive(playerEnt, thisEntity)
	then
		if (grabEndpoint - handEnt:GetOrigin()):Length() > RELEASE_DISTANCE
		then
			ReleaseHold()
			thisEntity:SetThink(TraceGrab, "trace_grab", 0.5)
			targetFound = false
			isTargeting = true
			return nil
		end
	
		return GRAB_MOVE_INTERVAL
	end
	
	local pullVector = nil
	local pullPos = GetControllerPos() 
	local gunRelativePos = pullPos - playerEnt:GetHMDAnchor():GetOrigin()
	
	
	pullVector = (grabEndpoint - pullPos):Normalized() * GRAB_PULL_PLAYER_SPEED
	 
	local distance = (grabEndpoint - pullPos):Length()

	
	if distance > GRAB_PULL_MIN_DISTANCE
	then
		if distance < GRAB_PULL_PLAYER_EASE_DISTANCE
		then 
			pullVector = pullVector * distance / GRAB_PULL_PLAYER_EASE_DISTANCE
		end

		g_VRScript.playerPhysController:MovePlayer(playerEnt, pullVector, false, false, thisEntity)
	end
		
	return GRAB_MOVE_INTERVAL
end

function RumbleController(intensity, length, frequency)
	if handEnt
	then
		rumbleTime = length
		rumbleFreq = frequency
		rumbleInt = intensity
	end
	thisEntity:SetThink(RumbleThink, "rumble", 1 / rumbleFreq)
end
		
function RumbleThink()
	local interval = 1 / rumbleFreq
	if handEnt
	then
		handEnt:FireHapticPulse(rumbleInt)
		
		rumbleTime = rumbleTime - interval
		if rumbleTime < interval
		then
			rumbleTime = 0
			return nil
		end
	
		return interval
	end
	return nil
end

function GetGrabPos()
	local idx = physProp:ScriptLookupAttachment("grabpos")
	return physProp:GetAttachmentOrigin(idx)
end

function GetControllerPos()
	local idx = handAttachment:ScriptLookupAttachment("grabpos")
	return handAttachment:GetAttachmentOrigin(idx)
end

