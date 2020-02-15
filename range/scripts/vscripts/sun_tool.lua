local isCarried = false
local playerEnt = nil
local handEnt = nil
local handID = 0
local handAttachment = nil
local sun = nil
local sunParticle = -1

local triggerHeld = false

local SUN_UPDATE_INTERVAL = 0.02

local envEnt = nil

local sunAngles = nil
local startAngles = nil
local startSunAngles = nil

local pickupTime = 0
local PICKUP_TRIGGER_DELAY = 0.5

local sunKeyvals = 
{
	targetname = "sun_prop";
	model = "models/tools/sun_tool_sun.vmdl";
	solid = 0
}

function Precache(context)
	PrecacheModel("models/tools/sun_tool_sun.vmdl", context)
	PrecacheParticle("particles/tools/sun_tool_glow.vpcf", context)
end

function Activate(activateType)

	if activateType == ACTIVATE_TYPE_ONRESTORE -- on game load
	then
			
		-- Hack to properly handle restoration from saves, 
		-- since variables written by Activate() on restore don't end up in the script scope.
		DoEntFireByInstanceHandle(thisEntity, "CallScriptFunction", "RestoreState", 0, thisEntity, thisEntity)
		
	else
		sunKeyvals.origin = thisEntity:GetOrigin()
		sunKeyvals.angles = thisEntity:GetAngles()	
		sun = SpawnEntityFromTableSynchronous("prop_dynamic", sunKeyvals)
		sun:SetParent(thisEntity, "sun")
		sun:SetLocalOrigin(Vector(0,0,0))
		
		thisEntity:SetThink(AddParticle, "particle", 0.1)
		
		envEnt = Entities:FindByClassname(nil, "light_environment")
		
		if envEnt then
		
			thisEntity:SetThink(UpdateSun, "sun", SUN_UPDATE_INTERVAL)
			
		end
	end

end

function RestoreState()

	thisEntity:GetOrCreatePrivateScriptScope() -- Script scopes do not seem to be properly created on restore

	local children = thisEntity:GetChildren()
	for idx, child in pairs(children)
	do
		if child:GetName() == sunKeyvals.targetname
		then
			sun = child
		end
	end

	if(not sun)
	then
		sunKeyvals.origin = thisEntity:GetOrigin()
		sunKeyvals.angles = thisEntity:GetAngles()	
		sun = SpawnEntityFromTableSynchronous("prop_dynamic", sunKeyvals)
		sun:SetParent(thisEntity, "sun")
		sun:SetLocalOrigin(Vector(0,0,0))
	end
	thisEntity:SetThink(AddParticle, "particle", 0.1)
	
	envEnt = Entities:FindByClassname(nil, "light_environment")
	
	if envEnt then
	
		thisEntity:SetThink(UpdateSun, "sun", SUN_UPDATE_INTERVAL)
		
	end

end


function AddParticle()
	sunParticle = ParticleManager:CreateParticle("particles/tools/sun_tool_glow.vpcf", 
			PATTACH_POINT_FOLLOW, thisEntity)
				
	ParticleManager:SetParticleControlEnt(sunParticle, 0, thisEntity,
			PATTACH_POINT_FOLLOW, "sun", Vector(0,0,0), true)
end


function UpdateSun()

	

	if triggerHeld then
		local rot = RotationDelta(startAngles, handAttachment:GetAngles())
		
		local angles = RotateOrientation(rot, startSunAngles)
		
		envEnt:SetAbsAngles(angles.x, angles.y, angles.z)
		sun:SetAbsAngles(angles.x, angles.y, angles.z)
	else	
		local angles = envEnt:GetAngles()
		sun:SetAbsAngles(angles.x, angles.y, angles.z)
	end

	return SUN_UPDATE_INTERVAL
end


function SetEquipped( this, pHand, nHandID, pHandAttachment, pPlayer )
	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	isCarried = true
	pickupTime = Time()

	
	ParticleManager:DestroyParticle(sunParticle, false)
	
	sunParticle = ParticleManager:CreateParticle("particles/tools/sun_tool_glow.vpcf", 
			PATTACH_POINT_FOLLOW, handAttachment)
	
	ParticleManager:SetParticleControlEnt(sunParticle, 0, handAttachment,
			PATTACH_POINT_FOLLOW, "sun", Vector(0,0,0), true)
	
	triggerHeld = false
	
	sun:SetParent(handAttachment, "sun")
	sun:SetLocalOrigin(Vector(0,0,0))
	--compass:SetAngles(0,0,0)

	return true
end



function SetUnequipped()
	
	playerEnt = nil
	handEnt = nil
	isCarried = false
	
	ParticleManager:DestroyParticle(sunParticle, false)
	
	sunParticle = ParticleManager:CreateParticle("particles/tools/sun_tool_glow.vpcf", 
			PATTACH_POINT_FOLLOW, thisEntity)
	
	ParticleManager:SetParticleControlEnt(sunParticle, 0, thisEntity,
			PATTACH_POINT_FOLLOW, "sun", Vector(0,0,0), true)
	
	sun:SetParent(thisEntity, "sun")
	sun:SetOrigin(thisEntity:GetOrigin())
	
	return true
end


function OnHandleInput(input)
	if not playerEnt
	then 
		return
	end

	local IN_TRIGGER = (handID == 0 and IN_USE_HAND0 or IN_USE_HAND1)
	local IN_GRIP = (handID == 0 and IN_GRIP_HAND0 or IN_GRIP_HAND1)

	
	if input.buttonsPressed:IsBitSet(IN_TRIGGER)
	then
		if Time() > pickupTime + PICKUP_TRIGGER_DELAY
		then
			triggerHeld = true
			startAngles = handAttachment:GetAngles()
			
			if envEnt then
				startSunAngles = envEnt:GetAngles()
			end
		end
		
		input.buttonsPressed:ClearBit(IN_TRIGGER)
	end		
	
	if input.buttonsReleased:IsBitSet(IN_TRIGGER) 
	then
		
		triggerHeld = false
		input.buttonsReleased:ClearBit(IN_TRIGGER)
	end

	
	if input.buttonsPressed:IsBitSet(IN_GRIP)
	then
		input.buttonsPressed:ClearBit(IN_GRIP)
		

	end
	
	if input.buttonsReleased:IsBitSet(IN_GRIP)
	then
		input.buttonsReleased:ClearBit(IN_GRIP)
		
		thisEntity:ForceDropTool()
	end

	return input
end