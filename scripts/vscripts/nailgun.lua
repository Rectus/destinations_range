--[[
	Nailgun script.
	
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


local CARRY_OFFSET = Vector(0, 0, 0)
local CARRY_ANGLES = QAngle(0, -90, 90)
local FIRE_RUMBLE_INTERVAL = 0.01
local FIRE_RUMBLE_TIME = 0.2
local SHOT_TRACE_DISTANCE = 16384
local FIRE_INTERVAL = 0.5


local isCarried = false
local fired = false
local controller = nil
local currentPlayer = nil
local fireRumbleElapsed = 0
local tracerParticle = nil
local tracerEnd = nil
local muzzleFlash = nil
local impactParticle = nil
local gunAnim = nil

local firstHit = false
local firstEnt = nil
local firstPos = nil

local dynamicEntities = {"prop_physics"; "prop_physics_override"; "simple_physics_prop"; "func_physbox"}


local tracerKeyvals = {
	classname = "info_particle_system";
	effect_name = "particles/weapon_tracers.vpcf";
	start_active = 0;
	cpoint1 = ""
}

local constraintKeyvals = {
	classname = "phys_lengthconstraint";
	targetname = "rope_constraint";
	attach1 = "";
	attach2 = "";
	addlength = 0;
	attachpoint = Vector(0,0,0)
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
	targetname = "nailgun_anim";
	model = "models/props_range/nailgun.vmdl";
	solid = 0
	}

function Precache(context)
	PrecacheParticle("particles/nailgun_rope.vpcf", context)
	PrecacheParticle(tracerKeyvals.effect_name, context)
	PrecacheParticle(dustKeyvals.effect_name, context)
	PrecacheModel(animKeyvals.model, context)
	PrecacheModel("models/weapons/hand_dummy.vmdl", context)
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


	local cpName = DoUniqueString("tracer")
	tracerEndKeyvals.targetname = cpName
	tracerKeyvals.cpoint1 = cpName
	tracerParticle = ParticleSystem("particles/weapon_tracers.vpcf", false)
	tracerEnd = tracerParticle:CreateControlPoint(1)
	
	muzzleFlash = ParticleSystem("particles/generic_fx/fx_dust.vpcf", false)
	impactParticle = ParticleSystem("particles/generic_fx/fx_dust.vpcf", false)
	
	--DoEntFireByInstanceHandle(gunAnim, "AddOutput", "targetname nailgun_new", 0 , nil, nil)
	thisEntity:SetConstraint(Vector(0, 0, 10))
end

function OnTriggerPressed(self)

	if not fired
	then
		Fire()	
	end
end

function Fire()
	fired = true
	StartSoundEvent("Suctioncup.Attach", thisEntity)
	TraceShot(self)
	
	if controller
	then
		thisEntity:SetThink(FireRumble, "fire_rumble", 0.1)
	end
	DoEntFireByInstanceHandle(gunAnim, "SetAnimationNoReset", "fire", 0 , nil, nil)
	DoEntFireByInstanceHandle(gunAnim, "SetDefaultAnimation", "idle_uncocked", 0 , nil, nil)
	
	prevAngles = thisEntity:GetAngles()
	thisEntity:SetThink(EnableFire, "enable_fire", FIRE_INTERVAL)
end


function EnableFire(self)
	fired = false
end


function TraceShot(self)
	local muzzle = GetAttachment("muzzle")
	local hitDynEnt = false
	local traceTable =
	{
		startpos = muzzle.origin + RotatePosition(Vector(0,0,0), RotateOrientation(thisEntity:GetAngles(), QAngle(0, -90, 0)), Vector(0.1, 0, 0));
		endpos = muzzle.origin + RotatePosition(Vector(0,0,0), RotateOrientation(thisEntity:GetAngles(), QAngle(0, -90, 0)), Vector(SHOT_TRACE_DISTANCE, 0, 0));
		ignore = currentPlayer

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
			for _, entClass in ipairs(dynamicEntities)
			do
				if traceTable.enthit:GetClassname() == entClass and traceTable.enthit:GetMoveParent() == nil
				then
					hitDynEnt = true
				end
			end
		
			if firstHit
			then
				if hitDynEnt or firstEnt
				then
					DebugDrawLine(traceTable.pos, firstPos, 128, 255, 128, false, 2)
					
					local ropeParticle = ParticleSystem("particles/nailgun_rope.vpcf", false)
					ropeParticle:CreateControlPoint(1)
					
					ropeParticle:SetOrigin(firstPos)					
					ropeParticle:GetControlPoint(1):SetOrigin(traceTable.pos)
					
					constraintKeyvals.origin = firstPos
					constraintKeyvals.attachpoint = traceTable.pos
					
					if firstEnt and firstEnt:GetName() ~= ""
					then	
						constraintKeyvals.attach1 = firstEnt:GetName()
						ropeParticle:SetParent(firstEnt, "")
						--print(firstEnt:GetName())
					end	
					if hitDynEnt and traceTable.enthit:GetName() ~= ""
					then
						constraintKeyvals.attach2 = traceTable.enthit:GetName()
						ropeParticle:GetControlPoint(1):SetParent(traceTable.enthit, "")
						--print(traceTable.enthit:GetName())
					end
					
					local constraint = SpawnEntityFromTableSynchronous(constraintKeyvals.classname, constraintKeyvals)
					--DoEntFireByInstanceHandle(constraint, "AddOutput", "OnKilled>".. ropeParticle:GetEntity():GetName() .. ">Stop>>0>-1", 0 , nil, nil)
					ropeParticle:Start()
				end
				firstHit = false
			else
				DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 0, 255, false, 2)
				firstHit = true
				firstPos = traceTable.pos
				if hitDynEnt
				then
					firstEnt = traceTable.enthit
				else
					firstEnt = nil
				end
			end
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
	hand:AddHandModelOverride("models/weapons/hand_dummy.vmdl")
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
	hand:RemoveHandModelOverride("models/weapons/hand_dummy.vmdl")
	thisEntity:SetParent(nil, "")
	controller = nil
end


function GetAttachment(name)
	local idx = thisEntity:ScriptLookupAttachment(name)
	
	local table = {}
	table.origin = thisEntity:GetAttachmentOrigin(idx)
	table.angles = VectorToAngles(thisEntity:GetAttachmentAngles(idx))
	
	return table
end
