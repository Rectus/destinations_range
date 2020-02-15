
DoIncludeScript("game/globalsystems/timeofday_skymodel", getfenv(1))

local UPDATE_INTERVAL = 0.011
local SECONDS_PER_DAY = 86400
local NIGHT_ANG = 87

local dayNightCycle = {
	Date = 166,
	DayLength = SECONDS_PER_DAY,
	NorthAngle = Deg2Rad(160),
	Latitude = Deg2Rad(59.3),
	Longitude = Deg2Rad(18.1),
	Meridian = Deg2Rad(18.1),
}

local lightTable = 
{
	{ang = 0, color = Vector(253, 230, 205), val = 5.5, sky = 1},
	{ang = 70, color = Vector(252, 229, 204), val = 5, sky = 1},
	{ang = 83, color = Vector(250, 210, 190), val = 4.5, sky = 1},
	{ang = 87, color = Vector(240, 150, 120), val = 3, sky = 0.8},
	{ang = 90.5, color = Vector(200, 70, 60), val = 0, sky = 0.4},
	{ang = 93, color = Vector(127, 0, 0), val = 0, sky = 0.2},
	{ang = 180, color = Vector(0, 0, 0), val = 0, sky = 0.05},
}

local prevAngles = nil
local playerParticles = {}
local isNight = false
local initialSpawn = false
local initGameTime = 0
local initDayTime = 0




function Precache(context)

	PrecacheParticle("particles/sun_projected.vpcf", context)
end

function Activate(activateType)
	
	if activateType == ACTIVATE_TYPE_ONRESTORE then
		EntFireByHandle(thisEntity, thisEntity, "CallScriptFunction", "SetAttributes")
		
	else
		initialSpawn = true
		SetAttributes()
	end
	
	EntFireByHandle(thisEntity, thisEntity, "RunScriptCode", "UpdateLight(true)", 0.5) 
	
	prevAngles = thisEntity:GetAngles()
	thisEntity:SetThink(Update, "update", 0.6)
end


function SetAttributes()
	
	local realTimeScale = thisEntity:Attribute_GetFloatValue("realTimeScale", 0)
	local useLocalTime = thisEntity:Attribute_GetIntValue("useLocalTime", 0)
	if realTimeScale > 0  then
		dayNightCycle.DayLength = SECONDS_PER_DAY / realTimeScale
	end
	
	if useLocalTime ~= 0 then
		
		initGameTime = Time()
		local time = LocalTime()
		initDayTime = time.Hours + time.Minutes / 60 + time.Seconds  / 3600
		
	elseif initialSpawn then
		
		initGameTime = Time()
		initDayTime = 8.75
	elseif realTimeScale > 0 then
	
		local sundir = -thisEntity:GetForwardVector()
		local sunYaw = Rad2Deg(math.atan2(-sunDir.y, -sunDir.x))
		initGameTime = Time()
		initDayTime = AngleDiff(dayNightCycle.NorthAngle, sunYaw) * 24 / 360
		
	end
	
	initialSpawn = false
	
	CalcSunAngles()
end


function CalcSunAngles()
	
	local clockTime = SkyModel_CalculateClockTime(initDayTime, Time() - initGameTime, dayNightCycle) 
	local sunDir = SkyModel_SunLightDirectionForDayNightCycle(dayNightCycle, clockTime)
	thisEntity:SetForwardVector(-sunDir)	
end


function SetTimeScale(scale)
	thisEntity:Attribute_SetFloatValue("realTimeScale", scale)
	
	if scale > 0 then
	
		dayNightCycle.DayLength = SECONDS_PER_DAY / scale
		CalcSunAngles()
		prevAngles = thisEntity:GetAngles()	
	else
		dayNightCycle.DayLength = 999999999999
	end
end


function SetDayTime(timeHours)
	thisEntity:Attribute_SetIntValue("useLocalTime", 0)
	initGameTime = Time()
	initDayTime = timeHours
	SetTimeScale(1)
end


function SetDayTimeToLocal()

	thisEntity:Attribute_SetIntValue("useLocalTime", 1)
	initGameTime = Time()
	local time = LocalTime()
	initDayTime = time.Hours + time.Minutes / 60 + time.Seconds  / 3600
	SetTimeScale(1)
end


function Update()

	local realTimeScale = thisEntity:Attribute_GetFloatValue("realTimeScale", 0)	
	local color = nil
	
	local anglesModified = abs(RotationDelta(thisEntity:GetAngles(), prevAngles).y) > 0.1

	if realTimeScale > 0  then
		
		if not anglesModified then
			CalcSunAngles()
		else
			-- Disable realtime if the sun angles get modified extenally
			thisEntity:Attribute_SetFloatValue("realTimeScale", 0)
		end
		
		color = UpdateLight(false)
		
	elseif anglesModified then
	
		color = UpdateLight(false)
	end
	
	prevAngles = thisEntity:GetAngles()	
	
	for player, particle in pairs(playerParticles)
	do
		if not IsValidEntity(player)
		then
			playerParticles[player] = nil
			ParticleManager:DestroyParticle(particle, true) 
			ParticleManager:ReleaseParticleIndex(particle)
			
		elseif color then
			ParticleManager:SetParticleControl(particle, 3, color)
		end
	end

	local players = Entities:FindAllByClassname("player") 
	
	for _, player in pairs(players)
	do
		if not playerParticles[player]
		then
			local id = ParticleManager:CreateParticleForPlayer("particles/sun_projected.vpcf", 
				PATTACH_ABSORIGIN_FOLLOW, thisEntity, player) 
		
			ParticleManager:SetParticleControlEnt(id, 0, thisEntity, PATTACH_ABSORIGIN_FOLLOW, "", Vector(0,0,0), false) 

			if color then
				ParticleManager:SetParticleControl(id, 3, color)	
			else
				ParticleManager:SetParticleControl(id, 3, Vector(252, 229, 204))		
			end
			
			playerParticles[player] = id
		end
	
	end

	return UPDATE_INTERVAL
end


function UpdateLight(forced)

	local sunAngle = Rad2Deg(math.acos(thisEntity:GetForwardVector():Dot(Vector(0,0,-1))))
	
	if (not isNight or forced) and sunAngle > NIGHT_ANG then
	
		isNight = true
		
		EntFire(thisEntity, "daytime_branch", "SetValueTest", "0", 0)
		EntFire(thisEntity, "nighttime_branch", "SetValueTest", "1", 0)
		SendToServerConsole("world_layer_set_visible base_island world_layer_daytime_layer false")
		SendToServerConsole("world_layer_set_visible base_island world_layer_nighttime_layer true")

	elseif (isNight or forced) and sunAngle < NIGHT_ANG then
	
		isNight = false
		
		EntFire(thisEntity, "daytime_branch", "SetValueTest", "1", 0)
		EntFire(thisEntity, "nighttime_branch", "SetValueTest", "0", 0)
		SendToServerConsole("world_layer_set_visible base_island world_layer_daytime_layer true")
		SendToServerConsole("world_layer_set_visible base_island world_layer_nighttime_layer false")

	end
	
	local prevData = nil

	for _, data in pairs(lightTable)
	do
		if prevData then
			
			if sunAngle <= data.ang then
			
				local factor = RemapVal(sunAngle, prevData.ang, data.ang, 0, 1)
			
				local colorVec = LerpVectors(prevData.color, data.color, factor)
				local colorStr = "" .. colorVec.x .. " " .. colorVec.y .. " " .. colorVec.z
				
				local brightness = Lerp(factor, prevData.val, data.val)
				
				EntFireByHandle(thisEntity, thisEntity, "setlightcolor", colorStr, 0) 
				EntFireByHandle(thisEntity, thisEntity, "setlightbrightness", "" .. brightness, 0) 
				
				local probe = RemapVal(brightness, 0, 7, 0.2, 1)
				--DoEntFire("probe_day", "setcolor", colorStr, 0, nil, nil) 
				EntFire(thisEntity, "probe_day", "setbrightness", tostring(probe)) 
			
				local skyBrightness = Lerp(factor, prevData.sky, data.sky)
				
				EntFire(thisEntity, "sky_fog", "setmaxdensity", tostring(1 - skyBrightness)) 
			
				return colorVec
			end
		end
		prevData = data
	end

	return nil
end



