--[[
	Gravity gun script.
	
	Since the gravity gun doesn't have any animations, no extra prop needs to be spawned.
	
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

g_VRScript.pickupManager:RegisterEntity(thisEntity)

local PUNT_IMPULSE = 1000
local MAX_PULL_IMPULSE = 500
local MAX_PULLED_VELOCITY = 500
local PULL_EASE_DISTANCE = 128.0
local CARRY_DISTANCE = 32
local CARRY_GLUE_DISTANCE = 16
local TRACE_DISTANCE = 512
local OBJECT_PULL_INTERVAL = 0.1
local MUZZLE_OFFSET = Vector(36, 0, 0)
local CARRY_OFFSET = Vector(-4, 0, 0)
local CARRY_ANGLES = QAngle(10, 0, 0)
local BEAM_TRACE_INTERVAL = 0.1

local pulledObject = nil
local isCarrying = false
local isCarried = false
local beamParticle = nil
local isTargeting = false

local pulledEntities = {"prop_physics"; "prop_physics_override"; "simple_physics_prop"}

function Precache(context)
	PrecacheParticle("particles/item_laser_pointer.vpcf", context)
	PrecacheSoundFile("soundevents/soundevents_addon.vsndevts", context)
end


function Init(self)

	beamParticle = ParticleSystem("particles/item_laser_pointer.vpcf", false)
	beamParticle:CreateControlPoint(1, Vector(TRACE_DISTANCE, 0, 0), thisEntity, "")
	-- Control point 3 sets the color of the beam.
	beamParticle:CreateControlPoint(3, Vector(0.5, 0.5, 0.8))

	
	beamParticle:SetParent(thisEntity, "beam")
	beamParticle:SetOrigin(thisEntity:GetAbsOrigin())
	
	
end


function OnTriggerPressed(self)
	if isCarrying
	then
		pulledObject = nil
		isCarrying = false
		StopSoundEvent("Physcannon.Charge", thisEntity)
		StopSoundEvent("Physcannon.HoldLoop", thisEntity)
		StartSoundEvent("Physcannon.Drop", thisEntity)
		thisEntity:SetThink(TraceBeam, "trace_beam", BEAM_TRACE_INTERVAL)
		beamParticle:Start()
		return
	end

	hitEnt = TraceEntity(self)
	
	if hitEnt
	then
		pulledObject = hitEnt

		print("Gravity gun grabbed entity: " .. hitEnt:GetDebugName())
		thisEntity:SetThink(PullObjectFrame, "gravitygun_pull", OBJECT_PULL_INTERVAL)
		
		StartSoundEvent("Physcannon.Charge", thisEntity)
	else
		StartSoundEvent("Physcannon.Dryfire", thisEntity)
	end
end


function OnTriggerUnpressed(self)
	if not isCarrying and pulledObject
	then
		pulledObject = nil
		StopSoundEvent("Physcannon.Charge", thisEntity)
		StopSoundEvent("Physcannon.HoldLoop", thisEntity)
		StartSoundEvent("Physcannon.Drop", thisEntity)
	end
end


function OnPadPressed(self)
	if isCarrying
	then
		pulledObject:ApplyAbsVelocityImpulse(thisEntity:GetAngles():Forward():Normalized() * PUNT_IMPULSE)
	
		pulledObject = nil
		isCarrying = false
		StopSoundEvent("Physcannon.HoldLoop", thisEntity)
		StartSoundEvent("Physcannon.Launch", thisEntity)
		thisEntity:SetThink(TraceBeam, "trace_beam", BEAM_TRACE_INTERVAL)
		beamParticle:Start()
	end

end


function OnPickedUp(self, hand, player)

	thisEntity:SetParent(hand, "")
	thisEntity:SetOrigin(hand:GetOrigin() + RotatePosition(Vector(0,0,0), hand:GetAngles(), CARRY_OFFSET))
	local carryAngles = hand:GetAngles() + CARRY_ANGLES
	thisEntity:SetAngles(carryAngles.x, carryAngles.y, carryAngles.z)

	beamParticle:Start()
	isTargeting = true
	thisEntity:SetThink(TraceBeam, "trace_beam", 0)
end


function OnDropped(self, hand, player)
	pulledObject = nil
	isCarrying = false
	StopSoundEvent("Physcannon.HoldLoop", thisEntity)
	thisEntity:SetParent(nil, "")
	beamParticle:StopPlayEndcap()
	isTargeting = false
end


function TraceEntity(self)
	local traceTable =
	{
		startpos = GetMuzzlePos();
		endpos = GetMuzzlePos() + RotatePosition(Vector(0,0,0), thisEntity:GetAngles(), Vector(TRACE_DISTANCE, 0, 0));
		ignore = thisEntity

	}
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 0, 255, 0, false, 0.11)
	TraceLine(traceTable)
	
	if traceTable.hit and traceTable.enthit
	then
		for _, entClass in ipairs(pulledEntities)
		do
			if traceTable.enthit:GetClassname() == entClass
			then
				return traceTable.enthit
			end
		end
	end
		
	return nil
end


function TraceBeam(self)
	if (not isTargeting) or isCarrying
	then 
		return nil
	end

	local traceTable =
	{
		startpos = GetMuzzlePos();
		endpos = GetMuzzlePos() + RotatePosition(Vector(0,0,0), 
				RotateOrientation(thisEntity:GetAngles(), QAngle(0, 0, 0)), Vector(TRACE_DISTANCE, 0, 0));
		ignore = thisEntity

	}
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, 0.1)
	TraceLine(traceTable)
	
	if traceTable.hit 
	then
		--DebugDrawLine(traceTable.startpos, GetMuzzlePos() + RotatePosition(Vector(0,0,0), 
				--RotateOrientation(thisEntity:GetAngles(), MUZZLE_ANGLES_OFFSET), Vector(TONGUE_MAX_DISTANCE * traceTable.fraction, 0, 0)), 0, 255, 255, false, 0.5)
		
		
		
		local pullableHit = false
		if traceTable.enthit 
		then
			for _, entClass in ipairs(pulledEntities)
			do
				if traceTable.enthit:GetClassname() == entClass
				then
					pullableHit = true
				end
			end
		end
		
		if pullableHit
		then
			beamParticle:GetControlPoint(3):SetOrigin(Vector(0.8, 0.8, 0.5))
		else
			beamParticle:GetControlPoint(3):SetOrigin(Vector(0.5, 0.5, 0.8))
		end
		
		
		beamParticle:GetControlPoint(1):SetAbsOrigin(thisEntity:GetAbsOrigin()  + RotatePosition(Vector(0,0,0), 
				thisEntity:GetAngles(), Vector(TRACE_DISTANCE * traceTable.fraction * 2 + 1, 0, 0)))
		

	
	else
		beamParticle:GetControlPoint(3):SetOrigin(Vector(0.4, 0.4, 0.6))
		beamParticle:GetControlPoint(1):SetAbsOrigin(thisEntity:GetAbsOrigin() + RotatePosition(Vector(0,0,0), 
				thisEntity:GetAngles(), Vector(TRACE_DISTANCE * 2 + 1, 0, 0)))
		
	end
	
	return BEAM_TRACE_INTERVAL
end


function PullObjectFrame(self)
	
	if not pulledObject
	then
		return nil
	end
	
	local distance = (GetMuzzlePos() - pulledObject:GetCenter()):Length()
	if distance < CARRY_DISTANCE
	then
		if not isCarrying
		then
			isCarrying = true
			StartedCarrying(self)
		end
	end
	
	local pullFactor = 1.0
	
	if distance < PULL_EASE_DISTANCE
	then
		pullFactor = distance / PULL_EASE_DISTANCE
	end
	local impulse = (GetMuzzlePos() - pulledObject:GetCenter()):Normalized() * MAX_PULL_IMPULSE * pullFactor
	pulledObject:ApplyAbsVelocityImpulse(impulse)
	ClampObjectVelocity(self, pulledObject, distance)
	
	return OBJECT_PULL_INTERVAL
end

function ClampObjectVelocity(self, entity, distance)
	velocity = entity:GetVelocity()
	
	if distance < CARRY_GLUE_DISTANCE
	then
		entity:SetVelocity(Vector(0,0,16))
	else
		if velocity:Length() > MAX_PULLED_VELOCITY
		then
			entity:SetVelocity(velocity:Normalized() * MAX_PULLED_VELOCITY)
		end
	end
end

function StartedCarrying(self)
	StopSoundEvent("Physcannon.Charge", thisEntity)
	StartSoundEvent("Physcannon.Pickup", thisEntity)
	StartSoundEvent("Physcannon.HoldLoop", thisEntity)
	beamParticle:StopPlayEndcap()
end

function GetMuzzlePos()
	return thisEntity:GetAbsOrigin() + RotatePosition(Vector(0,0,0), thisEntity:GetAngles(), MUZZLE_OFFSET)
end
