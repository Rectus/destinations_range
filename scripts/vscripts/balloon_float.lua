

local EXPLOSION_RANGE = 50
local EXPLOSION_MAX_IMPULSE = 50
local BASE_IMPULSE = 6

local exploded = false

local explosionKeyvals = {
	fireballsprite = "sprites/zerogxplode.spr";
	iMagnitude = 30;
	rendermode = "kRenderTransAdd"
}

function Precache(context)
	PrecacheSoundFile("soundevents/soundevents_addon.vsndevts", context)
	PrecacheEntityFromTable("env_explosion", explosionKeyvals, context)
end

function Think()

	if exploded
	then
		return nil
	end

	local scale = thisEntity:GetModelScale()
	local scaleFactor = scale
	if scale < 1
	then
		scaleFactor = scale * scale * scale
	end
	
	thisEntity:ApplyAbsVelocityImpulse(Vector(0, 0, BASE_IMPULSE * scaleFactor))

	return 0.02
end

function EnableThink(self)
	thisEntity:SetThink(Think, "think", 0.02)
end


function OnBreak(self)
	Explode()
end

function Explode(self)
	if exploded
	then
		return
	end

	exploded = true
	
	local pushEnt = Entities:FindByClassname(nil, "prop_destinations_physics")
	
	while pushEnt 
	do
		if pushEnt ~= thisEntity
		then
			local distance = (pushEnt:GetCenter() - thisEntity:GetCenter()):Length()
			
			if distance < EXPLOSION_RANGE
			then
				local magnitude = (EXPLOSION_MAX_IMPULSE - EXPLOSION_MAX_IMPULSE * distance / EXPLOSION_RANGE)
				local impulse = (pushEnt:GetCenter() - thisEntity:GetCenter()):Normalized() * magnitude
				pushEnt:ApplyAbsVelocityImpulse(impulse)
			end
		end
		pushEnt = Entities:FindByClassname(pushEnt, "prop_destinations_physics")
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

