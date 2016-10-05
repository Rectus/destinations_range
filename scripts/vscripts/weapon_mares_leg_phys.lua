
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

require("particle_system")

local SPIN_CHECK_INTERVAL = 0.2
local CARRY_OFFSET = Vector(-0.2, 0, 0)
local CARRY_ANGLES = QAngle(20, 0, 0)
local FIRE_RUMBLE_INTERVAL = 0.01
local FIRE_RUMBLE_TIME = 0.2
local SPIN_TIME = 1.1
local CYCLE_TIME = 1.0
local SPIN_RUMBLE_INTERVAL = 0.02
local SHOT_TRACE_DISTANCE = 16384

local DAMAGE = 50
local DAMAGE_FORCE = 100
local DAMAGE_ANG_FORCE = 25
local DAMAGE_MAX_ANG_MOMENTUM = 1000

local isCarried = false
local fired = false
local controller = nil
local currentPlayer = nil
local spinTimeElapsed = 0
local fireRumbleElapsed = 0
local tracerParticle = nil
local tracerEnd = nil
local muzzleFlash = nil
local impactParticle = nil
local gunAnim = nil

local tracerKeyvals = {
	classname = "info_particle_system";
	effect_name = "particles/weapon_tracers.vpcf";
	start_active = 0;
	cpoint1 = ""
}

local dustKeyvals = {
	classname = "info_particle_system";
	effect_name = "particles/generic_fx/fx_dust.vpcf";
	start_active = 0;
}


local tracerEndKeyvals = {
	classname = "info_particle_target";
	targetname = ""
}

local animKeyvals = {
	targetname = "mares_leg_anim";
	model = "models/weapons/mares_leg.vmdl";
	solid = 0
	}

function Precache(context)
	PrecacheParticle(tracerKeyvals.effect_name, context)
	PrecacheParticle(dustKeyvals.effect_name, context)
	PrecacheModel(animKeyvals.model, context)
	PrecacheSoundFile("soundevents/soundevents_addon.vsndevts", context)
end

g_VRScript.pickupManager:RegisterEntity(thisEntity)

function Init(self)
	local child = thisEntity:FirstMoveChild()

	animKeyvals.origin = thisEntity:GetOrigin()
	animKeyvals.angles = thisEntity:GetAngles()
	gunAnim = SpawnEntityFromTableSynchronous("prop_dynamic", animKeyvals)
	gunAnim:SetParent(thisEntity, "")
	gunAnim:SetOrigin(thisEntity:GetOrigin())

	if child and child:GetName() == "rds"
	then
		child:SetParent(gunAnim, "sight")
	end

	local cpName = DoUniqueString("tracer")
	tracerEndKeyvals.targetname = cpName
	tracerKeyvals.cpoint1 = cpName
	tracerParticle = ParticleSystem("particles/weapon_tracers.vpcf", false)
	tracerEnd = tracerParticle:CreateControlPoint(1)
	
	muzzleFlash = ParticleSystem("particles/generic_fx/fx_dust.vpcf", false)
	impactParticle = ParticleSystem("particles/generic_fx/fx_dust.vpcf", false)
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
	DoEntFireByInstanceHandle(gunAnim, "SetAnimationNoReset", "fire", 0 , nil, nil)
	DoEntFireByInstanceHandle(gunAnim, "SetDefaultAnimation", "idle_uncocked", 0 , nil, nil)
	
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
			local dmgInfo = CreateDamageInfo(thisEntity, currentPlayer, thisEntity:GetAngles():Forward() * DAMAGE_FORCE, traceTable.pos,  DAMAGE)
			--[[TakeDamage(
				{
					victim = traceTable.enthit;
					damage = DAMAGE;
					damage_type = DMG_BULLET;  
					force = thisEntity:GetAngles():Forward() * DAMAGE_FORCE;
					position = traceTable.pos;
					attacker = currentPlayer
				}
			
			)]]
			
			ApplyImpulse(traceTable.enthit, thisEntity:GetAngles(), traceTable.pos - traceTable.enthit:GetCenter(), DAMAGE_FORCE, DAMAGE_ANG_FORCE, DAMAGE_MAX_ANG_MOMENTUM)
			traceTable.enthit:TakeDamage(dmgInfo)
			
			DestroyDamageInfo(dmgInfo)
		
		end
		
		tracerEnd:SetOrigin(traceTable.pos)
		tracerEnd:SetAngles(-thisEntity:GetAngles().x, -thisEntity:GetAngles().y, -thisEntity:GetAngles().z)
		impactParticle:SetOrigin(traceTable.pos)
		
		impactParticle:Start()
		impactParticle:Stop(1)
		
	else
		tracerEnd:SetOrigin(muzzle.origin + RotatePosition(Vector(0,0,0), thisEntity:GetAngles(), Vector(SHOT_TRACE_DISTANCE, 0, 0)))
	end
	
	tracerParticle:SetOrigin(muzzle.origin)
	muzzleFlash:SetOrigin(muzzle.origin)
	muzzleFlash:SetAngles(thisEntity:GetAngles().x, thisEntity:GetAngles().y, thisEntity:GetAngles().z)
	
	tracerParticle:Start()
	tracerParticle:Stop(0.1)

	muzzleFlash:Start()
	muzzleFlash:Stop(1)
	
end


function ApplyImpulse(entity, absAngles, relLocation, magnitude, angMagnitude, clampAngImpulse)

	local angularImpulse = (absAngles:Forward() * -angMagnitude):Cross(relLocation)
	local inverseAngle = QAngle(-entity:GetAngles().x, -entity:GetAngles().y, -entity:GetAngles().z)
	local locAngularImpulse = RotatePosition(Vector(0,0,0), inverseAngle, angularImpulse)
	
	if g_VRScript.pickupManager.debug
	then
		DebugDrawLine(entity:GetCenter(), entity:GetCenter() + relLocation, 0, 255, 255, true, 1)
		DebugDrawLine(entity:GetCenter(), entity:GetCenter() + angularImpulse * 0.2, 255, 0, 255, true, 1)
		DebugDrawLine(entity:GetCenter(), entity:GetCenter() + locAngularImpulse * 0.2, 128, 0, 128, true, 1)
	end
	
	if locAngularImpulse:Length() > clampAngImpulse
	then
		locAngularImpulse = locAngularImpulse:Normalized() * clampAngImpulse
	end
	
	-- Not physically correct.
	entity:ApplyAbsVelocityImpulse(absAngles:Forward() * magnitude * (1 - locAngularImpulse:Length() / clampAngImpulse) )
	entity:ApplyLocalAngularVelocityImpulse(locAngularImpulse)
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
		DoEntFireByInstanceHandle(gunAnim, "SetAnimationNoReset", "draw", 0 , nil, nil)
		DoEntFireByInstanceHandle(gunAnim, "SetDefaultAnimation", "idle", 0 , nil, nil)
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
		DoEntFireByInstanceHandle(gunAnim, "SetAnimationNoReset", "spin_vr", 0 , nil, nil)
		DoEntFireByInstanceHandle(gunAnim, "SetDefaultAnimation", "idle", 0 , nil, nil)
		
		if controller
		then
			controller:FireHapticPulse(0)
		end
		
		prevAngles = nil
		thisEntity:SetThink(SpinRumble, "spin_complete", SPIN_RUMBLE_INTERVAL)
		return nil
		
	elseif angles.x > prevAngles.x + 20
	then
		DoEntFireByInstanceHandle(gunAnim, "SetAnimationNoReset", "cycle_vr", 0 , nil, nil)
		DoEntFireByInstanceHandle(gunAnim, "SetDefaultAnimation", "idle", 0 , nil, nil)
		
		if controller
		then
			controller:FireHapticPulse(0)
		end
		
		prevAngles = nil
		thisEntity:SetThink(CycleRumble, "spin_complete", SPIN_RUMBLE_INTERVAL)
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


function CycleRumble(self)
	spinTimeElapsed = spinTimeElapsed + SPIN_RUMBLE_INTERVAL
	
	if controller
	then
		controller:FireHapticPulse(0)
	end
	
	if spinTimeElapsed >= CYCLE_TIME
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

