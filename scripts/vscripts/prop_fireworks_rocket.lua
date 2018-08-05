--[[
	Fireworks rocket script.
	
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


local ROCKET_THRUST = 5000
local THRUST_INTERVAL = 0.022
local BURN_DURATION = 0.7
local EXPLODE_DELAY = 1.5
local EXPLODE_DELAY_VARIANCE = 0.3

local user = nil

local burnTimer = 0
local fuse = nil
local exhaust = -1

local EXPLOSION_RANGE = 50
local EXPLOSION_MAX_IMPULSE = 500
local EXPLOSION_DAMAGE_FACTOR = 0.1

local fired = false
local exploded = false

local fuseKeyvals = 
{
	classname = "prop_destinations_tool";
	model = "models/props_toys/fireworks_rocket_fuse.vmdl";
	vscripts = "prop_fireworks_rocket_fuse"
}


function Precache(context)
	PrecacheModel(fuseKeyvals.model, context)
	PrecacheParticle("particles/fireworks/rocket_exhaust.vpcf", context)
	PrecacheParticle("particles/weapons/law_explosion.vpcf", context)
	
end

function Activate()


	local colors =
	{
		{255, 0, 0},
		{0, 255, 0},
		{0, 64, 200},
		{127, 255, 0},
		{255, 220, 150},
		{230, 0, 179},
		{200, 0, 200}
	}
	
	local color = colors[RandomInt(1, #colors)]
	thisEntity:SetRenderColor(color[1], color[2], color[3])


	fuse = SpawnEntityFromTableSynchronous(fuseKeyvals.classname, fuseKeyvals)
	fuse:SetParent(thisEntity, "")
	fuse:SetLocalOrigin(Vector(0,0,0))
	fuse:SetLocalAngles(0,0,0)
	
	fuse:GetOrCreatePrivateScriptScope().Init(thisEntity)
end

function OnDropped(ent, hand)
	if not fired then
		
		local idx = thisEntity:ScriptLookupAttachment("arrow_nock")
		local pos = thisEntity:GetAttachmentOrigin(idx)
		local vec = thisEntity:GetAttachmentAngles(idx)
		local ang =  QAngle(vec.x, vec.y, vec.z)
	
		local traceTable =
		{
			startpos = pos - ang:Forward() * 0.1;
			endpos = pos - ang:Forward() * 2;
			ignore = hand:GetPlayer()	
		}
		--DebugDrawLine(traceTable.startpos, traceTable.endpos, 0, 255, 0, false, 10)
		TraceLine(traceTable)
		
		if traceTable.hit and (not traceTable.enthit or traceTable.enthit:GetClassname() ~= "player")
		then
			thisEntity:Freeze(true)
			EmitSoundOn("Fireworks_Place", thisEntity)
		else
			thisEntity:Freeze(false)
		end
	end
end

function EnableDamage(usingPlayer)

	Fire(usingPlayer)
end


function Fire(player)
	user = player
	fired = true
	thisEntity:Freeze(false)
	EmitSoundOn("Fireworks_Rocket_Launch", thisEntity)
	
	local forwardDir = thisEntity:GetAngles():Forward()
	thisEntity:ApplyAbsVelocityImpulse(forwardDir * ROCKET_THRUST * THRUST_INTERVAL)
	
	
	exhaust = ParticleManager:CreateParticle("particles/fireworks/rocket_exhaust.vpcf", 
		PATTACH_ABSORIGIN, thisEntity)
	ParticleManager:SetParticleControlEnt(exhaust, 
		0, thisEntity, PATTACH_POINT_FOLLOW, "exhaust", Vector(0, 0, 0), false)
		
	ParticleManager:SetParticleControlForward(exhaust, 0, -forwardDir)
	
	thisEntity:SetThink(ThrustThink, "thrust", THRUST_INTERVAL)
end


function ThrustThink(self)	
	local forwardDir = thisEntity:GetAngles():Forward()
	thisEntity:ApplyAbsVelocityImpulse(forwardDir * ROCKET_THRUST * THRUST_INTERVAL)
	
	burnTimer = burnTimer + THRUST_INTERVAL
	
	if burnTimer >= BURN_DURATION then
		ParticleManager:DestroyParticle(exhaust, false)
		thisEntity:SetThink(Explode, "explode", EXPLODE_DELAY + RandomFloat(-EXPLODE_DELAY_VARIANCE, EXPLODE_DELAY_VARIANCE))
		return nil
	end
	
	return THRUST_INTERVAL
end


function Explode()
	if exploded then return end

	exploded = true
	
	
	local explParticle = ParticleManager:CreateParticle("particles/fireworks/fireworks_explosion_1.vpcf", 
		PATTACH_POINT, thisEntity)
	ParticleManager:SetParticleControl(explParticle, 0, thisEntity:GetOrigin())
	--ParticleManager:SetParticleControlEnt(explParticle, 
		--0, thisEntity, PATTACH_POINT, "explosion_origin", Vector(0, 0, 0), true)
	ParticleManager:SetParticleControl(explParticle, 3, thisEntity:GetRenderColor())
	ParticleManager:SetParticleControl(explParticle, 1, Vector(RemapVal(thisEntity:GetAbsScale(), 0, 1, 0.2, 1), 0, 0))
	--ParticleManager:SetParticleControlForward(explParticle, 0, normal)
	
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
	
	StartSoundEventFromPosition("Fireworks_Rocket_Explode1", thisEntity:GetOrigin())
	DoEntFireByInstanceHandle(thisEntity, "Kill", "", 10, nil, nil)

	
end