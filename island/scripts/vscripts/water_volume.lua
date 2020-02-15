
local WATER_MAX_IMPULSE = 20
local VOLUME_FACTOR = 1.64e-5 --cubic meters in cubic inch
local WATER_DENSITY = 1000 --kg / cubic meters
local GRAVITY_ACC = 9.82
local BUOYANCY_FACTOR = 0.25
local BUOYANCY_SMALL_VOLUME_FACTOR = 2.0
local DRAG_FACTOR = 0.0001
local ROTATION_DAMPING_FACTOR = 0.02
local SPLASH_MIN_SPEED = 20
local RIPPLE_MIN_SPEED = 20
local SPLASH_INTERVAL = 0.5
local THINK_INTERVAL = FrameTime()
local waterLevel = 0

local touchEnts = {}

local propTypes = 
{
	prop_destinations_physics = true, 
	prop_physics_override = true,
	prop_physics = true,
	prop_destinations_tool = true
}


function Activate()

	waterLevel = thisEntity:GetAbsOrigin().z + thisEntity:GetBoundingMaxs().z
	
	thisEntity:SetThink(WaterThink, "water", THINK_INTERVAL)
end


function Precache(context)

	PrecacheParticle("particles/splash.vpcf", context)
	PrecacheParticle("particles/splash_ripple.vpcf", context)
	PrecacheSoundFile("soundevents_addon.vsndevts", context)
end


function OnStartTouch(params)

	if params.activator then
		local entity = params.activator
		CheckSplash(entity)
		
		if propTypes[entity:GetClassname()] then
			touchEnts[entity] = Time()
		end
	end
end

function OnEndTouch(params)
	
	if params.activator then
		touchEnts[params.activator] = nil
	end
end


function WaterThink()
	
	for entity, splashTime in pairs(touchEnts)
	do
		if not entity:IsNull() and entity:GetMoveParent() == nil
		then
			local scale = entity:GetAbsScale()					
			local boundMin = entity:GetBoundingMins() * scale
			local boundMax = entity:GetBoundingMaxs() * scale		
			local velocity = GetPhysVelocity(entity)
			local speed = velocity:Length()
			
			local halfHeight = (CalcClosestPointOnEntityOBB(entity, entity:GetCenter() + Vector(0, 0, boundMax.z - boundMin.z)).z - entity:GetCenter().z) * scale
			
			-- Against bugged props that return an OBB pos on the center
			if halfHeight < (boundMax.z - boundMin.z) / 8 then

				halfHeight = (boundMax.z - boundMin.z) / 2
			end
			
			if (splashTime + SPLASH_INTERVAL) < Time()
			then
				CheckSplash(entity)
				touchEnts[entity] = Time()
			end
			if g_VRScript.debugEnabled then
			
				DebugDrawBoxDirection(entity:GetAbsOrigin(), boundMin, boundMax, entity:GetAngles():Forward() , Vector(0, 255, 0), 0, THINK_INTERVAL)
				DebugDrawLine(entity:GetCenter(), entity:GetCenter() + velocity, 255, 0, 0, true, THINK_INTERVAL)
				DebugDrawLine(entity:GetCenter(), entity:GetCenter() + Vector(0, 0, halfHeight), 0, 0, 255, true, THINK_INTERVAL)
			
			end

			--Really crude approximation of volume.
			local volume = abs((boundMax.x - boundMin.x) * (boundMax.y - boundMin.y) * (boundMax.z - boundMin.z)) 
				 * VOLUME_FACTOR
			
			local area = GetAverageArea(boundMin, boundMax) 
			local fractionUnderwater = Clamp((waterLevel - (entity:GetCenter().z - halfHeight)) 
				/ (halfHeight * 2), 0, 1)

			local volFac = volume > 1 and 1 or RemapVal(volume, 0.1, 1, 0.1 * BUOYANCY_SMALL_VOLUME_FACTOR, 1)
			
			local buoyImpulse = WATER_DENSITY * fractionUnderwater * volFac * GRAVITY_ACC * BUOYANCY_FACTOR * THINK_INTERVAL
			
			
				
			local dragImpulse = velocity * -1 * Clamp(speed * area * DRAG_FACTOR 
				* fractionUnderwater * THINK_INTERVAL, 0, 0.8)
			
			entity:ApplyAbsVelocityImpulse(dragImpulse + Vector(0, 0, buoyImpulse))
			
			local angVel = GetPhysAngularVelocity(entity)
			
			-- Apply underwater rotational damping
			SetPhysAngularVelocity(entity, angVel * Clamp(1 - ROTATION_DAMPING_FACTOR * area * fractionUnderwater 
				* THINK_INTERVAL ,0 ,1))
		end		
	end
	
	return THINK_INTERVAL
end


function CheckSplash(entity)

	local velocity = GetPhysVelocity(entity)
	local speed = velocity:Length()
	
	if speed > RIPPLE_MIN_SPEED
	then	
		local splash
		local pos = Vector(entity:GetCenter().x, entity:GetCenter().y, waterLevel)
		
		if speed > SPLASH_MIN_SPEED
		then
			splash = ParticleManager:CreateParticle("particles/environment/splash.vpcf", PATTACH_ABSORIGIN, entity)
			--ParticleManager:SetParticleControl(splash, 0, pos)
			--ParticleManager:SetParticleControlEnt(splash, 0, entity, PATTACH_ABSORIGIN, nil, pos, false) 
			ParticleManager:SetParticleControl(splash, 1, Vector(0, 0, waterLevel))
			ParticleManager:SetParticleControl(splash, 3, velocity)	
		else
			--splash = ParticleManager:CreateParticle("particles/environment/splash_ripple.vpcf", PATTACH_CUSTOMORIGIN, entity)
		end
		
				
	end
end

function GetAverageArea(min, max)
	
	local side = abs((max.x - min.x) + (max.y - min.y) + (max.z - min.z) / 3)
	
	return side * side

end

