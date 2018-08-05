
local playerEnt = nil
local handEnt = nil
local handID = 0
local handAttachment = nil
local parentEnt = nil
local spawntime = 0

local lit = false

function Precache(context)

	PrecacheParticle("particles/fireworks/bomb_fuse_lit.vpcf", context)
end

function Activate()
	spawntime = Time()
end

function Init(parent)
	parentEnt = parent
end

function SetEquipped( self, pHand, nHandID, pHandAttachment, pPlayer )

	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	
	thisEntity:SetThink(DropThink, "drop", 0.1)
	
	return true
end

function SetUnequipped()

	handAttachment = nil
	
	if parentEnt and IsValidEntity(parentEnt) then

		LightFuse()

		thisEntity:SetParent(parentEnt, "")
		thisEntity:SetLocalOrigin(Vector(0,0,0))
		thisEntity:SetLocalAngles(0, 0, 0)
	end
	return true
end

function OnHandleInput(input)

	thisEntity:ForceDropTool()
	return input
end

function DropThink()
	thisEntity:ForceDropTool()
end

function OnTakeDamage(damageTable)

	if parentEnt and IsValidEntity(parentEnt) then
		
		LightFuse()
	end
	return false
end

function LightFuse()
	if not lit and Time() > spawntime + 0.5 then
		lit = true
		EmitSoundOn("Fireworks_Fuse", thisEntity)

		local sparks = ParticleManager:CreateParticle("particles/fireworks/bomb_fuse_lit.vpcf", 
			PATTACH_ABSORIGIN, thisEntity)
		ParticleManager:SetParticleControlEnt(sparks, 
			0, thisEntity, PATTACH_POINT_FOLLOW, "fuse_start", Vector(0, 0, 0), false)
			
		ParticleManager:SetParticleControlEnt(sparks, 
			1, thisEntity, PATTACH_POINT_FOLLOW, "fuse_curve1", Vector(0, 0, 0), false)
			
		ParticleManager:SetParticleControlEnt(sparks, 
			2, thisEntity, PATTACH_POINT_FOLLOW, "fuse_curve2", Vector(0, 0, 0), false)
			
		ParticleManager:SetParticleControlEnt(sparks, 
			3, thisEntity, PATTACH_POINT_FOLLOW, "fuse_end", Vector(0, 0, 0), false)
			
		ParticleManager:SetParticleControlEnt(sparks, 
			4, thisEntity, PATTACH_POINT_FOLLOW, "fuse_spark_angle", Vector(0, 0, 0), false)
			
		thisEntity:SetThink(OnFuseBurned, "fuse", 10 + RandomFloat(-0.5, 0.5))
		
	end
end




function OnFuseBurned()
	if parentEnt and IsValidEntity(parentEnt) then
		parentEnt:GetPrivateScriptScope():Explode(playerEnt)
	end
	thisEntity:Kill()
end

