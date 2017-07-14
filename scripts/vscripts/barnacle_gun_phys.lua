--[[
	Barnacle gun script.
	
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

g_VRScript.pickupManager:RegisterEntity(thisEntity)

local TONGUE_MAX_DISTANCE = 1024
local TONGUE_PULL_MIN_DISTANCE = 8
local TONGUE_SPEED = 32
local TONGUE_PULL_FORCE = 50
local TONGUE_PULL_INTERVAL = 0.02
local TONGUE_PULL_DELAY = 0.5
local REEL_SOUND_INTERVAL = 10
local REEL_ANIM_INTERVAL = 1
local MUZZLE_OFFSET = Vector(-24, -8, 0)
local MUZZLE_ANGLES_OFFSET = QAngle(-90, 0, 0) 

local TONGUE_PULL_PLAYER_SPEED = 10
local TONGUE_PULL_PLAYER_EASE_DISTANCE = 32

local CARRY_OFFSET = Vector(6, 7.5, -2)
local CARRY_ANGLES = QAngle(90, 180, 0)

local isCarried = false
local playerEnt = nil
local isPulling = false
local pulledEnt = nil
local pullEndpoint = nil
local tongueStartPoint = nil
local playerMoved = false
local tongueDistanceLeft = 0
local tongueParticle = nil
local barnacleAnim = nil

local beamParticle = nil
local BEAM_TRACE_INTERVAL = 0.1

local isTargeting = false
local targetFound = false
local isToungueLaunched = false

local pulledEntities = {"prop_physics"; "prop_physics_override"; "simple_physics_prop"}


animKeyvals = {
	targetname = "barnacle_anim";
	model = "models/weapons/barnacle_gun.vmdl";
	solid = 0;
	scales = "0.6885 0.6885 0.6885";
	DefaultAnim = "idle"
	}


function Precache(context)
	PrecacheParticle("particles/barnacle_tongue.vpcf", context)
	PrecacheParticle("particles/item_laser_pointer.vpcf", context)
	PrecacheModel(animKeyvals.model, context)
	PrecacheSoundFile("soundevents/soundevents_addon.vsndevts", context)
end


function Init(self)
	animKeyvals.origin = thisEntity:GetOrigin()
	animKeyvals.angles = thisEntity:GetAngles()
	barnacleAnim = SpawnEntityFromTableSynchronous("prop_dynamic", animKeyvals)
	barnacleAnim:SetParent(thisEntity, "")
	barnacleAnim:SetOrigin(thisEntity:GetOrigin())


	local cpTongueName = DoUniqueString("tongue")

	tongueParticle = ParticleSystem("particles/barnacle_tongue.vpcf", false)
	tongueParticle:CreateControlPoint(1)
	tongueParticle:SetParent(barnacleAnim, "tongue")
	tongueParticle:SetOrigin(barnacleAnim:GetAbsOrigin())
		
	beamParticle = ParticleSystem("particles/item_laser_pointer.vpcf", false)
	beamParticle:CreateControlPoint(1, Vector(TONGUE_MAX_DISTANCE, 0, 0), barnacleAnim, "base")
	-- Control point 3 sets the color of the beam.
	beamParticle:CreateControlPoint(3, Vector(0.5, 0.5, 0.8))

	
	beamParticle:SetParent(barnacleAnim, "base")
	beamParticle:SetOrigin(barnacleAnim:GetAbsOrigin())
	
	DoEntFireByInstanceHandle(barnacleAnim, "SetSequence", "idle", 0, nil, nil)

end


function OnTriggerPressed(self)
	

	if isToungueLaunched
	then
		ReleaseTongue(self)
		
	else
		thisEntity:SetThink(TraceBeam, "trace_beam", 0)
		beamParticle:Start()
		isTargeting = true
	end


end


function OnTriggerUnpressed(self)
	if isTargeting
	then
		beamParticle:StopPlayEndcap()
		isTargeting = false
		
		if targetFound
		then
			LaunchTongue()
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
	ReleaseTongue(self)
	playerEnt = nil
	beamParticle:StopPlayEndcap()
	isTargeting = false

	thisEntity:SetParent(nil, "")
end


function LaunchTongue(self)
	if playerEnt
	then
		
		DoEntFireByInstanceHandle(barnacleAnim, "SetSequence", "pull", 0, nil, nil)
		
		if TraceTongue(self)
		then
			StartSoundEvent("Barnacle.TongueAttack", thisEntity)
			StartSoundEvent("Barnacle.TongueFly", thisEntity)
		
			tongueDistanceLeft = (pullEndpoint - GetMuzzlePos()):Length()
			thisEntity:SetThink(TongueTravelFrame, "tongue_travel", TONGUE_PULL_INTERVAL)
			
			tongueStartPoint = GetMuzzlePos()
			tongueParticle:GetControlPoint(1):SetOrigin(GetMuzzlePos())
			
			tongueParticle:Start()	
			isToungueLaunched = true
		else
			StartSoundEvent("Barnacle.TongueMiss", thisEntity)
		end
	end
end


function ReleaseTongue(self)
	tongueParticle:GetControlPoint(1):SetParent(nil, "")
	isToungueLaunched = false
	isPulling = false
	pulledEnt = nil
	DoEntFireByInstanceHandle(barnacleAnim, "SetSequence", "idle", 0, nil, nil)
	StopSoundEvent("Barnacle.TongueFly", thisEntity)
	StartSoundEvent("Barnacle.TongueStrain", thisEntity)
	tongueParticle:Stop()
	
	if playerMoved
	then
		playerMoved = false
		g_VRScript.fallController:RemoveConstraint(playerEnt, thisEntity)
		g_VRScript.fallController:EnableGravity(playerEnt)
	end
end


function TraceTongue(self)
	local traceTable =
	{
		startpos = GetMuzzlePos();
		endpos = GetMuzzlePos() + RotatePosition(Vector(0,0,0), 
				RotateOrientation(thisEntity:GetAngles(), MUZZLE_ANGLES_OFFSET), Vector(TONGUE_MAX_DISTANCE, 0, 0));
		ignore = thisEntity

	}
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, 0.1)
	TraceLine(traceTable)
	
	if traceTable.hit 
	then
		--DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 255, 0, false, 0.2)
		
		pulledEnt = nil
		
		if traceTable.enthit 
		then
			for _, entClass in ipairs(pulledEntities)
			do
				if traceTable.enthit:GetClassname() == entClass
				then
					pulledEnt = traceTable.enthit
				end
			end
		end
		
		pullEndpoint = traceTable.pos
		isPulling = true
		return true
	end
	
	pulledEnt = nil
	isPulling = false
	return nil
end


function TraceBeam(self)
	if not isTargeting
	then 
		return nil
	end

	local traceTable =
	{
		startpos = GetMuzzlePos();
		endpos = GetMuzzlePos() + RotatePosition(Vector(0,0,0), 
				RotateOrientation(thisEntity:GetAngles(), MUZZLE_ANGLES_OFFSET), Vector(TONGUE_MAX_DISTANCE, 0, 0));
		ignore = thisEntity

	}
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, 0.1)
	TraceLine(traceTable)
	
	
	
	if traceTable.hit 
	then
		--DebugDrawLine(traceTable.startpos, GetMuzzlePos() + RotatePosition(Vector(0,0,0), 
				--RotateOrientation(thisEntity:GetAngles(), MUZZLE_ANGLES_OFFSET), Vector(TONGUE_MAX_DISTANCE * traceTable.fraction, 0, 0)), 0, 255, 255, false, 0.5)
		
		targetFound = true
		
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
			beamParticle:GetControlPoint(3):SetOrigin(Vector(0.5, 0.8, 0.5))
		end
		
		
		beamParticle:GetControlPoint(1):SetAbsOrigin(thisEntity:GetAbsOrigin()  + RotatePosition(Vector(0,0,0), 
				thisEntity:GetAngles(), Vector(TONGUE_MAX_DISTANCE * traceTable.fraction * 2 + 40, 0, 0)))
		

	
	else
		targetFound = false
		beamParticle:GetControlPoint(3):SetOrigin(Vector(0.5, 0.5, 0.8))
		beamParticle:GetControlPoint(1):SetAbsOrigin(thisEntity:GetAbsOrigin() + RotatePosition(Vector(0,0,0), 
				thisEntity:GetAngles(), Vector(TONGUE_MAX_DISTANCE * 2 + 40, 0, 0)))
		
	end
	
	return BEAM_TRACE_INTERVAL
end


function TongueTravelFrame(self)
	if not isPulling
	then
		return nil
	end
		
		tongueDistanceLeft = tongueDistanceLeft - TONGUE_SPEED
	
	if tongueDistanceLeft <= 0
	then
		if pulledEnt
		then
			tongueParticle:GetControlPoint(1):SetParent(pulledEnt, "")
		else
			playerMoved = true
			g_VRScript.fallController:AddConstraint(playerEnt, thisEntity)
			g_VRScript.fallController:DisableGravity(playerEnt)
		end
	
		tongueParticle:GetControlPoint(1):SetOrigin(pullEndpoint)
		thisEntity:SetThink(TonguePullFrame, "tongue_pull", TONGUE_PULL_DELAY)
		thisEntity:SetThink(TongueAnimationFrame, "tongue_anim", TONGUE_PULL_DELAY)
		StopSoundEvent("Barnacle.TongueFly", thisEntity)
		StartSoundEvent("Barnacle.TongueHit", thisEntity)
		return nil
	end
	
	tongueParticle:GetControlPoint(1):SetOrigin(pullEndpoint + (tongueStartPoint - pullEndpoint):Normalized() * tongueDistanceLeft)
	
	return TONGUE_PULL_INTERVAL
end


function TonguePullFrame(self)
	if not isPulling
	then
		return nil
	end
	
	if not g_VRScript.fallController:IsActive(playerEnt, thisEntity)
	then
		return TONGUE_PULL_INTERVAL
	end	
	
	local pullVector = nil
	
	--local gunRelativePos = GetMuzzlePos() - playerEnt:GetHMDAnchor():GetOrigin()
	
	if pulledEnt
	then
		pullVector = (pulledEnt:GetCenter() - GetMuzzlePos()):Normalized() * -TONGUE_PULL_FORCE
	else
		pullVector = (pullEndpoint - GetMuzzlePos()):Normalized() * TONGUE_PULL_PLAYER_SPEED
	end
	 
	local distance = (pullEndpoint - GetMuzzlePos()):Length()

	
	if distance > TONGUE_PULL_MIN_DISTANCE
	then
		if distance < TONGUE_PULL_PLAYER_EASE_DISTANCE
		then 
			pullVector = pullVector * distance / TONGUE_PULL_PLAYER_EASE_DISTANCE
		end
				
		if pulledEnt
		then
			pulledEnt:ApplyAbsVelocityImpulse(pullVector)
		else
			-- Prevent player from going through floors
			if pullVector.z < 0 and g_VRScript.fallController:TracePlayerHeight(playerEnt) <= 0
			then
				pullVector = pullVector - Vector(0, 0, pullVector.z)
			end
		
			g_VRScript.fallController:AddVelocity(playerEnt, pullVector)
			--playerEnt:GetHMDAnchor():SetOrigin(GetMuzzlePos() - gunRelativePos + pullVector)
		end		
	elseif not pulledEnt
	then
		g_VRScript.fallController:StickFrame(playerEnt)
		if distance < TONGUE_PULL_PLAYER_EASE_DISTANCE
		then 
			pullVector = pullVector * distance / TONGUE_PULL_PLAYER_EASE_DISTANCE
		end
		-- Prevent player from going through floors
		if pullVector.z < 0 and g_VRScript.fallController:TracePlayerHeight(playerEnt) <= 0
		then
			pullVector = pullVector - Vector(0, 0, pullVector.z)
		end
		g_VRScript.fallController:MovePlayer(playerEnt, pullVector)
		--playerEnt:GetHMDAnchor():SetOrigin(GetMuzzlePos() - gunRelativePos + pullVector)
	end
	
	--DebugDrawLine(GetMuzzlePos(), pullEndpoint, 0, 0, 255, false, TONGUE_PULL_INTERVAL)
		
	return TONGUE_PULL_INTERVAL
end



function TongueAnimationFrame(self)
if not isPulling
	then
		return nil
	end
	
	DoEntFireByInstanceHandle(barnacleAnim, "SetSequence", "pull", 0, nil, nil)
	StartSoundEvent("Barnacle.TongueRetract", thisEntity)
	return REEL_ANIM_INTERVAL
end


function GetMuzzlePos()
	return thisEntity:GetAbsOrigin() + RotatePosition(Vector(0,0,0), 
			RotateOrientation(thisEntity:GetAngles(), CARRY_ANGLES), MUZZLE_OFFSET)
end

