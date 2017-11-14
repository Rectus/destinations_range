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


-- Dynamic prop visible when attached, since the physics prop can't be frozen in place.
local animKeyvals = {
	classname = "prop_dynamic";
	targetname = "suction_cup_anim";
	model = "models/weapons/suction_cup.vmdl";
	solid = 0
}


function Precache(context)

	PrecacheModel(animKeyvals.model, context)
	PrecacheSoundFile("soundevents/soundevents_addon.vsndevts", context)
end


function SetEquipped( self, pHand, nHandID, pHandAttachment, pPlayer )
	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	isCarried = true
	
	thisEntity:SetThink(TraceGrab, "trace_grab", 0.5)
	targetFound = false
	isTargeting = true
	
	if not propAnim
	then
		
		animKeyvals.origin = thisEntity:GetOrigin()
		animKeyvals.angles = thisEntity:GetAngles()
		propAnim = SpawnEntityFromTableSynchronous(animKeyvals.classname, animKeyvals)
		propAnim:SetOrigin(thisEntity:GetOrigin())
		DoEntFireByInstanceHandle(propAnim, "SetBodygroup", "off", 0, nil, nil)	
		DoEntFireByInstanceHandle(propAnim, "SetSequence", "idle", 0, nil, nil)
	end
	
	local paintColor = thisEntity:GetRenderColor()
	handAttachment:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	return true
end

function SetUnequipped()
	if isGrabbing
	then
		ReleaseHold(self)
	end
	
	local paintColor = handAttachment:GetRenderColor()
	thisEntity:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
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

	-- Even uglier ternary operator
	local IN_TRIGGER = (handID == 0 and IN_USE_HAND0 or IN_USE_HAND1)
	local IN_GRIP = (handID == 0 and IN_GRIP_HAND0 or IN_GRIP_HAND1)

	
	if input.buttonsPressed:IsBitSet(IN_TRIGGER)
	then
		input.buttonsPressed:ClearBit(IN_TRIGGER)
		OnTriggerPressed(self)
	end
	
	if input.buttonsReleased:IsBitSet(IN_TRIGGER) 
	then
		input.buttonsReleased:ClearBit(IN_TRIGGER)
		OnTriggerUnpressed(self)
	end
	
	if input.buttonsReleased:IsBitSet(IN_GRIP)
	then
		input.buttonsReleased:ClearBit(IN_GRIP)
		thisEntity:ForceDropTool();
	end


	return input;
end


function OnTriggerPressed(self)
	
	if isGrabbing
	then
		ReleaseHold(self)
			
	end
	isTargeting = false

end


function OnTriggerUnpressed(self)
	if not isGrabbing
	then
		thisEntity:SetThink(TraceGrab, "trace_grab", 0.5)
		targetFound = false
		isTargeting = true
	end
end



function ReleaseHold(self)
	isGrabbing = false

	DoEntFireByInstanceHandle(propAnim, "SetBodygroup", "off", 0, nil, nil)
	DoEntFireByInstanceHandle(handAttachment, "SetBodygroup", "on", 0, nil, nil)
	
	StartSoundEvent("Suctioncup.Release", thisEntity)
	RumbleController(2, 0.4, 20)
	
	if grabbedEnt
	then
		grabbedEnt:SetParent(nil, "")
		grabbedEnt = nil
	end
	
	if playerMoved
	then
		playerMoved = false
		g_VRScript.fallController:RemoveConstraint(playerEnt, thisEntity)
	end
end


function TraceGrab(self)
	if not isTargeting
	then 
		return nil
	end

	local traceTable =
	{
		startpos = GetMuzzlePos();
		endpos = GetMuzzlePos() + RotatePosition(Vector(0,0,0), 
				RotateOrientation(thisEntity:GetAngles(), MUZZLE_ANGLES_OFFSET), Vector(GRAB_MAX_DISTANCE, 0, 0));
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
		StartSoundEvent("Suctioncup.Attach", thisEntity)
		RumbleController(2, 0.2, 20)
	
		if grabbedEnt
		then
			grabbedEnt:SetOrigin(grabbedEnt:GetOrigin() + (traceTable.startpos - traceTable.pos))
			grabbedEnt:SetParent(handAttachment, "")
		else
			playerMoved = true
			g_VRScript.fallController:AddConstraint(playerEnt, thisEntity, true)

			thisEntity:SetThink(GrabMoveFrame, "grab_move")
			DoEntFireByInstanceHandle(propAnim, "SetBodygroup", "on", 0, nil, nil)
			DoEntFireByInstanceHandle(handAttachment, "SetBodygroup", "off", 0, nil, nil)
			
			propAnim:SetOrigin(grabEndpoint + RotatePosition(Vector(0,0,0), 
				RotateOrientation(thisEntity:GetAngles(), CARRY_ANGLES), Vector(0, 0, 0)))
			
			local fixupAngle = QAngle(90, 0, 0)
			local normalAngles = RotateOrientation(VectorToAngles(traceTable.normal), fixupAngle)	
			propAnim:SetAngles(normalAngles.x, normalAngles.y, normalAngles.z)
			-- TODO: roll the attached prop to match tool
		end	
		
		return nil
	end
	
	grabbedEnt = nil
	targetFound = false
	return GRAB_TRACE_INTERVAL
end



function GrabMoveFrame(self)
	if not isGrabbing
	then
		return nil
	end
	
	if not g_VRScript.fallController:IsActive(playerEnt, thisEntity)
	then
		if (grabEndpoint - handEnt:GetOrigin()):Length() > RELEASE_DISTANCE
		then
			ReleaseHold(self)
			thisEntity:SetThink(TraceGrab, "trace_grab", 0.5)
			targetFound = false
			isTargeting = true
			return nil
		end
	
		return GRAB_MOVE_INTERVAL
	end
	
	local pullVector = nil
	local pullPos = GetMuzzlePos() --handEnt:GetOrigin() - RotatePosition(Vector(0,0,0), 
			--RotateOrientation(handEnt:GetAngles(), CARRY_ANGLES), MUZZLE_OFFSET) 
			--+ RotatePosition(Vector(0,0,0), handEnt:GetAngles(), CARRY_OFFSET)
	
	local gunRelativePos = pullPos - playerEnt:GetHMDAnchor():GetOrigin()
	
	
	pullVector = (grabEndpoint - pullPos):Normalized() * GRAB_PULL_PLAYER_SPEED
	 
	local distance = (grabEndpoint - pullPos):Length()

	
	if distance > GRAB_PULL_MIN_DISTANCE
	then
		if distance < GRAB_PULL_PLAYER_EASE_DISTANCE
		then 
			pullVector = pullVector * distance / GRAB_PULL_PLAYER_EASE_DISTANCE
		end
		-- Prevent player from going through floors
		if pullVector.z < 0 and g_VRScript.fallController:TracePlayerHeight(playerEnt) <= 0
		then
			pullVector = pullVector - Vector(0, 0, pullVector.z)
		end
		g_VRScript.fallController:MovePlayer(playerEnt, pullVector)
		--playerEnt:GetHMDAnchor():SetOrigin(playerEnt:GetHMDAnchor():GetOrigin() + pullVector)
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

function GetMuzzlePos()
	local idx = thisEntity:ScriptLookupAttachment("grabpos")
	return thisEntity:GetAttachmentOrigin(idx)
end

