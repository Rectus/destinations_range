

CQuickLocomotion = class(
	{
		player = nil;
		mode = 0;
		smoothMode = 0;
		grabMode = 1;
		turnMode = 1;
		turnIncrement = 45;
		grabOrigin = nil;
		activeGrabHandID = -1;
		handDirAdjust = QAngle(0,0,0);
		turnState = {};
	}, 
	
	{
		MODE_NONE = 0;
		MODE_SMOOTH = 1;
		MODE_GRAB = 2;

		SMOOTH_HAND = 0;
		SMOOTH_HEAD = 1;

		GRAB_SURFACE = 0;
		GRAB_GROUND = 1;
		GRAB_AIR = 2;

		TURN_NONE = 0;
		TURN_SNAP = 1;
		TURN_SMOOTH = 2;
		
		SMOOTH_MOVESPEED  = 200;
		SMOOTH_AIR_CONTROL_FACTOR = 0.1;
		GRAB_MOVE_FRAME_FACTOR = 0.1;

		MOVE_DIR_ADJUST_HANDS = QAngle(0, 0, 0);
		MOVE_DIR_ADJUST_KNUCKLES = QAngle(30, 180, 0);
		MOVE_DIR_ADJUST_OTHER = QAngle(0, 180, 0);
	},
	nil
)


function CQuickLocomotion.constructor(self, player, mode)
	self.player = player
	self.mode = mode
	self.turnState[0] = false
	self.turnState[1] = false
	
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
	self.turnMode = math.floor(g_VRScript.playerSettings:GetPlayerSetting(self.player, "quick_loco_turn_mode") or 0)

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

	if self.turnMode == self.TURN_SNAP then
		self:TurnSnap(isLocomotionAllowed, isPaused)
	end

	local modelName = self.player:GetHMDAvatar():GetVRHand(0):GetModelName()

	if modelName == "models/characters/avatars/hand_l_v3.vmdl" or
		modelName == "models/hands/steamvr_hand_left.vmdl"
	then
		self.handDirAdjust = self.MOVE_DIR_ADJUST_HANDS
	elseif modelName == "models/controllers/valve_controller_knu_1_0_left.vmdl" then
		self.handDirAdjust = self.MOVE_DIR_ADJUST_KNUCKLES
	else
		self.handDirAdjust = self.MOVE_DIR_ADJUST_OTHER
	end
end


function CQuickLocomotion:MoveSmooth(isLocomotionAllowed, isPaused)

	local hmd = self.player:GetHMDAvatar()
	if not hmd then return end

	local slideFactor = g_VRScript.playerSettings:GetPlayerSetting(self.player, "quick_loco_slide_factor") or 1

	self.smoothMode = math.floor(g_VRScript.playerSettings:GetPlayerSetting(self.player, "quick_loco_slide_mode") or 0)

	for handID = 0, 1
	do	
		if isLocomotionAllowed[handID] and not isPaused
		then
			local handEnt = hmd:GetVRHand(handID)
			if self.player:IsActionActiveForHand(handEnt:GetLiteralHandType() , MOVE_TELEPORT)
			then
				local desiredVel

				if self.smoothMode == 0 then
					desiredVel = RotateOrientation(handEnt:GetAngles(), self.handDirAdjust):Forward() * self.SMOOTH_MOVESPEED * slideFactor
				else
					desiredVel = hmd:GetAngles():Forward() * self.SMOOTH_MOVESPEED * slideFactor
				end

				desiredVel.z = 0
			
				local onGround, groundNormal = g_VRScript.playerPhysController:IsPlayerOnGround(self.player)
				if onGround
				then
					g_VRScript.playerPhysController:SetVelocity(self.player, desiredVel, true)
				else
					local playerVel = g_VRScript.playerPhysController:GetVelocity(self.player)
					playerVel.z = 0
					local vel = (desiredVel - playerVel) * self.SMOOTH_AIR_CONTROL_FACTOR
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

function CQuickLocomotion:TurnSnap(isLocomotionAllowed, isPaused)

	local hmd = self.player:GetHMDAvatar()
	if not hmd then return end

	self.turnIncrement = g_VRScript.playerSettings:GetPlayerSetting(self.player, "quick_loco_turn_increment") or 45

	local turnOrigin
	-- Turn around the grab origin if grabbing
	if self.grabOrigin then
		return -- broken so don't turn instad
		--turnOrigin = self.grabOrigin
	else
		turnOrigin = self.player:GetHMDAvatar():GetAbsOrigin()
	end

	for handID = 0, 1
	do	
		local handEnt = hmd:GetVRHand(handID)
		local actionActiveLeft = self.player:IsActionActiveForHand(handEnt:GetLiteralHandType(), MOVE_TURN_LEFT) and isLocomotionAllowed[handID]
		local actionActiveRight = self.player:IsActionActiveForHand(handEnt:GetLiteralHandType(), MOVE_TURN_RIGHT) and isLocomotionAllowed[handID]



		if actionActiveLeft and not self.turnState[handID] then

			g_VRScript.playerPhysController:RotatePlayer(self.player, QAngle(0, self.turnIncrement, 0), turnOrigin)
			self.turnState[handID] = true

		elseif actionActiveRight and not self.turnState[handID] then

			g_VRScript.playerPhysController:RotatePlayer(self.player, QAngle(0, -self.turnIncrement, 0), turnOrigin)
			self.turnState[handID] = true

		elseif not actionActiveLeft and not actionActiveRight then
			self.turnState[handID] = false
		end

	end
end