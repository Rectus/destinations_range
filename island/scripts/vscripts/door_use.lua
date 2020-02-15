
-- Constants

local FRAME_INTERVAL = FrameTime()
local UPDATE_INTERVAL = FRAME_INTERVAL * 5

local MAX_USE_DISTANCE = 16
local DISENGAGE_DISTANCE = 36

local DOOR_MAX_ANG_SPEED = 200
local DOOR_MIN_ANG_SPEED = 2
local DOOR_ANG_ACC = 70
local DOOR_ANG_ACC_FACTOR = 30
local DOOR_HAPTICS_DELTA = 0.3
local HAND_IDLE_START_ANG = 2
local HAND_ANG_RETURN_SPEED = 20

-- Entity attributes

local doorAngle = 0
local doorMaxAngle = 120
local doorMinAngle = -120

-- State

local initialSpawn = false
local zeroAngles = nil
local doorAngVel = 0
local handAngDelta = nil
local initHandAngDelta = nil

local usingPlayer = nil
local usingHand = nil
local useEntity = nil

local lerpStartTime = 0
local lerpStartAngle = 0
local lerpEndAngle = 0
local lastHapticsAngle = 0

local handIdleAng = 0
local handIdle = true

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
		initialSpawn = true
		SetAttributes()
	end

end


function SetAttributes()

	doorAngle = thisEntity:Attribute_GetFloatValue("doorAngle", thisEntity:GetAngles().y)	
	doorMinAngle = thisEntity:Attribute_GetFloatValue("doorMinAngle", doorMinAngle)
	doorMaxAngle = thisEntity:Attribute_GetFloatValue("doorMaxAngle", doorMaxAngle)

	if initialSpawn then
		initialSpawn = false
		
		zeroAngles = thisEntity:GetAngles()		
	else	
		zeroAngles = RotateOrientation(thisEntity:GetAngles(), QAngle(0, -doorAngle, 0))
	end
	
	local newAng = RotateOrientation(zeroAngles, QAngle(0, doorAngle, 0))
	thisEntity:SetAngles(newAng.x, newAng.y, newAng.z)
end

function StartUsingDoor(params)

	usingPlayer = params.activator
	useEntity = params.caller
	local hmd = usingPlayer:GetHMDAvatar()
	local prevHand = usingHand
	usingHand = nil
	
	if not hmd or not usingPlayer:AreAnyVRControllersConnected() then return end
	
	local conType = usingPlayer:GetVRControllerType()
	local distance = MAX_USE_DISTANCE
	
	for id = 0, 1 do
		local hand = hmd:GetVRHand(id) 
		local handDist = (useEntity:GetAbsOrigin() - hand:GetAbsOrigin()):Length()
		
		if IsHandUseActive(hand) and handDist < distance then
			usingHand = hand
			distance = handDist
		end
	end
	
	if usingHand then
	
		if prevHand and prevHand ~= usingHand then
			prevHand:RemoveAllHandModelOverrides() 
		end
	
		usingHand:FireHapticPulse(2)
		usingHand:AddHandModelOverride("models/development/invisiblebox.vmdl") 
		local handVec = (usingHand:GetAbsOrigin() - thisEntity:GetAbsOrigin()):Cross(thisEntity:GetUpVector()):Cross(-thisEntity:GetUpVector())
		local handAng = VectorToAngles(handVec)
		handAngDelta = RotationDelta(thisEntity:GetAngles(), handAng)
		initHandAngDelta = handAngDelta
		lastHapticsAngle = doorAngle
		lerpEndAngle = doorAngle
		handIdle = true
		handIdleAng = handAng

		thisEntity:SetThink(UseDoorUpdate, "update", UPDATE_INTERVAL)
	end
end


function UseDoorUpdate()

	if usingPlayer then
		local handDist = (useEntity:GetAbsOrigin() - usingHand:GetAbsOrigin()):Length()
		
		if not IsHandUseActive(usingHand) or handDist >= DISENGAGE_DISTANCE then
		
			RumbleController(1, 0.1, 100)
			usingPlayer = nil
			usingHand:RemoveAllHandModelOverrides() 
			usingHand = nil		
		end
		
	end
		
	local isMoving = UpdateDoorAngle(UPDATE_INTERVAL)
		
	if not isMoving and not usingPlayer then
	
		doorAngVel = 0
		thisEntity:Attribute_SetFloatValue("doorAngle", doorAngle)
		return nil
	end

	return UPDATE_INTERVAL
end


function UpdateDoorAngle(timeDelta)

	local prevAngle = lerpEndAngle
	local desiredAng = RotateOrientation(handAngDelta, thisEntity:GetAngles())
	local handAng
	local angDelta
	local angAcc
	
	if usingPlayer then
		local handVec = (usingHand:GetAbsOrigin() - thisEntity:GetAbsOrigin()):Cross(thisEntity:GetUpVector()):Cross(-thisEntity:GetUpVector())
		
		if g_VRScript.debugEnabled then
			DebugDrawLine(thisEntity:GetAbsOrigin(), thisEntity:GetAbsOrigin() + handVec, 255, 0, 0, true, timeDelta) 
			DebugDrawLine(thisEntity:GetAbsOrigin(), thisEntity:GetAbsOrigin() + desiredAng:Forward() * 32, 0, 255, 0, true, timeDelta)
		end
		
		local ang = VectorToAngles(handVec)
		
		if handIdle and abs(RotationDelta(ang, handIdleAng).y) < HAND_IDLE_START_ANG then
		
			handAng = handIdleAng
		else	
			-- Gradually return the hand grab position to the true grab position
			local diff = Clamp(AngleDiff(initHandAngDelta.y, handAngDelta.y), -HAND_ANG_RETURN_SPEED * timeDelta, HAND_ANG_RETURN_SPEED * timeDelta)
			handAngDelta = RotateOrientation(handAngDelta, QAngle(0, diff, 0))
		
			handIdle = false
			handAng = ang
		end
	end

	
	if usingPlayer and not handIdle then
	
		angDelta = RotationDelta(desiredAng, handAng).y
		angAcc = Clamp(angDelta * DOOR_ANG_ACC_FACTOR, -DOOR_ANG_ACC, DOOR_ANG_ACC)
	else	
		handAng = desiredAng
		angDelta = 0
		angAcc = Clamp(-doorAngVel, -DOOR_ANG_ACC, DOOR_ANG_ACC)
	end
	
	local prevAngVel = doorAngVel
	doorAngVel = Clamp(doorAngVel + angAcc * timeDelta, -DOOR_MAX_ANG_SPEED, DOOR_MAX_ANG_SPEED)
	local velSignChange = prevAngVel * doorAngVel < 0

	local moveDelta = doorAngVel * timeDelta	
	local hitEnd = CheckEndTravel(prevAngle + moveDelta)
	local isMoving = true
	
	lerpStartAngle = prevAngle
	lerpEndAngle = Clamp(prevAngle + moveDelta, doorMinAngle, doorMaxAngle)	
				
	if hitEnd or velSignChange then
	
		-- Consider the hand idle until moved enough when the door stops to prevent oscillations
		handIdleAng = handAng
		handIdle = true	

		-- Reset the hand offset to make it feel as if the player is still holding the handle
		handAngDelta = RotationDelta(thisEntity:GetAngles(), handAng)
	
		if hitEnd then
			doorAngVel = 0
		end
	end
	
	if (abs(doorAngVel) < DOOR_MIN_ANG_SPEED) then
	
		isMoving = false
	end
		
	if isMoving then
	
		lerpStartTime = Time()			
		thisEntity:SetThink(DoorAngleFrame, "frame", FRAME_INTERVAL)
		DoorAngleFrame()
	
	else
		-- Do single frame at the end
		lerpStartTime = Time() - UPDATE_INTERVAL
		thisEntity:StopThink("frame")
		DoorAngleFrame()
	end
	
	return isMoving
end


function DoorAngleFrame()
	local currTime = Time()
	local ang = Lerp((currTime - lerpStartTime) / UPDATE_INTERVAL, lerpStartAngle, lerpEndAngle)
	doorAngle = Clamp(ang, doorMinAngle, doorMaxAngle)

	local newAng = RotateOrientation(zeroAngles, QAngle(0, doorAngle, 0))
	thisEntity:SetAngles(newAng.x, newAng.y, newAng.z)
	
	if usingHand and abs(doorAngle - lastHapticsAngle) > DOOR_HAPTICS_DELTA then
		
		usingHand:FireHapticPulse(0)
		lastHapticsAngle = doorAngle
	end
	
	local lerping = currTime - lerpStartTime < UPDATE_INTERVAL
	return lerping and FRAME_INTERVAL or nil
end


function IsHandUseActive(hand)

	if not IsValidEntity(usingPlayer) or not IsValidEntity(hand) then return false end

	return usingPlayer:IsActionActiveForHand(hand:GetLiteralHandType(), DEFAULT_USE) or
		usingPlayer:IsActionActiveForHand(hand:GetLiteralHandType(), DEFAULT_USE_GRIP)
end


function CheckEndTravel(newAng)
	local speed = abs(doorAngVel)
	
	if newAng >= doorMaxAngle or newAng <= doorMinAngle then
		
		if speed > 30 then
			StartSoundEvent("Door_Slam", thisEntity)  
			
			if usingHand then
				RumbleController(2, 0.2, speed / 2)
			end
		end
		
		return true
	end
	
	return false
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

