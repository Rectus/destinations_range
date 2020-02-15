
local playerEnt = nil
local handEnt = nil
local handID = 0
local handAttachment = nil
local parentEnt = nil
local spawntime = 0

local lit = false

function Precache(context)

	PrecacheParticle("particles/fireworks/fuse_lit.vpcf", context)
end

function Activate()
	spawntime = Time()
end

function Init(parent)
	parentEnt = parent
end

function SetEquipped( this, pHand, nHandID, pHandAttachment, pPlayer )

	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	
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

		local sparks = ParticleManager:CreateParticle("particles/fireworks/fuse_lit.vpcf", 
			PATTACH_ABSORIGIN, thisEntity)
		ParticleManager:SetParticleControlEnt(sparks, 
			0, thisEntity, PATTACH_POINT_FOLLOW, "burn_start", Vector(0, 0, 0), false)
			
		ParticleManager:SetParticleControlEnt(sparks, 
			1, thisEntity, PATTACH_POINT_FOLLOW, "burn_end", Vector(0, 0, 0), false)
			
		thisEntity:SetThink(OnFuseBurned, "fuse", 2 + RandomFloat(-0.5, 0.5))
		
	end
end


function OnFuseBurned()
	if parentEnt and IsValidEntity(parentEnt) then
		parentEnt:GetPrivateScriptScope():Fire(playerEnt)
	end
	thisEntity:Kill()
end

