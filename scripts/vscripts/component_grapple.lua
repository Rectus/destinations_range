--[[
	Grapple tool component script.
	
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


local GRAPPLE_MAX_DISTANCE = 3000

local GRAPPLE_SPEED = 64
local GRAPPLE_PULL_FORCE = 200
local GRAPPLE_PULL_INTERVAL = 0.010
local GRAPPLE_PULL_DELAY = 0.5
local GRAPPLE_REEL_SOUND_INTERVAL = 10
local GRAPPLE_REEL_ANIM_INTERVAL = 0.2

local GRAPPLE_ENT_PULL_MAX_MASS = 100
local GRAPPLE_ENT_PULL_RELEASE_DISTANCE = 50

local GRAPPLE_PULL_PLAYER_MAX_SPEED = 500
local GRAPPLE_PULL_PLAYER_MIN_SPEED = 50
local GRAPPLE_PULL_PLAYER_MIN_DISTANCE = 1

local GRAPPLE_TRACE_OBSTACLE_INTERVAL = 0.044
local GRAPPLE_POINT_FIXUP = 0.5
local GRAPPLE_CORNER_TRACE_MAX_DIST = 2

local GRAPPLE_BEAM_TRACE_INTERVAL = 0.011


local grappleIsPulling = false
local grapplePulledEnt = nil
local grappleAnchorEnt = nil
local grappleDynamicEndpoint = false
local grapplePullEndpoint = nil
local grapplePoints = {}
local prevGrapplePos = nil
local prevGrappleTargetPos = nil
local grappleStartPoint = nil
local grapplePlayerMoved = false
local grappleDistanceLeft = 0
local grappleWireParticle = nil
local grappleWirePoints = {}
local grappleWireRetractPoints = {}

local grappleBeamEndEnt = nil
local grappleRappelling = false
local grappleGravityEnabled = true
local grappleTarget = nil
local grappleHook = nil
local grappleHoldingObject = false
local grapplePullDelay = false
local grappleSurfaceNormal = nil

local grappleBeamParticle = -1


local grappleIsTargeting = false
local grappleTargetFound = false
local isGrappleLaunched = false

local grapplePulledEntities = {"prop_physics"; "prop_physics_override"; "simple_physics_prop";
	"prop_destinations_physics"; "prop_destinations_tool"; "prop_destinations_game_trophy"}
	
local TARGET_KEYVALUES = {
	classname = "info_target";	
}

TARGET_KEYVALUES["spawnflags#0"] = "1"
TARGET_KEYVALUES["spawnflags#1"] = "1"
	
-- Base tool variables
local grappleIsCarried = false
local grapplePlayerEnt = nil	
local grappleHandAttachment = nil
local grappleBaseEnt = nil

local grappleKeyvals = nil
local playerPhys = nil



function EnableGrapple(hook, player, baseEnt, handAttchment, phys)
	grappleHook = hook
	grapplePlayerEnt = player	
	grappleHandAttachment = handAttchment
	grappleBaseEnt = baseEnt
	playerPhys = phys
	
	grappleHook:RemoveEffects(32)
	grappleIsTargeting = true
	grappleIsCarried = true
	
	grappleHook:SetSequence("idle")
	grappleHook:SetPoseParameter("claw_open", 1)
	grappleBaseEnt:SetThink(TraceBeam, "grapple_trace_beam", 0)
	return true
end


function DisableGrapple()
	ReleaseGrapple(true)
	
	ParticleManager:DestroyParticle(grappleBeamParticle, true)
	grappleBeamParticle = -1

	if IsValidEntity(grappleHandAttachment) then
		grappleHandAttachment:SetPoseParameter("spin", 0)
	end

	if IsValidEntity(grappleHook) then
		grappleHook:SetSequence("idle")
		grappleHook:SetPoseParameter("claw_open", 1)
		grappleHook:RemoveEffects(32)
	end
	
	grappleIsTargeting = false	
	grappleRappelling = false
	grappleIsCarried = false
	grappleIsPulling = false
	return true
end


function SetGrappleRappel(val)
	grappleRappelling = val
end


function LaunchGrapple()
	if grapplePlayerEnt then
	
		if not grappleTargetFound
		then
			StartSoundEvent("Grapple_Miss", grappleHandAttachment)
			return
		end
	
		ParticleManager:DestroyParticle(grappleBeamParticle, true)
		grappleBeamParticle = -1
		grappleIsTargeting = false
		grappleHook:SetPoseParameter("claw_open", 1)
		grappleHoldingObject = false
		
		if TraceGrapple()
		then
			StartSoundEvent("Grapple_Fire", grappleHook)
			StartSoundEvent("Grapple_Fly", grappleHandAttachment)
			grappleHandAttachment:SetPoseParameter("spin", 1)
			RumbleController(2, 0.1, 100)
			
			local smoke = ParticleManager:CreateParticle("particles/tools/grapple_launch.vpcf", 
				PATTACH_ABSORIGIN, grappleHook)
			ParticleManager:SetParticleControlEnt(smoke, 
				0, grappleHook, PATTACH_CUSTOMORIGIN_FOLLOW, nil, Vector(0, 0, 0), false)
			
		
			grappleDistanceLeft = (grapplePullEndpoint - GetMuzzlePos()):Length()
			grappleBaseEnt:SetThink(GrappleTravelFrame, "grapple_travel", GRAPPLE_PULL_INTERVAL)
			grappleHook:SetParent(nil, "")
			
			grappleStartPoint = GetMuzzlePos()
			
			grappleWireParticle = ParticleManager:CreateParticle("particles/tools/grapple_wire.vpcf", 
				PATTACH_CUSTOMORIGIN, grappleHandAttachment)
			ParticleManager:SetParticleControlEnt(grappleWireParticle, 0, grappleHandAttachment, 
				PATTACH_POINT_FOLLOW, "wire", Vector(0,0,0), true)
			SetWireEndpoint()
	
			isGrappleLaunched = true
		else
			StartSoundEvent("Grapple_Miss", grappleHandAttachment)
		end
	end
end


function ReleaseGrappleButton()
	
	if isGrappleLaunched
	then
		ReleaseGrapple(false)
		grappleBaseEnt:SetThink(TraceBeam, "grapple_trace_beam", 0.3)
	end	
	
	grappleIsTargeting = true
	grappleTargetFound = false	
end


function ReleaseGrapple(instant)

	isGrappleLaunched = false
	grappleIsPulling = false
	grapplePulledEnt = nil
	
	StopSoundEvent("Grapple_Fly", grappleHandAttachment)

	if grappleWireParticle then
		ParticleManager:DestroyParticle(grappleWireParticle, true)
	end
	
	if instant then
		
		while #grappleWirePoints > 0 do
			ParticleManager:DestroyParticle(grappleWirePoints[#grappleWirePoints], true)
			table.remove(grappleWirePoints)
		end
		--StartSoundEvent("Grapple_Return", grappleHandAttachment)
		grappleHook:SetPoseParameter("claw_open", 1)
		grappleHandAttachment:SetPoseParameter("spin", 0)
		grappleHook:SetParent(grappleHandAttachment, "")
		grappleHook:SetLocalOrigin(Vector(0,0,0))
		grappleHook:SetLocalAngles(0,0,0)
	
	else
		grappleWireRetractPoints = vlua.clone(grapplePoints)
		grappleBaseEnt:SetThink(RetractGrappleLine, "grapple_retract")
		grappleHook:AddEffects(32)
		grappleHandAttachment:SetPoseParameter("spin", -1)
		grappleHook:SetPoseParameter("claw_open", 0.25)
		RumbleController(1, 0.1, 100)
	end

	
	if grapplePlayerMoved
	then
		grapplePlayerMoved = false
		playerPhys:RemoveConstraint(grapplePlayerEnt, grappleBaseEnt)
		playerPhys:EnableGravity(grapplePlayerEnt, grappleBaseEnt)
		grappleGravityEnabled = true

	end
end


function RetractGrappleLine()
	if not grappleIsCarried then
		while #grappleWirePoints > 0 do
			ParticleManager:DestroyParticle(grappleWirePoints[#grappleWirePoints], true)
			table.remove(grappleWirePoints)
		end
		grappleHook:SetParent(grappleBaseEnt, "")
		grappleHook:RemoveEffects(32)
		grappleHandAttachment:SetPoseParameter("spin", 0)
		--StartSoundEvent("Grapple_Return", grappleHandAttachment)
		return nil
	end

	local segment = ParticleManager:CreateParticle("particles/tools/grapple_wire_retract.vpcf", 
			PATTACH_CUSTOMORIGIN, grappleHandAttachment)
	
	if grappleWireParticle > 0 then
	
		ParticleManager:DestroyParticle(grappleWireParticle, true)
		grappleWireParticle = 0
	
		ParticleManager:SetParticleControl(segment, 1, grapplePullEndpoint)
		ParticleManager:SetParticleControlForward(segment, 1, grapplePullEndpoint - grappleHandAttachment:GetOrigin())
		
		if #grappleWireRetractPoints > 0 then
			ParticleManager:SetParticleControl(segment, 0, grappleWireRetractPoints[1])
			grappleHook:SetAbsOrigin(grappleWireRetractPoints[1])
			return (grapplePullEndpoint - grappleWireRetractPoints[1]):Length() / 2000
		else
			ParticleManager:SetParticleControlEnt(segment, 0, grappleHandAttachment, 
				PATTACH_POINT_FOLLOW, "wire", Vector(0,0,0), true)
			grappleHook:SetParent(grappleHandAttachment, "")
			grappleHook:SetLocalOrigin(Vector(0,0,0))
			grappleHook:SetLocalAngles(0,0,0)
			grappleBaseEnt:SetThink(GrappleHookRenderDelay, "hook_render", (grapplePullEndpoint - GetMuzzlePos()):Length() / 2000)
			return nil
		end
	end	
	
	if #grappleWireRetractPoints < 1 then
		--grappleBaseEnt:SetThink(GrappleHookRenderDelay, "hook_render", 0.5)
		return nil
	end
		
	ParticleManager:SetParticleControl(segment, 1, grappleWireRetractPoints[1])
	if #grappleWirePoints > 0 then
		ParticleManager:DestroyParticle(grappleWirePoints[1], true)
	end
	
	if #grappleWireRetractPoints > 1 then
		
		local nextPoint = grappleWireRetractPoints[2]
		grappleHook:SetAbsOrigin(grappleWireRetractPoints[1])
		ParticleManager:SetParticleControl(segment, 0, nextPoint)
		table.remove(grappleWireRetractPoints, 1)
		table.remove(grappleWirePoints, 1)
		--grappleBaseEnt:SetThink(GrappleHookRenderDelay, "hook_render", (grappleWireRetractPoints[1] - nextPoint):Length() / 2000)
		return (grappleWireRetractPoints[1] - nextPoint):Length() / 2000
	else
		
		ParticleManager:SetParticleControlEnt(segment, 0, grappleHandAttachment, 
			PATTACH_POINT_FOLLOW, "wire", Vector(0,0,0), true)
		ParticleManager:SetParticleControl(segment, 0, GetMuzzlePos())
		grappleHook:SetParent(grappleHandAttachment, "")
		grappleHook:SetLocalOrigin(Vector(0,0,0))
		grappleHook:SetLocalAngles(0,0,0)
		grappleBaseEnt:SetThink(GrappleHookRenderDelay, "hook_render", (grappleWireRetractPoints[1] - GetMuzzlePos()):Length() / 2000)
		return nil
	end
end


function GrappleHookRenderDelay()
	grappleHook:RemoveEffects(32)
	grappleHandAttachment:SetPoseParameter("spin", 0)
	grappleHook:SetPoseParameter("claw_open", 1)
	StartSoundEvent("Grapple_Return", grappleHandAttachment)
	RumbleController(2, 0.05, 100)
end


function TraceGrapple(this)
	local traceTable =
	{
		startpos = GetMuzzlePos();
		endpos = GetMuzzlePos() + GetMuzzleAng():Forward() * GRAPPLE_MAX_DISTANCE;
		ignore = grapplePlayerEnt

	}
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, 0.1)
	TraceLine(traceTable)
	
	if traceTable.hit 
	then
		--DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 255, 0, false, 0.2)
		
		grapplePulledEnt = nil
		grappleAnchorEnt = nil
		grappleSurfaceNormal = traceTable.normal
		
		if traceTable.enthit and traceTable.enthit:GetEntityIndex() > 0
		then
			for _, entClass in ipairs(grapplePulledEntities)
			do
				if traceTable.enthit:GetClassname() == entClass
				then
					if traceTable.enthit:GetMass() <= GRAPPLE_ENT_PULL_MAX_MASS then
						grapplePulledEnt = traceTable.enthit
					end
					break
				end
			end
			
			if not grapplePulledEnt then
				grappleAnchorEnt = traceTable.enthit 
			end			
			grappleDynamicEndpoint = true
		else
			
			grappleDynamicEndpoint = false
		end
		
		grapplePullEndpoint = traceTable.pos + traceTable.normal * GRAPPLE_POINT_FIXUP
		
		if grappleDynamicEndpoint then
			grappleTarget = SpawnEntityFromTableSynchronous(TARGET_KEYVALUES.classname, TARGET_KEYVALUES)
			if grapplePulledEnt then
				grappleTarget:SetParent(grapplePulledEnt, "")
			else
				grappleTarget:SetParent(grappleAnchorEnt, "")
			end
			grappleTarget:SetAbsOrigin(grapplePullEndpoint)
		end
		
		prevGrappleTargetPos = grapplePullEndpoint
		prevGrapplePos = GetMuzzlePos()
		grapplePoints = {}
		grappleIsPulling = true
		return true
	end
	
	grappleAnchorEnt = nil
	grapplePulledEnt = nil
	grappleIsPulling = false
	return nil
end


function TraceBeam(this)
	if not grappleIsTargeting
	then 
		return nil
	end
	
	
	if grappleBeamParticle < 0 then
		grappleBeamParticle = ParticleManager:CreateParticle("particles/item_laser_pointer.vpcf", 
		PATTACH_CUSTOMORIGIN, grappleHandAttachment)
		ParticleManager:SetParticleControlEnt(grappleBeamParticle, 0, grappleHandAttachment,
			PATTACH_POINT_FOLLOW, "beam", Vector(0,0,0), true)
		--ParticleManager:SetParticleControl(grappleBeamParticle, 1, GetMuzzlePos())
			
		-- Control point 3 sets the color of the beam.
		ParticleManager:SetParticleControl(grappleBeamParticle, 3, Vector(0.4, 0.4, 0.6))
	end
		
	local beamColor = Vector(0.5, 0.5, 0.8)

	local traceTable =
	{
		startpos = GetMuzzlePos();
		endpos = GetMuzzlePos() + GetMuzzleAng():Forward() * GRAPPLE_MAX_DISTANCE;
		ignore = grapplePlayerEnt

	}
	
	local beamEnd = traceTable.endpos
	
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, 0.1)
	TraceLine(traceTable)

	if traceTable.hit 
	then
		--DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 255, 255, false, 0.5)
		
		grappleTargetFound = true
		
		local pullableHit = false
		if traceTable.enthit 
		then
			for _, entClass in ipairs(grapplePulledEntities)
			do
				if traceTable.enthit:GetClassname() == entClass
				then
					if traceTable.enthit:GetMass() <= GRAPPLE_ENT_PULL_MAX_MASS then
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
		grappleTargetFound = false		
		beamEnd = GetMuzzlePos() + GetMuzzleAng():Forward() * GRAPPLE_MAX_DISTANCE
	end
	
		
	--ParticleManager:SetParticleControlEnt(beamParticle, 1, 
		--laserEndEnt, PATTACH_ABSORIGIN_FOLLOW, "", laserEndEnt:GetOrigin(), true)
	ParticleManager:SetParticleControl(grappleBeamParticle, 1, beamEnd)
	ParticleManager:SetParticleControl(grappleBeamParticle, 3, beamColor)
	
	return GRAPPLE_BEAM_TRACE_INTERVAL
end


function GrappleTravelFrame(this)
	if not grappleIsPulling then
		return nil
	end
		
	grappleDistanceLeft = grappleDistanceLeft - GRAPPLE_SPEED
	
	if grappleDynamicEndpoint then
		grapplePullEndpoint = grappleTarget:GetAbsOrigin()
	end
	
	if grappleDistanceLeft <= 0 then
		if grapplePulledEnt then
			SetHookTransform(grappleTarget:GetAbsOrigin(), GetHookSurfaceAng())
			
			SetWireEndpoint()
			grappleHook:SetParent(grapplePulledEnt, "")
			
			grappleBaseEnt:SetThink(LineDelayPosFixup, "grapple_pull_delay", GRAPPLE_PULL_INTERVAL)
			grappleHook:SetPoseParameter("claw_open", 0.34)
		else
			
			if grappleAnchorEnt then					
				grappleBaseEnt:SetThink(LineDelayPosFixup, "grapple_pull_delay", GRAPPLE_PULL_INTERVAL)
				grappleHook:SetParent(grappleAnchorEnt, "")
			end	
			SetHookTransform(grapplePullEndpoint, GetHookSurfaceAng())
			SetWireEndpoint()
			
			grapplePlayerMoved = true
			playerPhys:AddConstraint(grapplePlayerEnt, grappleBaseEnt)
			
			playerPhys:DisableGravity(grapplePlayerEnt, grappleBaseEnt)
			grappleGravityEnabled = false
					
			grappleHook:SetPoseParameter("claw_open", 0.66)
		end
		
		grappleHandAttachment:SetPoseParameter("spin", 0)
		if grapplePulledEnt or grappleAnchorEnt then
			local impactParticle = ParticleManager:CreateParticle("particles/tools/grapple_grab_ent.vpcf", 
				PATTACH_CUSTOMORIGIN, thisEntity)
			ParticleManager:SetParticleControl(impactParticle, 0, grapplePullEndpoint)
			ParticleManager:SetParticleControlForward(impactParticle, 0, grappleSurfaceNormal)
		else
			local impactParticle = ParticleManager:CreateParticle("particles/tools/grapple_grab_world.vpcf", 
				PATTACH_CUSTOMORIGIN, thisEntity)
			ParticleManager:SetParticleControl(impactParticle, 0, grapplePullEndpoint)
			ParticleManager:SetParticleControlForward(impactParticle, 0, grappleSurfaceNormal)
		end
		
		
		grapplePullDelay = true
		grappleBaseEnt:SetThink(TraceGrappleObstacles, "grapple_trace_obstacles", GRAPPLE_TRACE_OBSTACLE_INTERVAL)
		grappleBaseEnt:SetThink(GrapplePullFrame, "grapple_pull", GRAPPLE_PULL_DELAY)
		grappleBaseEnt:SetThink(GrappleAnimationFrame, "grapple_anim", GRAPPLE_PULL_DELAY)
		StopSoundEvent("Grapple_Fly", grappleHandAttachment)
		StartSoundEvent("Grapple_Hit", grappleHook)
		RumbleController(1, 0.1, 100)
		return nil
	end
	
	local currentPos = grapplePullEndpoint + (grappleStartPoint - grapplePullEndpoint):Normalized() * grappleDistanceLeft

	SetHookTransform(currentPos)
	SetWireEndpoint()
	
	return GRAPPLE_PULL_INTERVAL
end


function LineDelayPosFixup()

	if grappleIsPulling and grapplePullDelay and grappleDynamicEndpoint and IsValidEntity(grappleTarget) then
		grapplePullEndpoint = grappleTarget:GetAbsOrigin()
		return GRAPPLE_PULL_INTERVAL
	end
	return nil
end


function GrapplePullFrame(this)
	
	grapplePullDelay = false
	
	if not grappleIsPulling or not IsValidEntity(grappleHandAttachment)
	then
		return nil
	end
	
	if not IsValidEntity(grapplePulledEnt)
	then
		grapplePulledEnt = nil
	end
	
	if not IsValidEntity(grappleAnchorEnt)
	then
		grappleAnchorEnt = nil
	end
	
	if not grappleTarget or not IsValidEntity(grappleTarget) then
		grappleTarget = nil
		grappleAnchorEnt = nil
		grapplePulledEnt = nil
	end
	
	if grapplePulledEnt then
		PullObject()
	else
		PullPlayer()
	end

		
	return GRAPPLE_PULL_INTERVAL
end



function PullPlayer()

	if grappleRappelling then
		
		if not grappleGravityEnabled
		then
			playerPhys:EnableGravity(grapplePlayerEnt, grappleBaseEnt)
			grappleGravityEnabled = true		
		end		
		
		if playerPhys:IsPlayerOnGround(grapplePlayerEnt) then
			return
		end
		
	elseif grappleGravityEnabled then
			playerPhys:DisableGravity(grapplePlayerEnt, grappleBaseEnt)
			grappleGravityEnabled = false
	end

		
	if grappleAnchorEnt then
		grapplePullEndpoint = grappleTarget:GetOrigin()
		SetWireEndpoint()
	end	
	
	local grapplePoint = grapplePullEndpoint
	
	if #grapplePoints > 0 then
		grapplePoint = grapplePoints[#grapplePoints]
	end
	
	local targetDelta = (grapplePoint - GetMuzzlePos())
	local distance = targetDelta:Length()
	
	local pullVector = (targetDelta - playerPhys:GetVelocity(grapplePlayerEnt) * 0.6)
		* GRAPPLE_PULL_INTERVAL * 8.0
		
	local pullSpeed = pullVector:Length()
	
	if pullSpeed > GRAPPLE_PULL_PLAYER_MAX_SPEED * GRAPPLE_PULL_INTERVAL then
		pullVector = targetDelta:Normalized() * GRAPPLE_PULL_PLAYER_MAX_SPEED * GRAPPLE_PULL_INTERVAL
		
	elseif pullSpeed < GRAPPLE_PULL_PLAYER_MIN_SPEED * GRAPPLE_PULL_INTERVAL 
		and (distance > GRAPPLE_PULL_PLAYER_MIN_DISTANCE or grappleRappelling) then
		
		pullVector = targetDelta:Normalized() * GRAPPLE_PULL_PLAYER_MIN_SPEED * GRAPPLE_PULL_INTERVAL
	end

	if distance > GRAPPLE_PULL_PLAYER_MIN_DISTANCE or #grapplePoints > 0 or grappleRappelling
	then
		if grappleRappelling then
			pullVector = Vector(pullVector.x * 0.5, pullVector.y * 0.5, pullVector.z * 0.8)
		end
	
		playerPhys:AddVelocity(grapplePlayerEnt, pullVector)	
	else
		playerPhys:StickFrame(grapplePlayerEnt)
		playerPhys:MovePlayer(grapplePlayerEnt, targetDelta)
	end
	
end



function TraceGrappleObstacles()
	if not grappleIsPulling then
		return nil
	end

	local anchorPoint = grapplePullEndpoint
	
	if grapplePulledEnt then
		anchorPoint = grapplePulledEnt:GetCenter()
	end
	
	if #grapplePoints > 0 then
		anchorPoint = grapplePoints[#grapplePoints]
	end
	
	local endVec = GetMuzzlePos()
	
	local traceTable =
	{
		startpos = endVec;
		endpos = anchorPoint;
		ignore = grapplePlayerEnt;
		mask = 33636363
	}
	TraceLine(traceTable)
	
	-- If inside something, consider position invalid and don't update state.
	if traceTable.startsolid or TraceCheckIfInside(endVec, prevGrapplePos) then
		return GRAPPLE_TRACE_OBSTACLE_INTERVAL
	end
	
	local prevPos = prevGrapplePos
	prevGrapplePos = endVec
	
	-- Obstacle between player and grappling point
	if traceTable.hit then
		--DebugDrawLine(traceTable.startpos, traceTable.pos, 255, 0, 0, false, TRACE_OBSTACLE_INTERVAL)
		
		-- Don't create corner on pulled prop
		if grapplePulledEnt and traceTable.enthit and traceTable.enthit == grapplePulledEnt then
			return GRAPPLE_TRACE_OBSTACLE_INTERVAL
		end
		
		anchorPoint = traceTable.pos
		
		local hitPos = traceTable.pos
		local hitNormal = traceTable.normal
		local travelVec = endVec - prevPos
		local travelDist = travelVec:Length()
		local traceDist = GRAPPLE_CORNER_TRACE_MAX_DIST
		local pointFound = false
		
		
		if #grapplePoints > 64 then
			return GRAPPLE_TRACE_OBSTACLE_INTERVAL
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
		 			traceTable.endpos = grapplePullEndpoint
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
	
	UpdateGrappleLineParticle()
	TraceTargetObstacles()
	UpdateGrappleLineParticleFront()
	
	-- Draw grapple path
	if playerPhys:IsDebugDrawEnabled()
	then
		local prev = grapplePullEndpoint
		
		if grapplePulledEnt then
			prev = grapplePulledEnt:GetCenter()
		end
		
		for _, point in ipairs(grapplePoints) do
			DebugDrawLine(prev, point, 128, 128, 128, true, GRAPPLE_TRACE_OBSTACLE_INTERVAL)
			prev = point
		end
		DebugDrawLine(prev, GetMuzzlePos(), 128, 128, 128, true, GRAPPLE_TRACE_OBSTACLE_INTERVAL)
	end

	
	return GRAPPLE_TRACE_OBSTACLE_INTERVAL
end


function TraceTargetObstacles()

	if not grappleDynamicEndpoint then
		return
	end
	
	local objectPos = grapplePullEndpoint
	
	if grapplePulledEnt then
		objectPos = grapplePulledEnt:GetCenter()
	end
	
	local jointPos = GetMuzzlePos()
	
	if #grapplePoints > 0 then
		jointPos = grapplePoints[1]
	end

	
	local traceTable =
	{
		startpos = objectPos;
		endpos = jointPos;
		ignore = grapplePlayerEnt;
		mask = 33636363
	}
	TraceLine(traceTable)
	
	-- If inside something, consider position invalid and don't update state.
	if traceTable.startsolid or TraceCheckIfInside(objectPos, prevGrappleTargetPos) then
		return
	end
	
	local prevPos = prevGrappleTargetPos
	prevGrappleTargetPos = objectPos
	
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


function SetWireEndpoint()
	local idx = grappleHook:ScriptLookupAttachment("wire_attach")
	local wireEnd = grappleHook:GetAttachmentOrigin(idx)
	ParticleManager:SetParticleControl(grappleWireParticle, 1, wireEnd)
end



-- Primitive way of checking if position is inside a mesh. Fails if blocked by another mesh.
function TraceCheckIfInside(pos, outsidePos)
	local traceTable =
	{
		startpos = outsidePos;
		endpos = pos;
		ignore = grapplePlayerEnt;
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

function UpdateGrappleLineParticleFront()

	if #grapplePoints < 2 then 
		return
	end
	if #grapplePoints > #grappleWirePoints then
	

			ParticleManager:DestroyParticle(grappleWireParticle, true)
			grappleWireParticle = ParticleManager:CreateParticle("particles/tools/grapple_wire.vpcf", 
				PATTACH_CUSTOMORIGIN, grappleHandAttachment)
			ParticleManager:SetParticleControl(grappleWireParticle, 0, grapplePoints[1])
			SetWireEndpoint()
	
			
		for idx = 1, #grapplePoints - #grappleWirePoints  do
			local point = ParticleManager:CreateParticle("particles/tools/grapple_wire.vpcf", 
				PATTACH_CUSTOMORIGIN, grappleHandAttachment)
			ParticleManager:SetParticleControl(point, 1, grapplePoints[idx])
			ParticleManager:SetParticleControl(point, 0, grapplePoints[idx + 1])

			table.insert(grappleWirePoints, idx, point)
		end
	end
	
		
	while #grapplePoints > 1 and #grapplePoints < #grappleWirePoints do
		
		if #grappleWirePoints > 0 then
			ParticleManager:DestroyParticle(grappleWirePoints[1], true)
			table.remove(grappleWirePoints, 1)
		end
		table.remove(grapplePoints, 1)
		
		ParticleManager:SetParticleControl(grappleWireParticle, 0, grapplePoints[1])
	end


end


function UpdateGrappleLineParticle()
	
	if #grapplePoints > #grappleWirePoints then
	
		-- Recreate the last segment to not be attached to the grapple.
		if #grappleWirePoints == 0 then
			ParticleManager:DestroyParticle(grappleWireParticle, true)
			grappleWireParticle = ParticleManager:CreateParticle("particles/tools/grapple_wire.vpcf", 
				PATTACH_CUSTOMORIGIN, grappleHandAttachment)
			ParticleManager:SetParticleControl(grappleWireParticle, 0, grapplePoints[1])
			SetWireEndpoint()
			
		else	
			ParticleManager:DestroyParticle(grappleWirePoints[#grappleWirePoints], true)
			grappleWirePoints[#grappleWirePoints] = ParticleManager:CreateParticle("particles/tools/grapple_wire.vpcf", 
				PATTACH_CUSTOMORIGIN, grappleHandAttachment)
			ParticleManager:SetParticleControl(grappleWirePoints[#grappleWirePoints], 0, grapplePoints[#grappleWirePoints + 1])
			ParticleManager:SetParticleControl(grappleWirePoints[#grappleWirePoints], 1, grapplePoints[#grappleWirePoints])
		end
			
		for idx = #grappleWirePoints + 1, #grapplePoints  do
			local point = ParticleManager:CreateParticle("particles/tools/grapple_wire.vpcf", 
				PATTACH_CUSTOMORIGIN, grappleHandAttachment)
			ParticleManager:SetParticleControl(point, 1, grapplePoints[idx])
				
			if idx + 1 > #grapplePoints then
				ParticleManager:SetParticleControlEnt(point, 0, grappleHandAttachment, 
					PATTACH_POINT_FOLLOW, "wire", Vector(0,0,0), true)
			else
				ParticleManager:SetParticleControl(point, 0, grapplePoints[idx + 1])
			end
			table.insert(grappleWirePoints, point)
		end
	
	elseif #grapplePoints < #grappleWirePoints then
		
		local idx = #grappleWirePoints
		
		while #grapplePoints < #grappleWirePoints do
			ParticleManager:DestroyParticle(grappleWirePoints[idx], true)

			if idx > 1 then
				ParticleManager:SetParticleControlEnt(grappleWirePoints[idx - 1], 0, grappleHandAttachment, 
					PATTACH_POINT_FOLLOW, "wire", Vector(0,0,0), true)
			else
				ParticleManager:SetParticleControlEnt(grappleWireParticle, 0, grappleHandAttachment, 
					PATTACH_POINT_FOLLOW, "wire", Vector(0,0,0), true)
			end
			table.remove(grappleWirePoints)
			idx = idx - 1
		end
	
	end

end


function PullObject()
	
	SetWireEndpoint()
	
	if grappleRappelling then return end

	local pullTargetPoint = GetMuzzlePos()
	
	if #grapplePoints > 0 then
		pullTargetPoint = grapplePoints[1]
	end
	
	local pullVector = nil

	pullVector = (grapplePulledEnt:GetCenter() - pullTargetPoint):Normalized() * -GRAPPLE_PULL_FORCE / grapplePulledEnt:GetMass()
	 
	local distance = (grapplePulledEnt:GetCenter() - pullTargetPoint):Length()

	grapplePulledEnt:ApplyAbsVelocityImpulse(pullVector)
	
	if not (distance > GRAPPLE_ENT_PULL_RELEASE_DISTANCE or #grapplePoints > 0)
	then	
		ReleaseGrapple(true)
		
		grappleBaseEnt:SetThink(TraceBeam, "grapple_trace_beam", 0.2)
		grappleIsTargeting = true
		grappleTargetFound = false	
	end
	
end



function GrappleAnimationFrame()
if not grappleIsPulling
	then
		RumbleController(1, 0.1, 100)
		return nil
	end
	
	if grappleRappelling
	then
		if playerPhys:IsPlayerOnGround(grapplePlayerEnt) then
			grappleHandAttachment:SetPoseParameter("spin", 0)
		else
			grappleHandAttachment:SetPoseParameter("spin", 0.5)
		end
		--grappleHook:SetSequence("rappel")
	elseif grappleHoldingObject then
		--grappleHook:SetSequence("hold_item")
	else
		RumbleController(0, GRAPPLE_REEL_ANIM_INTERVAL, 200)
		grappleHandAttachment:SetPoseParameter("spin", -0.5)
		--grappleHook:SetSequence("pull")
	end
	
	return GRAPPLE_REEL_ANIM_INTERVAL
end


-- Lerp the grappling hook attachment angle to a nice direction between the surface normal and shot direction.
function GetHookSurfaceAng()
	local dot = (-grappleSurfaceNormal):Dot(grappleHook:GetAngles():Forward())
		return VectorToAngles(LerpVectors(-grappleSurfaceNormal, grappleHook:GetAngles():Forward(), dot))
end


function SetHookTransform(pos, ang)
	ang = ang or grappleHook:GetAngles()
	grappleHook:SetAngles(ang.x, ang.y, ang.z)
	
	local idx = grappleHook:ScriptLookupAttachment("grapple_spot")
	local grapplePos = grappleHook:GetAttachmentOrigin(idx)
	
	pos = pos + grappleHook:GetAbsOrigin() - grapplePos
	
	grappleHook:SetAbsOrigin(pos)
	
end


function GetMinDimension(entity)
	local boundMin = entity:GetBoundingMins()
	local boundMax = entity:GetBoundingMaxs()
	
	return min(abs(boundMax.x - boundMin.x), abs(boundMax.y - boundMin.y), abs(boundMax.z - boundMin.z))
end


function GetMuzzlePos()
	local idx = grappleHandAttachment:ScriptLookupAttachment("grapple_spot")
	return grappleHandAttachment:GetAttachmentOrigin(idx)
end

function GetMuzzleAng()
	local idx = grappleHandAttachment:ScriptLookupAttachment("grapple_spot")
	local vec = grappleHandAttachment:GetAttachmentAngles(idx)
	return QAngle(vec.x, vec.y, vec.z)
end

