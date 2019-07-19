--[[
	Player physics contoller
	
	Copyright (c) 2017-2019 Rectus
	
	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:
	
	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.
	
	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
]]--

local MathUtils = require "libraries.mathutils"
--require "utils.deepprint"

if DebugCall == nil then DebugCall = function() end end 

CPlayerPhysics = class(
	{
		players = nil;
		thinkEnt = nil;
		debugDraw = false;
		lastThinkTime = 0;
		lastThinkDelta = 0;
		lastFrameTime = 0;
	}, 
	
	{
		GRAVITY_ACC = 386; -- 9.8 m/s2
		PLAYER_FALL_TERMINAL_SPEED = 2200; -- 56 m/s
		GRAVITY_DRAG_COEFF = 7.795e-5; -- 56 m/s ^2 * x = 9.8 m/s2
		FALL_DISTANCE = 64000;
		FALL_GLUE_DISTANCE = 4;
		PULL_UP_DISTANCE = 16;
		PULL_UP_SPEED = 50;
		PLAYER_STEP_MAX_SIZE = 12;
		PLAYER_FULL_HEIGHT = 72;
		PLAYER_HEIGHT_DRAG_FACTOR = 1.0;
		
		GROUND_HIT_REDIR_FACTOR = 0.4;
		AIR_DRAG_DECEL = 5e-4;
		DRAG_DECEL = 1e-1;
		DRAG_CONSTANT = 2;
		STOP_SPEED = 50;
		MAP_CUBE_BOUND = 15800;
		MOVE_ENT_USE_MIN_VELOCITY = 0;
		
		THINK_FRAME_INTERVAL = 2;
		MOVE_FRAME_INTERVAL = 2;
		
		HEIGHT_TRACE_RADIUS = 4;
		HEAD_COLLISION_RADIUS = 3;
		COLLISION_RADIUS = 5;
		COLLISION_RADIUS_NARROW = 0.5;
		
		TELEPORT_DETECT_TOLERANCE_SQ = 8 * 8;

		PROP_CLASSES =
		{
			prop_physics = true;
			prop_physics_override = true;
			prop_destinations_physics = true;
			prop_destinations_tool = true;
			steamTours_item_tool = true;
			simple_physics_prop = true;
			prop_destinations_game_trophy = true;
		};
		MOVE_ENTITY =
		{
			classname = "prop_dynamic";
			targetname = "player_movement";
			model = "models/editor/axis_helper.vmdl";
			solid = 0;
			ScriptedMovement = 1;
			LagCompensate = 1;
		};
	},
	nil
)


function CPlayerPhysics.constructor(self)
	self.players = {}
	self.thinkEnt = SpawnEntityFromTableSynchronous("logic_script", 
		{targetname = "phys_think_ent", vscripts = "player_fall_ent"})
	
end


function CPlayerPhysics:Init()

	self.thinkEnt:GetPrivateScriptScope().EnableThink(self, self.lastThinkDelta)
end


---------------------------------------------------
-- Interface
---------------------------------------------------

function CPlayerPhysics:AddPlayer(player)

	if not player or not player:GetHMDAnchor() then return end

	if not self.players[player]
	then
		local moveEnt = SpawnEntityFromTableSynchronous(self.MOVE_ENTITY.classname, self.MOVE_ENTITY) 
	
		self.players[player] = 
		{
			idle = true, 
			constraints = {}, 
			activeConstraint = nil, 
			velocity = Vector(0,0,0),
			velocityBuffer = Vector(0,0,0), 
			rotationBuffer = 0,
			prevPos = Vector(0,0,0),
			prevPlayAreaPos = Vector(0,0,0),
			stick = false, 
			gravity = true, 
			groundNormal = Vector(0,0,1), 
			onGround = true, 
			menuButtonHeld = false, 
			isPaused = false, 
			gravConstraints = {},
			dragConstraint = nil,
			dragLinear = self.DRAG_DECEL,
			airDragLinear = self.AIR_DRAG_DECEL,
			dragConstant = self.DRAG_CONSTANT,
			dragOverride = nil,
			lerpDest = nil,
			lerpTime = 0,
			moveNextFrame = nil,
			groundEnt = nil,
			velChangeThisThink = false,
			moveEntity = moveEnt,
			moveEntInUse = false,
			forcePrecision = false,
			hasTeleported = false,
		}
		
		moveEnt:SetAbsOrigin(player:GetHMDAnchor():GetAbsOrigin())
		moveEnt:AddEffects(32) --EF_NODRAW
	end
end


-- Add a movement constraint to the player. The constraint indicates that another entity is controlling the players movement.
-- The constraint parameter an be any object reference, for example the entity that controls the player.
-- If the constriant is rigid, only direct movemnt affects the player. The last added rigid constraint added is set to active,
-- and only its user will be able to control the players movement.
function CPlayerPhysics:AddConstraint(player, constraint, isRigid)
	if not self.players[player]
	then
		self:AddPlayer(player)
	
	end
	self.players[player].constraints[constraint] = {rigid = isRigid}
	
	if isRigid
	then
		self.players[player].activeConstraint = constraint
	end
end


function CPlayerPhysics:AddVelocity(player, inVelocity)
	if not self.players[player]
	then
		self:AddPlayer(player)
	end
	
	local playerProps = self.players[player]
	
	if playerProps.isPaused or player:IsVRDashboardShowing() or player:IsContentBrowserShowing()
	then
		return
	end
		
	playerProps.velocityBuffer = playerProps.velocityBuffer + inVelocity
	
	-- Limit to terminal velocity
	local speed = (playerProps.velocity + playerProps.velocityBuffer):Length()
	if speed > self.PLAYER_FALL_TERMINAL_SPEED
	then
		playerProps.velocityBuffer = (playerProps.velocity + playerProps.velocityBuffer)
			* self.PLAYER_FALL_TERMINAL_SPEED / speed - playerProps.velocity
	end
	
	playerProps.velChangeThisThink = true	
	playerProps.idle = false
end


function CPlayerPhysics:SetVelocity(player, inVelocity)
	if not self.players[player]
	then
		self:AddPlayer(player)
	end
	
	local playerProps = self.players[player]
		
	playerProps.velocityBuffer = inVelocity - playerProps.velocity

	-- Limit to terminal velocity
	local speed = inVelocity:Length()
	if speed > self.PLAYER_FALL_TERMINAL_SPEED
	then
		playerProps.velocityBuffer = inVelocity
			* self.PLAYER_FALL_TERMINAL_SPEED / speed - playerProps.velocity
	end
	
	self.players[player].velChangeThisThink = true
	self.players[player].idle = false
end


function CPlayerPhysics:GetVelocity(player)
	if not self.players[player]
	then
		self:AddPlayer(player)
	end
	
	if self.players[player].idle then
		return Vector(0,0,0)
	end
	
	return self.players[player].velocity + self.players[player].velocityBuffer
end


function CPlayerPhysics:GetPlayerHeight(player)
	if not self.players[player]
	then
		self:AddPlayer(player)
	end
	
	if self.players[player].idle then
		return 0
	end
	
	local height = self:TracePlayerHeight(player, self.players[player])
	
	if height < self.FALL_GLUE_DISTANCE then
		return 0
	end
	
	return height
end


function CPlayerPhysics:IsPlayerOnGround(player)
	if not self.players[player]
	then
		self:AddPlayer(player)
	end
	return self.players[player].onGround or self:TracePlayerHeight(player, self.players[player]) 
		< self.FALL_GLUE_DISTANCE
end


-- Locks the player on the spot for a frame
function CPlayerPhysics:StickFrame(player)
	if not self.players[player]
	then
		self:AddPlayer(player)
	end

	self.players[player].velocity = Vector(0,0,0)
	self.players[player].stick = true
	
end


function CPlayerPhysics:EnableGravity(player, constraint)

	if not self.players[player]
	then
		self:AddPlayer(player)
	end

	self.players[player].gravConstraints[constraint] = nil
	
	local numConstraints = 0
  	for _ in pairs(self.players[player].gravConstraints) do numConstraints = numConstraints + 1 end
	
	if numConstraints <= 0
	then
		self.players[player].gravity = true
		self.players[player].idle = false
	end
end


function CPlayerPhysics:DisableGravity(player, constraint)

	if not self.players[player]
	then
		self:AddPlayer(player)
	end

	self.players[player].gravConstraints[constraint] = true

	self.players[player].gravity = false

end


function CPlayerPhysics:ForcePrecisionMovement(player, forced)

	if not self.players[player]
	then
		self:AddPlayer(player)
	end

	self.players[player].forcePrecision = forced

end


function CPlayerPhysics:RotatePlayer(playerEnt, rotationDelta, rotationOrigin, constraint)
	if not self.players[playerEnt]
	then
		self:AddPlayer(playerEnt)
	end
	
	local playerProps = self.players[playerEnt]
	
	if playerProps.isPaused or playerEnt:IsVRDashboardShowing() or playerEnt:IsContentBrowserShowing()
	then
		return false
	end

	playerProps.rotationBuffer = playerProps.rotationBuffer + rotationDelta.y
	local playSpace = self:GetPlayspaceOrigin(playerEnt, playerProps)
	local moveVector = RotatePosition(rotationOrigin, rotationDelta, playSpace) - playSpace
	self:MovePlayer(playerEnt, moveVector, false, false, constraint)
	
	return true

end


function CPlayerPhysics:RemoveDragConstraint(player, constraint)

	if not self.players[player]
	then
		self:AddPlayer(player)
	end

	if self.players[player].dragConstraint == constraint
	then
		self.players[player].dragLinear = self.DRAG_DECEL
		self.players[player].airDragLinear = self.AIR_DRAG_DECEL
		self.players[player].dragConstant = self.DRAG_CONSTANT	
		self.players[player].dragOverride = nil
		self.players[player].dragConstraint = nil
	end

end


function CPlayerPhysics:TrySetDragConstraint(player, constraint)

	if not self.players[player]
	then
		self:AddPlayer(player)
	end
	
	if self.players[player].dragConstraint == constraint
	then
		return true
	end
	
	if self.players[player].dragConstraint == nil
	then
		self.players[player].dragConstraint = constraint
		return true
	end
	
	return false
end


function CPlayerPhysics:SetDrag(player, constraint, dragLinear, dragConstant, dragOverride, airDragLinear)

	if not self.players[player]
	then
		self:AddPlayer(player)
	end

	if self.players[player].dragConstraint == constraint
	then
		if dragLinear ~= nil then
			self.players[player].dragLinear = dragLinear
		end
		
		if airDragLinear ~= nil then
			self.players[player].airDragLinear = airDragLinear
		end
		
		if dragConstant ~= nil then
			self.players[player].dragConstant = dragConstant	
		end
		
		if dragOverride ~= nil then
			self.players[player].dragOverride = dragOverride	
		end
	end

end


function CPlayerPhysics:SetPaused(player, paused)

	if not self.players[player]
	then
		self:AddPlayer(player)
	end

	self.players[player].isPaused = paused
end


function CPlayerPhysics:IsPaused(player)

	if not self.players[player]
	then
		self:AddPlayer(player)
	end

	return self.players[player].isPaused
end


function CPlayerPhysics:ToggleDebugDraw()

	self.debugDraw = not self.debugDraw
end


function CPlayerPhysics:IsDebugDrawEnabled()
	return self.debugDraw
end


-- Move the player, while testing for world collisions in the move direction
function CPlayerPhysics:MovePlayer(playerEnt, offset, accelerate, grounded, constraint)

	accelerate = accelerate or false
	grounded = grounded or false
	constraint = constraint or nil

	if not self.players[playerEnt]
	then
		self:AddPlayer(playerEnt)
	end

	local playerProps = self.players[playerEnt]
	
	if playerProps.activeConstraint and constraint ~= playerProps.activeConstraint then return end

	if playerProps.isPaused or playerEnt:IsVRDashboardShowing() or playerEnt:IsContentBrowserShowing()
	then
		return
	end

	local hitVector = self:TracePlayerCollision(playerEnt, playerProps, offset)
	
	if hitVector
	then
		offset = offset - hitVector
	end
	
	local height, foundGround, heightTrace = self:TracePlayerHeight(playerEnt, playerProps)
	local groundNormal = heightTrace.normal
		
	if foundGround and (grounded or height <= 0)
	then
		local groundCorrection = offset.z
		if not grounded 
		then
			groundCorrection = min(groundCorrection, 0)
		end
		
		if not playerProps.activeConstraint
		then
			groundCorrection = groundCorrection + Clamp(height, -self.PULL_UP_SPEED * self.lastThinkDelta, 0)
		end
		offset = offset - Vector(0, 0, groundCorrection)
	end

	playerProps.idle = false

	if accelerate
	then
		if playerProps.onGround then
			-- Add velocity to give player momentum
			playerProps.velocity = offset * (1 / self.lastThinkDelta)
			-- Remove velocity in the ground normal direction. 
			playerProps.velocity = playerProps.velocity - playerProps.velocity:Dot(groundNormal) * groundNormal
		end
	end

	if not playerProps.moveNextFrame then
		playerProps.moveNextFrame = offset + self:GetPlayspaceOrigin(playerEnt, playerProps)
	else
		playerProps.moveNextFrame = playerProps.moveNextFrame + offset
	end
	
	return hitVector
end


-- Forcefully set the players position
function CPlayerPhysics:SetPlayerPosition(playerEnt, position, onGround, haltMovement)

	onGround = onGround or false
	haltMovement = haltMovement or false

	if not self.players[playerEnt]
	then
		self:AddPlayer(playerEnt)
	end

	local playerProps = self.players[playerEnt]
	local offset = position - self:GetPlayerOrigin(playerEnt, playerProps)	
	local newOrigin = offset + self:GetPlayspaceOrigin(playerEnt, playerProps)
	
	if onGround
	then
		local trace =
		{
			startpos = newOrigin;
			endpos = newOrigin - Vector(0, 0, self.FALL_DISTANCE);
			ignore = playerEnt;
			mask = 33636363; -- TRACE_MASK_PLAYER_SOLID	
			min = Vector(-self.HEIGHT_TRACE_RADIUS, -self.HEIGHT_TRACE_RADIUS, 0);
			max = Vector(self.HEIGHT_TRACE_RADIUS, self.HEIGHT_TRACE_RADIUS, 1)
		}
		TraceHull(trace)
		
		if trace.hit and not trace.startsolid
		then
			local height = trace.startpos.z - trace.pos.z
			newOrigin = newOrigin - Vector(0,0, height)
			self:SetPlayspaceOrigin(playerEnt, playerProps, newOrigin, true)
			self:CheckPlayerTeleport(playerEnt, playerProps, 0)
		end
	end
	
	if haltMovement
	then
		playerProps.velocity = Vector(0,0,0)
		playerProps.velocityBuffer = Vector(0,0,0)
		playerProps.moveEntity:SetVelocity(Vector(0,0,0))
		playerProps.moveNextFrame = nil
		playerProps.idle = true
	end
	
	
	

	playerProps.activeConstraint = nil
	playerProps.stick = true
end


function CPlayerPhysics:RemoveConstraint(player, constraint)
	
	if not self.players[player]
	then
		self:AddPlayer(player)
	end
	
	self.players[player].constraints[constraint] = nil
	
	if self.players[player].activeConstraint == constraint
	then
		self.players[player].activeConstraint = nil
	
		-- Find new rigid constraint to set as active
		for con, props in pairs(self.players[player].constraints)
		do
			if not self.players[player].activeConstraint and props.isRigid
			then
				self.players[player].activeConstraint = con
			end 
		end
	end
	
	if not self.players[player].activeConstraint
	then
		self.players[player].idle = false
	end
	
end


-- Check if the passed in object is the active rigid constriant
function CPlayerPhysics:IsActive(player, constraint)
	if not player
	then 
		return false
	end
	
	if not self.players[player]
	then
		self:AddPlayer(player)
	end

	if self.players[player].activeConstraint == constraint
	then
		return true
		
	elseif self.players[player].activeConstraint ~= nil
	then
		return false
	else
		return true
	end
end


---------------------------------------------------
-- Callbacks
---------------------------------------------------


-- Simulates physics
function CPlayerPhysics:PlayerMoveThink()

	if GetFrameCount() % self.THINK_FRAME_INTERVAL ~= 0 then return end

	self.lastThinkDelta = Time() - self.lastThinkTime
	self.lastThinkTime = Time()
	
	for playerEnt, playerProps in pairs(self.players)
	do
		if not playerEnt or not IsValidEntity(playerEnt) then
		
			self.players[playerEnt] = nil
		else
			if playerProps.hasTeleported 
			then 
				if g_VRScript.pauseManager and g_VRScript.pauseManager.OnTeleported 
				then 
					g_VRScript.pauseManager:OnTeleported(playerEnt) 
				end
				playerProps.hasTeleported = false
			end	
		
			playerProps.lerpTime = 0
		
			local move = not playerProps.idle
			
			if playerProps.isPaused or playerEnt:IsVRDashboardShowing() or playerEnt:IsContentBrowserShowing()
			then
				move = false
			end
				
			if playerProps.activeConstraint
			then
				playerProps.velocity = Vector(0,0,0)
			end

			self:TracePlayerHeadCollision(playerEnt, playerProps)	
		
			if move
			then
				playerProps.velocity = playerProps.velocity + playerProps.velocityBuffer
				playerProps.velocityBuffer = Vector(0,0,0)
			
				local groundDist, gravVelChange, onGround, groundEnt = self:CalcPlayerGravity(playerEnt, playerProps)
				playerProps.velocity = playerProps.velocity + gravVelChange
				if onGround
				then
					self.players[playerEnt].groundEnt = groundEnt
					self.players[playerEnt].onGround = true
				else
					self.players[playerEnt].groundEnt = nil
					self.players[playerEnt].onGround = false
				end
				
				local hitVector = self:TracePlayerCollision(playerEnt, playerProps, 
					playerProps.velocity * self.lastThinkDelta)
								
				if hitVector
				then
					playerProps.velocity = playerProps.velocity - hitVector / self.lastThinkDelta
				end
				
				local stopped, dragVelChange = self:CalcPlayerDrag(playerEnt, playerProps)
				if playerProps.velChangeThisThink then stopped = false end
				playerProps.velocity = playerProps.velocity + dragVelChange
				
				if self:CheckMapBounds(playerEnt, playerProps)
				then
					local origin = self:GetPlayspaceOrigin(playerEnt, playerProps)
					self:SetPlayspaceOrigin(playerEnt, playerProps, 
						Vector(
							Clamp(origin.x, -self.MAP_CUBE_BOUND, self.MAP_CUBE_BOUND), 
							Clamp(origin.y, -self.MAP_CUBE_BOUND, self.MAP_CUBE_BOUND),
							Clamp(origin.z, -self.MAP_CUBE_BOUND, self.MAP_CUBE_BOUND)
						))
					playerProps.velocity = Vector(0,0,0
					)
					playerProps.moveNextFrame = nil
					playerProps.stick = true
				end
				
				DebugCall(DebugDrawLine, playerEnt:GetCenter(), 
						playerEnt:GetCenter() + playerProps.velocity * 0.1, 0, 255, 255, false, self.lastThinkDelta)
				
				self:UpdateMoveMethod(playerEnt, playerProps)

				if playerProps.rotationBuffer ~= 0
				then
					self:RotatePlayspace(playerEnt, playerProps, playerProps.rotationBuffer)
					playerProps.rotationBuffer = 0
				end
		
				
				if not playerProps.stick
				then
					local groundFixup = Vector(0,0,0)
					local maxFixup = self.PULL_UP_SPEED * self.lastThinkDelta
				
					if not playerProps.activeConstraint
					then
						groundFixup = Vector(0, 0, Clamp(groundDist, -maxFixup, maxFixup))
					end
				
					if playerProps.moveNextFrame 
					then
						playerProps.lerpDest = playerProps.moveNextFrame + groundFixup
						playerProps.moveNextFrame = nil	
						playerProps.moveEntity:SetVelocity(Vector(0,0,0))
						
					elseif playerProps.activeConstraint
					then
						playerProps.velocity = Vector(0,0,0)
						playerProps.moveEntity:SetVelocity(Vector(0,0,0))
					
					elseif stopped and abs(groundDist) <= maxFixup
					then
						playerProps.lerpDest = self:GetPlayspaceOrigin(playerEnt, playerProps) + groundFixup
						playerProps.moveEntity:SetVelocity(Vector(0,0,0))
						playerProps.velocity = Vector(0,0,0)
						playerProps.idle = true
					
					elseif not playerProps.moveEntInUse or abs(groundDist) < self.FALL_GLUE_DISTANCE
					then
						playerProps.moveEntity:SetVelocity(Vector(0,0,0))
						
						playerProps.lerpDest = self:GetPlayspaceOrigin(playerEnt, playerProps) 
							+ playerProps.velocity * self.lastThinkDelta + groundFixup
					else
						playerProps.moveEntity:SetVelocity(playerProps.velocity + groundFixup / self.lastThinkDelta)
					end
				else
					playerProps.moveEntity:SetVelocity(Vector(0,0,0))
					playerProps.stick = false
				end	
				playerProps.prevPos = self:GetPlayspaceOrigin(playerEnt, playerProps)
				
			else
				self:UpdateMoveMethod(playerEnt, playerProps)
				playerProps.moveEntity:SetVelocity(Vector(0,0,0))
				playerProps.lerpDest = nil
				playerProps.moveNextFrame = nil
				playerProps.velocityBuffer = Vector(0,0,0)
			end
			playerProps.velChangeThisThink = false
		end
	end
end


function CPlayerPhysics:FrameThink()

	if GetFrameCount() % self.MOVE_FRAME_INTERVAL ~= 0 then return end

	local time = Time()
	local frameDelta = time - self.lastFrameTime
	self.lastFrameTime = time

	for playerEnt, playerProps in pairs(self.players)
	do
		if IsValidEntity(playerEnt) then
			playerProps.lerpTime = Clamp(playerProps.lerpTime + frameDelta / self.lastThinkDelta, 0, 1)
			
			-- Reactivate movement if the player teleported or got moved by other means.
			if self:CheckPlayerTeleport(playerEnt, playerProps, frameDelta)
			then	
				DebugCall(print, "Teleport detected")
				playerProps.hasTeleported = true
				playerProps.lerpDest = nil
				playerProps.moveNextFrame = nil
				playerProps.activeConstraint = nil
				playerProps.idle = false
			end
		
			if playerProps.lerpDest then
				self:SetPlayspaceOrigin(playerEnt, playerProps, 
					VectorLerp(playerProps.lerpTime, playerProps.prevPos, playerProps.lerpDest))
					
				if playerProps.lerpTime >= 1 then
					playerProps.lerpDest = nil
				end
			end
			
			playerProps.prevPlayAreaPos = playerEnt:GetHMDAnchor():GetAbsOrigin()
		end
	end
end


---------------------------------------------------
-- Internal
---------------------------------------------------



function CPlayerPhysics:GetPlayerOrigin(playerEnt, playerProps)

	local playSpace = self:GetPlayspaceOrigin(playerEnt, playerProps)
	local playerPos = playerEnt:GetAbsOrigin()

	return Vector(playerPos.x, playerPos.y, playSpace.z)
end


function CPlayerPhysics:RotatePlayspace(playerEnt, playerProps, yaw)

	if playerProps.moveEntInUse
	then
		local ang = RotateOrientation(playerProps.moveEntity:GetAngles(), QAngle(0, yaw, 0))
		playerProps.moveEntity:SetAngles(ang.x, ang.y, ang.z)
	else
		local ang = RotateOrientation(playerEnt:GetHMDAnchor():GetAngles(), QAngle(0, yaw, 0))
		playerEnt:GetHMDAnchor():SetAngles(ang.x, ang.y, ang.z)
	end
end


function CPlayerPhysics:GetPlayspaceOrigin(playerEnt, playerProps)

	if playerProps.moveEntInUse
	then
		return playerProps.moveEntity:GetAbsOrigin()
	end
	
	return playerEnt:GetHMDAnchor():GetAbsOrigin()
end


function CPlayerPhysics:SetPlayspaceOrigin(playerEnt, playerProps, newOrigin, forceSync)

	forceSync = forceSync or false

	if not playerProps.moveEntInUse
	then
		playerEnt:GetHMDAnchor():SetAbsOrigin(newOrigin)
	end
	
	playerProps.moveEntity:SetAbsOrigin(newOrigin)
	
	if forceSync and playerProps.moveEntInUse 
	then
		playerEnt:GetHMDAnchor():SetParent(nil, "")
		playerProps.moveEntity:SetAbsOrigin(newOrigin)
		playerEnt:GetHMDAnchor():SetParent(playerProps.moveEntity, "")
	end
end


function CPlayerPhysics:UpdateMoveMethod(playerEnt, playerProps)

	local anchor = playerEnt:GetHMDAnchor()
	local moveEnt = playerProps.moveEntity
	
	if playerProps.idle or playerProps.forcePrecision or next(playerProps.constraints) ~= nil 
		or playerProps.velocity:Length() < self.MOVE_ENT_USE_MIN_VELOCITY 
	then
		if playerProps.moveEntInUse
		then
			moveEnt:SetVelocity(Vector(0,0,0))
			anchor:SetParent(nil, "")
			moveEnt:SetAbsOrigin(anchor:GetAbsOrigin())
			--moveEnt:SetParent(anchor, "")
			playerProps.moveEntInUse = false
			moveEnt:AddEffects(32) 
		end	
		
	elseif not playerProps.moveEntInUse
	then
		--moveEnt:SetVelocity(Vector(0,0,0))
		--moveEnt:SetParent(nil, "")
		moveEnt:SetAbsOrigin(anchor:GetAbsOrigin())
		anchor:SetParent(moveEnt, "")
		playerProps.moveEntInUse = true
		DebugCall(moveEnt.RemoveEffects, moveEnt, 32)
	end
end


function CPlayerPhysics:CheckPlayerTeleport(playerEnt, playerProps, timeFrame)
	local playAreaPos = playerEnt:GetHMDAnchor():GetAbsOrigin()
			
	if VectorDistanceSq(playAreaPos, playerProps.prevPlayAreaPos) 
		> self.TELEPORT_DETECT_TOLERANCE_SQ + VectorDistanceSq(playerProps.velocity * timeFrame, Vector(0,0,0))
	then
		if playerProps.moveEntInUse 
		then
			playerEnt:GetHMDAnchor():SetParent(nil, "")
			playerProps.moveEntity:SetAbsOrigin(playAreaPos)
			playerEnt:GetHMDAnchor():SetParent(playerProps.moveEntity, "")
			playerProps.moveEntity:SetVelocity(Vector(0,0,0))
		else
			playerProps.moveEntity:SetAbsOrigin(playAreaPos)
		end
		return true
	end
	return false
end


function CPlayerPhysics:CheckMapBounds(playerEnt, playerProps)
	local origin = self:GetPlayspaceOrigin(playerEnt, playerProps)
	local predictedOrigin = origin + playerProps.velocity * FrameTime() * self.MOVE_FRAME_INTERVAL
	if playerProps.moveNextFrame
	then
		predictedOrigin = playerProps.moveNextFrame
	end
	local hitBounds = false
	
	if abs(predictedOrigin.x) > self.MAP_CUBE_BOUND then
		hitBounds = true 
	end
	
	if abs(predictedOrigin.y) > self.MAP_CUBE_BOUND then
		hitBounds = true  
	end
	
	if abs(predictedOrigin.z) > self.MAP_CUBE_BOUND then
		hitBounds = true
	end	

	return hitBounds
end


function CPlayerPhysics:CalcPlayerDrag(playerEnt, playerProps)

	local dragVector = nil
	local speed = playerProps.velocity:Length()
	local relativePlayerVel = playerProps.velocity
	local dragVelChange = Vector(0,0,0)
	
	local playerHeightFac = (playerEnt:GetHMDAvatar():GetCenter().z + 4 
			- self:GetPlayspaceOrigin(playerEnt, playerProps).z) 
			/ self.PLAYER_FULL_HEIGHT * self.PLAYER_HEIGHT_DRAG_FACTOR
	
	if playerProps.onGround
	then	
		if not playerProps.dragOverride
		then
			if playerProps.groundEnt and IsValidEntity(playerProps.groundEnt) 
				and playerProps.groundEnt:GetEntityIndex() > 0 then
				
				relativePlayerVel = relativePlayerVel - GetPhysVelocity(playerProps.groundEnt)
				speed = relativePlayerVel:Length()
			end
				
			dragVector = relativePlayerVel * (playerProps.dragConstant * min(speed / playerProps.dragConstant, 1)
				+ playerProps.dragLinear * abs(speed)) * self.lastThinkDelta * playerHeightFac
		else
			dragVector = playerProps.dragOverride * self.lastThinkDelta
		end
		
		dragVelChange = -dragVector
			
	else
		local vel = Vector(playerProps.velocity.x, playerProps.velocity.y, 0)
		speed = vel:Length()
		dragVector = vel * playerProps.airDragLinear * speed * self.lastThinkDelta * playerHeightFac
		
		if dragVector:Length() > speed
		then 
			dragVector = dragVector:Normalized() * speed
		end
		
		dragVelChange = -dragVector
	end
	
	if self.debugDraw then 
		DebugDrawLine(playerEnt:GetCenter(), 
			playerEnt:GetCenter() + dragVector, 0, 0, 255, false, self.lastThinkDelta)
	end
	
	if playerProps.onGround then
	
		if playerProps.groundEnt and IsValidEntity(playerProps.groundEnt) 
			and playerProps.groundEnt:GetEntityIndex() > 0 then

			if VectorDistanceSq(playerProps.velocity, GetPhysVelocity(playerProps.groundEnt)) < 25 then
				dragVelChange = dragVelChange + GetPhysVelocity(playerProps.groundEnt) - playerProps.velocity
			end
		
			return false, dragVelChange
		
		elseif playerProps.velocity:Length() < self.STOP_SPEED then 
			return true, dragVelChange
		end
	end
	return false, dragVelChange
end


function CPlayerPhysics:CalcPlayerGravity(playerEnt, playerProps)

	local groundFixup = 0
	local playerPos = self:GetPlayerOrigin(playerEnt, playerProps)
	local gravVelChange = Vector(0,0,0)
	local onGround = false 
	local groundEnt = nil
		
	local height, foundGround, heightTrace = self:TracePlayerHeight(playerEnt, playerProps)
	local groundNormal = heightTrace.normal
	

	if playerProps.gravity and foundGround
	then
		gravVelChange = -Vector(0, 0, (self.GRAVITY_ACC - self.GRAVITY_DRAG_COEFF 
			* playerProps.velocity.z * playerProps.velocity.z) * self.lastThinkDelta) 
	end
	
	local groundNormalDot = playerProps.velocity:Dot(groundNormal)
	
	-- Player close to the ground and not moving away from it
	if ((height < playerProps.velocity.z * self.lastThinkDelta
		or abs(height) <= self.FALL_GLUE_DISTANCE)) and groundNormalDot <= 0
	then
		groundEnt = heightTrace.enthit
		onGround = true
		groundFixup = -height
		
		-- If the player velocity vector points through the ground, 
		--	remove that part and use the rest to accelerate the player.
		if groundNormalDot < 0
		then
			if self.debugDraw 
			then
				local redirVec = playerProps.velocity - 
					(-groundNormal):Cross(playerProps.velocity):Cross(-groundNormal) 
				DebugDrawLine(playerEnt:GetCenter(), playerEnt:GetCenter() + redirVec * 10, 
					255, 0, 255, false, self.lastThinkDelta)
			end
		
			gravVelChange = gravVelChange + (-groundNormal):Cross(playerProps.velocity):Cross(-groundNormal) - playerProps.velocity
		end
	else
		onGround = false
	end		

	return groundFixup, gravVelChange, onGround, groundEnt
end


function CPlayerPhysics:TracePlayerCollision(playerEnt, playerProps, offset)

	local playerHeadHeight = playerEnt:GetHMDAvatar():GetAbsOrigin().z 
		- self:GetPlayspaceOrigin(playerEnt, playerProps).z + self.HEIGHT_TRACE_RADIUS 
	local playerPos = self:GetPlayerOrigin(playerEnt, playerProps)

	-- Trace in the direction the player is moving.
	local trace =
	{
		startpos = playerPos;
		endpos = playerPos + offset;
		ignore = playerEnt;
		mask = 33636363; -- TRACE_MASK_PLAYER_SOLID	
		min = Vector(-self.COLLISION_RADIUS, -self.COLLISION_RADIUS, self.PLAYER_STEP_MAX_SIZE);
		max = Vector(self.COLLISION_RADIUS, self.COLLISION_RADIUS, playerHeadHeight);
	}
	--DebugDrawBox(traceTable.startpos, traceTable.min, traceTable.max, 0, 255, 255, 0, self.lastThinkDelta)
	--DebugDrawBox(traceTable.endpos, traceTable.min, traceTable.max, 0, 0, 255, 0, self.lastThinkDelta)
	TraceHull(trace)

	if not trace.hit and not trace.startsolid
	then
		return nil
	end
	
	if not trace.startsolid
	then
		if self.debugDraw 
		then
			DebugDrawBox(trace.pos, trace.min, trace.max, 0, 255, 0, 0, self.lastThinkDelta)
			DebugDrawLine(trace.pos + Vector(0,0,32), trace.pos + 
				Vector(0,0,32) + trace.normal * offset:Length(), 255, 0, 255, false, self.lastThinkDelta)
		end
			
		return trace.normal * trace.normal:Dot(offset)

	else -- Trace across the player with a narrow box if we are overlapping
		DebugCall(DebugDrawBox, trace.startpos, trace.min, trace.max, 0, 255, 255, 0, self.lastThinkDelta)
		
		local direction = offset:Normalized()
		local trace =
		{
			startpos = playerPos - direction * self.COLLISION_RADIUS;
			endpos = playerPos + offset + direction * self.COLLISION_RADIUS;
			ignore = playerEnt;
			mask = 33636363; -- TRACE_MASK_PLAYER_SOLID	
			min = Vector(-self.COLLISION_RADIUS_NARROW, -self.COLLISION_RADIUS_NARROW, self.PLAYER_STEP_MAX_SIZE + 2);
			max = Vector(self.COLLISION_RADIUS_NARROW, self.COLLISION_RADIUS_NARROW, playerHeadHeight - 2);
			startsolid = nil
		}
		TraceHull(trace)
		
		if trace.hit and not trace.startsolid
		then
		
			if self.debugDraw 
			then
				DebugDrawBox(trace.pos, trace.min, trace.max, 255, 255, 0, 0, self.lastThinkDelta)
				DebugDrawLine(trace.pos + Vector(0,0,32), trace.pos + 
				Vector(0,0,32) + trace.normal * offset:Length(), 255, 128, 255, false, self.lastThinkDelta)
			end
				
			return trace.normal * trace.normal:Dot(offset)
			
		elseif trace.startsolid
		then
			DebugCall(DebugDrawBox, trace.startpos, trace.min, trace.max, 0, 128, 255, 0, self.lastThinkDelta)
			return -offset
		end
	end
	
	return nil
end


function CPlayerPhysics:TracePlayerHeadCollision(playerEnt, playerProps)

	if not playerEnt:GetHMDAvatar() then return end

	local headCenter = playerEnt:GetHMDAvatar():GetCenter()
	local trace =
	{
		startpos = headCenter;
		endpos = headCenter;
		ignore = playerEnt;
		mask = 33636363; -- TRACE_MASK_PLAYER_SOLID	
		min = Vector(-self.HEAD_COLLISION_RADIUS, -self.HEAD_COLLISION_RADIUS, -self.HEAD_COLLISION_RADIUS);
		max = Vector(self.HEAD_COLLISION_RADIUS, self.HEAD_COLLISION_RADIUS, self.HEAD_COLLISION_RADIUS);
	}
	TraceHull(trace)
	
	if trace.hit or trace.startsolid
		and (not trace.enthit or self.PROP_CLASSES[trace.enthit:GetClassname()] == nil)
	then
		local bestPos = nil
		local bestDist = 0
		
		for ang = 0, 359, 30 
		do
			trace.startpos = headCenter + RotatePosition(Vector(0,0,0), QAngle(0, ang, 0), Vector(32, 0, 0))
			trace.startsolid = nil
				
			TraceHull(trace)
			
			DebugCall(DebugDrawBox, trace.pos, trace.min, trace.max, 0, 255, 0, 0, self.lastThinkDelta)
			DebugCall(DebugDrawLine, trace.startpos,trace.endpos, 255, 0, 255, false, self.lastThinkDelta)
			
			if not trace.startsolid and trace.fraction > bestDist
			then
				bestPos = trace.pos
				bestDist = trace.fraction
			end
		end
		
		if bestPos
		then
			self:SetPlayspaceOrigin(playerEnt, playerProps, 
				self:GetPlayspaceOrigin(playerEnt, playerProps) + bestPos - headCenter)
				
			playerProps.moveNextFrame = nil
		end
	end
end


function CPlayerPhysics:TracePlayerHeight(playerEnt, playerProps)

	local playerPos = self:GetPlayerOrigin(playerEnt, playerProps)
	local trace =
	{
		startpos = playerPos + Vector(0, 0, self.PULL_UP_DISTANCE);
		endpos = playerPos;
		ignore = playerEnt;
		mask = 33636363; -- TRACE_MASK_PLAYER_SOLID	
		min = Vector(-self.HEIGHT_TRACE_RADIUS, -self.HEIGHT_TRACE_RADIUS, 0);
		max = Vector(self.HEIGHT_TRACE_RADIUS, self.HEIGHT_TRACE_RADIUS, 1)
	}
	
	TraceHull(trace)
	
	-- Player below ground
	if trace.hit and not trace.startsolid
	then
		DebugCall(DebugDrawLine, trace.endpos, trace.pos, 255, 0, 0, true, 10)
		
		return trace.endpos.z - trace.pos.z, true, trace
	end
	trace.startpos = playerPos;
	trace.endpos = playerPos - Vector(0, 0, self.FALL_DISTANCE)
	trace.startsolid = nil
	
	TraceHull(trace)
	
	-- Player above ground
	if trace.hit and not trace.startsolid
	then
		DebugCall(DebugDrawLine, trace.startpos, trace.pos, 0, 255, 0, true, 10)

		return trace.startpos.z - trace.pos.z, true, trace
	elseif trace.startsolid
	then
		DebugCall(DebugDrawLine, trace.startpos, trace.endpos, 0, 255, 255, true, 10)
	end
	
	return self.FALL_DISTANCE, false, trace
end