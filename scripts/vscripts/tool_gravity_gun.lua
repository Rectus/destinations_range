--[[
	Gravity gun script.
	
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

require("particle_system")

local PUNT_IMPULSE = 1000
local MAX_PULL_IMPULSE = 250
local MAX_PULLED_VELOCITY = 500
local PULL_EASE_DISTANCE = 32.0
local CARRY_DISTANCE = 32
local CARRY_GLUE_DISTANCE = 8
local TRACE_DISTANCE = 1024
local OBJECT_PULL_INTERVAL = 0.1
local BEAM_TRACE_INTERVAL = 0.1
local PUNT_DISTANCE = 512
local CLAMP_VEL_IMPULSE = 1
local COUNTER_IMPULSE_FACTOR = 0.1
local ROTATION_DAMPING_FACTOR = 0.05

local playerEnt = nil
local handID = 0
local handEnt = nil
local handAttachment = nil
local pulledObject = nil
local isCarrying = false
local isCarried = false
local beamParticle = nil
local isTargeting = false

local pickupTime = 0
local PICKUP_TRIGGER_DELAY = 0.2

local pulledEntities = {"prop_physics"; "prop_physics_override"; "simple_physics_prop";
	"prop_destinations_physics"; "prop_destinations_tool"; "prop_destinations_game_trophy"}

function Precache(context)
	PrecacheParticle("particles/item_laser_pointer.vpcf", context)
	PrecacheSoundFile("soundevents/soundevents_addon.vsndevts", context)
end


function SetEquipped( this, pHand, nHandID, pHandAttachment, pPlayer )
	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	isCarried = true
	pickupTime = Time()
	
	if not beamParticle or not IsValidEntity(beamParticle)
	then
		beamParticle = ParticleSystem("particles/item_laser_pointer.vpcf", false)
		beamParticle:CreateControlPoint(1, Vector(TRACE_DISTANCE, 0, 0), handAttachment, "")
		-- Control point 3 sets the color of the beam.
		beamParticle:CreateControlPoint(3, Vector(0.5, 0.5, 0.8))
		
		beamParticle:SetParent(handAttachment, "beam")
		beamParticle:SetOrigin(handAttachment:GetAbsOrigin())
	else
		beamParticle:SetParent(handAttachment, "beam")
		beamParticle:GetControlPoint(1):SetParent(handAttachment, "")	
	end
	
	beamParticle:Start()
	isTargeting = true
	thisEntity:SetThink(TraceBeam, "trace_beam", 0)
	
	local paintColor = thisEntity:GetRenderColor()
	handAttachment:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	if g_VRScript.pauseManager
	then
		g_VRScript.pauseManager:SetTeleportControlsAllowed(playerEnt, handID, false)
	else
		playerEnt:AllowTeleportFromHand(handID, false)
	end
	
	return true
end


function SetUnequipped()

	if g_VRScript.pauseManager
	then
		g_VRScript.pauseManager:SetTeleportControlsAllowed(playerEnt, handID, true)
	else
		playerEnt:AllowTeleportFromHand(handID, true)
	end
		
	playerEnt = nil
	handEnt = nil
	isCarried = false
	
	
	pulledObject = nil
	isCarrying = false
	StopSoundEvent("Physcannon.HoldLoop", thisEntity)
	beamParticle:StopPlayEndcap()
	beamParticle:SetParent(thisEntity, "beam")
	beamParticle:GetControlPoint(1):SetParent(thisEntity, "")
	isTargeting = false
	
	local paintColor = handAttachment:GetRenderColor()
	thisEntity:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	return true
end


function OnHandleInput( input )
	if not playerEnt
	then 
		return input
	end

	-- Even uglier lua ternary operator
	local IN_TRIGGER = (handID == 0 and IN_USE_HAND0 or IN_USE_HAND1)
	local IN_PAD = (handID == 0 and IN_PAD_HAND0 or IN_PAD_HAND1)
	local IN_PAD_TOUCH = (handID == 0 and IN_PAD_TOUCH_HAND0 or IN_PAD_TOUCH_HAND1)
	local IN_GRIP = (handID == 0 and IN_GRIP_HAND0 or IN_GRIP_HAND1)

	
	if input.buttonsPressed:IsBitSet(IN_TRIGGER)
	then
		input.buttonsPressed:ClearBit(IN_TRIGGER)
		if Time() > pickupTime + PICKUP_TRIGGER_DELAY
		then
			Punt()
		end
	end
		
	if input.buttonsReleased:IsBitSet(IN_TRIGGER) 
	then
		input.buttonsReleased:ClearBit(IN_TRIGGER)
	end
	
	
	if input.buttonsPressed:IsBitSet(IN_PAD)
	then
		input.buttonsPressed:ClearBit(IN_PAD)
		StartPull()
	end
	
	if input.buttonsReleased:IsBitSet(IN_PAD) 
	then
		input.buttonsReleased:ClearBit(IN_PAD)
		EndPull()
	end
	
	if input.buttonsReleased:IsBitSet(IN_GRIP)
	then
		input.buttonsReleased:ClearBit(IN_GRIP)
		thisEntity:ForceDropTool();
	end
	
	-- Needed to disable teleports
	
	--input.buttonsDown:ClearBit(IN_PAD)
	--input.buttonsDown:ClearBit(IN_PAD_TOUCH)
	--input.buttonsPressed:ClearBit(IN_PAD_TOUCH)
	--input.buttonsReleased:ClearBit(IN_PAD_TOUCH)


	return input;
end




function StartPull()
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

	local hitEnt = TraceEntity()
	
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


function EndPull()
	if not isCarrying and pulledObject
	then
		pulledObject = nil
		StopSoundEvent("Physcannon.Charge", thisEntity)
		StopSoundEvent("Physcannon.HoldLoop", thisEntity)
		StartSoundEvent("Physcannon.Drop", thisEntity)
	end
end


function Punt()
	if isCarrying
	then
		pulledObject:ApplyAbsVelocityImpulse(handAttachment:GetAngles():Forward() * PUNT_IMPULSE)
		pulledObject = nil
		isCarrying = false
		StopSoundEvent("Physcannon.HoldLoop", thisEntity)
		StartSoundEvent("Physcannon.Launch", thisEntity)
		thisEntity:SetThink(TraceBeam, "trace_beam", BEAM_TRACE_INTERVAL)
		beamParticle:Start()
	else
		local ent = TracePunt()
		
		if ent
		then
			ent:ApplyAbsVelocityImpulse(handAttachment:GetAngles():Forward() * PUNT_IMPULSE)
			StartSoundEvent("Physcannon.Launch", thisEntity)
		else
			StartSoundEvent("Physcannon.Dryfire", thisEntity)
		end
	end
end


function TraceEntity()
	local traceTable =
	{
		startpos = GetMuzzlePos();
		endpos = GetMuzzlePos() + RotatePosition(Vector(0,0,0), handAttachment:GetAngles(), Vector(TRACE_DISTANCE, 0, 0));
		ignore = playerEnt

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


function TraceBeam()
	if (not isTargeting) or isCarrying
	then 
		return nil
	end

	local traceTable =
	{
		startpos = GetMuzzlePos();
		endpos = GetMuzzlePos() + RotatePosition(Vector(0,0,0), 
				RotateOrientation(handAttachment:GetAngles(), QAngle(0, 0, 0)), Vector(TRACE_DISTANCE, 0, 0));
		ignore = playerEnt

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
				
		beamParticle:GetControlPoint(1):SetAbsOrigin(traceTable.pos)

	else
		beamParticle:GetControlPoint(3):SetOrigin(Vector(0.4, 0.4, 0.6))
		beamParticle:GetControlPoint(1):SetAbsOrigin(traceTable.endpos)		
	end
	
	return BEAM_TRACE_INTERVAL
end


function TracePunt()

	local traceTable =
	{
		startpos = GetMuzzlePos();
		endpos = GetMuzzlePos() + handAttachment:GetAngles():Forward() * PUNT_DISTANCE;
		ignore = playerEnt

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
					return traceTable.enthit 
				end
			end
		end
			
	end
	
	return nil
end


function PullObjectFrame()
	
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
			StartedCarrying()
		end
	end
	
	local pullFactor = 1.0
	
	if distance < PULL_EASE_DISTANCE
	then
		pullFactor = distance / PULL_EASE_DISTANCE
	end
	local impulse = (GetMuzzlePos() - pulledObject:GetCenter()):Normalized() * MAX_PULL_IMPULSE * pullFactor
	pulledObject:ApplyAbsVelocityImpulse(impulse)
	
	-- Dampen object movement
	pulledObject:ApplyAbsVelocityImpulse(GetPhysVelocity(pulledObject) * -COUNTER_IMPULSE_FACTOR)				
	SetPhysAngularVelocity(pulledObject, (1 - ROTATION_DAMPING_FACTOR) * GetPhysAngularVelocity(pulledObject))
	
	ClampObjectVelocity(pulledObject, distance)
	
	return OBJECT_PULL_INTERVAL
end

function ClampObjectVelocity(entity, distance)
	local velocity = GetPhysVelocity(entity)
	
	if distance < CARRY_GLUE_DISTANCE
	then
		entity:SetAbsOrigin(GetMuzzlePos())
	else
		if velocity:Length() > MAX_PULLED_VELOCITY
		then
			entity:ApplyAbsVelocityImpulse(velocity:Normalized() * -CLAMP_VEL_IMPULSE)
		end
	end
end

function StartedCarrying()
	StopSoundEvent("Physcannon.Charge", thisEntity)
	StartSoundEvent("Physcannon.Pickup", thisEntity)
	StartSoundEvent("Physcannon.HoldLoop", thisEntity)
	beamParticle:StopPlayEndcap()
end

function GetMuzzlePos()
	local idx = handAttachment:ScriptLookupAttachment("muzzle")
	return handAttachment:GetAttachmentOrigin(idx)
end
