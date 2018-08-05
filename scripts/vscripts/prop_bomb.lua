--[[
	Round bomb script.
	
	Copyright (c) 2017 Rectus
	
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



local user = nil

local burnTimer = 0
local fuse = nil
local exhaust = -1

local EXPLOSION_RANGE = 300
local EXPLOSION_MAX_IMPULSE = 4000
local EXPLOSION_DAMAGE_FACTOR = 1.5

local fired = false
local exploded = false

local fuseKeyvals = 
{
	classname = "prop_destinations_tool";
	model = "models/props_toys/bomb_fuse.vmdl";
	vscripts = "prop_bomb_fuse"
}


function Precache(context)
	PrecacheModel(fuseKeyvals.model, context)
	PrecacheParticle("particles/fireworks/bomb_fuse_lit.vpcf", context)
	PrecacheParticle("particles/weapons/law_explosion.vpcf", context)
	
end

function Activate()


	fuse = SpawnEntityFromTableSynchronous(fuseKeyvals.classname, fuseKeyvals)
	fuse:SetParent(thisEntity, "")
	fuse:SetLocalOrigin(Vector(0,0,0))
	fuse:SetLocalAngles(0,0,0)
	
	fuse:GetOrCreatePrivateScriptScope().Init(thisEntity)
end

function OnDropped(ent, hand)
	
end

function EnableDamage(usingPlayer)

	fuse:GetOrCreatePrivateScriptScope():LightFuse()
end



function Explode()
	if exploded then return end

	exploded = true
	
	
	local explParticle = ParticleManager:CreateParticle("particles/weapons/law_explosion.vpcf", 
		PATTACH_POINT, thisEntity)
	ParticleManager:SetParticleControl(explParticle, 0, thisEntity:GetOrigin())
	ParticleManager:SetParticleControl(explParticle, 1, Vector(RemapVal(thisEntity:GetAbsScale(), 0, 1, 0.2, 1), 0, 0))
	ParticleManager:SetParticleControlForward(explParticle, 0, Vector(0,0,1))
	
	thisEntity:AddEffects(32)
	
	
	local entities = Entities:FindAllInSphere(thisEntity:GetOrigin(), EXPLOSION_RANGE)
	
	for _,dmgEnt in ipairs(entities) 
	do
		if IsValidEntity(dmgEnt) and dmgEnt:IsAlive() and dmgEnt ~= thisEntity
		then
			local distance = (dmgEnt:GetCenter() - thisEntity:GetCenter()):Length()
				
			local magnitude = (EXPLOSION_MAX_IMPULSE - EXPLOSION_MAX_IMPULSE * distance / EXPLOSION_RANGE)			
			local impulse = (dmgEnt:GetCenter() - thisEntity:GetCenter()):Normalized() * magnitude
			
			dmgEnt:ApplyAbsVelocityImpulse(impulse)
			
			local dmg = CreateDamageInfo(thisEntity, user, impulse * EXPLOSION_DAMAGE_FACTOR, thisEntity:GetOrigin(), magnitude, DMG_BLAST)
			dmgEnt:TakeDamage(dmg)
			DestroyDamageInfo(dmg)

		end
	end
	
	StartSoundEventFromPosition("Law.Explode", thisEntity:GetOrigin())
	DoEntFireByInstanceHandle(thisEntity, "Kill", "", 2, nil, nil)

	
end