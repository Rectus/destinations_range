--[[
	Rocket script.
	
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


local ROCKET_INITVELOCITY = 3000
local ROCKET_ADDVELOCITY = 1000
local THINK_INTERVAL = 0.02
local armCounter = 0
local ARM_DELAY = 1 
local TRACE_DISTANCE = 48
local prevAngles = nil
local ANGLE_TOLERANCE = 0.1
local user = nil

local EXPLOSION_RANGE = 500
local EXPLOSION_MAX_IMPULSE = 5000

local exploded = false

local explosionKeyvals = {
	--fireballsprite = "sprites/zerogxplode.spr";
	iMagnitude = 100;
	rendermode = "kRenderTransAdd"
}

function Precache(context)
	--PrecacheEntityFromTable("env_explosion", explosionKeyvals, context)
	PrecacheParticle("particles/weapons/law_rocket_smoke.vpcf", context)
	PrecacheParticle("particles/weapons/law_explosion.vpcf", context)
	
end

function EnableDamage(usingPlayer)
	Fire(usingPlayer)
end


function Fire(player)
	user = player
	thisEntity:ApplyAbsVelocityImpulse(thisEntity:GetAngles():Forward() * ROCKET_INITVELOCITY)
	thisEntity:ApplyLocalAngularVelocityImpulse(Vector(1000, 0, 0))
	
	
	local smoke = ParticleManager:CreateParticle("particles/weapons/law_rocket_smoke.vpcf", 
			PATTACH_ABSORIGIN, thisEntity)
		ParticleManager:SetParticleControlEnt(smoke, 
			0, thisEntity, PATTACH_POINT_FOLLOW, "exhaust", Vector(0, 0, 0), false)
	
	thisEntity:SetThink(Think, "ent_think", THINK_INTERVAL)
end

function Think()	
	if exploded 
	then 
		return false
	end
	
	armCounter = armCounter + 1
	if armCounter < ARM_DELAY
	then
		return THINK_INTERVAL
	end
	
	if TraceDirectHit()
	then
		
		return false
	end	
	
	return THINK_INTERVAL
end

function TraceDirectHit()
	local traceTable =
	{
		startpos = thisEntity:GetOrigin();
		endpos = thisEntity:GetOrigin() + RotatePosition(Vector(0,0,0), thisEntity:GetAngles(), Vector(TRACE_DISTANCE, 0, 0));
		ignore = thisEntity

	}
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 0, 255, 0, false, 0.11)
	TraceLine(traceTable)
	
	if traceTable.hit
	then
		Explode(traceTable.normal)
	
		return true
	end
	
	return false
end

function Explode(normal)
	exploded = true
	
	local entities = Entities:FindAllInSphere(thisEntity:GetOrigin(), EXPLOSION_RANGE)
	
	for _,dmgEnt in ipairs(entities) 
	do
		if IsValidEntity(dmgEnt) and dmgEnt:IsAlive() and dmgEnt ~= thisEntity
		then
			local distance = (dmgEnt:GetCenter() - thisEntity:GetCenter()):Length()
				
			local magnitude = (EXPLOSION_MAX_IMPULSE - EXPLOSION_MAX_IMPULSE * distance / EXPLOSION_RANGE)			
			local impulse = (dmgEnt:GetCenter() - thisEntity:GetCenter()):Normalized() * magnitude
			
			dmgEnt:ApplyAbsVelocityImpulse(impulse)
			
			local dmg = CreateDamageInfo(thisEntity, user, impulse, thisEntity:GetOrigin(), magnitude, DMG_BLAST)
			dmgEnt:TakeDamage(dmg)
			DestroyDamageInfo(dmg)

		end
	end
	
	--local explosion = SpawnEntityFromTableSynchronous("env_explosion", explosionKeyvals)
	--explosion:SetOrigin(thisEntity:GetOrigin())
	
	local explParticle = ParticleManager:CreateParticle("particles/weapons/law_explosion.vpcf", 
		PATTACH_ABSORIGIN, thisEntity)
	ParticleManager:SetParticleControl(explParticle, 0, thisEntity:GetOrigin())
	ParticleManager:SetParticleControlForward(explParticle, 0, normal)
	
	thisEntity:AddEffects(32)
	
	--DoEntFireByInstanceHandle(explosion, "Explode", "", 0, nil, nil)
	--DoEntFireByInstanceHandle(explosion, "Kill", "", 5, nil, nil)
	
	DoEntFireByInstanceHandle(thisEntity, "Kill", "", 5, nil, nil)
	
	StartSoundEventFromPosition("Law.Explode", thisEntity:GetOrigin())
	--thisEntity:Kill()
	
end