MAX_DISTANCE = 64
DOT_PROJECT_SPOT = Vector(1024, 0, 0)
LENS_POS = Vector(0, 0, 1.5)
DOT_MOVE_FACTOR = 2.0
DOT_UPDATE_INTERVAL = 0.05

function Think(self)
	local player = Entities:FindByClassname(nil, "player")
	local closestPlayer = nil
	local distance = 0
	
	while player
	do
		local playerDist = (thisEntity:GetCenter() - player:GetCenter()):Length()
		
		if playerDist <= MAX_DISTANCE
		then
			if not closestPlayer
			then
				closestPlayer = player
				distance = playerDist
				
			elseif distance < playerDist
			then
				closestPlayer = player
				distance = playerDist
				
			end
			
		end
		player = Entities:FindByClassname(player, "player")
	end
	
	if closestPlayer
	then
		
		-- Choose the closest eye.
		local localEyePos = Vector(0, 1.3, 0)
		if NormalizeAngle(closestPlayer:GetHMDAvatar():GetAngles().y - thisEntity:GetAngles().y) > 0
		then
			localEyePos = Vector(0, -1.3, 0)
		end
	
		local lensPos = thisEntity:GetOrigin() + RotatePosition(Vector(0,0,0), thisEntity:GetAngles(), LENS_POS)
		local sightDist = DOT_PROJECT_SPOT:Length()
		local eyePos = closestPlayer:GetHMDAvatar():GetOrigin() + RotatePosition(Vector(0,0,0), closestPlayer:GetHMDAvatar():GetAngles(), localEyePos)
		local sightAng = RotateOrientation(thisEntity:GetAngles(), QAngle(0, 180, 0))
		
		local projPos = lensPos + RotatePosition(Vector(0,0,0), thisEntity:GetAngles(), DOT_PROJECT_SPOT)
		local projAng = VectorToAngles((eyePos - projPos))
		local anglePitch = NormalizeAngle((sightAng.x - projAng.x))
		local angleYaw = NormalizeAngle((sightAng.y - projAng.y))
		
		local dotY = math.tan(math.rad(anglePitch)) * sightDist
		local dotX = math.tan(math.rad(angleYaw))* sightDist

		local sightTilt = math.rad(thisEntity:GetAngles().z)
		local dotLocalPos = Vector(dotX * math.cos(sightTilt) + dotY * math.sin(sightTilt), dotY * math.cos(sightTilt) + dotX * -math.sin(sightTilt), 0)

		if g_VRScript.playerPhysController and g_VRScript.playerPhysController:IsDebugDrawEnabled()
		then
			local dotPos = lensPos + RotatePosition(Vector(0,0,0), thisEntity:GetAngles(), Vector(0, dotLocalPos.x, dotLocalPos.y))
			DebugDrawLine(lensPos, dotPos, 0, 255, 0, false, DOT_UPDATE_INTERVAL)
		end
		
		local circleFactor = dotX * dotX + dotY * dotY 
		
		if circleFactor > 1.41
		then
			dotLocalPos = Vector(-0.4, -1, 0)
		end
		
		if g_VRScript.playerPhysController and g_VRScript.playerPhysController:IsDebugDrawEnabled()
		then
			DebugDrawLine(eyePos, projPos, 255, 0, 0, false, DOT_UPDATE_INTERVAL)
			DebugDrawLine(eyePos, lensPos, 255, 0, 0, false, DOT_UPDATE_INTERVAL)
			DebugDrawLine(lensPos, projPos, 255, 0, 0, false, DOT_UPDATE_INTERVAL)
			
			dotPos = lensPos + RotatePosition(Vector(0,0,0), thisEntity:GetAngles(), Vector(0, dotLocalPos.x, dotLocalPos.y))
			DebugDrawLine(lensPos, dotPos, 0, 0, 255, false, DOT_UPDATE_INTERVAL)
		end
		
		thisEntity:SetPoseParameter("dot_x", -dotLocalPos.x * DOT_MOVE_FACTOR)
		thisEntity:SetPoseParameter("dot_y", dotLocalPos.y * DOT_MOVE_FACTOR)
	end
	
	return DOT_UPDATE_INTERVAL
end

thisEntity:SetThink(Think, "think_main", DOT_UPDATE_INTERVAL)

function NormalizeAngle(angle)
	if angle > 180
	then 
		return angle - 360
	elseif angle < -180
	then
		return angle + 360
	end
	
	return angle
end
