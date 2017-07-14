
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
require "utils.deepprint"
 

local SPIN_CHECK_INTERVAL = 0.2
local FIRE_RUMBLE_INTERVAL = 0.01
local FIRE_RUMBLE_TIME = 0.2
local SPIN_TIME = 1.1
local CYCLE_TIME = 1.0
local SPIN_RUMBLE_INTERVAL = 0.02
local SHOT_TRACE_DISTANCE = 16384

local DAMAGE = 150
local DAMAGE_FORCE = 500

local isCarried = false
local fired = false
local cycling = false
local controller = nil
local currentPlayer = nil
local handID = 0
local handAttachment = nil
local isFireButtonPressed = false
local alreadyPickedUp = false
local prevAngles = nil

local spinTimeElapsed = 0
local fireRumbleElapsed = 0
local tracerParticle = nil
local tracerEnd = nil
local muzzleFlash = nil
local impactParticle = nil

local sight = nil



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
	PrecacheModel("models/weapons/hand_dummy.vmdl", context)
	PrecacheSoundFile("soundevents/soundevents_addon.vsndevts", context)
end

function Activate()
	thisEntity:SetSequence("idle_uncocked")
end

function SetEquipped( self, pHand, nHandID, pHandAttachment, pPlayer )
	handID = nHandID
	controller = pHand
	currentPlayer = pPlayer
	handAttachment = pHandAttachment
	isCarried = true
	
	local child = thisEntity:FirstMoveChild()

	if child and child:GetName() == "rds"
	then
		sight = child
		child:SetParent(handAttachment, "sight")
		child:SetLocalOrigin(Vector(0,0,0))
		child:SetLocalAngles(0,0,0)
	end
	
	if not alreadyPickedUp
	then
		handAttachment:SetSequence("draw")
		thisEntity:SetThink(SequenceFinished, "sequence", handAttachment:ActiveSequenceDuration())
		alreadyPickedUp = true
	else
		SequenceFinished()
	end
	
	if fired and not cycling
	then
		handAttachment:SetSequence("idle_uncocked")
		prevAngles = thisEntity:GetLocalAngles()
		thisEntity:SetThink(CheckSpin, "check_spin", SPIN_CHECK_INTERVAL)
	end

	return true
end

function SetUnequipped()
	isCarried = false
	
	if sight ~= nil
	then
		sight:SetParent(thisEntity, "sight")
		sight:SetLocalOrigin(Vector(0,0,0))
		sight:SetLocalAngles(0,0,0)
	end
	
	if fired and not cycling
	then
		thisEntity:SetSequence("idle_uncocked")
	else
		thisEntity:SetSequence("idle")
	end
	
	return true
end


function OnHandleInput( input )
	-- Even uglier ternary operator
	local IN_TRIGGER = (handID == 0 and IN_USE_HAND0 or IN_USE_HAND1)
	local IN_GRIP = (handID == 0 and IN_GRIP_HAND0 or IN_GRIP_HAND1)
	
	if input.buttonsPressed:IsBitSet(IN_TRIGGER)
	then
		input.buttonsPressed:ClearBit(IN_TRIGGER)
		OnTriggerPressed(self)
	end
	
	if input.buttonsReleased:IsBitSet(IN_TRIGGER) 
	then
		input.buttonsReleased:ClearBit(IN_TRIGGER)
	end
	
	if input.buttonsReleased:IsBitSet(IN_GRIP)
	then
		input.buttonsReleased:ClearBit(IN_GRIP)
		thisEntity:ForceDropTool();
	end

	return input
end


function Init(self)
	local child = thisEntity:FirstMoveChild()

	animKeyvals.origin = handAttachment:GetOrigin()
	animKeyvals.angles = handAttachment:GetAngles()
	
	gunAnim = SpawnEntityFromTableSynchronous("prop_dynamic", animKeyvals)

	gunAnim:SetParent(handAttachment, "")
	gunAnim:SetOrigin(handAttachment:GetOrigin())

	if child and child:GetName() == "rds"
	then
		sight = child
		child:SetParent(gunAnim, "sight")
		child:SetLocalOrigin(Vector(0,0,0))
		child:SetLocalAngles(0,0,0)
	end
end


function OnTriggerPressed(self)

	if not fired and not cycling
	then
		Fire()	
	end
end


function Fire()
	fired = true
	cycling = false
	StartSoundEvent("Law.Fire", thisEntity)
	TraceShot(self)
	
	if controller
	then
		thisEntity:SetThink(FireRumble, "fire_rumble", 0.1)
	end
	handAttachment:SetSequence("fire")
	thisEntity:SetThink(SequenceFinished, "sequence", handAttachment:ActiveSequenceDuration())
	
	prevAngles = thisEntity:GetLocalAngles()
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
	local tracerEndPos = traceTable.endpos
	if false
	then
		DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, 0.1)
	end
	
	TraceLine(traceTable)
	
	if traceTable.hit 
	then
		if false
		then
			DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 255, 0, false, 0.2)
		end
		
		if traceTable.enthit
		then
		
			local dmgInfo = CreateDamageInfo(thisEntity, currentPlayer, thisEntity:GetAngles():Forward() * DAMAGE_FORCE, 
				traceTable.pos,  DAMAGE, DMG_BULLET)
				
			traceTable.enthit:TakeDamage(dmgInfo)		
			DestroyDamageInfo(dmgInfo)
			
			--[[if traceTable.enthit:GetPrivateScriptScope() and 
				traceTable.enthit:GetPrivateScriptScope().OnHurt
			then
				traceTable.enthit:GetPrivateScriptScope().OnHurt()
			end]]
		
		end
		
		tracerEndPos = traceTable.pos
		
		local impactParticle = ParticleManager:CreateParticle("particles/generic_fx/fx_dust.vpcf", PATTACH_CUSTOMORIGIN, nil)
		ParticleManager:SetParticleControl(impactParticle, 0, traceTable.pos)
		ParticleManager:SetParticleControlForward(impactParticle, 0, traceTable.normal)
		
	end
	
	local tracer = ParticleManager:CreateParticle("particles/weapon_tracers.vpcf", PATTACH_CUSTOMORIGIN, nil)
	ParticleManager:SetParticleControl(tracer, 0, traceTable.startpos)
	ParticleManager:SetParticleControl(tracer, 1, tracerEndPos)
	
	local muzzleFlash = ParticleManager:CreateParticle("particles/generic_fx/fx_dust.vpcf", PATTACH_POINT_FOLLOW, gunAnim)
	ParticleManager:SetParticleControlEnt(muzzleFlash, 0, gunAnim, PATTACH_POINT_FOLLOW, "muzzle", Vector(0, 0, 0), true)
	
end


function SequenceFinished()
	if IsValidEntity(handAttachment) and handAttachment:IsSequenceFinished()
	then
		cycling = false
	
		if fired
		then
			handAttachment:SetSequence("idle_uncocked")
		else		
			handAttachment:SetSequence("idle")
		end
	else
		return handAttachment:ActiveSequenceDuration()
	end
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



function CheckSpin(self)
	if not isCarried
	then
		return nil
	end

	local angles = thisEntity:GetLocalAngles()

	if angles.x < prevAngles.x - 20
	then
		handAttachment:SetSequence("spin_vr")
		thisEntity:SetThink(SequenceFinished, "sequence", handAttachment:ActiveSequenceDuration())
		cycling = true
		fired = false
		
		
		if controller
		then
			controller:FireHapticPulse(0)
		end
		
		prevAngles = nil
		thisEntity:SetThink(SpinRumble, "spin_complete", SPIN_RUMBLE_INTERVAL)
		return nil
		
	elseif angles.x > prevAngles.x + 20
	then
		handAttachment:SetSequence("cycle_vr")
		thisEntity:SetThink(SequenceFinished, "sequence", handAttachment:ActiveSequenceDuration())
		cycling = true
		fired = false
		
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

