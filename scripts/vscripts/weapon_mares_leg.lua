
--[[
	Mare's leg weapon script.
	
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

SPIN_CHECK_INTERVAL = 0.2
CARRY_OFFSET = Vector(-0.2, 0, 0)
CARRY_ANGLES = QAngle(20, 0, 0)
FIRE_RUMBLE_INTERVAL = 0.01
FIRE_RUMBLE_TIME = 0.2
SPIN_TIME = 1.5
SPIN_RUMBLE_INTERVAL = 0.02
SHOT_TRACE_DISTANCE = 16384

DAMAGE = 50
DAMAGE_FORCE = 1000 

isCarried = false
fired = false
controller = nil
currentPlayer = nil
spinTimeElapsed = 0
fireRumbleElapsed = 0
tracerParticle = nil
tracerEnd = nil
muzzleFlash = nil
impactParticle = nil

tracerKeyvals = {
	classname = "info_particle_system";
	effect_name = "particles/weapon_tracers.vpcf";
	start_active = 0;
	cpoint1 = ""
}

dustKeyvals = {
	classname = "info_particle_system";
	effect_name = "particles/generic_fx/fx_dust.vpcf";
	start_active = 0;
}


tracerEndKeyvals = {
	classname = "info_particle_target";
	targetname = ""
}

g_VRScript.AddEntityPrecache(tracerKeyvals)
g_VRScript.AddEntityPrecache(dustKeyvals)

g_VRScript.pickupManager:RegisterEntity(thisEntity)

function Init(self)
	local cpName = DoUniqueString("tongue")
	tracerEndKeyvals.targetname = cpName
	tracerKeyvals.cpoint1 = cpName
	tracerParticle = SpawnEntityFromTableSynchronous(tracerKeyvals.classname, tracerKeyvals)
	tracerEnd = SpawnEntityFromTableSynchronous(tracerEndKeyvals.classname, tracerEndKeyvals)
	
	muzzleFlash = SpawnEntityFromTableSynchronous(dustKeyvals.classname, dustKeyvals)
	impactParticle = SpawnEntityFromTableSynchronous(dustKeyvals.classname, dustKeyvals)
end

function OnTriggerPressed(self)

	if not fired
	then
		Fire()	
	end
end

function Fire()
	fired = true
	StartSoundEvent("Law.Fire", thisEntity)
	TraceShot(self)
	
	if controller
	then
		thisEntity:SetThink(FireRumble, "fire_rumble", 0.1)
	end
	DoEntFireByInstanceHandle(thisEntity, "SetAnimationNoReset", "fire", 0 , nil, nil)
	DoEntFireByInstanceHandle(thisEntity, "SetDefaultAnimation", "idle_uncocked", 0 , nil, nil)
	
	prevAngles = thisEntity:GetAngles()
	thisEntity:SetThink(CheckSpin, "check_spin", SPIN_CHECK_INTERVAL)
end


function TraceShot(self)
	local muzzle = GetAttachment("muzzle")
	local traceTable =
	{
		startpos = muzzle.origin;
		endpos = muzzle.origin + RotatePosition(Vector(0,0,0), thisEntity:GetAngles(), Vector(SHOT_TRACE_DISTANCE, 0, 0));
		ignore = thisEntity

	}
	if g_VRScript.pickupManager.debug
	then
		DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, 0.1)
	end
	
	TraceLine(traceTable)
	
	if traceTable.hit 
	then
		if g_VRScript.pickupManager.debug
		then
			DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 255, 0, false, 0.2)
		end
		
		if traceTable.enthit
		then
			TakeDamage(
				{
					victim = traceTable.enthit;
					damage = DAMAGE;
					damage_type = DMG_BULLET;  
					force = thisEntity:GetAngles():Forward() * DAMAGE_FORCE;
					position = traceTable.pos;
					attacker = currentPlayer
				}
			)
			
			
		
		end
		
		tracerEnd:SetOrigin(traceTable.pos)
		tracerEnd:SetAngles(-thisEntity:GetAngles().x, -thisEntity:GetAngles().y, -thisEntity:GetAngles().z)
		impactParticle:SetOrigin(traceTable.pos)
		
		DoEntFireByInstanceHandle(impactParticle, "Start", "", 0, nil, nil)
		DoEntFireByInstanceHandle(impactParticle, "Stop", "", 1, nil, nil)
	else
		tracerEnd:SetOrigin(muzzle.origin + RotatePosition(Vector(0,0,0), thisEntity:GetAngles(), Vector(SHOT_TRACE_DISTANCE, 0, 0)))
	end
	
	tracerParticle:SetOrigin(muzzle.origin)
	muzzleFlash:SetOrigin(muzzle.origin)
	muzzleFlash:SetAngles(thisEntity:GetAngles().x, thisEntity:GetAngles().y, thisEntity:GetAngles().z)
	
	DoEntFireByInstanceHandle(tracerParticle, "Start", "", 0, nil, nil)
	DoEntFireByInstanceHandle(tracerParticle, "Stop", "", 0.1, nil, nil)
	
	DoEntFireByInstanceHandle(muzzleFlash, "Start", "", 0, nil, nil)
	DoEntFireByInstanceHandle(muzzleFlash, "Stop", "", 1, nil, nil)
	
end


function FireRumble(self)
	if controller
	then
		controller:FireHapticPulse(2)
	end
	
	fireRumbleElapsed = fireRumbleElapsed + FIRE_RUMBLE_INTERVAL
	if fireRumbleElapsed >= FIRE_RUMBLE_TIME
	then
		fireRumbleElapsed = 0
		return nil
	end
	
	return FIRE_RUMBLE_INTERVAL
end

function OnTriggerUnpressed(self)

end

function OnPickedUp(self, hand, player)
	controller = hand
	currentPlayer = player
	thisEntity:SetParent(hand, "")
	thisEntity:SetOrigin(hand:GetOrigin() + RotatePosition(Vector(0,0,0), hand:GetAngles(), CARRY_OFFSET))
	local carryAngles = RotateOrientation(hand:GetAngles(), CARRY_ANGLES)
	thisEntity:SetAngles(carryAngles.x, carryAngles.y, carryAngles.z)
	
	if not alreadyPickedUp
	then
		DoEntFireByInstanceHandle(thisEntity, "SetAnimationNoReset", "draw", 0 , nil, nil)
		DoEntFireByInstanceHandle(thisEntity, "SetDefaultAnimation", "idle", 0 , nil, nil)
		alreadyPickedUp = true
	end

end

function OnDropped(self, hand, player)
	thisEntity:SetParent(nil, "")
	controller = nil
end


function CheckSpin(self)
	local angles = thisEntity:GetAngles()

	if angles.x < prevAngles.x - 20
	then
		DoEntFireByInstanceHandle(thisEntity, "SetAnimationNoReset", "spin_vr", 0 , nil, nil)
		DoEntFireByInstanceHandle(thisEntity, "SetDefaultAnimation", "idle", 0 , nil, nil)
		
		if controller
		then
			controller:FireHapticPulse(0)
		end
		
		prevAngles = nil
		thisEntity:SetThink(SpinRumble, "spin_complete", SPIN_RUMBLE_INTERVAL)
		return nil
	end
	
	prevAngles = angles
	return SPIN_CHECK_INTERVAL
end


function SpinRumble(self)
	spinTimeElapsed = spinTimeElapsed + SPIN_RUMBLE_INTERVAL
	
	if controller
	then
		controller:FireHapticPulse(0)
	end
	
	if spinTimeElapsed >= SPIN_TIME
	then
		spinTimeElapsed = 0
		fired = false
		return nil
	end
	
	return SPIN_RUMBLE_INTERVAL
end


function GetAttachment(name)
	local idx = thisEntity:ScriptLookupAttachment(name)
	
	local table = {}
	table.origin = thisEntity:GetAttachmentOrigin(idx)
	table.angles = VectorToAngles(thisEntity:GetAttachmentAngles(idx))
	
	return table
end

