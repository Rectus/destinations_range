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

g_VRScript.pickupManager:RegisterEntity(thisEntity)

TONGUE_MAX_DISTANCE = 1024
TONGUE_PULL_MIN_DISTANCE = 8
TONGUE_SPEED = 32
TONGUE_PULL_FORCE = 50
TONGUE_PULL_INTERVAL = 0.02
REEL_SOUND_INTERVAL = 10
REEL_ANIM_INTERVAL = 1
MUZZLE_OFFSET = Vector(-32, 8, 0)
MUZZLE_ANGLES_OFFSET = QAngle(-90, 0, 0) 

TONGUE_PULL_PLAYER_SPEED = 8
TONGUE_PULL_PLAYER_EASE_DISTANCE = 128
PLAYER_FALL_SPEED = 8

CARRY_OFFSET = Vector(-6, -7.5, -2)
CARRY_ANGLES = QAngle(90, 0, 0)

isCarried = false
playerEnt = nil
isPulling = false
pulledEnt = nil
pullEndpoint = nil
tongueStartPoint = nil
playerMoved = false
tongueDistanceLeft = 0
tongueParticle = nil
tongueCP1 = nil

particleKeyvals = {
	effect_name = "particles/barnacle_tongue.vpcf";
	start_active = 0;
	cpoint1 = ""
}

PrecacheEntityFromTable("info_particle_system", particleKeyvals, thisEntity)

function Init(self)
	local cpName = DoUniqueString("tongue")
	particleKeyvals.cpoint1 = cpName
	tongueParticle = SpawnEntityFromTableSynchronous("info_particle_system", particleKeyvals)
	tongueCP1 = SpawnEntityFromTableSynchronous("info_particle_target", {targetname = cpName})
	tongueParticle:SetParent(thisEntity, "tongue")
	tongueParticle:SetOrigin(thisEntity:GetAbsOrigin())
	
	DoEntFireByInstanceHandle(thisEntity, "SetSequence", "idle", 0, nil, nil)
end


function OnTriggerPressed(self)
	LaunchTongue()
end


function OnTriggerUnpressed(self)
	tongueCP1:SetParent(nil, "")
	isPulling = false
	pulledEnt = nil
	DoEntFireByInstanceHandle(thisEntity, "SetSequence", "idle", 0, nil, nil)
	StopSoundEvent("Barnacle.TongueFly", thisEntity)
	StartSoundEvent("Barnacle.TongueStrain", thisEntity)
	DoEntFireByInstanceHandle(tongueParticle, "Stop", "", 0, nil, nil)
	
	if playerMoved
	then
		playerMoved = false
		thisEntity:SetThink(PlayerFallFrame, "player_fall", TONGUE_PULL_INTERVAL)
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
	tongueCP1:SetParent(nil, "")
	DoEntFireByInstanceHandle(tongueParticle, "Stop", "", 0, nil, nil)
	StopSoundEvent("Barnacle.TongueFly", thisEntity)
	isPulling = false
	playerEnt = nil
	pulledObject = nil
	isCarrying = false
	thisEntity:SetParent(nil, "")
end


function LaunchTongue(self)
	if playerEnt
	then
		
		DoEntFireByInstanceHandle(thisEntity, "SetSequence", "pull", 0, nil, nil)
		
		if TraceTongue(self)
		then
			StartSoundEvent("Barnacle.TongueAttack", thisEntity)
			StartSoundEvent("Barnacle.TongueFly", thisEntity)
		
			tongueDistanceLeft = (pullEndpoint - GetMuzzlePos()):Length()
			thisEntity:SetThink(TongueTravelFrame, "tongue_travel", TONGUE_PULL_INTERVAL)
			
			tongueStartPoint = GetMuzzlePos()
			tongueCP1:SetOrigin(GetMuzzlePos())
			

			DoEntFireByInstanceHandle(tongueParticle, "Start", "", 0, nil, nil)
			
		else
			StartSoundEvent("Barnacle.TongueMiss", thisEntity)
		end
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
		if traceTable.enthit and traceTable.enthit:GetClassname() == "prop_physics_override"
		then
			pulledEnt = traceTable.enthit
		else
			pulledEnt = nil
			
		end
		
		pullEndpoint = traceTable.pos
		isPulling = true
		return true
	end
	
	pulledEnt = nil
	isPulling = false
	return nil
end


function TracePlayerHeight(self)
	local startVector = playerEnt:GetOrigin() + Vector(0, 0, playerEnt:GetHMDAnchor():GetOrigin().z - playerEnt:GetOrigin().z)
	local traceTable =
	{
		startpos = startVector;
		endpos = startVector - Vector(0, 0, 4096);
		ignore = playerEnt
	}
	
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, 10.1)
	TraceLine(traceTable)
	
	if traceTable.hit 
	then
		--DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 255, 0, false, 10.2)
		
		local playerHeight = (traceTable.startpos - traceTable.pos).z
		
		--DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 255, 0, false, 10.2)
		return playerHeight
	end
	
	return 0
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
			tongueCP1:SetParent(pulledEnt, "")
		end
	
		tongueCP1:SetOrigin(pullEndpoint)
		playerMoved = true
		thisEntity:SetThink(TonguePullFrame, "tongue_pull", TONGUE_PULL_INTERVAL)
		thisEntity:SetThink(TongueAnimationFrame, "tongue_anim", REEL_ANIM_INTERVAL)
		StopSoundEvent("Barnacle.TongueFly", thisEntity)
		StartSoundEvent("Barnacle.TongueHit", thisEntity)
		return nil
	end
	
	tongueCP1:SetOrigin(pullEndpoint + (tongueStartPoint - pullEndpoint):Normalized() * tongueDistanceLeft)
	
	return TONGUE_PULL_INTERVAL
end


function TonguePullFrame(self)
	if not isPulling
	then
		return nil
	end
	
	local pullVector = nil
	
	local gunRelativePos = GetMuzzlePos() - playerEnt:GetHMDAnchor():GetOrigin()
	
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
		-- Prevent player from going through floors
		if pullVector.z < 0 and TracePlayerHeight(self) <= 0
		then
			pullVector = pullVector - Vector(0, 0, pullVector.z)
		end
		
		if pulledEnt
		then
			pulledEnt:ApplyAbsVelocityImpulse(pullVector)
		else
			playerEnt:GetHMDAnchor():SetOrigin(GetMuzzlePos() - gunRelativePos + pullVector)
		end
	end
	
	--DebugDrawLine(GetMuzzlePos(), pullEndpoint, 0, 0, 255, false, TONGUE_PULL_INTERVAL)
		
	return TONGUE_PULL_INTERVAL
end


function PlayerFallFrame()
	local distanceLeft = TracePlayerHeight(self)

	if distanceLeft <= PLAYER_FALL_SPEED
	then
		playerEnt:GetHMDAnchor():SetOrigin(playerEnt:GetHMDAnchor():GetOrigin() - Vector(0, 0, distanceLeft))
		return nil
	end
	
	distanceLeft = distanceLeft - PLAYER_FALL_SPEED
	playerEnt:GetHMDAnchor():SetOrigin(playerEnt:GetHMDAnchor():GetOrigin() - Vector(0, 0, PLAYER_FALL_SPEED))

	return TONGUE_PULL_INTERVAL
end


function TongueAnimationFrame(self)
if not isPulling
	then
		return nil
	end
	
	DoEntFireByInstanceHandle(thisEntity, "SetSequence", "pull", 0, nil, nil)
	StartSoundEvent("Barnacle.TongueRetract", thisEntity)
	return REEL_ANIM_INTERVAL
end


function GetMuzzlePos()
	return thisEntity:GetAbsOrigin() + RotatePosition(Vector(0,0,0), 
			RotateOrientation(thisEntity:GetAngles(), CARRY_ANGLES), MUZZLE_OFFSET)
end

