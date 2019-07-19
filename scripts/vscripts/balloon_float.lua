

local EXPLOSION_RANGE = 100
local EXPLOSION_MAX_IMPULSE = 200

local BASE_IMPULSE = 6.5
local MASS_FACTOR = 0.01

local exploded = false

--[[local explosionKeyvals = {
	fireballsprite = "sprites/zerogxplode.spr";
	iMagnitude = 30;
	rendermode = "kRenderTransAdd"
}]]

function Precache(context)
	PrecacheSoundFile("soundevents/soundevents_addon.vsndevts", context)
	--PrecacheEntityFromTable("env_explosion", explosionKeyvals, context)
end

function Activate(activateType)

	if activateType == ACTIVATE_TYPE_ONRESTORE -- on game load
	then		
		EntFireByHandle(thisEntity, thisEntity, "CallScriptFunction", "EnableThink")
	end
end

function Think()

	if exploded
	then
		return nil
	end

	local scale = thisEntity:GetModelScale()
	local scaleFactor = RemapVal(scale, 1, 2, 1, 1.3)

	
	thisEntity:SetMass(MASS_FACTOR * scaleFactor)
	thisEntity:ApplyAbsVelocityImpulse(Vector(0, 0, BASE_IMPULSE * scaleFactor))

	return 0.02
end

function EnableThink()
	thisEntity:SetThink(Think, "think", 0.02)
end


function OnBreak()
	Explode()
end

function Explode()
	if exploded
	then
		return
	end

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
		end
	end

	
	local explosion = ParticleManager:CreateParticle("particles/tool_fx/drone_explosion01_flame01.vpcf", PATTACH_CUSTOMORIGIN, nil)
	ParticleManager:SetParticleControl(explosion, 0, thisEntity:GetCenter())
	
	local smoke = ParticleManager:CreateParticle("particles/entity/env_explosion/explosion_smoke.vpcf", PATTACH_CUSTOMORIGIN, nil)
	ParticleManager:SetParticleControl(smoke, 0, thisEntity:GetCenter())
	
	--local explosion = SpawnEntityFromTableSynchronous("env_explosion", explosionKeyvals)
	--explosion:SetOrigin(thisEntity:GetOrigin())
	--DoEntFireByInstanceHandle(explosion, "Explode", "", 0, nil, nil)
	--DoEntFireByInstanceHandle(explosion, "Kill", "", 20, nil, nil)
	
	StartSoundEventFromPosition("Balloon.Explode", thisEntity:GetOrigin())
	--thisEntity:Kill()
	
end

function UpdateOnRemove()
	for _, child in pairs(thisEntity:GetChildren())
	do
		child:SetParent(nil, "")
		 if child:GetClassname() == "info_particle_system"
		 then
		 	DoEntFireByInstanceHandle(child, "StopPlayEndCap", "", 0, nil, nil)
		 	
		 end
	end
end

