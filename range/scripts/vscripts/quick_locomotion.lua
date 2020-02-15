

CQuickLocomotion = class(
	{
		player = nil;
		mode = 0;
		grabOrigin = nil;
		activeGrabHandID = -1;
	}, 
	
	{
		MODE_NONE = 0;
		MODE_SMOOTH = 1;
		MODE_GRAB = 2;
		
		SMOOTH_MOVESPEED  = 200;
		SMOOTH_AIR_CONTROL_FACTOR = 0.1;
		GRAB_MOVE_FRAME_FACTOR = 0.1;
	},
	nil
)


function CQuickLocomotion.constructor(self, player, mode)
	self.player = player
	self.mode = mode
	
	if mode ~= self.MODE_NONE
	then
		for handID = 0, 1
		do
			self.player:AllowTeleportFromHand(handID, false) 
		end
	end 
end


function CQuickLocomotion:Think(isLocomotionAllowed, isPaused)

	self.mode = math.floor(g_VRScript.playerSettings:GetPlayerSetting(self.player, "locomotion_mode") or 0)

	if self.mode == self.MODE_NONE
	then
		return
	elseif self.mode == self.MODE_SMOOTH
	then
		self:MoveSmooth(isLocomotionAllowed, isPaused)
	
	elseif self.mode == self.MODE_GRAB
	then
		self:MoveGrab(isLocomotionAllowed, isPaused)
	end

end


function CQuickLocomotion:MoveSmooth(isLocomotionAllowed, isPaused)

	local hmd = self.player:GetHMDAvatar()
	if not hmd then return end

	local slideFactor = g_VRScript.playerSettings:GetPlayerSetting(self.player, "quick_loco_slide_factor") or 1

	for handID = 0, 1
	do	
		if isLocomotionAllowed[handID] and not isPaused
		then
			local handEnt = hmd:GetVRHand(handID)
			if self.player:IsActionActiveForHand(handEnt:GetLiteralHandType() , MOVE_TELEPORT) 
			then
				local desriedVel = handEnt:GetForwardVector() * self.SMOOTH_MOVESPEED * slideFactor
				desriedVel.z = 0
			
				local onGround, groundNormal = g_VRScript.playerPhysController:IsPlayerOnGround(self.player)
				if onGround
				then
					g_VRScript.playerPhysController:SetVelocity(self.player, desriedVel, true)
				else
					local playerVel = g_VRScript.playerPhysController:GetVelocity(self.player)
					playerVel.z = 0
					local vel = (desriedVel - playerVel) * self.SMOOTH_AIR_CONTROL_FACTOR
					g_VRScript.playerPhysController:AddVelocity(self.player, vel)
				end
			end
		end
	end
end


function CQuickLocomotion:MoveGrab(isLocomotionAllowed, isPaused)

	local hmd = self.player:GetHMDAvatar()
	if not hmd then return end

	for handID = 0, 1
	do	
		local handEnt = hmd:GetVRHand(handID)
		local actionActive = self.player:IsActionActiveForHand(handEnt:GetLiteralHandType() , MOVE_TELEPORT) 
			and isLocomotionAllowed[handID]
	
		if self.activeGrabHandID == handID
		then
			if not actionActive
			then
				self.activeGrabHandID = -1
				self.grabOrigin = nil
				g_VRScript.playerPhysController:RemoveConstraint(self.player, self)
			end
			
		elseif self.activeGrabHandID == -1 and actionActive
		then
			self.activeGrabHandID = handID
			self.grabOrigin = handEnt:GetAbsOrigin()
			g_VRScript.playerPhysController:AddConstraint(self.player, self, true)
		else
			actionActive = false
		end
		
		if actionActive and g_VRScript.playerPhysController:IsActive(self.player, self) and not isPaused
		then
			local move = (self.grabOrigin - handEnt:GetAbsOrigin()) * self.GRAB_MOVE_FRAME_FACTOR
			
			g_VRScript.playerPhysController:MovePlayer(self.player, move, false, false, self)
		end
	end
end