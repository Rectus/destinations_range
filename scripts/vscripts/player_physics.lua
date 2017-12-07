--[[
	Player physics contoller
	
	Copyright (c) 2017 Rectus
	
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


--require "utils.deepprint"

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
		FALL_GLUE_DISTANCE = 8;
		PULL_UP_DISTANCE = 16;
		PULL_UP_SPEED = 100;
		PLAYER_STEP_MAX_SIZE = 12;
		PLAYER_FULL_HEIGHT = 72;
		PLAYER_HEIGHT_DRAG_FACTOR = 1.0;
		
		GROUND_HIT_REDIR_FACTOR = 0.4;
		AIR_DRAG_DECEL = 5e-4;
		DRAG_DECEL = 1e-1;
		DRAG_CONSTANT = 2;
		STOP_SPEED = 50;
		MAP_CUBE_BOUND = 16000;
		PLAYER_COLLISION_DEPTH = 6;
		PLAYER_COLLISION_PUSH_FACTOR = 0.2;
		PLAYER_COLLISON_BOUNDS = 
		{
			{dir = Vector(0, 1, 0), min = Vector(-3, 0, 0), max = Vector(3, 1, 0), push = false},
			{dir = Vector(1, 0, 0), min = Vector(0, -3, 0), max = Vector(1, 3, 0), push = false},
			{dir = Vector(0, -1, 0), min = Vector(-3, -1, 0), max = Vector(3, 0, 0), push = false},
			{dir = Vector(-1, 0, 0), min = Vector(-1, -3, 0), max = Vector(0, 3, 0), push = false},
			{dir = Vector(0, 1, 0), min = Vector(-3, 0, 0), max = Vector(3, 1, 0), push = true, headonly = true},
			{dir = Vector(1, 0, 0), min = Vector(0, -3, 0), max = Vector(1, 3, 0), push = true, headonly = true},
			{dir = Vector(0, -1, 0), min = Vector(-3, -1, 0), max = Vector(3, 0, 0), push = true, headonly = true},
			{dir = Vector(-1, 0, 0), min = Vector(-1, -3, 0), max = Vector(0, 3, 0), push = true, headonly = true},
			{dir = Vector(0, 0, 1), min = Vector(-3, -3, 16), max = Vector(3, 3, -6), push = false}
		};
		PROP_CLASSES =
		{
			prop_physics = true;
			prop_physics_override = true;
			prop_destinations_physics = true;
			prop_destinations_tool = true;
			steamTours_item_tool = true;
			simple_physics_prop = true;
			prop_destinations_game_trophy = true;
		}
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

	if not self.players[player]
	then
		self.players[player] = 
		{
			idle = true, 
			constraints = {}, 
			active = nil, 
			velocity = Vector(0,0,0), 
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
			lerpOrigin = nil,
			lerpTime = 0,
			moveNextFrame = nil,
			groundEnt = nil,
			velChangeThisThink = false,
			--[[turnSoundCounter = 0,
			moveSoundLevel = 0,
			moveSoundCounter = 0,
			previousSkiDir = nil]]
		}
	end
end


function CPlayerPhysics:AddConstraint(player, constraint, isRigid)
	if not self.players[player]
	then
		self:AddPlayer(player)
	
	end
	self.players[player].constraints[constraint] = {rigid = isRigid}
	
	if isRigid
	then
		self.players[player].active = constraint
	end
end


function CPlayerPhysics:AddVelocity(player, inVelocity)
	if not self.players[player]
	then
		self:AddPlayer(player)
	end
	
	if self.players[player].isPaused or player:IsVRDashboardShowing() or player:IsContentBrowserShowing()
	then
		return
	end
		
	self.players[player].velocity = self.players[player].velocity + inVelocity
	
	-- Limit to terminal velocity
	local speed = self.players[player].velocity:Length()
	if speed > self.PLAYER_FALL_TERMINAL_SPEED
	then
		self.players[player].velocity = self.players[player].velocity:Normalized() * self.PLAYER_FALL_TERMINAL_SPEED
	end
	
	if inVelocity.z ~= 0
	then
		self.players[player].onGround = false
		
		-- Ignore forced movement unless we have a rigid constraint.
		if not self.players[player].active or not self.players[player].active.rigid then
			self.players[player].moveNextFrame = nil
		end
	end
	
	self.players[player].velChangeThisThink = true
	
	self.players[player].idle = false
end


function CPlayerPhysics:SetVelocity(player, inVelocity)
	if not self.players[player]
	then
		self:AddPlayer(player)
	end
		
	self.players[player].velocity = inVelocity
	
	-- Limit to terminal velocity
	local speed = self.players[player].velocity:Length()
	if speed > self.PLAYER_FALL_TERMINAL_SPEED
	then
		self.players[player].velocity = self.players[player].velocity:Normalized() * self.PLAYER_FALL_TERMINAL_SPEED
	end
	
	if inVelocity.z ~= 0
	then
		self.players[player].onGround = false
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
	
	return self.players[player].velocity
end


function CPlayerPhysics:GetPlayerHeight(player)
	if not self.players[player]
	then
		self:AddPlayer(player)
	end
	
	if self.players[player].idle then
		return 0
	end
	
	local height = self:TracePlayerHeight(player)
	
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
	return self.players[player].onGround or self:TracePlayerHeight(player) < self.FALL_GLUE_DISTANCE
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

	--self.gravConstraintCounter = self.gravConstraintCounter + 1

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
function CPlayerPhysics:MovePlayer(player, offset, accelerate, grounded)

	grounded = grounded or false

	if not self.players[player]
	then
		self:AddPlayer(player)
	end

	if self.players[player].isPaused or player:IsVRDashboardShowing() or player:IsContentBrowserShowing()
	then
		return
	end

	local playerHeadHeight = player:GetHMDAvatar():GetOrigin().z + 4 - player:GetOrigin().z
	local startVector = player:GetOrigin()

	local maxMoveDistance = 5
	
	if not self.players[player].idle 
	then
		maxMoveDistance = max(self.players[player].velocity:Length() * self.lastThinkDelta, maxMoveDistance)
	end

	-- Do precise traces to find where the collsion is. 
	for _, bound in pairs(self.PLAYER_COLLISON_BOUNDS)
	do
		local zOffset = self.PLAYER_STEP_MAX_SIZE
	
		if bound.headonly
		then
			zOffset = playerHeadHeight - 16 
		end
		
		local traceTable =
		{
			startpos = startVector;
			endpos = startVector + bound.dir * (self.PLAYER_COLLISION_DEPTH + maxMoveDistance);
			ignore = player;
			mask = 33636363; -- TRACE_MASK_PLAYER_SOLID	
			min = bound.min + Vector(0, 0, zOffset);
			max = bound.max + Vector(0, 0, playerHeadHeight);
		}
		TraceHull(traceTable)

		--DebugDrawBox(startVector, traceTable.min, traceTable.max, 0, 255, 0, 0, self.lastThinkDelta)
		if traceTable.hit --and (not traceTable.enthit or self.PROP_CLASSES[traceTable.enthit:GetClassname()] == nil)
		then
			--DebugDrawBox(traceTable.pos, traceTable.min, traceTable.max, 0, 255, 0, 0, 2)
			local normalLen = offset:Dot(bound.dir)
			if normalLen > 0
			then
				offset = offset - bound.dir * normalLen 
			end
			
		end
	end
	
	local height = self:TracePlayerHeight(player)
	
	self.players[player].idle = false
	if not grounded and self.players[player].velocity.z <= 0 then
		self.players[player].stick = true
	elseif height > self.FALL_GLUE_DISTANCE then
		self.players[player].onGround = false
	end
	
	if (height + offset.z < 0) or height < 0
	then
		offset.z = min(-height, self.PULL_UP_SPEED * self.lastThinkDelta)
	elseif height > 0 and offset.z <= 0 and grounded and height < self.FALL_GLUE_DISTANCE then
		offset.z = max(-height , -self.PULL_UP_SPEED * self.lastThinkDelta)
	elseif grounded then
		offset.z = 0
	end

	local newOrigin = offset + player:GetHMDAnchor():GetOrigin()

	if accelerate
	then
		if self.players[player].onGround then
			-- Add velocity to give player momentum
			self.players[player].velocity = (newOrigin - self.players[player].prevPos) * (1 / self.lastThinkDelta)
			self.players[player].velocity.z = 0
		end
	end
	if not self.players[player].velChangeThisThink then
		self.players[player].moveNextFrame = newOrigin
	end
	--self:CheckMapBounds(player, self.players[player])
end


function CPlayerPhysics:RemoveConstraint(player, constraint)
	
	if not self.players[player]
	then
		self:AddPlayer(player)
	end
	
	self.players[player].constraints[constraint] = nil
	
	if self.players[player].active == constraint
	then 
		self.players[player].active = nil
	end
	
	self.players[player].idle = false
	
end


function CPlayerPhysics:IsActive(player, constraint)
	if not player
	then 
		return false
	end
	
	if not self.players[player]
	then
		self:AddPlayer(player)
	end

	if self.players[player].active ~= nil
	then
		if self.players[player].active == constraint
		then
			return true
		end
	else
		return true
	end
	
	return false
end


---------------------------------------------------
-- Callbacks
---------------------------------------------------


function CPlayerPhysics:PlayerMoveThink()

	local time = Time()
	self.lastThinkDelta = time - self.lastThinkTime
	self.lastThinkTime = time

	
	for playerEnt, playerProps in pairs(self.players)
	do
		if not playerEnt or not IsValidEntity(playerEnt) then
		
			self.players[playerEnt] = nil
		else
			playerProps.velChangeThisThink = false
			playerProps.lerpTime = 0
		
			local move = not playerProps.idle
			
			if playerProps.isPaused or playerEnt:IsVRDashboardShowing() or playerEnt:IsContentBrowserShowing()
			then
				move = false
			end
				
			
			if move
			then
				for _, constraint in pairs(playerProps.constraints)
				do
					if constraint and constraint.rigid
					then
						self.players[playerEnt].velocity = Vector(0,0,0)
						move = false
					end
				end
			end
		
			self:TracePlayerSideCollision(playerEnt)
		
			if move
			then		
				
				self:CalcPlayerGravity(playerEnt, playerProps)
					
				playerProps.idle = self:CalcPlayerDrag(playerEnt, playerProps)
				
				self:CheckMapBounds(playerEnt, playerProps)
				
				if self.debugDraw then
					DebugDrawLine(playerEnt:GetCenter(), 
						playerEnt:GetCenter() + playerProps.velocity * 0.1, 0, 255, 255, false, self.lastThinkDelta)
				end
					
				--print(playerProps.velocity)
				if not playerProps.stick
				then	
					--[[if playerProps.moveNextFrame then
						playerEnt:GetHMDAnchor():SetOrigin(playerProps.moveNextFrame)
						playerProps.moveNextFrame = nil
						
					else			
						playerEnt:GetHMDAnchor():SetOrigin(playerEnt:GetHMDAnchor():GetOrigin() 
							+ playerProps.velocity * self.lastThinkDelta)
							
					end]]

					playerProps.lerpOrigin = playerEnt:GetHMDAnchor():GetOrigin() 
						+ playerProps.velocity * self.lastThinkDelta
				else	
					playerProps.stick = false
				end	
				playerProps.prevPos = playerEnt:GetHMDAnchor():GetOrigin()
			else
				playerProps.lerpOrigin = nil
			end
		end
	end
end


function CPlayerPhysics:FrameThink()
	local time = Time()
	local frameDelta = time - self.lastFrameTime
	self.lastFrameTime = time


	for playerEnt, playerProps in pairs(self.players)
	do
		if IsValidEntity(playerEnt) then
			playerProps.lerpTime = Clamp(playerProps.lerpTime + frameDelta / self.lastThinkDelta, 0, 1)
		
			-- Reactivate movement if the player teleported or got moved by other means.
			if playerProps.prevPlayAreaPos ~= playerEnt:GetHMDAnchor():GetOrigin() then
				playerProps.idle = false
			end
	
			if playerProps.moveNextFrame then
				playerEnt:GetHMDAnchor():SetOrigin(playerProps.moveNextFrame)
				playerProps.prevPos = playerProps.moveNextFrame
				playerProps.moveNextFrame = nil
				
			elseif playerProps.lerpOrigin then
		
				playerEnt:GetHMDAnchor():SetOrigin(
					VectorLerp(playerProps.lerpTime, playerProps.prevPos, playerProps.lerpOrigin))
					
				if playerProps.lerpTime >= 1 then
					playerProps.lerpOrigin = nil
				end
			end
			playerProps.prevPlayAreaPos = playerEnt:GetHMDAnchor():GetOrigin()
		end
	end
end


---------------------------------------------------
-- Internal
---------------------------------------------------



function sign(x)
	return x > 0 and 1 or x < 0 and -1 or 1
end


function CPlayerPhysics:CheckMapBounds(playerEnt, playerProps)
	local origin = playerEnt:GetHMDAnchor():GetOrigin()
	
	if abs(origin.x) > self.MAP_CUBE_BOUND then
		if sign(playerProps.velocity.x) == sign(origin.x) then
			playerProps.velocity = Vector(0, playerProps.velocity.y, playerProps.velocity.z)
		end
		playerEnt:GetHMDAnchor():SetOrigin(Vector(self.MAP_CUBE_BOUND * sign(origin.x), origin.y, origin.z))
	end
	
	if abs(origin.y) > self.MAP_CUBE_BOUND then
		if sign(playerProps.velocity.y) == sign(origin.y) then
			playerProps.velocity = Vector(playerProps.velocity.x, 0, playerProps.velocity.z)
		end
		playerEnt:GetHMDAnchor():SetOrigin(Vector(origin.x, self.MAP_CUBE_BOUND * sign(origin.y), origin.z))
	end
	
	if abs(origin.z) > self.MAP_CUBE_BOUND then
		if sign(playerProps.velocity.z) == sign(origin.z) then
			playerProps.velocity = Vector(playerProps.velocity.x, playerProps.velocity.y, 0)
		end
		playerEnt:GetHMDAnchor():SetOrigin(Vector(origin.x, origin.y, self.MAP_CUBE_BOUND * sign(origin.z)))
	end
	
end


function CPlayerPhysics:CalcPlayerDrag(playerEnt, playerProps)

	local dragVector = nil
	local speed = playerProps.velocity:Length()
	local relativePlayerVel = playerProps.velocity
	
	if playerProps.onGround
	then

		
		if not playerProps.dragOverride
		then
			local playerHeightFac = ((playerEnt:GetCenter().z - playerEnt:GetHMDAnchor():GetOrigin().z) * 2) 
			/ self.PLAYER_FULL_HEIGHT * self.PLAYER_HEIGHT_DRAG_FACTOR
		
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
		

		playerProps.velocity = playerProps.velocity - dragVector
		
	else
	
		local playerHeightFac = ((playerEnt:GetCenter().z - playerEnt:GetHMDAnchor():GetOrigin().z) * 2) 
			/ self.PLAYER_FULL_HEIGHT * self.PLAYER_HEIGHT_DRAG_FACTOR
	
		local vel = Vector(playerProps.velocity.x, playerProps.velocity.y, 0)
		speed = vel:Length()
		dragVector = vel * playerProps.airDragLinear * speed * self.lastThinkDelta * playerHeightFac
		
		if dragVector:Length() > speed
		then 
			dragVector = dragVector:Normalized() * speed
		end
		
		playerProps.velocity = playerProps.velocity - dragVector
	end
	
	if self.debugDraw then 
		DebugDrawLine(playerEnt:GetCenter(), 
			playerEnt:GetCenter() + dragVector, 0, 0, 255, false, self.lastThinkDelta)
	end
	
	--print("speed: " .. speed .. ", drag: " .. dragVector:__tostring())
	
	if playerProps.onGround then
	
		if playerProps.groundEnt and IsValidEntity(playerProps.groundEnt) 
			and playerProps.groundEnt:GetEntityIndex() > 0 then

			if (playerProps.velocity - GetPhysVelocity(playerProps.groundEnt)):Length() < 5 then
				playerProps.velocity = GetPhysVelocity(playerProps.groundEnt)
			end
		
			return false
		
		elseif playerProps.velocity:Length() < self.STOP_SPEED then 
			return true
		end
	end
	return false
end



function CPlayerPhysics:CalcPlayerGravity(playerEnt, playerProps)

	local distanceLeft = -1024 -- Positive inside ground, negative above
	local playerOrigin = playerEnt:GetOrigin()
	local foundGround = false
	local startVector =  Vector(playerOrigin.x, playerOrigin.y, playerEnt:GetHMDAnchor():GetOrigin().z)
	local traceTable =
	{
		startpos = startVector + Vector(0, 0, self.PULL_UP_DISTANCE);
		endpos = startVector  + Vector(0, 0, -1);
		ignore = playerEnt;
		mask = 33636363; -- TRACE_MASK_PLAYER_SOLID	
		min = Vector(-3, -3, 0);
		max = Vector(3, 3, 2)
	}
	
	TraceHull(traceTable)
	
	-- Player below ground
	if traceTable.hit 
	then	
		foundGround = true
		
		if self.debugDraw
		then
			DebugDrawLine(traceTable.startpos, traceTable.pos, 255, 0, 0, true, 10)
		end		
	
		distanceLeft = self.PULL_UP_DISTANCE - (traceTable.startpos - traceTable.pos).z
	else
		traceTable.startpos = startVector + Vector(0, 0, 4);
		traceTable.endpos = startVector - Vector(0, 0, self.FALL_DISTANCE)
		
		TraceHull(traceTable)

		-- Player above ground
		if traceTable.hit
		then
			foundGround = true
			
			if self.debugDraw
			then
				DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 255, 0, false, 10)
			end		
			distanceLeft = (traceTable.pos - startVector).z
			--print(distanceLeft)	
		end	
	end
	

	if playerProps.gravity and foundGround
	then
		playerProps.velocity = Vector(playerProps.velocity.x, playerProps.velocity.y, playerProps.velocity.z 
			- (self.GRAVITY_ACC - self.GRAVITY_DRAG_COEFF 
			* playerProps.velocity.z * playerProps.velocity.z) * self.lastThinkDelta) 
	end
	
	local groundNormalDot = playerProps.velocity:Dot(traceTable.normal)
	
	-- Player close to the ground and not moving away from it
	if ((distanceLeft >= playerProps.velocity.z * self.lastThinkDelta
		or abs(distanceLeft) <= self.FALL_GLUE_DISTANCE)) and groundNormalDot <= 0
	then
	
		self.players[playerEnt].groundEnt = traceTable.enthit
		self.players[playerEnt].onGround = true
		playerEnt:GetHMDAnchor():SetOrigin(playerEnt:GetHMDAnchor():GetOrigin() + Vector(0, 0, distanceLeft))
		
		-- If the player velocity vector points through the ground, remove that part and use the rest to accelerate the player.
		if groundNormalDot < 0
		then
			if self.debugDraw
			then
				local redirVec = playerProps.velocity - 
					(-traceTable.normal):Cross(playerProps.velocity):Cross(-traceTable.normal) 
				DebugDrawLine(playerEnt:GetCenter(), playerEnt:GetCenter() + redirVec * 10, 255, 0, 255, false, 0.02)
			end
		
			playerProps.velocity = (-traceTable.normal):Cross(playerProps.velocity):Cross(-traceTable.normal) 

		end
	
	else
		self.players[playerEnt].groundEnt = nil
		self.players[playerEnt].onGround = false
	end		

end


function CPlayerPhysics:TracePlayerSideCollision(playerEnt)

	local playerHeadHeight = playerEnt:GetHMDAvatar():GetOrigin().z + 4 - playerEnt:GetOrigin().z
	local startVector = playerEnt:GetOrigin()

	-- Simple trace in the direction the player is moving.
	local traceTable =
	{
		startpos = startVector;
		endpos = startVector + self.players[playerEnt].velocity * self.lastThinkDelta;
		ignore = playerEnt;
		mask = 33636363; -- TRACE_MASK_PLAYER_SOLID	
		min = Vector(-3, -3, self.PLAYER_STEP_MAX_SIZE);
		max = Vector(3, 3, playerHeadHeight);
	}
	--DebugDrawBox(traceTable.startpos, traceTable.min, traceTable.max, 0, 255, 255, 0, self.lastThinkDelta)
	--DebugDrawBox(traceTable.endpos, traceTable.min, traceTable.max, 0, 0, 255, 0, self.lastThinkDelta)
	TraceHull(traceTable)

	if not traceTable.hit and not traceTable.startsolid
	then
		return
	end
	--DebugDrawBox(traceTable.pos, traceTable.min, traceTable.max, 0, 255, 0, 0, 2)

	local maxMoveDistance = 5
	
	if not self.players[playerEnt].idle 
	then
		maxMoveDistance = max(self.players[playerEnt].velocity:Length() * self.lastThinkDelta, maxMoveDistance)
	end

	-- Do precise traces to find where the collsion is. 
	for _, bound in pairs(self.PLAYER_COLLISON_BOUNDS)
	do
		local zOffset = self.PLAYER_STEP_MAX_SIZE
	
		if bound.headonly
		then
			zOffset = playerHeadHeight - 16 
		end
		
		local traceTable =
		{
			startpos = startVector;
			endpos = startVector + bound.dir * (self.PLAYER_COLLISION_DEPTH + maxMoveDistance);
			ignore = playerEnt;
			mask = 33636363; -- TRACE_MASK_PLAYER_SOLID	
			min = bound.min + Vector(0, 0, zOffset);
			max = bound.max + Vector(0, 0, playerHeadHeight);
		}
		--DebugDrawBox(startVector, traceTable.min, traceTable.max, 0, 255, 0, 0, self.lastThinkDelta)
		--DebugDrawBox(startVector + bound.dir * self.PLAYER_COLLISION_DEPTH, traceTable.min, traceTable.max, 0, 255, 0, 0, self.lastThinkDelta)
		TraceHull(traceTable)
		
		-- Hack to detect if we hit something solid that isn't a prop. Not 100% reliable. 
		if traceTable.hit and not traceTable.startsolid and 
			(not traceTable.enthit or self.PROP_CLASSES[traceTable.enthit:GetClassname()] == nil)
		then
			local hitNormal = bound.dir
			if not VectorIsZero(traceTable.normal)
			then
				hitNormal = -traceTable.normal
			end
		
			local normalSpeed = self.players[playerEnt].velocity:Dot(hitNormal)
			if normalSpeed > 0
			then
				self.players[playerEnt].velocity = self.players[playerEnt].velocity - hitNormal * normalSpeed
			end
			
			if bound.push
			then
				playerEnt:GetHMDAnchor():SetOrigin(playerEnt:GetHMDAnchor():GetOrigin() -
					hitNormal * (1 - traceTable.fraction) * self.PLAYER_COLLISION_PUSH_FACTOR)
			end
		end
	end
	
end


function CPlayerPhysics:TracePlayerHeight(playerEnt)

	local playerOrigin = playerEnt:GetOrigin()
	local startVector =  Vector(playerOrigin.x, playerOrigin.y, playerEnt:GetHMDAnchor():GetOrigin().z)
	local traceTable =
	{
		startpos = startVector + Vector(0, 0, self.PULL_UP_DISTANCE);
		endpos = startVector;
		ignore = playerEnt;
		mask = 33636363; -- TRACE_MASK_PLAYER_SOLID	
		min = Vector(-3, -3, 0);
		max = Vector(3, 3, 2)
	}
	
	TraceHull(traceTable)
	
	if traceTable.hit 
	then
		if self.debugDraw
		then
			DebugDrawLine(traceTable.startpos, traceTable.pos, 192, 0, 0, true, 10)	
		end
		return traceTable.endpos.z - traceTable.pos.z
	end
	traceTable.startpos = startVector;
	traceTable.endpos = startVector - Vector(0, 0, self.FALL_DISTANCE)
	
	
	TraceHull(traceTable)
	
	if traceTable.hit 
	then
		if self.debugDraw
		then
			DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 192, 0, true, 10)
		end
		return traceTable.startpos.z - traceTable.pos.z
	end
	
	return 16384
end