--[[
	Gravity gun script.
	
	Copyright (c) 2016-2020 Rectus
	
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


local PUNT_IMPULSE = 1000
local MAX_PULL_IMPULSE = 250
local MAX_PULLED_VELOCITY = 500
local PULL_EASE_DISTANCE = 32.0
local CARRY_DISTANCE = 16
local CARRY_GLUE_DISTANCE = 6
local TRACE_DISTANCE = 1024
local TRACE_RADIUS = 4
local OBJECT_PULL_INTERVAL = 0.1
local BEAM_TRACE_INTERVAL = FrameTime()
local PUNT_DISTANCE = 512
local CLAMP_VEL_IMPULSE = 1
local COUNTER_IMPULSE_FACTOR = 0.1
local COUNTER_IMPULSE_FACTOR_CLOSE = 0.3
local ROTATION_DAMPING_FACTOR = 0.05
local PICKUP_TRIGGER_DELAY = 0.2
local OPEN_POSE_SPEED = 3
local NEEDLE_POSE_SPEED = 10
local PULL_POSE_SPEED = 5

local playerEnt = nil
local handID = 0
local handEnt = nil
local handAttachment = nil
local pulledObject = nil
local pulledObjectLocalPos = Vector(0,0,0)
local pulledObjectInPuntRange = false
local isCarrying = false
local isCarried = false
local laserParticle = -1
local beamParticle = -1
local idleParticle = -1
local activateParticle = -1
local isTargeting = false
local needlePose = 0.0
local openPose = 0.0
local pullPose = 0.0
local needleSetPose = 0.0
local openSetPose = 0.0
local pullSetPose = 0.0
local showLaser = false
local clawsOpen = false
local clawSoundTime = 0
local secondHandGrabbing = false
local secondHandWasIdle = false

local pickupTime = 0

local rumbleDuration = 0
local rumbleInterval = 0
local rumbleIntensity = 0
local rumbleHand = nil


local pulledEntities =
{
	prop_physics = true;
	prop_physics_override = true;
	simple_physics_prop = true;
	prop_destinations_physics = true;
	prop_destinations_tool = true;
	prop_destinations_game_trophy = true;
	prop_ragdoll = true;
}

function Precache(context)
	PrecacheParticle("particles/item_laser_pointer.vpcf", context)
	PrecacheParticle("particles/tools/gravity_gun_beam.vpcf", context)
	PrecacheParticle("particles/tools/gravity_gun_punt.vpcf", context)
	PrecacheParticle("particles/tools/gravity_gun_idle.vpcf", context)
	PrecacheParticle("particles/tools/gravity_gun_activate.vpcf", context)
	PrecacheSoundFile("soundevents/soundevents_addon.vsndevts", context)
end

function Activate()
	thisEntity:SetSequence("idle")
	--thisEntity:SetThink(UpdateTwoHanded, "update_two_handed", 0.01)
end


function SetEquipped( this, pHand, nHandID, pHandAttachment, pPlayer )
	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	isCarried = true
	pickupTime = Time()

	handAttachment:SetSequence("idle")
	StartLaser()

	idleParticle = ParticleManager:CreateParticle("particles/tools/gravity_gun_idle.vpcf", 
	PATTACH_ABSORIGIN_FOLLOW, handAttachment)
	

	isTargeting = true
	thisEntity:SetThink(UpdateCarriedIdle, "update_beam", 0)
	thisEntity:SetThink(UpdatePose, "update_pose", 0)
	--thisEntity:SetThink(UpdateTwoHanded, "update_two_handed", 0)
	
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

	ParticleManager:DestroyParticle(idleParticle, true)
		
	playerEnt = nil
	handEnt = nil
	isCarried = false
	
	
	pulledObject = nil
	isCarrying = false
	StopSoundEvent("Physcannon.HoldLoop", thisEntity)
	StopLaser()
	StopBeam()

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
	local IN_PAD_UP = (handID == 0 and IN_PAD_UP_HAND0 or IN_PAD_UP_HAND1)
	local IN_PAD_DOWN = (handID == 0 and IN_PAD_DOWN_HAND0 or IN_PAD_DOWN_HAND1)
	local IN_PAD_TOUCH = (handID == 0 and IN_PAD_TOUCH_HAND0 or IN_PAD_TOUCH_HAND1)
	
	if input.buttonsPressed:IsBitSet(IN_TRIGGER)
	then
		if Time() > pickupTime + PICKUP_TRIGGER_DELAY
		then
			Punt()
		end
	end

	if input.buttonsPressed:IsBitSet(IN_PAD)
	then
		StartPull()
	end
	
	if input.buttonsReleased:IsBitSet(IN_PAD)
	then
		EndPull()
	end
	
	if input.buttonsPressed:IsBitSet(IN_PAD_DOWN)
	then
		StartPull()
	end
	
	if input.buttonsReleased:IsBitSet(IN_PAD_DOWN)
	then
		EndPull()
	end

	if input.buttonsPressed:IsBitSet(IN_PAD_UP)
	then
		handAttachment:EmitSound("Pole.Click")
		showLaser = not showLaser
		StartLaser()
	end

	return input;
end


--[[function UpdateTwoHanded()

	if not isCarried then
		thisEntity:SetPoseParameter("two_handed_yaw", 0)
		thisEntity:SetPoseParameter("two_handed_roll", 0)
		return nil
	end

	local secondHand = playerEnt:GetHMDAvatar():GetVRHand(handEnt:GetHandID() == 0 and 1 or 0)

	local gripPos, gripAng = GetAttachment("left_grip")

	if not secondHandGrabbing then

		if secondHandWasIdle then

			if (secondHand:GetCenter() - gripPos):Length() < 5 then
				secondHandGrabbing = true
			end

		else
			secondHandWasIdle = not IsHandUseActive(secondHand)
		end

	else
		if not IsHandUseActive(secondHand) then
			secondHandGrabbing = false
			secondHandWasIdle = true
			handAttachment:SetPoseParameter("two_handed_yaw", 0)
			handAttachment:SetPoseParameter("two_handed_roll", 0)
		end
	end

	if secondHandGrabbing then
		local leftGripOffset = handAttachment:TransformPointWorldToEntity(gripPos)
		local rotOrigin = Vector(leftGripOffset.x, 0, leftGripOffset.z)
		local handOffset = handAttachment:TransformPointWorldToEntity(secondHand:GetAbsOrigin())

		local angles = RotationDelta(VectorToAngles(handOffset - rotOrigin), VectorToAngles(leftGripOffset - rotOrigin))
		DebugDrawLine(gripPos, secondHand:GetCenter(), 255, 255, 0, true, FrameTime())
		DebugDrawLine(gripPos, gripPos - handAttachment:GetAbsOrigin() + handAttachment:TransformPointEntityToWorld(Vector((handOffset - rotOrigin).x, 0, 0)), 255, 0, 0, true, FrameTime())
		DebugDrawLine(gripPos, gripPos - handAttachment:GetAbsOrigin() + handAttachment:TransformPointEntityToWorld(Vector(0, 0, (handOffset - rotOrigin).z)), 0, 0, 255, true, FrameTime())

		local orig = handAttachment:TransformPointEntityToWorld(rotOrigin)
		DebugDrawLine(orig, orig - handAttachment:GetAbsOrigin() + handAttachment:TransformPointEntityToWorld(VectorToAngles(handOffset - rotOrigin):Forward())* 5, 255, 0, 255, true, FrameTime())

		DebugDrawLine(orig, orig - handAttachment:GetAbsOrigin() + handAttachment:TransformPointEntityToWorld(VectorToAngles(leftGripOffset - rotOrigin):Forward())* 5, 0, 255, 255, true, FrameTime())


		local yaw = Clamp(angles.y, -45, 45)
		local roll = Clamp(angles.z, -45, 45)

		handAttachment:SetPoseParameter("two_handed_yaw", yaw)
		handAttachment:SetPoseParameter("two_handed_roll", roll)

	end


	return FrameTime()
end

function IsHandUseActive(hand)

	if not IsValidEntity(hand) then return false end
	
	return playerEnt:IsActionActiveForHand(hand:GetLiteralHandType(), DEFAULT_USE) or
		playerEnt:IsActionActiveForHand(hand:GetLiteralHandType(), DEFAULT_USE_GRIP)
end]]


function UpdatePose()
	if not isCarried then
		needlePose = needleSetPose
		pullPose = pullSetPose
		openPose = openSetPose
		thisEntity:SetPoseParameter("needle", needlePose)
		thisEntity:SetPoseParameter("pull", pullPose)
		thisEntity:SetPoseParameter("open", openPose)
		return nil
	end
	local interval = FrameTime()

	local maxDelta = interval * NEEDLE_POSE_SPEED
	needlePose = needlePose + Clamp(needleSetPose - needlePose, -maxDelta, maxDelta)
	handAttachment:SetPoseParameter("needle", needlePose)
	thisEntity:SetPoseParameter("needle", needlePose)

	maxDelta = interval * PULL_POSE_SPEED
	pullPose = pullPose + Clamp(pullSetPose - pullPose, -maxDelta, maxDelta)
	handAttachment:SetPoseParameter("pull", pullPose)
	thisEntity:SetPoseParameter("pull", pullPose)

	maxDelta = interval * OPEN_POSE_SPEED
	openPose = openPose + Clamp(openSetPose - openPose, -maxDelta, maxDelta)
	handAttachment:SetPoseParameter("open", openPose)
	thisEntity:SetPoseParameter("open", openPose)

	return interval
end


function StartLaser()

	if laserParticle > -1 then
		ParticleManager:DestroyParticle(laserParticle, true)
		laserParticle = -1
	end

	if not showLaser then
		return
	end

	local beamPos = GetAttachment("beam")
	laserParticle = ParticleManager:CreateParticle("particles/item_laser_pointer.vpcf", 
		PATTACH_CUSTOMORIGIN, handAttachment)
	ParticleManager:SetParticleControlEnt(laserParticle, 0, handAttachment,
		PATTACH_POINT_FOLLOW, "beam", Vector(0,0,0), false)
	ParticleManager:SetParticleControl(laserParticle, 1, beamPos)

	-- Control point 3 sets the color of the beam.
	ParticleManager:SetParticleControl(laserParticle, 3, Vector(0.5, 0.5, 0.8))
end


function StopLaser()

	if laserParticle > -1 then
		ParticleManager:DestroyParticle(laserParticle, true)
		laserParticle = -1
	end
end


function StartBeam(endpoint)

	if beamParticle > -1 then
		ParticleManager:DestroyParticle(beamParticle, false)
	end

	beamParticle = ParticleManager:CreateParticle("particles/tools/gravity_gun_beam.vpcf", 
	PATTACH_CUSTOMORIGIN_FOLLOW, handAttachment)
	ParticleManager:SetParticleControlEnt(beamParticle, 0, handAttachment,
		PATTACH_POINT_FOLLOW, "beam", Vector(0,0,0), false)
	ParticleManager:SetParticleControlEnt(beamParticle, 1, handAttachment,
		PATTACH_POINT_FOLLOW, "muzzle", Vector(0,0,0), false)
	ParticleManager:SetParticleControlEnt(beamParticle, 2, handAttachment,
		PATTACH_POINT_FOLLOW, "pull_pos", Vector(0,0,0), false)

	--ParticleManager:SetParticleControlEnt(beamParticle, 3, handAttachment,
		--PATTACH_CUSTOMORIGIN_FOLLOW, nil, endpoint, false)
	ParticleManager:SetParticleControl(beamParticle, 3, endpoint)

	ParticleManager:SetParticleControlEnt(beamParticle, 4, handAttachment,
		PATTACH_POINT_FOLLOW, "emitter_top", Vector(0,0,0), false)
	ParticleManager:SetParticleControlEnt(beamParticle, 5, handAttachment,
		PATTACH_POINT_FOLLOW, "emitter_left", Vector(0,0,0), false)
	ParticleManager:SetParticleControlEnt(beamParticle, 6, handAttachment,
		PATTACH_POINT_FOLLOW, "emitter_right", Vector(0,0,0), false)

end


function StopBeam()

	if beamParticle > -1 then
		ParticleManager:DestroyParticle(beamParticle, false)
		beamParticle = -1
	end
end


function StartPuntParticle(endpoint)

	local puntParticle = ParticleManager:CreateParticle("particles/tools/gravity_gun_punt.vpcf", 
	PATTACH_ABSORIGIN, handAttachment)
	ParticleManager:SetParticleControlEnt(puntParticle, 0, handAttachment,
		PATTACH_POINT_FOLLOW, "beam", Vector(0,0,0), false)
	ParticleManager:SetParticleControlEnt(puntParticle, 1, handAttachment,
		PATTACH_POINT_FOLLOW, "muzzle", Vector(0,0,0), false)
	ParticleManager:SetParticleControlEnt(puntParticle, 2, handAttachment,
		PATTACH_POINT_FOLLOW, "pull_pos", Vector(0,0,0), false)

	ParticleManager:SetParticleControl(puntParticle, 3, endpoint)

	ParticleManager:SetParticleControlEnt(puntParticle, 4, handAttachment,
		PATTACH_POINT_FOLLOW, "emitter_top", Vector(0,0,0), false)
	ParticleManager:SetParticleControlEnt(puntParticle, 5, handAttachment,
		PATTACH_POINT_FOLLOW, "emitter_left", Vector(0,0,0), false)
	ParticleManager:SetParticleControlEnt(puntParticle, 6, handAttachment,
		PATTACH_POINT_FOLLOW, "emitter_right", Vector(0,0,0), false)
end


function StartPull()
	if isCarrying
	then
		pulledObject = nil
		isCarrying = false
		StopSoundEvent("Physcannon.Charge", thisEntity)
		StopSoundEvent("Physcannon.HoldLoop", thisEntity)
		StartSoundEvent("Physcannon.Drop", thisEntity)
		RumbleController(1, 0.15, 60, handEnt)
		thisEntity:SetThink(UpdateCarriedIdle, "update_beam", BEAM_TRACE_INTERVAL)
		handAttachment:SetSequence("idle")
		StopBeam()
		StartLaser()

		return
	end

	activateParticle =  ParticleManager:CreateParticle("particles/tools/gravity_gun_activate.vpcf", 
		PATTACH_POINT_FOLLOW, handAttachment)
	ParticleManager:SetParticleControlEnt(activateParticle, 1, handAttachment,
		PATTACH_POINT_FOLLOW, "muzzle", Vector(0,0,0), false)

	local hitEnt, hitPos = TracePullables(TRACE_DISTANCE)
	
	if hitEnt
	then
		-- Trace a grab position on the surface of the entity
		local trace = 
		{
			startpos = hitPos,
			endpos = hitEnt:GetCenter(),
			ent = hitEnt
		}		
		TraceCollideable(trace)
		if trace.hit then
			hitPos = trace.pos
		end

		pulledObject = hitEnt
		pulledObjectLocalPos = hitEnt:TransformPointWorldToEntity(hitPos)

		print("Gravity gun grabbed entity: " .. hitEnt:GetDebugName())
		thisEntity:SetThink(PullObjectFrame, "gravitygun_pull", OBJECT_PULL_INTERVAL)
		
		openSetPose = 1
		RumbleController(1, 0.3, 50, handEnt)
		StartSoundEvent("Physcannon.Charge", thisEntity)
		handAttachment:SetSequence("strain_low")
		StartBeam(hitPos)
		StopLaser()
	else
		RumbleController(1, 0.2, 10, handEnt)
		StartSoundEvent("Physcannon.Dryfire", thisEntity)
		handAttachment:SetSequence("dryfire")
	end
end


function EndPull()

	if activateParticle > -1 then
		ParticleManager:DestroyParticle(activateParticle, false)
		activateParticle = -1
	end

	if not isCarrying and pulledObject
	then
		pulledObject = nil
		StopSoundEvent("Physcannon.Charge", thisEntity)
		StopSoundEvent("Physcannon.HoldLoop", thisEntity)
		StartSoundEvent("Physcannon.Drop", thisEntity)
		needleSetPose = 0
		handAttachment:SetSequence("idle")
		StopBeam()
		RumbleController(1, 0.15, 40, handEnt)
		thisEntity:SetThink(StartLaser, "laser_delay", 0.1)
		thisEntity:SetThink(UpdateCarriedIdle, "update_beam", BEAM_TRACE_INTERVAL)
	end
end


function Punt()
	local puntObject
	local puntPos
	if (isCarrying or pulledObjectInPuntRange) and pulledObject and IsValidEntity(pulledObject) then
		puntPos = pulledObject:TransformPointEntityToWorld(pulledObjectLocalPos)
		puntObject = pulledObject
		pulledObject = nil
		isCarrying = false
		StopSoundEvent("Physcannon.HoldLoop", thisEntity)
		thisEntity:SetThink(UpdateCarriedIdle, "update_beam", BEAM_TRACE_INTERVAL)
		StopBeam()
		
	else
		local ent, pos = TracePullables(PUNT_DISTANCE)
		
		if ent then
			puntObject = ent
			puntPos = pos
			StartPuntParticle(pos)
		else
			RumbleController(1, 0.2, 10, handEnt)
			StartSoundEvent("Physcannon.Dryfire", thisEntity)
			return
		end
	end

	puntObject:ApplyAbsVelocityImpulse(handAttachment:GetAngles():Forward() * PUNT_IMPULSE)

	local damage = CreateDamageInfo(thisEntity, playerEnt, handAttachment:GetAngles():Forward() * 5, puntPos, 5, DMG_PHYSGUN)
	puntObject:TakeDamage(damage)
	DestroyDamageInfo(damage)

	StartPuntParticle(puntPos)
	pullSetPose = 0
	pullPose = 1
	openSetPose = 1
	needlePose = -1
	needleSetPose = 0
	RumbleController(2, 0.4, 120, handEnt)
	StartSoundEvent("Physcannon.Launch", thisEntity)
	thisEntity:SetThink(StartLaser, "laser_delay", 0.3)
end


function UpdateCarriedIdle()
	if (not isTargeting) or isCarrying or pulledObject
	then
		return nil
	end

	local ent, pos, beamHit = TracePullables(TRACE_DISTANCE)
	
	if beamHit then

		if ent then
			SetClawsOpen(true)
			ParticleManager:SetParticleControl(laserParticle, 3, Vector(0.8, 0.8, 0.5))
		else
			SetClawsOpen(false)
			ParticleManager:SetParticleControl(laserParticle, 3, Vector(0.5, 0.5, 0.8))
		end
	
		ParticleManager:SetParticleControl(laserParticle, 1, pos)

	else
		SetClawsOpen(false)
		ParticleManager:SetParticleControl(laserParticle, 3, Vector(0.4, 0.4, 0.6))
		ParticleManager:SetParticleControl(laserParticle, 1, pos)
	end
	
	return BEAM_TRACE_INTERVAL
end


function SetClawsOpen(open)
	if open then
		openSetPose = 0.5
		if clawsOpen == false then	

			if clawSoundTime + 0.5 < Time() then
				clawSoundTime = Time()
				clawsOpen = true
				RumbleControllerLowPriority(0, 0.4, 30, handEnt)
				StartSoundEvent("Physcannon.ClawsOpen", thisEntity)
			end
		end
	else
		openSetPose = 0
		if clawsOpen == true then

			if clawSoundTime + 0.5 < Time() then
				clawSoundTime = Time()
				clawsOpen = false
				RumbleControllerLowPriority(0, 0.4, 25, handEnt)
				StartSoundEvent("Physcannon.ClawsClose", thisEntity)
			end
		end
	end
end


function TracePullables(distance)

	local muzzlePos, MuzzleAng = GetAttachment("muzzle")

	local traceTable =
	{
		startpos = muzzlePos + MuzzleAng:Forward() * TRACE_RADIUS * 2;
		endpos = muzzlePos + MuzzleAng:Forward() * distance;
		ignore = playerEnt;
		min = Vector(-TRACE_RADIUS, -TRACE_RADIUS, -TRACE_RADIUS);
		max = Vector(TRACE_RADIUS, TRACE_RADIUS, TRACE_RADIUS);
	}
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, 0.1)
	TraceHull(traceTable)
	
	if traceTable.hit
	then
		--DebugDrawLine(traceTable.startpos, GetMuzzlePos() + RotatePosition(Vector(0,0,0), 
			--RotateOrientation(thisEntity:GetAngles(), MUZZLE_ANGLES_OFFSET), Vector(TONGUE_MAX_DISTANCE * traceTable.fraction, 0, 0)), 0, 255, 255, false, 0.5)
		
		if traceTable.enthit and traceTable.enthit ~= thisEntity and pulledEntities[traceTable.enthit:GetClassname()] ~= nil
		then
			return traceTable.enthit, traceTable.pos, true
		end
	end

	traceTable =
	{
		startpos = muzzlePos;
		endpos = muzzlePos + MuzzleAng:Forward() * distance;
		ignore = playerEnt;
	}

	TraceLine(traceTable)

	if traceTable.hit
	then
		if traceTable.enthit and traceTable.enthit ~= thisEntity and  pulledEntities[traceTable.enthit:GetClassname()] ~= nil
		then
			return traceTable.enthit, traceTable.pos, true
		end

		local entities = Entities:FindAllInSphere(traceTable.pos, TRACE_RADIUS * 2)
		for _, ent in pairs(entities)
		do
			if ent ~= thisEntity and pulledEntities[ent:GetClassname()] ~= nil
			then
				return ent, traceTable.pos, true
			end
		end

		return nil, traceTable.endpos, true
	end
	
	return nil, traceTable.endpos, false
end


function PullObjectFrame()

	if not pulledObject or not IsValidEntity(pulledObject)
	then
		if pulledObject then
			EndPull()
		end
		return nil
	end

	local mass = RemapVal(pulledObject:GetMass(), 0, 100, 0, 1)
	needleSetPose = mass

	local objectPos = pulledObject:TransformPointEntityToWorld(pulledObjectLocalPos)
	ParticleManager:SetParticleControl(beamParticle, 3, objectPos)
	
	
	local pullPos, pullAng = GetAttachment("pull_pos")
	pullPos = pullPos + pullAng:Forward() * GetMaxRadius(pulledObject)
	local distance = (pullPos - objectPos):Length()

	local m = GetAttachment("muzzle")
	--DebugDrawLine(pullPos, objectPos, 255, 0, 255, true, OBJECT_PULL_INTERVAL)

	pulledObjectInPuntRange = distance >= PUNT_DISTANCE

	pullSetPose = mass * RemapVal(distance, 0, TRACE_DISTANCE, 0, 1)

	local rumbleFreq = RemapVal(distance, 0, TRACE_DISTANCE, 70, 20)
	if isCarrying then
		RumbleControllerLowPriority(0, 0.2, rumbleFreq + 20, handEnt)
	else
		RumbleControllerLowPriority(0, 0.2, rumbleFreq, handEnt)
	end

	if distance < CARRY_DISTANCE
	then
		if not isCarrying
		then
			isCarrying = true
			StartCarrying()
		end
	end
	
	local pullFactor = 1.0
	
	if distance < PULL_EASE_DISTANCE
	then
		pullFactor = distance / PULL_EASE_DISTANCE
	end
	local impulse = (pullPos - objectPos):Normalized() * MAX_PULL_IMPULSE * pullFactor
	pulledObject:ApplyAbsVelocityImpulse(impulse)

	pullSetPose = pullFactor
	
	-- Dampen object movement
	if distance < CARRY_GLUE_DISTANCE
	then	
		pulledObject:ApplyAbsVelocityImpulse(GetPhysVelocity(pulledObject) * -COUNTER_IMPULSE_FACTOR_CLOSE)-- (pullPos - objectPullOrigin) * 2)
	else
		pulledObject:ApplyAbsVelocityImpulse(GetPhysVelocity(pulledObject) * -COUNTER_IMPULSE_FACTOR)
	end
	SetPhysAngularVelocity(pulledObject, (1 - ROTATION_DAMPING_FACTOR) * GetPhysAngularVelocity(pulledObject))
	
	ClampObjectVelocity(pulledObject, distance, pullPos, objectPos)
	
	return OBJECT_PULL_INTERVAL
end


function ClampObjectVelocity(entity, distance, pullPos, objectPullOrigin)
	local velocity = GetPhysVelocity(entity)
	
	--if distance < CARRY_GLUE_DISTANCE
	--then	
		--entity:SetAbsOrigin(pullPos + (entity:GetAbsOrigin() - objectPullOrigin))

	if velocity:Length() > MAX_PULLED_VELOCITY
	then
		entity:ApplyAbsVelocityImpulse(velocity:Normalized() * -CLAMP_VEL_IMPULSE)
	end
end


function StartCarrying()
	RumbleController(1, 0.3, 70, handEnt)
	StopSoundEvent("Physcannon.Charge", thisEntity)
	StartSoundEvent("Physcannon.Pickup", thisEntity)
	StartSoundEvent("Physcannon.HoldLoop", thisEntity)
	handAttachment:SetSequence("strain_high")
	pullSetPose = -1
	openSetPose = 1
end


function GetMaxRadius(entity)
	return entity:GetBoundingMaxs():Length() * entity:GetAbsScale()
end


function GetAttachment(name)
	local idx = handAttachment:ScriptLookupAttachment(name)
	local ang = handAttachment:GetAttachmentAngles(idx)
	return handAttachment:GetAttachmentOrigin(idx), QAngle(ang.x, ang.y, ang.z)
end


function RumbleController(intensity, duration, frequency, hand)
	if hand and IsValidEntity(hand)
	then
		rumbleDuration = duration
		rumbleInterval = 1 / frequency
		rumbleIntensity = intensity
		rumbleHand = hand
		
		rumbleHand:FireHapticPulse(rumbleIntensity)
		thisEntity:SetThink(RumblePulse, "rumble", rumbleInterval)
	end
end

function RumbleControllerLowPriority(intensity, duration, frequency, hand)
	if hand and IsValidEntity(hand)
	then
		if rumbleDuration > 0 then
			
			if intensity >= rumbleIntensity and rumbleHand == hand
			then
				rumbleDuration = duration
				rumbleInterval = 1 / frequency
				rumbleIntensity = intensity
			end
		else
			rumbleDuration = duration
			rumbleInterval = 1 / frequency
			rumbleIntensity = intensity
			rumbleHand = hand
			
			rumbleHand:FireHapticPulse(rumbleIntensity)
			thisEntity:SetThink(RumblePulse, "rumble", rumbleInterval)
		end
	end
end


function RumblePulse()
	if rumbleHand and IsValidEntity(rumbleHand)
	then
		rumbleHand:FireHapticPulse(rumbleIntensity)
		rumbleDuration = rumbleDuration - rumbleInterval
		if rumbleDuration >= rumbleInterval
		then
			return rumbleInterval
		end
	end
	rumbleDuration = 0
	return nil
end