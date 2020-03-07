
local playerEnt = nil
local handEnt = nil
local handID = 0
local handAttachment = nil

local playeStartEnt = nil
local currentSpawn = nil
local newSpawn = nil

local triggerHeld = false

local startUseTime = 0
local USE_TIME = 1.0

local pickupTime = 0
local USE_DELAY = 0.5

local spawnModelKeyvals = 
{
	targetname = "spawn_model";
	model = "models/editor/playerstart.vmdl";
	solid = 0;
}

function Precache(context)

	PrecacheModel("models/editor/playerstart.vmdl", context)
	PrecacheParticle("particles/entity/player_teleport_sparks.vpcf", context)
end


function Update()

	if not playerEnt or not IsValidEntity(playerEnt) or
		not playeStartEnt or not IsValidEntity(playeStartEnt) then
	
		return nil
	end
	
	currentSpawn:SetAbsOrigin(playeStartEnt:GetAbsOrigin())
	local spawnAngles = playeStartEnt:GetAngles()
	currentSpawn:SetAbsAngles(spawnAngles.x, spawnAngles.y, spawnAngles.z)
	
	local anchor = playerEnt:GetHMDAnchor()
	
	newSpawn:SetAbsOrigin(anchor:GetAbsOrigin())
	local newAngles = anchor:GetAngles()
	newSpawn:SetAbsAngles(newAngles.x, newAngles.y, newAngles.z)
	
	--DebugDrawLine(playeStartEnt:GetAbsOrigin(), anchor:GetAbsOrigin(), 255, 0, 0, false, FrameTime())

	if triggerHeld and Time() > startUseTime + USE_TIME then

		playeStartEnt:SetAbsOrigin(anchor:GetAbsOrigin())
		playeStartEnt:SetAbsAngles(newAngles.x, newAngles.y, newAngles.z)
		
		EmitSoundOn( "cache_open", playeStartEnt)
		StopSoundOn( "cache_finder_target_loop", handAttachment)
		ParticleManager:CreateParticle("particles/entity/player_teleport_sparks.vpcf", PATTACH_ABSORIGIN, newSpawn)
		triggerHeld = false
	end

	return FrameTime()
end


function SetEquipped( this, pHand, nHandID, pHandAttachment, pPlayer )

	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	pickupTime = Time()

	playeStartEnt = Entities:FindByClassname(nil, "info_player_start")
	
	
	if not playeStartEnt or not IsValidEntity(playeStartEnt) then
	
		return true
	end
	
	local spawnAngles = playeStartEnt:GetAngles()
	
	currentSpawn = SpawnEntityFromTableSynchronous("prop_dynamic", spawnModelKeyvals)
	
	--currentSpawn:SetRenderMode(5) 
	currentSpawn:SetRenderColor(192, 192, 0) 
	currentSpawn:SetRenderAlpha(128) 
	
	newSpawn = SpawnEntityFromTableSynchronous("prop_dynamic", spawnModelKeyvals)
	newSpawn:SetAbsOrigin(playeStartEnt:GetAbsOrigin())
	newSpawn:SetAbsAngles(spawnAngles.x, spawnAngles.y, spawnAngles.z)
	
	--newSpawn:SetRenderMode(5) 
	newSpawn:SetRenderColor(0, 255, 0) 
	newSpawn:SetRenderAlpha(128) 

	thisEntity:SetThink(Update, "update")
	
	return true
end



function SetUnequipped()
	
	playerEnt = nil
	handEnt = nil
	
	StopSoundOn( "cache_finder_target_loop", handAttachment)
	
	currentSpawn:Kill()
	newSpawn:Kill()
	
	return true
end


function OnHandleInput(input)
	if not playerEnt then 
	
		return
	end

	local IN_TRIGGER = (handID == 0 and IN_USE_HAND0 or IN_USE_HAND1)
	
	if input.buttonsPressed:IsBitSet(IN_TRIGGER) and Time() > pickupTime + USE_DELAY then
	
		if playeStartEnt and IsValidEntity(playeStartEnt) then
			EmitSoundOn( "cache_finder_target", handAttachment)
			EmitSoundOn( "cache_finder_target_loop", handAttachment)
			startUseTime = Time()
			triggerHeld = true
		else
			EmitSoundOn( "cache_finder_trigger_nocache", handAttachment)
			
		end
	end		
	
	if input.buttonsReleased:IsBitSet(IN_TRIGGER) then
	
		triggerHeld = false
		StopSoundOn( "cache_finder_target_loop", handAttachment)
	end


	return input
end