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

--require("particle_system")

g_VRScript.pickupManager:RegisterEntity(thisEntity)

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

local rumbleTime = 0
local rumbleFreq = 0
local rumbleInt = 0

local isTargeting = false
local targetFound = false
local isGrabbing = false
local grabAngles = nil

local pulledEntities = {"prop_physics"; "prop_physics_override"; "simple_physics_prop"; "func_physbox"}
local excludedEntities = {"player"}


-- Dynamic prop visible when attached, since the physics prop can't be frozen in place.
animKeyvals = {
	classname = "prop_dynamic";
	targetname = "suction_cup_anim";
	model = "models/weapons/suction_cup.vmdl";
	solid = 0
}


function Precache(context)

	PrecacheModel(animKeyvals.model, context)
	PrecacheSoundFile("soundevents/soundevents_addon.vsndevts", context)
end


function Init(self)
	animKeyvals.origin = thisEntity:GetOrigin()
	animKeyvals.angles = thisEntity:GetAngles()
	propAnim = SpawnEntityFromTableSynchronous(animKeyvals.classname, animKeyvals)
	propAnim:SetOrigin(thisEntity:GetOrigin())
	DoEntFireByInstanceHandle(propAnim, "SetBodygroup", "off", 0, nil, nil)	
	DoEntFireByInstanceHandle(propAnim, "SetSequence", "idle", 0, nil, nil)

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


function OnPickedUp(self, hand, player)
	hand:AddHandModelOverride("models/weapons/hand_dummy.vmdl")
	playerEnt = player
	handEnt = hand
	thisEntity:SetParent(hand, "")
	thisEntity:SetOrigin(hand:GetOrigin() + RotatePosition(Vector(0,0,0), hand:GetAngles(), CARRY_OFFSET))
	local carryAngles = RotateOrientation(hand:GetAngles(), CARRY_ANGLES)
	thisEntity:SetAngles(carryAngles.x, carryAngles.y, carryAngles.z)
	
	thisEntity:SetThink(TraceGrab, "trace_grab", 0.5)
	targetFound = false
	isTargeting = true
end


function OnDropped(self, hand, player)
	hand:RemoveHandModelOverride("models/weapons/hand_dummy.vmdl")
	if isGrabbing
	then
		ReleaseHold(self)
	end
	playerEnt = nil
	handEnt = nil
	isTargeting = false

	thisEntity:SetParent(nil, "")
end




function ReleaseHold(self)
	isGrabbing = false

	DoEntFireByInstanceHandle(propAnim, "SetBodygroup", "off", 0, nil, nil)
	DoEntFireByInstanceHandle(thisEntity, "SetBodygroup", "on", 0, nil, nil)
	
	StartSoundEvent("Suctioncup.Release", thisEntity)
	RumbleController(thisEntity, 2, 0.4, 20)
	
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
	
	if playerEnt
	then
		thisEntity:SetParent(handEnt, "")
		thisEntity:SetOrigin(handEnt:GetOrigin() + RotatePosition(Vector(0,0,0), handEnt:GetAngles(), CARRY_OFFSET))
		local carryAngles = RotateOrientation(handEnt:GetAngles(), CARRY_ANGLES)
		thisEntity:SetAngles(carryAngles.x, carryAngles.y, carryAngles.z)
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
			if traceTable.enthit == thisEntity
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
		RumbleController(thisEntity, 2, 0.2, 20)
	
		if grabbedEnt
		then
			grabbedEnt:SetOrigin(grabbedEnt:GetOrigin() + (traceTable.startpos - traceTable.pos))
			grabbedEnt:SetParent(thisEntity, "")
		else
			playerMoved = true
			g_VRScript.fallController:AddConstraint(playerEnt, thisEntity, true)
			thisEntity:SetParent(nil, "")
			thisEntity:SetThink(GrabMoveFrame, "grab_move")
			DoEntFireByInstanceHandle(propAnim, "SetBodygroup", "on", 0, nil, nil)
			DoEntFireByInstanceHandle(thisEntity, "SetBodygroup", "off", 0, nil, nil)
			grabAngles = thisEntity:GetAngles()
			thisEntity:SetThink(AnimSetAngles, "angles_think", 0.1)
			propAnim:SetOrigin(grabEndpoint + RotatePosition(Vector(0,0,0), 
				RotateOrientation(thisEntity:GetAngles(), CARRY_ANGLES), Vector(0, 0, 0)))
			propAnim:SetAngles(grabAngles.x, grabAngles.y, grabAngles.z)
		end	
		
		return nil
	end
	
	grabbedEnt = nil
	targetFound = false
	return GRAB_TRACE_INTERVAL
end

-- Allows the physics prop to collide and settle on the grabbed wall before we copy the final angles.
function AnimSetAngles()
	grabAngles = thisEntity:GetAngles()
	propAnim:SetAngles(grabAngles.x, grabAngles.y, grabAngles.z)
	return nil
end


function GrabMoveFrame(self)
	if not isGrabbing
	then
		return nil
	end
	
	local origin = grabEndpoint + RotatePosition(Vector(0,0,0), 
			RotateOrientation(thisEntity:GetAngles(), CARRY_ANGLES), Vector(0, 0, 0))
	
	thisEntity:SetOrigin(origin)
	
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
	local pullPos = handEnt:GetOrigin() - RotatePosition(Vector(0,0,0), 
			RotateOrientation(handEnt:GetAngles(), CARRY_ANGLES), MUZZLE_OFFSET) 
			+ RotatePosition(Vector(0,0,0), handEnt:GetAngles(), CARRY_OFFSET)
	
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

function GetMuzzlePos()
	return thisEntity:GetAbsOrigin() + RotatePosition(Vector(0,0,0), 
			RotateOrientation(thisEntity:GetAngles(), CARRY_ANGLES), MUZZLE_OFFSET)
end

