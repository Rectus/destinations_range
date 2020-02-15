


-- Constants

local FRAME_INTERVAL = FrameTime()
local UPDATE_INTERVAL = FRAME_INTERVAL * 4

local MAX_USE_DISTANCE = 16
local DISENGAGE_DISTANCE = 20

local CRANK_MAX_ANG_SPEED = 500
local CRANK_MIN_ANG_SPEED = 2
local CRANK_ANG_ACC = 500
local CRANK_ANG_ACC_FACTOR = 100
local CRANK_HAPTICS_DELTA = 0.01
local CRANK_STOP_HAPTICS_DELTA = 120

local CRANK_RAISE_FACTOR = 0.1 / 360

-- Entity attributes

raisePos = 0.99

-- State

local lowered = false
local angVel = 0
local handAngDelta = nil
local initHandAngDelta = nil
local crankSvivel = 0
local crankPos = 0

local usingPlayer = nil
local usingHand = nil
local useEntity = nil

local lerpStartTime = 0
local lerpStartAngle = 0
local lerpEndAngle = 0
local lastHapticsPos = 0
local lastStopHapticsPos = 0
local lerpRaiseStart = 0
local lerpRaiseEnd = 0


local rumbleDuration = 0
local rumbleInterval = 0
local rumbleIntensity = 0
local rumbleHand = nil



function Precache(context)
	PrecacheModel("models/development/invisiblebox.vmdl", context)
end


function Activate(activateType)

	if activateType == ACTIVATE_TYPE_ONRESTORE then
		EntFireByHandle(thisEntity, thisEntity, "CallScriptFunction", "SetAttributes")
		
	else
		SetAttributes()
	end
end


function SetAttributes()

	raisePos = thisEntity:Attribute_GetFloatValue("raisePos", 0.99)

	EntFireByHandle(thisEntity, thisEntity, "RunScriptCode", "thisEntity:SetPoseParameter('flag', raisePos)", 1)
	crankSvivel = thisEntity:ScriptLookupAttachment("crank_svivel") 
	
	if raisePos > 0.15 then
		lowered = false
		EntFire(thisEntity, "flag_pole_panel", "RemoveCSSClass", "Activated")
	else
		lowered = true
	end
end

function StartUsingCrank(params)

	usingPlayer = params.activator
	useEntity = params.caller
	local hmd = usingPlayer:GetHMDAvatar()
	local prevHand = usingHand
	usingHand = nil
	
	if not hmd or not usingPlayer:AreAnyVRControllersConnected() then return end
	
	local crankOrigin = thisEntity:GetAttachmentOrigin(crankSvivel)
	
	local distance = MAX_USE_DISTANCE	
	
	for id = 0, 1 do
		local hand = hmd:GetVRHand(id) 
		if hand then
			local handDist = (crankOrigin - hand:GetAbsOrigin()):Length()
			
			if IsHandUseActive(hand) and handDist < distance then
				usingHand = hand
				distance = handDist
			end
		end
	end
	
	if usingHand then
	
		if prevHand and prevHand ~= usingHand then
			prevHand:RemoveAllHandModelOverrides() 
		end
	
		usingHand:FireHapticPulse(2)
		RumbleController(1, 0.05, 200)
		usingHand:AddHandModelOverride("models/development/invisiblebox.vmdl") 

		lastHapticsPos = crankPos
		lerpEndAngle = crankPos
		lerpRaiseStart = raisePos
		lerpRaiseEnd = raisePos

		thisEntity:SetThink(UseCrankUpdate, "update", UPDATE_INTERVAL)
	end
end


function UseCrankUpdate()

	if usingPlayer then
		local handDist = (useEntity:GetAbsOrigin() - usingHand:GetAbsOrigin()):Length()
		
		if not IsHandUseActive(usingHand) or handDist >= DISENGAGE_DISTANCE then
		
			RumbleController(1, 0.03, 150)
			usingPlayer = nil
			usingHand:RemoveAllHandModelOverrides() 
			usingHand = nil		
		end
		
	end
		
	local isMoving = UpdateCrank(UPDATE_INTERVAL)
		
	if not isMoving and not usingPlayer then
	
		angVel = 0
		thisEntity:Attribute_SetFloatValue("raisePos", raisePos)
		return nil
	end

	return UPDATE_INTERVAL
end


function UpdateCrank(timeDelta)

	local prevAngle = lerpEndAngle
	
	local angAcc
	local crankOrigin = thisEntity:GetAttachmentOrigin(crankSvivel)
	local crankAngleVec = thisEntity:GetAttachmentAngles(crankSvivel)
	local crankAngles = QAngle(crankAngleVec.x, crankAngleVec.y, crankAngleVec.z)
	--local desiredAng = RotateOrientation(handAngDelta, crankAngles)
	
	if usingPlayer then
		local handVec = (usingHand:GetAbsOrigin() - crankOrigin):Cross(crankAngles:Up()):Cross(-crankAngles:Up())
		
		if g_VRScript.debugEnabled then
			DebugDrawLine(crankOrigin, crankOrigin + handVec, 255, 0, 0, true, timeDelta) 
			DebugDrawLine(crankOrigin, crankOrigin + desiredAng:Forward() * 32, 0, 255, 0, true, timeDelta)
			DebugDrawLine(crankOrigin, crankOrigin + desiredAng:Up() * 32, 0, 255, 255, true, timeDelta)
		end
		
		local handAng = VectorToAngles(handVec)
	
		local angDelta = RotationDeltaAsAngularVelocity(crankAngles, handAng):Dot(crankAngles:Up())
		angAcc = Clamp(angDelta * CRANK_ANG_ACC_FACTOR, -CRANK_ANG_ACC, CRANK_ANG_ACC)
	else	
		angAcc = Clamp(-angVel, -CRANK_ANG_ACC, CRANK_ANG_ACC)
	end
	
	local prevAngVel = angVel
	angVel = Clamp(angVel + angAcc * timeDelta, -CRANK_MAX_ANG_SPEED, CRANK_MAX_ANG_SPEED)

	local moveDelta = angVel * timeDelta	
	local isMoving = true
	
	lerpStartAngle = prevAngle
	lerpEndAngle = prevAngle + moveDelta
	lerpRaiseStart = lerpRaiseEnd
	lerpRaiseEnd = Clamp(lerpRaiseEnd + moveDelta * CRANK_RAISE_FACTOR, 0, 1)
	
	if lerpRaiseEnd < 0.1 and not lowered then
		lowered = true
		EntFire(thisEntity, "flag_pole_panel", "AddCSSClass", "Activated")
		
	elseif lerpRaiseEnd > 0.15 and lowered then
		lowered = false
		EntFire(thisEntity, "flag_pole_panel", "RemoveCSSClass", "Activated")
	end
	
	
	if (abs(angVel) < CRANK_MIN_ANG_SPEED) then
	
		isMoving = false
	end
		
	if isMoving then
	
		lerpStartTime = Time()			
		thisEntity:SetThink(CrankFrame, "frame", FRAME_INTERVAL)
		CrankFrame()
	
	else
		-- Do single frame at the end
		lerpStartTime = Time() - UPDATE_INTERVAL
		thisEntity:StopThink("frame")
		CrankFrame()
	end
	
	return isMoving
end


function CrankFrame()
	local currTime = Time()
	local timeFrac = (currTime - lerpStartTime) / UPDATE_INTERVAL
	crankPos = Lerp(timeFrac, lerpStartAngle, lerpEndAngle)
	raisePos = Lerp(timeFrac, lerpRaiseStart, lerpRaiseEnd)
	
	local pose = 360 - Clamp((crankPos + 360) % 360, 0, 359.9)
	thisEntity:SetPoseParameter("crank", pose)
	thisEntity:SetPoseParameter("flag", raisePos)
	
	if usingHand and abs(raisePos - lastHapticsPos) > CRANK_HAPTICS_DELTA then
		
		usingHand:FireHapticPulse(1)
		lastHapticsPos = raisePos
		
	elseif usingHand and (raisePos > 0.99 or raisePos < 0.01) 
		and abs(crankPos - lastStopHapticsPos) > CRANK_STOP_HAPTICS_DELTA then
		
		RumbleController(2, 0.05, 50)
		lastStopHapticsPos  = crankPos
	end
	
	local lerping = currTime - lerpStartTime < UPDATE_INTERVAL
	return lerping and FRAME_INTERVAL or nil
end


function IsHandUseActive(hand)

	if not IsValidEntity(usingPlayer) or not IsValidEntity(hand) then return false end

	return usingPlayer:IsActionActiveForHand(hand:GetLiteralHandType(), DEFAULT_USE) or
		usingPlayer:IsActionActiveForHand(hand:GetLiteralHandType(), DEFAULT_USE_GRIP)
end


function RumbleController(intensity, duration, frequency)
	if usingHand and IsValidEntity(usingHand)
	then
		rumbleDuration = duration
		rumbleInterval = 1 / frequency
		rumbleIntensity = intensity
		rumbleHand = usingHand
		
		rumbleHand:FireHapticPulse(rumbleIntensity)
		thisEntity:SetThink(RumblePulse, "rumble", rumbleInterval)
	end
end


function RumblePulse()
	if rumbleHand and IsValidEntity(rumbleHand)
	then	
		rumbleHand:FireHapticPulse(rumbleIntensity)	
		rumbleDuration = rumbleDuration - rumbleInterval
		if rumbleDuration >= rumbleInterval
		then
			return rumbleInterval
		end
	end
	
	return nil
end

