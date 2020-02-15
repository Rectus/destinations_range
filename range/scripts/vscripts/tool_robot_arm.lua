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




local GRAB_MAX_DISTANCE = 2
local GRAB_PULL_MIN_DISTANCE = 0.1
local GRAB_MOVE_INTERVAL = 0.02
local MUZZLE_OFFSET = Vector(0, 0, -0.2)
local MUZZLE_ANGLES_OFFSET = QAngle(90, 0, 0) 

local GRAB_PULL_PLAYER_SPEED = 8
local GRAB_PULL_PLAYER_EASE_DISTANCE = 16
local GRAB_TRACE_INTERVAL = 0.02
local RELEASE_DISTANCE = 8

local CARRY_OFFSET = Vector(3.5, 0, -3)
local CARRY_ANGLES = QAngle(0, 90, 0)

local isCarried = false
local playerEnt = nil
local handEnt = nil
local grabEnt = nil
local grabbedEnt = nil
local grabEndpoint = nil
local playerMoved = false
local propAnim = nil
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



function Precache(context)

	PrecacheSoundFile("soundevents/soundevents_addon.vsndevts", context)
	
end



function SetEquipped( this, pHand, nHandID, pHandAttachment, pPlayer )
	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	isCarried = true
	
	handAttachment:SetProceduralIKTarget("arm_ik", "arm_target", GetMuzzlePos(), QAngle(0,0,0))
	handAttachment:SetProceduralIKTargetWeight("arm_ik", "arm_target", 1)
	handAttachment:SetSequence("script_arm_open")
	thisEntity:SetThink(TraceGrab, "trace_grab", 0.5)
	targetFound = false
	isTargeting = true
	
	local paintColor = thisEntity:GetRenderColor()
	handAttachment:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)

	thisEntity:SetThink(IdleFrame, "move", 0.1)
	return true
end

function SetUnequipped()
	if isGrabbing
	then
		ReleaseHold()
	end
	--thisEntity:SetProceduralIKTargetWeight("arm_ik", "arm_target", 0)
	playerEnt = nil
	handEnt = nil
	isCarried = false
	isTargeting = false
	
	local paintColor = handAttachment:GetRenderColor()
	thisEntity:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
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

	
	if input.buttonsPressed:IsBitSet(IN_TRIGGER)
	then
		input.buttonsPressed:ClearBit(IN_TRIGGER)
		OnTriggerPressed()
	end
	
	if input.buttonsReleased:IsBitSet(IN_TRIGGER) 
	then
		input.buttonsReleased:ClearBit(IN_TRIGGER)
		OnTriggerUnpressed()
	end
	
	if input.buttonsReleased:IsBitSet(IN_GRIP)
	then
		input.buttonsReleased:ClearBit(IN_GRIP)
		thisEntity:ForceDropTool();
	end


	return input;
end


function OnTriggerPressed()
	
	if isGrabbing
	then
		ReleaseHold()
			
	end
	isTargeting = false
	
	
end


function OnTriggerUnpressed()
	if not isGrabbing
	then
		thisEntity:SetThink(TraceGrab, "trace_grab", 0.5)
		targetFound = false
		isTargeting = true
	end
	
end



function ReleaseHold()
	isGrabbing = false
	
	StartSoundEvent("Suctioncup.Release", thisEntity)
	RumbleController(2, 0.4, 20)
	
	if grabbedEnt
	then
		--handAttachment:SetProceduralIKTargetWeight("arm_ik", "arm_target", 0)
		
		handAttachment:SetProceduralIKTarget("arm_ik", "arm_target", GetMuzzlePos(), thisEntity:GetAngles())
		handAttachment:SetSequence("arm_open")
		grabbedEnt:SetParent(nil, "")
		grabbedEnt = nil
		
	end
	thisEntity:SetVelocity(Vector(1000,1000,1000))
	thisEntity:SetThink(IdleFrame, "move", GRAB_MOVE_INTERVAL)
end


function TraceGrab()
	if not isTargeting
	then 
		return nil
	end
	
	for _, entClass in pairs(pulledEntities)
	do
	
	
		local ent = Entities:FindByClassnameNearest(entClass, GetMuzzlePos(), 48)
	
		if ent and IsValidEntity(ent) and ent ~= thisEntity and not ent:GetMoveParent()
		then
		
			local grabLoc = CalcClosestPointOnEntityOBB(ent, GetMuzzlePos())
			
			if (grabLoc - thisEntity:GetOrigin()):Length() < 22
			then
				print(ent:GetDebugName())
				grabbedEnt = ent
				grabEndpoint = ent:GetCenter()
				targetFound = true
				isTargeting = false
				isGrabbing = true
				StartSoundEvent("Suctioncup.Attach", thisEntity)
				RumbleController(2, 0.2, 20)
				handAttachment:SetSequence("arm_closed")
		
				local ang = VectorToAngles(grabLoc - GetMuzzlePos())
				
				
				if not grabEnt or not IsValidEntity(grabEnt)
				then
					grabEnt = SpawnEntityFromTableSynchronous("info_target", {origin = grabLoc})
				end
				grabEnt:SetParent(ent, "")
				grabEnt:SetAbsOrigin(grabLoc)
				
				handAttachment:SetProceduralIKTarget("arm_ik", "arm_target", grabLoc, ang)
				thisEntity:SetProceduralIKTarget("arm_ik", "arm_target", grabLoc, ang)
				handAttachment:SetProceduralIKTargetWeight("arm_ik", "arm_target", 1)
				grabbedEnt:SetParent(handAttachment, "")
				thisEntity:SetThink(GrabMoveFrame, "move", GRAB_MOVE_INTERVAL)
			return nil
			end
		end	
		
		
	end
	
	grabbedEnt = nil
	targetFound = false
	return GRAB_TRACE_INTERVAL
end



function GrabMoveFrame()
	if not isGrabbing or not grabbedEnt or not IsValidEntity(grabbedEnt)
	then
		return nil
	end
	
	local ang = VectorToAngles(grabEnt:GetOrigin() - GetMuzzlePos())
	handAttachment:SetProceduralIKTarget("arm_ik", "arm_target", grabEnt:GetOrigin(), ang)
		
	return GRAB_MOVE_INTERVAL
end


function IdleFrame()
	if isGrabbing
	then
		return nil
	end

	local ent = thisEntity
	
	if handAttachment and IsValidEntity(handAttachment)
	then
		ent = handAttachment
	end

	ent:SetProceduralIKTarget("arm_ik", "arm_target", GetMuzzlePos(), ent:GetAngles())
		
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

function GetMuzzlePos()
	local ent = thisEntity
	
	if handAttachment and IsValidEntity(handAttachment)
	then
		ent = handAttachment
	end

	local idx = ent:ScriptLookupAttachment("claw_rest_pos")
	return ent:GetAttachmentOrigin(idx)
end

