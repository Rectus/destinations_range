

function Activate()
	
	thisEntity:SetThink(Delay, 1)

end

function Delay()
	local player = Entities:FindByClassname(nil, "player") 
	local hmd = player:GetHMDAvatar()
	local spawnOrigin = player:GetAbsOrigin()
	
	local particleIndex = ParticleManager:CreateParticle("particles/weapons/red_dot_sight.vpcf", 
		PATTACH_POINT_FOLLOW, thisEntity)
	
	--ParticleManager:SetParticleControlEnt(particleIndex, 1, thisEntity, 0, nil, Vector(0,0,0), true)
	
	--ParticleManager:SetParticleControlEnt(particleIndex, 2, thisEntity, 0, nil, Vector(0,0,0), true)
	ParticleManager:SetParticleControlEnt(particleIndex, 0, thisEntity, PATTACH_POINT_FOLLOW, nil, Vector(0,0,0), true) 
	--ParticleManager:SetParticleControlOffset(particleIndex, 0, Vector(0,0,10)) 
end