
function Precache(context)
	PrecacheParticle("particles/weapons/sight_red_dot.vpcf", context)
end

function Activate()
	thisEntity:SetThink(SpawnDot, "spawn", 1)


end

function SpawnDot()
	local dot = ParticleManager:CreateParticle("particles/weapons/sight_red_dot.vpcf", 
		PATTACH_POINT_FOLLOW, thisEntity)
	ParticleManager:SetParticleControlEnt(dot, 0, thisEntity,
		PATTACH_POINT_FOLLOW, "dot_project", Vector(0,0,0), true)
end