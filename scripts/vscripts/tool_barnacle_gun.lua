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


local TONGUE_MAX_DISTANCE = 3000
local TONGUE_PULL_MIN_DISTANCE = 8
local TONGUE_SPEED = 64
local TONGUE_PULL_FORCE = 50
local TONGUE_PULL_INTERVAL = 0.02
local TONGUE_PULL_DELAY = 0.5
local REEL_SOUND_INTERVAL = 10
local REEL_ANIM_INTERVAL = 1
local MUZZLE_ANGLES_OFFSET = QAngle(-90, 0, 0) 

local TONGUE_PULL_PLAYER_SPEED = 10
local TONGUE_PULL_PLAYER_EASE_DISTANCE = 32

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
local handID = 0
local handEnt = nil
local handAttachment = nil
local laserEndEnt = nil
local rappelling = false
local gravityEnabled = true

local beamParticle = nil
local BEAM_TRACE_INTERVAL = 0.1

local isTargeting = false
local targetFound = false
local isToungueLaunched = false

local pulledEntities = {"prop_physics"; "prop_physics_override"; "simple_physics_prop";
	"prop_destinations_physics"; "prop_destinations_tool"}


animKeyvals = 
{
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
	thisEntity:SetThink(DelaySetAnim, "init_delay", 0.5)
end


function SetEquipped( self, pHand, nHandID, pHandAttachment, pPlayer )
	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	isCarried = true
	
	barnacleAnim:SetParent(handAttachment, "")
	barnacleAnim:SetLocalOrigin(Vector(0,0,0))
	barnacleAnim:SetLocalAngles(0,0,0)

	if not tongueParticle
	then
	
		tongueParticle = ParticleSystem("particles/barnacle_tongue.vpcf", false)
		tongueParticle:CreateControlPoint(1)
		tongueParticle:SetParent(barnacleAnim, "tongue")
		tongueParticle:SetOrigin(barnacleAnim:GetAbsOrigin())
		
		beamParticle = ParticleSystem("particles/item_laser_pointer.vpcf", false)
		beamParticle:CreateControlPoint(1, Vector(TONGUE_MAX_DISTANCE, 0, 0), handAttachment, "beam")
		-- Control point 3 sets the color of the beam.
		beamParticle:CreateControlPoint(3, Vector(0.5, 0.5, 0.8))
		
		beamParticle:SetParent(handAttachment, "beam")
		beamParticle:SetOrigin(handAttachment:GetAbsOrigin())
		
	else
		beamParticle:SetParent(handAttachment, "beam")
		beamParticle:GetControlPoint(1):SetParent(handAttachment, "beam")	
		beamParticle:SetOrigin(barnacleAnim:GetAbsOrigin())
	end
	
	thisEntity:SetThink(TraceBeam, "trace_beam", 0)
	beamParticle:Start()
	isTargeting = true
	
	--[[if not laserEndEnt or laserEndEnt:IsNull()
	then	

		laserEndEnt = SpawnEntityFromTableSynchronous("info_target_instructor_hint", {origin = thisEntity:GetOrigin()})
		laserEndEnt:SetParent(handAttachment, "")
	end]]
	
	return true
end

function SetUnequipped()
	ReleaseTongue(self)

	barnacleAnim:SetParent(thisEntity, "")
	--laserEndEnt:SetParent(thisEntity, "")
	--ParticleManager:DestroyParticle(beamParticle, false)
	
	beamParticle:SetParent(thisEntity, "muzzle")
	beamParticle:GetControlPoint(1):SetParent(thisEntity, "muzzle")
	beamParticle:GetControlPoint(1):SetLocalOrigin(Vector(0,0,0))
	beamParticle:StopPlayEndcap()
	isTargeting = false
	
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


function DelaySetAnim()
	animKeyvals.origin = thisEntity:GetOrigin()
	animKeyvals.angles = thisEntity:GetAngles()
	barnacleAnim = SpawnEntityFromTableSynchronous("prop_dynamic", animKeyvals)
	barnacleAnim:SetParent(thisEntity, "")
	barnacleAnim:SetOrigin(thisEntity:GetOrigin())
	
	DoEntFireByInstanceHandle(barnacleAnim, "SetSequence", "idle", 0, nil, nil)
end


function OnTriggerPressed(self)

	if targetFound
	then
		beamParticle:StopPlayEndcap()
		isTargeting = false
		LaunchTongue()
	else
		thisEntity:EmitSound("Barnacle.TongueMiss")
	end

end


function OnTriggerUnpressed(self)
	
	if isToungueLaunched
	then
		ReleaseTongue(self)
		
	end	
	
	thisEntity:SetThink(TraceBeam, "trace_beam", 0)
	beamParticle:Start()
	isTargeting = true

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
			
			--tongueParticle = ParticleManager:CreateParticle("particles/barnacle_tongue.vpcf", PATTACH_POINT_FOLLOW, handAttachment)
			--ParticleManager:SetParticleControlEnt(tongueParticle, 0, handAttachment, PATTACH_POINT_FOLLOW, "tongue", Vector(0,0,0), true)
			--ParticleManager:SetParticleControl(tongueParticle, 1, GetMuzzlePos())
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
	--ParticleManager:DestroyParticle(tongueParticle, false)
	
	if playerMoved
	then
		playerMoved = false
		g_VRScript.fallController:RemoveConstraint(playerEnt, thisEntity)
		g_VRScript.fallController:EnableGravity(playerEnt, thisEntity)
		gravityEnabled = true

	end
end


function TraceTongue(self)
	local traceTable =
	{
		startpos = GetMuzzlePos();
		endpos = GetMuzzlePos() + RotatePosition(Vector(0,0,0), 
				RotateOrientation(handAttachment:GetAngles(), MUZZLE_ANGLES_OFFSET), Vector(TONGUE_MAX_DISTANCE, 0, 0));
		ignore = playerEnt

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
					pullableHit = true
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
			
		--beamEnd = traceTable.pos
	
		beamEnd = handAttachment:GetAbsOrigin()  + RotatePosition(Vector(0,0,0), 
				handAttachment:GetAngles(), Vector(TONGUE_MAX_DISTANCE * traceTable.fraction, 0, 0))	
	else
		targetFound = false		
		beamEnd = handAttachment:GetAbsOrigin() + RotatePosition(Vector(0,0,0), 
				handAttachment:GetAngles(), Vector(TONGUE_MAX_DISTANCE, 0, 0))
	end
	
		beamParticle:GetControlPoint(3):SetOrigin(beamColor)
		beamParticle:GetControlPoint(1):SetOrigin(beamEnd)
	
	--laserEndEnt:SetAbsOrigin(beamEnd)
	--ParticleManager:SetParticleControlEnt(beamParticle, 1, laserEndEnt, PATTACH_ABSORIGIN_FOLLOW, "", laserEndEnt:GetOrigin(), true)
	--ParticleManager:SetParticleControl(beamParticle, 1, beamEnd)
	--ParticleManager:SetParticleControl(beamParticle, 3, beamColor)
	
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
			--ParticleManager:SetParticleControl(tongueParticle, 1, GetMuzzlePos())
			tongueParticle:GetControlPoint(1):SetParent(pulledEnt, "")
		else
			playerMoved = true
			g_VRScript.fallController:AddConstraint(playerEnt, thisEntity)
			
			g_VRScript.fallController:DisableGravity(playerEnt, thisEntity)
			gravityEnabled = false

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
	
	
	if rappelling 
	then
		if not pulledEnt
		then
			if not gravityEnabled
			then
				g_VRScript.fallController:EnableGravity(playerEnt, thisEntity)
				gravityEnabled = true		
			end		
		end
		
		return TONGUE_PULL_INTERVAL
	else
		if not pulledEnt and gravityEnabled
		then
			g_VRScript.fallController:DisableGravity(playerEnt, thisEntity)
			gravityEnabled = false
		end
	end
	
	
		
	local pullVector = nil
	
	if not IsValidEntity(pulledEnt)
	then
		pulledEnt = nil
	end
	
	if pulledEnt
	then
		pullVector = (pulledEnt:GetCenter() - GetMuzzlePos()):Normalized() * -TONGUE_PULL_FORCE
	else
		if not g_VRScript.fallController:IsActive(playerEnt, thisEntity)
		then
			return TONGUE_PULL_INTERVAL
		end
			
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
	
	if rappelling
	then
		DoEntFireByInstanceHandle(barnacleAnim, "SetSequence", "idle", 0, nil, nil)
	else
		DoEntFireByInstanceHandle(barnacleAnim, "SetSequence", "pull", 0, nil, nil)
	end
	StartSoundEvent("Barnacle.TongueRetract", thisEntity)
	return REEL_ANIM_INTERVAL
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

