
--[[
	Laser pistol weapon script.
	
	Copyright (c) 2019 Rectus
	
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

local PICKUP_FIRE_DELAY = 0.1

local SHOT_TRACE_DISTANCE = 16384
local DAMAGE_TICK = 10
local DAMAGE_TICK_INTERVAL = 0.055
local THINK_INTERVAL = 0.011
local DAMAGE_TICK_MAX_DIST = 1

local FIRE_RUMBLE_INTERVAL = 0.07

local STATE_READY = 1
local STATE_FIRING = 2
local STATE_OVERHEAT = 3

local state = STATE_READY
local lastTickTime = 0
local lastTickPos = Vector(0,0,0)
local lastTickNormal = Vector(1,0,0)

local isCarried = false
local pickupTime = 0
local controller = nil
local currentPlayer = nil
local handID = 0
local handAttachment = nil
local isFireButtonPressed = false
local alreadyPickedUp = false


local spinTimeElapsed = 0
local fireRumbleElapsed = 0
local tracerParticle = nil
local tracerEnd = nil
local beam = nil
local impactParticle = nil
local meltParticle = nil



function Precache(context)
	PrecacheParticle("particles/weapons/laser_pistol_impact_melt.vpcf", context)
	PrecacheParticle("particles/weapons/laser_pistol_beam.vpcf", context)
	PrecacheParticle("particles/weapons/laser_pistol_impact.vpcf", context)
end

function Activate()
	
end

function SetEquipped( this, pHand, nHandID, pHandAttachment, pPlayer )
	handID = nHandID
	controller = pHand
	currentPlayer = pPlayer
	handAttachment = pHandAttachment
	isCarried = true
	pickupTime = Time()
	
	--handAttachment:SetGraphParameterFloat("safety", 1) 
	handAttachment:SetSequence("idle")
	handAttachment:SetPoseParameter("safety", 1)
	
	local paintColor = thisEntity:GetRenderColor()
	handAttachment:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	StartSoundEvent("toy_gun_equip", handAttachment) 
	return true
end

function SetUnequipped()
	isCarried = false
	
	local paintColor = handAttachment:GetRenderColor()
	thisEntity:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	if state == STATE_FIRING then
		EndFiring()
	end
	
	return true
end


function OnHandleInput( input )
	-- Even uglier ternary operator
	local IN_TRIGGER = (handID == 0 and IN_USE_HAND0 or IN_USE_HAND1)
	local IN_GRIP = (handID == 0 and IN_GRIP_HAND0 or IN_GRIP_HAND1)
	
	--handAttachment:SetGraphParameterFloat("trigger", input.triggerValue) 
	handAttachment:SetPoseParameter("trigger", input.triggerValue)
	
	if input.buttonsPressed:IsBitSet(IN_TRIGGER)
	then
		input.buttonsPressed:ClearBit(IN_TRIGGER)
		
		if state == STATE_READY and Time() > pickupTime + PICKUP_FIRE_DELAY
		then
			StartFiring()	
		end	
	end
	
	if input.buttonsReleased:IsBitSet(IN_TRIGGER) 
	then
		input.buttonsReleased:ClearBit(IN_TRIGGER)
		
		if state == STATE_FIRING then
			EndFiring()
		end
	end

	return input
end


function StartFiring()
	state = STATE_FIRING
	StartSoundEvent("Laser_Pistol_Fire", handAttachment) 
	StartSoundEvent("Laser_Pistol_Loop", handAttachment)
	
	beam = ParticleManager:CreateParticle("particles/weapons/laser_pistol_beam.vpcf", 
		PATTACH_POINT_FOLLOW, handAttachment)
	ParticleManager:SetParticleControlEnt(beam, 0, handAttachment, PATTACH_POINT_FOLLOW, 
		"beam_origin", Vector(0, 0, 0), false)
		
	local attach = GetAttachment(handAttachment, "beam_origin")
	ParticleManager:SetParticleControlForward(beam, 0, Vector(0,0,0))	
		
	ParticleManager:SetParticleControl(beam, 1, attach.origin)
	
	if controller
	then
		thisEntity:SetThink(FireRumble, "fire_rumble")
	end
	
	thisEntity:SetThink(FireTick, "fire_tick", 0)

end


function EndFiring()
	state = STATE_READY
	StopSoundEvent("Laser_Pistol_Loop", handAttachment)
	
	if beam then
		ParticleManager:DestroyParticle(beam, false)
		beam = nil
	end
	if impactParticle then
		ParticleManager:DestroyParticle(impactParticle, false)
		impactParticle = nil
	end
	if meltParticle then
		ParticleManager:DestroyParticle(meltParticle, false)
		meltParticle = nil
	end
end


function FireTick()

	if state ~= STATE_FIRING then
		return
	end

	local muzzle = GetAttachment(handAttachment, "muzzle")
	local traceTable =
	{
		startpos = muzzle.origin;
		endpos = muzzle.origin + muzzle.angles:Forward() * SHOT_TRACE_DISTANCE;
		ignore = currentPlayer

	}
	local beamEndPos = traceTable.endpos
	if g_VRScript.playerPhysController and g_VRScript.playerPhysController:IsDebugDrawEnabled()
	then
		DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, 0.1)
	end
	
	TraceLine(traceTable)
	
	if traceTable.hit
	then
		if g_VRScript.playerPhysController and g_VRScript.playerPhysController:IsDebugDrawEnabled()
		then
			DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 255, 0, false, 0.2)
		end
		
		if traceTable.enthit and traceTable.enthit:GetEntityIndex() > 0
		then
			if Time() > lastTickTime + DAMAGE_TICK_INTERVAL then
				lastTickTime = Time()
				
				if (lastTickPos - traceTable.pos):Length() < DAMAGE_TICK_MAX_DIST then
					local dmgInfo = CreateDamageInfo(thisEntity, currentPlayer, Vector(0, 0, 0), traceTable.pos, 
						DAMAGE_TICK, DMG_BURN)
					
					traceTable.enthit:TakeDamage(dmgInfo)		
					DestroyDamageInfo(dmgInfo)
				end
		
			end
		else
			if meltParticle == nil 
			then
				meltParticle = ParticleManager:CreateParticle("particles/weapons/laser_pistol_impact_melt.vpcf", 
					PATTACH_CUSTOMORIGIN, thisEntity)
			end
			ParticleManager:SetParticleControl(meltParticle, 0, traceTable.pos)
			ParticleManager:SetParticleControl(meltParticle, 2, lastTickPos)
			ParticleManager:SetParticleControlForward(meltParticle, 0, traceTable.normal)
			ParticleManager:SetParticleControlForward(meltParticle, 2, lastTickNormal)
		end
		
		
		
		if impactParticle == nil then
			impactParticle = ParticleManager:CreateParticle("particles/weapons/laser_pistol_impact.vpcf", 
				PATTACH_CUSTOMORIGIN, thisEntity)
		end
		
		ParticleManager:SetParticleControl(impactParticle, 0, traceTable.pos)
		ParticleManager:SetParticleControlForward(impactParticle, 0, traceTable.normal)
		
		lastTickPos = traceTable.pos
		lastTickNormal = traceTable.normal
		beamEndPos = traceTable.pos
	else
		if meltParticle then
			ParticleManager:DestroyParticle(meltParticle, false)
			meltParticle = nil
		end
	
		if impactParticle then
			ParticleManager:DestroyParticle(impactParticle, false)
			impactParticle = nil
		end
	end
	
	if beam then
		ParticleManager:SetParticleControl(beam, 1, beamEndPos)
	end
	
	return THINK_INTERVAL
end



function FireRumble()
	
	if not controller or state ~= STATE_FIRING 
	then
		return nil
	end

	controller:FireHapticPulse(1)
	
	return FIRE_RUMBLE_INTERVAL
end




function sign(x)
	return x > 0 and 1 or x < 0 and -1 or 1
end



function GetAttachment(ent, name)
	local idx = ent:ScriptLookupAttachment(name)
	
	local table = {}
	table.origin = ent:GetAttachmentOrigin(idx)
	local ang = ent:GetAttachmentAngles(idx)
	table.angles = QAngle(ang.x, ang.y, ang.z)
	
	return table
end

