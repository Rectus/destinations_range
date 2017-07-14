--[[
	Climb hook script.
	
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

local GRAB_MAX_DISTANCE = 4
local GRAB_PULL_MIN_DISTANCE = 0.1
local GRAB_MOVE_INTERVAL = 0.02
local MUZZLE_OFFSET = Vector(3, 0, 4)
local MUZZLE_ANGLES_OFFSET = QAngle(0, 0, 0) 

local GRAB_PULL_PLAYER_SPEED = 8
local GRAB_PULL_PLAYER_EASE_DISTANCE = 16
local GRAB_TRACE_INTERVAL = 0.1

local CARRY_OFFSET = Vector(0, 0, 0)
local CARRY_ANGLES = QAngle(60, 0, 0)

local isCarried = false
local playerEnt = nil
local grabbedEnt = nil
local grabEndpoint = nil
local playerMoved = false
local propAnim = nil

local isTargeting = false
local targetFound = false
local isGrabbing = false

local pulledEntities = {"prop_physics"; "prop_physics_override"; "simple_physics_prop"; "func_physbox"}
local excludedEntities = {"player"}


animKeyvals = {
	targetname = "climb_hook_anim";
	model = "models/props_beach/flashlight.vmdl";
	solid = 0;
	--scales = "0.6885 0.6885 0.6885";
	--DefaultAnim = "idle"
	}


function Precache(context)
	--PrecacheParticle("particles/barnacle_tongue.vpcf", context)
	--PrecacheParticle("particles/item_laser_pointer.vpcf", context)
	PrecacheModel(animKeyvals.model, context)
	--PrecacheSoundFile("soundevents/soundevents_addon.vsndevts", context)
end


function Init(self)
	animKeyvals.origin = thisEntity:GetOrigin()
	animKeyvals.angles = thisEntity:GetAngles()
	propAnim = SpawnEntityFromTableSynchronous("prop_dynamic", animKeyvals)
	propAnim:SetParent(thisEntity, "")
	propAnim:SetOrigin(thisEntity:GetOrigin())

	
	--DoEntFireByInstanceHandle(propAnim, "SetSequence", "idle", 0, nil, nil)

end


function OnTriggerPressed(self)
	
	if isGrabbing
	then
		ReleaseHold(self)
		
	else
		thisEntity:SetThink(TraceGrab, "trace_grab", 0)
		targetFound = false
		isTargeting = true
	end

end


function OnTriggerUnpressed(self)
	if isTargeting
	then

		isTargeting = false
		
		if targetFound
		then
			isGrabbing = true
		
			if grabbedEnt
			then
				grabbedEnt:SetParent(thisEntity, "")
			else
				playerMoved = true
				g_VRScript.fallController:AddConstraint(playerEnt, thisEntity)
				thisEntity:SetThink(GrabMoveFrame, "grab_move")
			end	
		end
	end
end


function OnPickedUp(self, hand, player)
	playerEnt = player
	thisEntity:SetParent(hand, "")
	thisEntity:SetOrigin(hand:GetOrigin() + RotatePosition(Vector(0,0,0), hand:GetAngles(), CARRY_OFFSET))
	local carryAngles = RotateOrientation(hand:GetAngles(), CARRY_ANGLES)
	thisEntity:SetAngles(carryAngles.x, carryAngles.y, carryAngles.z)

end


function OnDropped(self, hand, player)
	ReleaseHold(self)
	playerEnt = nil
	isTargeting = false

	thisEntity:SetParent(nil, "")
end




function ReleaseHold(self)
	isGrabbing = false
	
	--DoEntFireByInstanceHandle(propAnim, "SetSequence", "idle", 0, nil, nil)
	--StopSoundEvent("Barnacle.TongueFly", thisEntity)
	--StartSoundEvent("Barnacle.TongueStrain", thisEntity)
	
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
	DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, 0.1)
	TraceLine(traceTable)
	
	if traceTable.hit 
	then
		DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 255, 0, false, 0.2)
		
		grabbedEnt = nil
		
		if traceTable.enthit 
		then
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
				if traceTable.enthit:GetClassname() == entClass
				then
					grabbedEnt = traceTable.enthit
				end
			end
		end
		
		grabEndpoint = traceTable.pos
		targetFound = true
		return GRAB_TRACE_INTERVAL
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
	
	local pullVector = nil
	
	local gunRelativePos = GetMuzzlePos() - playerEnt:GetHMDAnchor():GetOrigin()
	
	
	pullVector = (grabEndpoint - GetMuzzlePos()):Normalized() * GRAB_PULL_PLAYER_SPEED
	 
	local distance = (grabEndpoint - GetMuzzlePos()):Length()

	
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
			
		--playerEnt:GetHMDAnchor():SetOrigin(GetMuzzlePos() - gunRelativePos + pullVector)
		playerEnt:GetHMDAnchor():SetOrigin(playerEnt:GetHMDAnchor():GetOrigin() + pullVector)
	end
		
	return GRAB_MOVE_INTERVAL
end



function GetMuzzlePos()
	return thisEntity:GetAbsOrigin() + RotatePosition(Vector(0,0,0), 
			RotateOrientation(thisEntity:GetAngles(), CARRY_ANGLES), MUZZLE_OFFSET)
end

