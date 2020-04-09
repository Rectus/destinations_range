

CQuickLocomotion = class(
	{
		physController = nil;
		settings = nil;
		player = nil;
		mode = 0;
		smoothMode = 0;
		grabMode = 1;
		turnMode = 1;
		moveOrigin = nil;
		activeMoveHandID = -1;
		handDirAdjust = QAngle(0,0,0);
		turnState = {};
		releasedThisFrame = false;
	},

	{
		MODE_NONE = 0;
		MODE_SMOOTH = 1;
		MODE_GRAB = 2;
		MODE_RING = 3;

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

		RING_RADIUS = 50;
		RING_BASE_INNER_MOVESPEED = 50;
		RING_BASE_OUTER_MOVESPEED = 500;
		RING_DEADZONE = 2;

		TURN_SMOOTH_BASE_SPEED = 90;

		MOVE_DIR_ADJUST_HANDS = QAngle(0, 0, 0);
		MOVE_DIR_ADJUST_KNUCKLES = QAngle(30, 180, 0);
		MOVE_DIR_ADJUST_OTHER = QAngle(0, 180, 0);
	},
	nil
)


function CQuickLocomotion.constructor(self, player, mode, phys, settings)
	self.physController = phys
	self.settings = settings
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

	local newMode = math.floor(self.settings:GetPlayerSetting(self.player, "locomotion_mode") or 0)
	self.turnMode = math.floor(self.settings:GetPlayerSetting(self.player, "quick_loco_turn_mode") or 0)
	local allowTurn = isLocomotionAllowed and self.mode ~= self.MODE_NONE

	self:CheckHandModel()

	-- Run one frame on the old mode with movement disabled on change.
	if newMode ~=self.mode then
		isPaused = true
	end

	if self.mode == self.MODE_SMOOTH then
		self:MoveSmooth(isLocomotionAllowed, isPaused)

	elseif self.mode == self.MODE_GRAB then
		self:MoveGrab(isLocomotionAllowed, isPaused)

	elseif self.mode == self.MODE_RING then
		self:MoveRing(isLocomotionAllowed, isPaused)
	end

	if self.turnMode ~= self.TURN_NONE then
		self:Turn(isLocomotionAllowed, allowTurn, isPaused)
	end

	self.mode = newMode
end


function CQuickLocomotion:CheckHandModel()
	if not self.player:GetHMDAvatar() then return end
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

	local slideFactor = self.settings:GetPlayerSetting(self.player, "quick_loco_slide_factor") or 1

	self.smoothMode = math.floor(self.settings:GetPlayerSetting(self.player, "quick_loco_slide_mode") or 0)

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

				local onGround, groundNormal = self.physController:IsPlayerOnGround(self.player)
				if onGround
				then
					self.physController:SetVelocity(self.player, desiredVel, true)
				else
					local playerVel = self.physController:GetVelocity(self.player)
					playerVel.z = 0
					local vel = (desiredVel - playerVel) * self.SMOOTH_AIR_CONTROL_FACTOR
					self.physController:AddVelocity(self.player, vel)
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
			and isLocomotionAllowed[handID] and not isPaused

		if self.activeMoveHandID == handID
		then
			if not actionActive
			then
				self.activeMoveHandID = -1
				self.moveOrigin = nil
				self.physController:RemoveConstraint(self.player, self)
			end

		elseif self.activeMoveHandID == -1 and actionActive
		then
			self.activeMoveHandID = handID
			self.moveOrigin = handEnt:GetAbsOrigin()
			self.physController:AddConstraint(self.player, self, true)
		else
			actionActive = false
		end

		if actionActive and self.physController:IsActive(self.player, self) and not isPaused
		then
			local move = (self.moveOrigin - handEnt:GetAbsOrigin()) * self.GRAB_MOVE_FRAME_FACTOR

			self.physController:MovePlayer(self.player, move, false, false, self)
		end
	end
end


function CQuickLocomotion:MoveRing(isLocomotionAllowed, isPaused)

	local hmd = self.player:GetHMDAvatar()
	if not hmd then return end
	local anchor = self.player:GetHMDAnchor()

	local vertical = self.settings:GetPlayerSetting(self.player, "quick_loco_ring_vert")

	local relHeadPos = self:GetHeadCenter(self.player) - anchor:GetAbsOrigin()

	for handID = 0, 1
	do
		local handEnt = hmd:GetVRHand(handID)
		local actionActive = self.player:IsActionActiveForHand(handEnt:GetLiteralHandType() , MOVE_TELEPORT)
			and isLocomotionAllowed[handID] and not isPaused

		if self.activeMoveHandID == handID
		then
			if not actionActive
			then
				self.releasedThisFrame = true
				self.activeMoveHandID = -1
				ParticleManager:DestroyParticle(self.ringParticleIndex, false)
				self.ringParticleIndex = -1
				--self.physController:RemoveConstraint(self.player, self)
			end

		elseif self.activeMoveHandID == -1 and actionActive
		then
			-- Don't recenter the ring if the player holds both buttons in and releases the active one.
			if not self.releasedThisFrame or not self.moveOrigin then
				self.moveOrigin = relHeadPos
			end
			self.releasedThisFrame = false
			self.activeMoveHandID = handID
			self:SpawnRingParticle(self.moveOrigin)
			--self.physController:AddConstraint(self.player, self, false)
		else
			self.releasedThisFrame = false
			actionActive = false
		end

		if actionActive and self.physController:IsActive(self.player, self) and not isPaused
		then
			local slideFactor = self.settings:GetPlayerSetting(self.player, "quick_loco_slide_factor") or 1

			local particlePos = relHeadPos
			particlePos.z = vertical
			ParticleManager:SetParticleControl(self.ringParticleIndex, 5, particlePos)

			local move = relHeadPos - self.moveOrigin
			move.z = move.z * vertical

			local distance = move:Length()
			local moveVel

			if distance < self.RING_DEADZONE then
				moveVel = Vector(0, 0, 0)
			else
				local speed = RemapValClamped(distance, self.RING_DEADZONE, self.RING_RADIUS, self.RING_BASE_INNER_MOVESPEED, self.RING_BASE_OUTER_MOVESPEED)
				moveVel = move:Normalized() * speed * slideFactor
			end

			local onGround, _groundNormal = self.physController:IsPlayerOnGround(self.player)
			if onGround
			then
				self.physController:SetVelocity(self.player, moveVel, true)
			else
				local playerVel = self.physController:GetVelocity(self.player)
				playerVel.z = 0
				local vel = (moveVel - playerVel) * self.SMOOTH_AIR_CONTROL_FACTOR
				self.physController:AddVelocity(self.player, vel)
			end
		end
	end
end


function CQuickLocomotion:GetHeadCenter(player)

	local hmd = player:GetHMDAvatar()

	return hmd:TransformPointEntityToWorld(Vector(-4, 0, 0))
end


function CQuickLocomotion:SpawnRingParticle(origin)
	local anchor = self.player:GetHMDAnchor()

	self.ringParticleIndex = ParticleManager:CreateParticleForPlayer("particles/ui/locomotion_ring.vpcf",
		PATTACH_ABSORIGIN_FOLLOW, anchor, self.player)

	ParticleManager:SetParticleControl(self.ringParticleIndex, 2, origin)
	ParticleManager:SetParticleControl(self.ringParticleIndex, 1, Vector(self.RING_RADIUS, self.RING_DEADZONE, 0))
	ParticleManager:SetParticleControl(self.ringParticleIndex, 3, Vector(180, 180, 255))
end


function CQuickLocomotion:Turn(isLocomotionAllowed, allowTurn, isPaused)

	local hmd = self.player:GetHMDAvatar()
	if not hmd then return end

	if self.mode == self.MODE_GRAB and self.moveOrigin then
		return
	end

	local turnIncrement = self.settings:GetPlayerSetting(self.player, "quick_loco_turn_increment") or 45
	local turnSpeed = self.settings:GetPlayerSetting(self.player, "quick_loco_turn_speed") or 1

	for handID = 0, 1
	do
		local handEnt = hmd:GetVRHand(handID)
		local actionActiveLeft = self.player:IsActionActiveForHand(handEnt:GetLiteralHandType(), MOVE_TURN_LEFT) and isLocomotionAllowed[handID] and allowTurn
		local actionActiveRight = self.player:IsActionActiveForHand(handEnt:GetLiteralHandType(), MOVE_TURN_RIGHT) and isLocomotionAllowed[handID] and allowTurn

		local turnAng = nil

		if self.turnMode == self.TURN_SNAP then

			if actionActiveLeft and not self.turnState[handID] then
				turnAng = QAngle(0, turnIncrement, 0)
				self.turnState[handID] = true

			elseif actionActiveRight and not self.turnState[handID] then
				turnAng = QAngle(0, -turnIncrement, 0)
				self.turnState[handID] = true

			elseif not actionActiveLeft and not actionActiveRight then
				self.turnState[handID] = false
			end

		elseif self.turnMode == self.TURN_SMOOTH then

			local turnStep = FrameTime() * self.TURN_SMOOTH_BASE_SPEED * turnSpeed
			local turnOrigin = self.player:GetAbsOrigin()

			if actionActiveLeft then
				turnAng = QAngle(0, turnStep, 0)
			elseif actionActiveRight then
				turnAng = QAngle(0, -turnStep, 0)
			end
		end

		if turnAng then
			-- Update ring position if active
			if self.mode == self.MODE_RING and self.activeMoveHandID ~= -1 then
				local playerPos = self:GetHeadCenter(self.player)
				local anchorPos = self.player:GetHMDAnchor():GetAbsOrigin()
				local moveDelta = playerPos - RotatePosition(anchorPos, QAngle(0, turnAng.y, 0), playerPos)
				self.moveOrigin = self.moveOrigin - moveDelta
				ParticleManager:DestroyParticle(self.ringParticleIndex, false)
				self:SpawnRingParticle(self.moveOrigin)
			end

			self.physController:ForceRotateInPlace(self.player, turnAng)
		end
	end
end
