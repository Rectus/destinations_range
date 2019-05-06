--[[
	Barnacle gun script.
	
	Copyright (c) 2016-2017 Rectus
	
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


local TONGUE_MAX_DISTANCE = 3000
local TONGUE_PULL_MIN_DISTANCE = 8
local TONGUE_SPEED = 64
local TONGUE_PULL_FORCE = 50
local TONGUE_PULL_INTERVAL = 0.02
local TONGUE_PULL_DELAY = 0.5
local REEL_SOUND_INTERVAL = 10
local REEL_ANIM_INTERVAL = 1
local MUZZLE_ANGLES_OFFSET = QAngle(-90, 0, 0) 
local ENT_PULL_MAX_MASS = 100

local TONGUE_PULL_PLAYER_SPEED = 10
local TONGUE_PULL_PLAYER_EASE_DISTANCE = 64

local TRACE_OBSTACLE_INTERVAL = 0.1
local GRAPPLE_POINT_FIXUP = 2
local GRAPPLE_CORNER_TRACE_MAX_DIST = 2

local isCarried = false
local playerEnt = nil
local isPulling = false
local pulledEnt = nil
local anchorEnt = nil
local dynamicEndpoint = false
local pullEndpoint = nil
local grapplePoints = {}
local prevGrapplePos = nil
local prevTargetPos = nil
local tongueStartPoint = nil
local playerMoved = false
local tongueDistanceLeft = 0
local tongueParticle = nil
local tonguePoints = {}
local tongueRetractPoints = {}
local handID = 0
local handEnt = nil
local handAttachment = nil
local laserEndEnt = nil
local rappelling = false
local gravityEnabled = true
local entityTarget = nil
local holdingObject = false
local pullDelay = false

local beamParticle = nil
local BEAM_TRACE_INTERVAL = 0.011

local isTargeting = false
local targetFound = false
local isToungueLaunched = false

local pickupTime = 0
local PICKUP_TRIGGER_DELAY = 0.5

local pulledEntities = {"prop_physics"; "prop_physics_override"; "simple_physics_prop";
	"prop_destinations_physics"; "prop_destinations_tool"; "prop_destinations_game_trophy"}

local TARGET_KEYVALUES = {
	classname = "info_target";	
}

TARGET_KEYVALUES["spawnflags#0"] = "1"
TARGET_KEYVALUES["spawnflags#1"] = "1"


function Precache(context)
	PrecacheParticle("particles/barnacle_tongue.vpcf", context)
	PrecacheParticle("particles/item_laser_pointer.vpcf", context)
	PrecacheSoundFile("soundevents/soundevents_addon.vsndevts", context)
end


function Activate()
	thisEntity:SetThink(function() thisEntity:SetSequence("idle") end, "anim", 0.1)
	
end




function SetEquipped( self, pHand, nHandID, pHandAttachment, pPlayer )
	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	isCarried = true
	pickupTime = Time()
	
	
	beamParticle = ParticleManager:CreateParticle("particles/item_laser_pointer.vpcf", 
		PATTACH_CUSTOMORIGIN, handAttachment)
	ParticleManager:SetParticleControlEnt(beamParticle, 0, handAttachment,
		PATTACH_POINT_FOLLOW, "beam", Vector(0,0,0), true)
	ParticleManager:SetParticleControl(beamParticle, 1, GetMuzzlePos())
		
	-- Control point 3 sets the color of the beam.
	ParticleManager:SetParticleControl(beamParticle, 3, Vector(0.4, 0.4, 0.6))
	
	local paintColor = thisEntity:GetRenderColor()
	handAttachment:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	handAttachment:SetAbsScale(thisEntity:GetAbsScale())
	
	thisEntity:SetThink(TraceBeam, "trace_beam", 0)

	isTargeting = true
	
	return true
end

function SetUnequipped()
	ReleaseTongue(true)

	thisEntity:SetAbsScale(handAttachment:GetAbsScale())
	
	
	isTargeting = false
	
	handAttachment = nil
	playerEnt = nil
	handEnt = nil
	isCarried = false
	rappelling = false
	
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
	
	if input.buttonsPressed:IsBitSet(IN_TRIGGER)
	then
		input.buttonsPressed:ClearBit(IN_TRIGGER)
		if Time() > pickupTime + PICKUP_TRIGGER_DELAY
		then
			OnTriggerPressed()
		end
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


	if input.buttonsPressed:IsBitSet(IN_PAD)
	then
		input.buttonsPressed:ClearBit(IN_PAD)
		rappelling = true
	end
	
	if input.buttonsReleased:IsBitSet(IN_PAD) 
	then
		input.buttonsReleased:ClearBit(IN_PAD)
		rappelling = false
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

	return input;
end



function OnTriggerPressed()

	if targetFound
	then
		ParticleManager:DestroyParticle(beamParticle, true)
		isTargeting = false
		LaunchTongue()
	else
		thisEntity:EmitSound("Barnacle.TongueMiss")
	end

end


function OnTriggerUnpressed()
	
	if isToungueLaunched
	then
		ReleaseTongue(false)
	end	
	
	thisEntity:SetThink(TraceBeam, "trace_beam", 0)
	ParticleManager:DestroyParticle(beamParticle, true)
	beamParticle = ParticleManager:CreateParticle("particles/item_laser_pointer.vpcf", 
		PATTACH_CUSTOMORIGIN, handAttachment)
	ParticleManager:SetParticleControlEnt(beamParticle, 0, handAttachment,
		PATTACH_POINT_FOLLOW, "beam", Vector(0,0,0), true)
	ParticleManager:SetParticleControl(beamParticle, 1, GetMuzzlePos())
	isTargeting = true

end


function LaunchTongue()
	if playerEnt then
		
		handAttachment:SetSequence("rappel")
		holdingObject = false
		
		if TraceTongue()
		then
			StartSoundEvent("Barnacle.TongueAttack", handAttachment)
			StartSoundEvent("Barnacle.TongueFly", handAttachment)
		
			tongueDistanceLeft = (pullEndpoint - GetMuzzlePos()):Length()
			thisEntity:SetThink(TongueTravelFrame, "tongue_travel", TONGUE_PULL_INTERVAL)
			
			tongueStartPoint = GetMuzzlePos()
			
			tongueParticle = ParticleManager:CreateParticle("particles/barnacle_tongue.vpcf", 
				PATTACH_CUSTOMORIGIN, handAttachment)
			ParticleManager:SetParticleControlEnt(tongueParticle, 0, handAttachment, 
				PATTACH_POINT_FOLLOW, "tongue", Vector(0,0,0), true)
			ParticleManager:SetParticleControl(tongueParticle, 1, GetMuzzlePos())
	
			isToungueLaunched = true
		else
			StartSoundEvent("Barnacle.TongueMiss", handAttachment)
		end
	end
end


function ReleaseTongue(instant)

	isToungueLaunched = false
	isPulling = false
	pulledEnt = nil
	handAttachment:SetSequence("idle")
	StopSoundEvent("Barnacle.TongueFly", handAttachment)
	StartSoundEvent("Barnacle.TongueStrain", handAttachment)

	if tongueParticle then
		ParticleManager:DestroyParticle(tongueParticle, true)
	end
	
	if instant then
		
		while #tonguePoints > 0 do
			ParticleManager:DestroyParticle(tonguePoints[#tonguePoints], true)
			table.remove(tonguePoints)
		end
	
	else
		tongueRetractPoints = vlua.clone(grapplePoints)
		thisEntity:SetThink(RetractToungue, "retract")
	end
	
	if entityTarget and IsValidEntity(entityTarget) then
		entityTarget:Kill()
	end
	entityTarget = nil
	
	if playerMoved
	then
		playerMoved = false
		g_VRScript.playerPhysController:RemoveConstraint(playerEnt, thisEntity)
		g_VRScript.playerPhysController:EnableGravity(playerEnt, thisEntity)
		gravityEnabled = true

	end
end


function RetractToungue()
	if not isCarried then
		while #tonguePoints > 0 do
			ParticleManager:DestroyParticle(tonguePoints[#tonguePoints], true)
			table.remove(tonguePoints)
		end
		return nil
	end

	local segment = ParticleManager:CreateParticle("particles/barnacle_tongue_retract.vpcf", 
			PATTACH_CUSTOMORIGIN, handAttachment)
	
	if tongueParticle > 0 then
	
		ParticleManager:DestroyParticle(tongueParticle, true)
		tongueParticle = 0
	
		ParticleManager:SetParticleControl(segment, 1, pullEndpoint)
		
		if #tongueRetractPoints > 0 then
			ParticleManager:SetParticleControl(segment, 0, tongueRetractPoints[1])
			return (pullEndpoint - tongueRetractPoints[1]):Length() / 2000
		else
			ParticleManager:SetParticleControlEnt(segment, 0, handAttachment, 
				PATTACH_POINT_FOLLOW, "tongue", Vector(0,0,0), true)
			return nil
		end
	end	
	
	if #tongueRetractPoints < 1 then
		return nil
	end
		
	ParticleManager:SetParticleControl(segment, 1, tongueRetractPoints[1])
	if #tonguePoints > 0 then
		ParticleManager:DestroyParticle(tonguePoints[1], true)
	end
	
	if #tongueRetractPoints > 1 then
		
		local nextPoint = tongueRetractPoints[2]
		
		ParticleManager:SetParticleControl(segment, 0, nextPoint)
		table.remove(tongueRetractPoints, 1)
		table.remove(tonguePoints, 1)
		return (tongueRetractPoints[1] - nextPoint):Length() / 2000
	else
		
		ParticleManager:SetParticleControlEnt(segment, 0, handAttachment, 
			PATTACH_POINT_FOLLOW, "tongue", Vector(0,0,0), true)
		return nil
	end
end


function TraceTongue()
	local traceTable =
	{
		startpos = GetMuzzlePos();
		endpos = GetMuzzlePos() + GetMuzzleAng():Forward() * TONGUE_MAX_DISTANCE;
		ignore = playerEnt

	}
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, 0.1)
	TraceLine(traceTable)
	
	if traceTable.hit 
	then
		--DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 255, 0, false, 0.2)
		
		pulledEnt = nil
		anchorEnt = nil
		
		if traceTable.enthit and traceTable.enthit:GetEntityIndex() > 0
		then
			for _, entClass in ipairs(pulledEntities)
			do
				if traceTable.enthit:GetClassname() == entClass
				then
					if traceTable.enthit:GetMass() <= ENT_PULL_MAX_MASS then
						pulledEnt = traceTable.enthit
					end
					break
				end
			end
			
			if not pulledEnt then
				anchorEnt = traceTable.enthit 
			end			
			dynamicEndpoint = true
		else
			
			
			dynamicEndpoint = false
		end
		
		pullEndpoint = traceTable.pos + traceTable.normal * GRAPPLE_POINT_FIXUP
		
		if dynamicEndpoint then
			entityTarget = SpawnEntityFromTableSynchronous(TARGET_KEYVALUES.classname, TARGET_KEYVALUES)
			if pulledEnt then
				entityTarget:SetParent(pulledEnt, "")
			else
				entityTarget:SetParent(anchorEnt, "")
			end
			entityTarget:SetAbsOrigin(pullEndpoint)
		end
		
		prevTargetPos = pullEndpoint
		prevGrapplePos = GetMuzzlePos()
		grapplePoints = {}
		isPulling = true
		return true
	end
	
	anchorEnt = nil
	pulledEnt = nil
	isPulling = false
	return nil
end


function TraceBeam()
	if not isTargeting
	then 
		return nil
	end
		
	local beamColor = Vector(0.5, 0.5, 0.8)

	local traceTable =
	{
		startpos = GetMuzzlePos();
		endpos = GetMuzzlePos() + GetMuzzleAng():Forward() * TONGUE_MAX_DISTANCE;
		ignore = playerEnt

	}
	
	local beamEnd = traceTable.endpos
	
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, 0.1)
	TraceLine(traceTable)

	if traceTable.hit 
	then
		--DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 255, 255, false, 0.5)
		
		targetFound = true
		
		local pullableHit = false
		if traceTable.enthit 
		then
			for _, entClass in ipairs(pulledEntities)
			do
				if traceTable.enthit:GetClassname() == entClass
				then
					if traceTable.enthit:GetMass() <= ENT_PULL_MAX_MASS then
						pullableHit = true
					end
					break
				end
			end
		end
		
		if traceTable.enthit:GetMoveParent() ~= nil
		then
			pullableHit = false
		end
		
		if pullableHit
		then
			beamColor = Vector(0.8, 0.8, 0.5)
		else
			beamColor = Vector(0.5, 0.8, 0.5)
		end
			
		beamEnd = traceTable.pos
	
		--beamEnd = handAttachment:GetAbsOrigin()  + RotatePosition(Vector(0,0,0), 
				--handAttachment:GetAngles(), Vector(TONGUE_MAX_DISTANCE * traceTable.fraction, 0, 0))	
	else
		targetFound = false		
		beamEnd = GetMuzzlePos() + GetMuzzleAng():Forward() * TONGUE_MAX_DISTANCE
	end
	
		
	--ParticleManager:SetParticleControlEnt(beamParticle, 1, 
		--laserEndEnt, PATTACH_ABSORIGIN_FOLLOW, "", laserEndEnt:GetOrigin(), true)
	ParticleManager:SetParticleControl(beamParticle, 1, beamEnd)
	ParticleManager:SetParticleControl(beamParticle, 3, beamColor)
	
	return BEAM_TRACE_INTERVAL
end


function TongueTravelFrame()
	if not isPulling then
		return nil
	end
		
	tongueDistanceLeft = tongueDistanceLeft - TONGUE_SPEED
	
	if dynamicEndpoint then
		pullEndpoint = entityTarget:GetAbsOrigin()
	end
	
	if tongueDistanceLeft <= 0 then
		if pulledEnt then

			--ParticleManager:SetParticleControlEnt(tongueParticle, 1, entityTarget, 
				--PATTACH_ABSORIGIN_FOLLOW, "", Vector(0,0,0), true)
			ParticleManager:SetParticleControl(tongueParticle, 1, entityTarget:GetAbsOrigin())
			
			thisEntity:SetThink(TongueDelayPosFixup, "pull_delay", TONGUE_PULL_INTERVAL)

		else
		
			if anchorEnt then					
				ParticleManager:SetParticleControl(tongueParticle, 1, entityTarget:GetAbsOrigin())
				thisEntity:SetThink(TongueDelayPosFixup, "pull_delay", TONGUE_PULL_INTERVAL)
			else
				ParticleManager:SetParticleControl(tongueParticle, 1, pullEndpoint)
			end
			
			playerMoved = true
			g_VRScript.playerPhysController:AddConstraint(playerEnt, thisEntity)
			
			g_VRScript.playerPhysController:DisableGravity(playerEnt, thisEntity)
			gravityEnabled = false
					
			
		end
		pullDelay = true
		thisEntity:SetThink(TraceGrappleObstacles, "trace_obstacles", TRACE_OBSTACLE_INTERVAL)
		thisEntity:SetThink(TonguePullFrame, "tongue_pull", TONGUE_PULL_DELAY)
		thisEntity:SetThink(TongueAnimationFrame, "tongue_anim", TONGUE_PULL_DELAY)
		StopSoundEvent("Barnacle.TongueFly", handAttachment)
		StartSoundEvent("Barnacle.TongueHit", handAttachment)
		return nil
	end
	
	ParticleManager:SetParticleControl(tongueParticle, 1, 
		pullEndpoint + (tongueStartPoint - pullEndpoint):Normalized() * tongueDistanceLeft)
	
	return TONGUE_PULL_INTERVAL
end


function TongueDelayPosFixup()

	if isPulling and pullDelay and dynamicEndpoint and IsValidEntity(entityTarget) then
		pullEndpoint = entityTarget:GetAbsOrigin()
		return TONGUE_PULL_INTERVAL
	end
	return nil
end


function TonguePullFrame()
	
	pullDelay = false
	
	if not isPulling
	then
		return nil
	end
	
	if not IsValidEntity(pulledEnt)
	then
		pulledEnt = nil
	end
	
	if not IsValidEntity(anchorEnt)
	then
		anchorEnt = nil
	end
	
	if not entityTarget or not IsValidEntity(entityTarget) then
		entityTarget = nil
		anchorEnt = nil
		pulledEnt = nil
	end
	
	if pulledEnt then
		PullObject()
	else
		PullPlayer()
	end

		
	return TONGUE_PULL_INTERVAL
end



function PullPlayer()

	if rappelling then
		
		if not gravityEnabled
		then
			g_VRScript.playerPhysController:EnableGravity(playerEnt, thisEntity)
			gravityEnabled = true		
		end		
		
		if g_VRScript.playerPhysController:IsPlayerOnGround(playerEnt) then
			return
		end
		
	elseif gravityEnabled then
			g_VRScript.playerPhysController:DisableGravity(playerEnt, thisEntity)
			gravityEnabled = false
	end

		
	if anchorEnt then
		pullEndpoint = entityTarget:GetOrigin()
		ParticleManager:SetParticleControl(tongueParticle, 1, entityTarget:GetAbsOrigin())
	end	
	
	local grapplePoint = pullEndpoint
	
	if #grapplePoints > 0 then
		grapplePoint = grapplePoints[#grapplePoints]
	end
	
	local pullVector = (grapplePoint - GetMuzzlePos()):Normalized() * TONGUE_PULL_PLAYER_SPEED 
	
	if rappelling then
		pullVector = Vector(pullVector.x, pullVector.y, pullVector.z * 0.8)
	end
	
	local distance = (grapplePoint - GetMuzzlePos()):Length()
	
	if distance > TONGUE_PULL_MIN_DISTANCE or rappelling
	then
	
		if distance < TONGUE_PULL_PLAYER_EASE_DISTANCE
		then 
			pullVector = pullVector * (distance / TONGUE_PULL_PLAYER_EASE_DISTANCE)			
		end
				
		-- Prevent player from going through floors
		if pullVector.z < 0 and g_VRScript.playerPhysController:TracePlayerHeight(playerEnt) <= 0
		then
			pullVector = pullVector - Vector(0, 0, pullVector.z)
		end
	
		g_VRScript.playerPhysController:AddVelocity(playerEnt, pullVector)
		--playerEnt:GetHMDAnchor():SetOrigin(GetMuzzlePos() - gunRelativePos + pullVector)
	
	else
		g_VRScript.playerPhysController:StickFrame(playerEnt)
		if distance < TONGUE_PULL_PLAYER_EASE_DISTANCE
		then 
			pullVector = pullVector * distance / TONGUE_PULL_PLAYER_EASE_DISTANCE
		end
		-- Prevent player from going through floors
		if pullVector.z < 0 and g_VRScript.playerPhysController:TracePlayerHeight(playerEnt) <= 0
		then
			pullVector = pullVector - Vector(0, 0, pullVector.z)
		end
		g_VRScript.playerPhysController:MovePlayer(playerEnt, pullVector)
		--playerEnt:GetHMDAnchor():SetOrigin(GetMuzzlePos() - gunRelativePos + pullVector)
	end
	
	--DebugDrawLine(GetMuzzlePos(), pullEndpoint, 0, 0, 255, false, TONGUE_PULL_INTERVAL)
end



function TraceGrappleObstacles()
	if not isPulling then
		return nil
	end

	local anchorPoint = pullEndpoint
	
	if pulledEnt then
		anchorPoint = pulledEnt:GetCenter()
	end
	
	if #grapplePoints > 0 then
		anchorPoint = grapplePoints[#grapplePoints]
	end
	
	local endVec = GetMuzzlePos()
	
	local traceTable =
	{
		startpos = endVec;
		endpos = anchorPoint;
		ignore = playerEnt;
		mask = 33636363
	}
	TraceLine(traceTable)
	
	-- If inside something, consider position invalid and don't update state.
	if traceTable.startsolid or TraceCheckIfInside(endVec, prevGrapplePos) then
		return TRACE_OBSTACLE_INTERVAL
	end
	
	local prevPos = prevGrapplePos
	prevGrapplePos = endVec
	
	-- Obstacle between player and grappling point
	if traceTable.hit then
		--DebugDrawLine(traceTable.startpos, traceTable.pos, 255, 0, 0, false, TRACE_OBSTACLE_INTERVAL)
		
		-- Don't create corner on pulled prop
		if pulledEnt and traceTable.enthit and traceTable.enthit == pulledEnt then
			return TRACE_OBSTACLE_INTERVAL
		end
		
		anchorPoint = traceTable.pos
		
		local hitPos = traceTable.pos
		local hitNormal = traceTable.normal
		local travelVec = endVec - prevPos
		local travelDist = travelVec:Length()
		local traceDist = GRAPPLE_CORNER_TRACE_MAX_DIST
		local pointFound = false
		
		
		if #grapplePoints > 64 then
			return TRACE_OBSTACLE_INTERVAL
		end
		
		-- Do traces from previous player location to find edge of the obstacle
		while not pointFound and traceDist < travelDist do
					
			traceTable.startpos = VectorLerp(traceDist / travelDist, prevPos, endVec)
			TraceLine(traceTable)
			--DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 255, 0, false, 2)
			if traceTable.hit then
				pointFound = true
				anchorPoint = traceTable.pos + traceTable.normal * GRAPPLE_POINT_FIXUP -- Push out point from surface
			end
			
			traceDist = traceDist + GRAPPLE_CORNER_TRACE_MAX_DIST
			
		end
		
		table.insert(grapplePoints, anchorPoint)
		
	else -- Check for unraveling
	
		traceTable.startpos = endVec
		local firstElem = true
		
		--DebugDrawLine(traceTable.startpos, traceTable.endpos, 0, 255, 0, true, TRACE_OBSTACLE_INTERVAL)
		
		 if #grapplePoints > 0 then
		 	
		 	for i = #grapplePoints, 0, -1 do
		 		
		 		if i > 0 then
		 			traceTable.endpos = grapplePoints[i]
		 		else
		 			traceTable.endpos = pullEndpoint
		 		end
		 		
		 		TraceLine(traceTable)
		 		
		 		if traceTable.hit then
		 			--DebugDrawLine(traceTable.startpos, traceTable.endpos, 128, 128, 255, true, TRACE_OBSTACLE_INTERVAL)
		 			break
		 		end
		 		--DebugDrawLine(traceTable.startpos, traceTable.endpos, 0, 128, 128, true, TRACE_OBSTACLE_INTERVAL)
		 		
		 		if not firstElem then 		
		 			table.remove(grapplePoints, i + 1)
		 		end
		 		
		 		firstElem = false
		 	end
		 end
	end
	
	UpdateTongueParticle()
	TraceTargetObstacles()
	UpdateTongueParticleFront()
	
	-- Draw grapple path
	if g_VRScript.playerPhysController:IsDebugDrawEnabled()
	then
		local prev = pullEndpoint
		
		if pulledEnt then
			prev = pulledEnt:GetCenter()
		end
		
		for _, point in ipairs(grapplePoints) do
			DebugDrawLine(prev, point, 128, 128, 128, true, TRACE_OBSTACLE_INTERVAL)
			prev = point
		end
		DebugDrawLine(prev, GetMuzzlePos(), 128, 128, 128, true, TRACE_OBSTACLE_INTERVAL)
	end

	
	return TRACE_OBSTACLE_INTERVAL
end


function TraceTargetObstacles()

	if not dynamicEndpoint then
		return
	end
	
	local objectPos = pullEndpoint
	
	if pulledEnt then
		objectPos = pulledEnt:GetCenter()
	end
	
	local jointPos = GetMuzzlePos()
	
	if #grapplePoints > 0 then
		jointPos = grapplePoints[1]
	end

	
	local traceTable =
	{
		startpos = objectPos;
		endpos = jointPos;
		ignore = playerEnt;
		mask = 33636363
	}
	TraceLine(traceTable)
	
	-- If inside something, consider position invalid and don't update state.
	if traceTable.startsolid or TraceCheckIfInside(objectPos, prevTargetPos) then
		return
	end
	
	local prevPos = prevTargetPos
	prevTargetPos = objectPos
	
	-- Obstacle between object and grappling point
	if traceTable.hit then
		--DebugDrawLine(traceTable.startpos, traceTable.pos, 255, 0, 0, false, TRACE_OBSTACLE_INTERVAL)
		
		local newPointPos = traceTable.pos
		
		local hitPos = traceTable.pos
		local hitNormal = traceTable.normal
		local travelVec = objectPos - prevPos
		local travelDist = travelVec:Length()
		local traceDist = GRAPPLE_CORNER_TRACE_MAX_DIST
		local pointFound = false
		
		
		if #grapplePoints > 64 then
			return
		end
		
		-- Do traces from previous player location to find edge of the obstacle
		while not pointFound and traceDist < travelDist do
					
			traceTable.startpos = VectorLerp(traceDist / travelDist, prevPos, objectPos)
			TraceLine(traceTable)
			--DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 255, 0, false, 2)
			if traceTable.hit then
				pointFound = true
				newPointPos = traceTable.pos + traceTable.normal * GRAPPLE_POINT_FIXUP -- Push out point from surface
			end
			
			traceDist = traceDist + GRAPPLE_CORNER_TRACE_MAX_DIST
			
		end
		
		table.insert(grapplePoints, 1, newPointPos)
		
	else -- Check for unraveling
	
		traceTable.startpos = objectPos
		local firstElem = true
		
		--DebugDrawLine(traceTable.startpos, traceTable.endpos, 0, 255, 0, true, TRACE_OBSTACLE_INTERVAL)
		
		 if #grapplePoints > 0 then
		 	
		 	for i = 1, #grapplePoints + 1 do
		 			 		
		 		if i <= #grapplePoints then
		 			traceTable.endpos = grapplePoints[i]
		 		else
		 			traceTable.endpos = GetMuzzlePos()
		 		end
		 		
		 		TraceLine(traceTable)
		 		
		 		if traceTable.hit then
		 			--DebugDrawLine(traceTable.startpos, traceTable.endpos, 128, 128, 255, true, TRACE_OBSTACLE_INTERVAL)
		 			break
		 		end
		 		
		 		-- Offest the removed points by one, so we preserve the last visible one.
		 		if not firstElem then
		 			table.remove(grapplePoints, 1)
		 		end
		 		
		 		firstElem = false
		 		
		 		--DebugDrawLine(traceTable.startpos, traceTable.endpos, 0, 128, 128, true, TRACE_OBSTACLE_INTERVAL)
		 	end
		end
	end
	
end



-- Primitive way of checking if position is inside a mesh. Fails if blocked by another mesh.
function TraceCheckIfInside(pos, outsidePos)
	local traceTable =
	{
		startpos = outsidePos;
		endpos = pos;
		ignore = playerEnt;
		mask = 33636363
	}
	TraceLine(traceTable)

	if traceTable.hit then
		traceTable.startpos = pos
		traceTable.endpos = outsidePos
		TraceLine(traceTable)
		
		return not traceTable.hit
	end
	return false
end

function UpdateTongueParticleFront()

	if #grapplePoints < 2 then 
		return
	end
	if #grapplePoints > #tonguePoints then
	

			ParticleManager:DestroyParticle(tongueParticle, true)
			tongueParticle = ParticleManager:CreateParticle("particles/barnacle_tongue.vpcf", 
				PATTACH_CUSTOMORIGIN, handAttachment)
			ParticleManager:SetParticleControl(tongueParticle, 0, grapplePoints[1])
			ParticleManager:SetParticleControl(tongueParticle, 1, pullEndpoint)	
	
			
		for idx = 1, #grapplePoints - #tonguePoints  do
			local point = ParticleManager:CreateParticle("particles/barnacle_tongue.vpcf", 
				PATTACH_CUSTOMORIGIN, handAttachment)
			ParticleManager:SetParticleControl(point, 1, grapplePoints[idx])
			ParticleManager:SetParticleControl(point, 0, grapplePoints[idx + 1])

			table.insert(tonguePoints, idx, point)
		end
	end
	
		
	while #grapplePoints > 1 and #grapplePoints < #tonguePoints do
		
		if #tonguePoints > 0 then
			ParticleManager:DestroyParticle(tonguePoints[1], true)
			table.remove(tonguePoints, 1)
		end
		table.remove(grapplePoints, 1)
		
		ParticleManager:SetParticleControl(tongueParticle, 0, grapplePoints[1])
	end


end


function UpdateTongueParticle()
	
	if #grapplePoints > #tonguePoints then
	
		-- Recreate the last segment to not be attached to the grapple.
		if #tonguePoints == 0 then
			ParticleManager:DestroyParticle(tongueParticle, true)
			tongueParticle = ParticleManager:CreateParticle("particles/barnacle_tongue.vpcf", 
				PATTACH_CUSTOMORIGIN, handAttachment)
			ParticleManager:SetParticleControl(tongueParticle, 0, grapplePoints[1])
			ParticleManager:SetParticleControl(tongueParticle, 1, pullEndpoint)
			
		else	
			ParticleManager:DestroyParticle(tonguePoints[#tonguePoints], true)
			tonguePoints[#tonguePoints] = ParticleManager:CreateParticle("particles/barnacle_tongue.vpcf", 
				PATTACH_CUSTOMORIGIN, handAttachment)
			ParticleManager:SetParticleControl(tonguePoints[#tonguePoints], 0, grapplePoints[#tonguePoints + 1])
			ParticleManager:SetParticleControl(tonguePoints[#tonguePoints], 1, grapplePoints[#tonguePoints])
		end
			
		for idx = #tonguePoints + 1, #grapplePoints  do
			local point = ParticleManager:CreateParticle("particles/barnacle_tongue.vpcf", 
				PATTACH_CUSTOMORIGIN, handAttachment)
			ParticleManager:SetParticleControl(point, 1, grapplePoints[idx])
				
			if idx + 1 > #grapplePoints then
				ParticleManager:SetParticleControlEnt(point, 0, handAttachment, 
					PATTACH_POINT_FOLLOW, "tongue", Vector(0,0,0), true)
			else
				ParticleManager:SetParticleControl(point, 0, grapplePoints[idx + 1])
			end
			table.insert(tonguePoints, point)
		end
	
	elseif #grapplePoints < #tonguePoints then
		
		local idx = #tonguePoints
		
		while #grapplePoints < #tonguePoints do
			ParticleManager:DestroyParticle(tonguePoints[idx], true)

			if idx > 1 then
				ParticleManager:SetParticleControlEnt(tonguePoints[idx - 1], 0, handAttachment, 
					PATTACH_POINT_FOLLOW, "tongue", Vector(0,0,0), true)
			else
				ParticleManager:SetParticleControlEnt(tongueParticle, 0, handAttachment, 
					PATTACH_POINT_FOLLOW, "tongue", Vector(0,0,0), true)
			end
			table.remove(tonguePoints)
			idx = idx - 1
		end
	
	end

end


function PullObject()
	
	ParticleManager:SetParticleControl(tongueParticle, 1, entityTarget:GetAbsOrigin())
	
	if rappelling then return end

	local pullTargetPoint = GetMuzzlePos()
	
	if #grapplePoints > 0 then
		pullTargetPoint = grapplePoints[1]
	end
	
	local pullVector = nil

	pullVector = (pulledEnt:GetCenter() - pullTargetPoint):Normalized() * -TONGUE_PULL_FORCE	
	 
	local distance = (pulledEnt:GetCenter() - pullTargetPoint):Length()

	
	--[[if #grapplePoints > 0 and distance < GetMinDimension(pulledEnt) then
		
		ParticleManager:DestroyParticle(tonguePoints[1], true)
		table.remove(grapplePoints, 1)
		table.remove(tonguePoints, 1)
		
		if #grapplePoints > 0 then
			ParticleManager:SetParticleControl(tongueParticle, 0, grapplePoints[1])
		else
			ParticleManager:SetParticleControlEnt(tongueParticle, 0, handAttachment, 
				PATTACH_POINT_FOLLOW, "tongue", Vector(0,0,0), true)
		end

	
		if #grapplePoints > 0 then
			pullTargetPoint = grapplePoints[#grapplePoints]
		else
			pullTargetPoint = GetMuzzlePos()
		end
	end]]
	
	if distance > TONGUE_PULL_MIN_DISTANCE or #grapplePoints > 0
	then
		if distance < TONGUE_PULL_PLAYER_EASE_DISTANCE and #grapplePoints == 0
		then 
			pullVector = pullVector * (distance / TONGUE_PULL_PLAYER_EASE_DISTANCE)
		end
				
		pulledEnt:ApplyAbsVelocityImpulse(pullVector)
	end
	
	if #grapplePoints == 0 then
		local collisionDist = CalcDistanceBetweenEntityOBB(pulledEnt, handAttachment)
		
		if collisionDist == 0 then
			local pushVec = (pullTargetPoint - pulledEnt:GetCenter())
			
	
			pulledEnt:ApplyAbsVelocityImpulse(pushVec * 10 - GetPhysVelocity(pulledEnt))
			SetPhysAngularVelocity(pulledEnt, GetPhysAngularVelocity(handAttachment))
		end
		
		if collisionDist < 16 then
			holdingObject = true
		else
			holdingObject = false
		end
	end
end



function TongueAnimationFrame()
if not isPulling
	then
		return nil
	end
	
	if rappelling
	then
		handAttachment:SetSequence("rappel")
	elseif holdingObject then
		handAttachment:SetSequence("hold_item")
	else
		StartSoundEvent("Barnacle.TongueRetract", handAttachment)
		handAttachment:SetSequence("pull")
	end
	
	return REEL_ANIM_INTERVAL
end

function GetMinDimension(entity)
	local boundMin = entity:GetBoundingMins()
	local boundMax = entity:GetBoundingMaxs()
	
	return min(abs(boundMax.x - boundMin.x), abs(boundMax.y - boundMin.y), abs(boundMax.z - boundMin.z))
end


function GetMuzzlePos()
	local idx = handAttachment:ScriptLookupAttachment("muzzle")
	return handAttachment:GetAttachmentOrigin(idx)
end

function GetMuzzleAng()
	local idx = handAttachment:ScriptLookupAttachment("muzzle")
	vec = handAttachment:GetAttachmentAngles(idx)
	return QAngle(vec.x, vec.y, vec.z)
end

