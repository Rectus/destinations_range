
local WATER_IMPULSE_INTERVAL = 2
local waterImpulseCounter = 0
local WATER_MAX_IMPULSE = 20
local WATER_MAX_IMPULSE_LEVEL = 20.0
local WATER_LEVEL = 0.0
local VOLUME_FACTOR = 400
local MAX_VOLUME_IMPULSE = 3
local ENTITY_SIZE_FACTOR = 0.2
local DRAG_FACTOR = 10.1
local COUNTER_IMPULSE_FACTOR = 0.05
local ROTATION_DAMPING_FACTOR = 0.05
local SPLASH_MIN_SPEED = 80
local RIPPLE_MIN_SPEED = 20
local SPLASH_INTERVAL = 0.5

local splashEnts = {}

local propTypes = 
{
	"prop_destinations_physics",
	"prop_physics_override",
	"prop_physics",
	"prop_destinations_tool"
}

function OnInit()
	

end

function OnGameplayStart()

	g_VRScript.ScriptSystem_AddPerFrameUpdateFunction(OnThink)
end

function OnPrecache(context)
	PrecacheParticle("particles/splash.vpcf", context)
	PrecacheParticle("particles/splash_ripple.vpcf", context)
	PrecacheSoundFile("soundevents_addon.vsndevts", context)
end

function OnHMDAvatarAndHandsSpawned()

end

function OnThink()
	
	waterImpulseCounter = waterImpulseCounter + 1
	if waterImpulseCounter < WATER_IMPULSE_INTERVAL
	then
		return
	end
	
	waterImpulseCounter = 0
	
	for _, propType in pairs(propTypes)
	do
		local entity = Entities:FindByClassname(nil, propType)
		while entity
		do
			if not entity:IsNull()
			then
				local scale = entity:GetModelScale()
			
				local level = entity:GetCenter().z - GetMinDimension(entity) * ENTITY_SIZE_FACTOR * scale
				if level < WATER_LEVEL
				then
					--print("under water level")
					local boundMin = entity:GetBoundingMins()
					local boundMax = entity:GetBoundingMaxs()
					local velocity = GetPhysVelocity(entity)
					local speed = velocity:Length()
					
					if speed > RIPPLE_MIN_SPEED
					then
						if splashEnts[entity] == nil or (splashEnts[entity] + SPLASH_INTERVAL) < Time()
						then			
							splashEnts[entity] = Time()
							local splash
							local pos = Vector(entity:GetCenter().x, entity:GetCenter().y, 0)
							
							if speed > SPLASH_MIN_SPEED
							then
								StartSoundEventFromPosition("Beach.Splash", pos)
								splash = ParticleManager:CreateParticle("particles/splash.vpcf", PATTACH_CUSTOMORIGIN, nil)
							else
								splash = ParticleManager:CreateParticle("particles/splash_ripple.vpcf", PATTACH_CUSTOMORIGIN, nil)
							end
							
							ParticleManager:SetParticleControl(splash, 0, pos)						
						end
					end

					--Really crude approximation of volume.
					local volume = abs((boundMax.x - boundMin.x) * (boundMax.y - boundMin.y) * (boundMax.z - boundMin.z)) * scale * scale * scale 
					
					local impulse = (abs(level + WATER_LEVEL) / WATER_MAX_IMPULSE_LEVEL) * WATER_MAX_IMPULSE * min( volume / VOLUME_FACTOR, MAX_VOLUME_IMPULSE)
					entity:ApplyAbsVelocityImpulse(Vector(0, 0, impulse))
					
					local fractionUnderwater = Clamp(abs(2 * (entity:GetCenter().z + WATER_LEVEL)) / (boundMax.z - boundMin.z), 0, 1)
					
					-- Apply underwater drag
					local drag = volume * fractionUnderwater / entity:GetMass()
					local dragFactor = (drag / (drag + DRAG_FACTOR))
					entity:ApplyAbsVelocityImpulse(velocity * -COUNTER_IMPULSE_FACTOR * dragFactor)
					
					-- Apply underwater rotational damping
					SetPhysAngularVelocity(entity, (1 - dragFactor * ROTATION_DAMPING_FACTOR) * GetPhysAngularVelocity(entity))
				end
			end
		
			entity = Entities:FindByClassname(entity, propType)
		end
	end
end

function Clamp(val, min, max)
	if val > max then return max end
	if val < min then return min end
	return val	
end

function GetMinDimension(entity)
	local boundMin = entity:GetBoundingMins()
	local boundMax = entity:GetBoundingMaxs()
	
	return min(abs(boundMax.x - boundMin.x), abs(boundMax.y - boundMin.y), abs(boundMax.z - boundMin.z))
end

function PrintTable(table)
	for key, value in pairs(table)
	do
		
		if(type(value) == "table")
		
		then
			print(type(value) .. ": " .. key)
			for key2, value2 in pairs(value)
			do
				print("  " .. type(value2) .. ": " .. key2)
			end
		end
	end
end