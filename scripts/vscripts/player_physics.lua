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
		players;
		thinkEnt;
		traceIntervalCounter = 0
	}, 
	
	{
		THINK_INTERVAL = 0.02;
		TRACE_INTERVAL = 1; -- Trace every n thinks
		GRAVITY_ACC = 386; -- 9.8 m/s2
		PLAYER_FALL_TERMINAL_SPEED = 2200; -- 56 m/s
		GRAVITY_DRAG_COEFF = 7.795e-5; -- 56 m/s ^2 * x = 9.8 m/s2
		FALL_DISTANCE = 1024;
		FALL_GLUE_DISTANCE = 4;
		PULL_UP_DISTANCE = 16;
		PULL_UP_SPEED = 50;
		SIDE_DRAG_DECEL = 100;
		PLAYER_STEP_MAX_SIZE = 12;
		
		GROUND_HIT_REDIR_FACTOR = 0.4;
		AIR_DRAG_DECEL = 5e-4;
		DRAG_DECEL = 8e-2;
		DRAG_CONSTANT = 1;
		STOP_SPEED = 30;
		PLAYER_COLLISION_DEPTH = 6;
		PLAYER_COLLISION_PUSH_FACTOR = 0.5;
		PLAYER_COLLISON_BOUNDS = 
		{
			{dir = Vector(0, 1, 0), min = Vector(-3, 0, 0), max = Vector(3, 1, 0), push = true},
			{dir = Vector(1, 0, 0), min = Vector(0, -3, 0), max = Vector(1, 3, 0), push = true},
			{dir = Vector(0, -1, 0), min = Vector(-3, -1, 0), max = Vector(3, 0, 0), push = true},
			{dir = Vector(-1, 0, 0), min = Vector(-1, -3, 0), max = Vector(0, 3, 0), push = true},
			{dir = Vector(0, 0, 1), min = Vector(-3, -3, 16), max = Vector(3, 3, -6), push = false}
		};
		PROP_CLASSES =
		{
			prop_physics = true;
			prop_physics_override = true;
			prop_destinations_physics = true;
			prop_destinations_tool = true;
			steamTours_item_tool = true;
			simple_physics_prop = true
		}
	},
	nil
)


function CPlayerPhysics:constructor()
	players = {}
	thinkEnt = SpawnEntityFromTableSynchronous("logic_script", 
		{targetname = "fall_think_ent", vscripts = "player_fall_ent"})
end


function CPlayerPhysics:Init()
	thinkEnt:GetPrivateScriptScope().EnableThink(self, self.THINK_INTERVAL)
end

function CPlayerPhysics:AddPlayer(player)

	if not players[player]
	then
		players[player] = {idle = true, constraints = {}, active = nil, velocity = Vector(0,0,0), prevPos = Vector(0,0,0),
			stick = false, gravity = true, groundNormal = Vector(0,0,1), onGround = true, 
			menuButtonHeld = false, isPaused = false, gravConstraints = {}}
	end
end


function CPlayerPhysics:AddConstraint(player, constraint, isRigid)
	if not players[player]
	then
		self:AddPlayer(player)
	
	end
	players[player].constraints[constraint] = {rigid = isRigid}
	
	if isRigid
	then
		players[player].active = constraint
	end
end


function CPlayerPhysics:AddVelocity(player, inVelocity)
	if not players[player]
	then
		self:AddPlayer(player)
	end
	
	if players[player].isPaused or player:IsVRDashboardShowing() or player:IsContentBrowserShowing()
	then
		return
	end
		
	players[player].velocity = players[player].velocity + inVelocity
	
	-- Limit to terminal velocity
	local speed = players[player].velocity:Length()
	if speed > self.PLAYER_FALL_TERMINAL_SPEED
	then
		players[player].velocity = players[player].velocity:Normalized() * self.PLAYER_FALL_TERMINAL_SPEED
	end
	
	if inVelocity.z ~= 0
	then
		players[player].onGround = false
	end
	
	players[player].idle = false
end


function CPlayerPhysics:GetVelocity(player)
	if not players[player]
	then
		self:AddPlayer(player)
	end
	return players[player].velocity
end


function CPlayerPhysics:IsPlayerOnGround(player)
	if not players[player]
	then
		self:AddPlayer(player)
	end
	return players[player].onGround or self:TracePlayerHeight(player) < self.FALL_GLUE_DISTANCE
end


-- Locks the player on the spot for a frame
function CPlayerPhysics:StickFrame(player)
	if not players[player]
	then
		self:AddPlayer(player)
	end

	players[player].velocity = Vector(0,0,0)
	players[player].stick = true
	
end


function CPlayerPhysics:EnableGravity(player, constraint)

	if not players[player]
	then
		self:AddPlayer(player)
	end

	players[player].gravConstraints[constraint] = nil
	
	local numConstraints = 0
  	for _ in pairs(players[player].gravConstraints) do numConstraints = numConstraints + 1 end
	
	if numConstraints <= 0
	then
		players[player].gravity = true
		players[player].idle = false
	end
end


function CPlayerPhysics:DisableGravity(player, constraint)

	if not players[player]
	then
		self:AddPlayer(player)
	end

	players[player].gravConstraints[constraint] = true

	players[player].gravity = false

end


function CPlayerPhysics:SetPaused(player, paused)

	if not players[player]
	then
		self:AddPlayer(player)
	end

	self.gravConstraintCounter = self.gravConstraintCounter + 1

	players[player].isPaused = paused

end


-- Move the player, while testing for world collisions in the move direction
function CPlayerPhysics:MovePlayer(player, offset, accelerate)

	if not players[player]
	then
		self:AddPlayer(player)
	end

	if players[player].isPaused or player:IsVRDashboardShowing() or player:IsContentBrowserShowing()
	then
		return
	end

	local playerHeadHeight = player:GetHMDAvatar():GetOrigin().z + 4 - player:GetOrigin().z
	local startVector = player:GetOrigin()

	for _, bound in pairs(self.PLAYER_COLLISON_BOUNDS)
	do
		
		local traceTable =
		{
			startpos = startVector;
			endpos = startVector + bound.dir * self.PLAYER_COLLISION_DEPTH;
			ignore = player;
			mask = 33636363; -- TRACE_MASK_PLAYER_SOLID	
			min = bound.min + Vector(0, 0, self.PLAYER_STEP_MAX_SIZE);
			max = bound.max + Vector(0, 0, playerHeadHeight);
		}
		TraceHull(traceTable)

		--DebugDrawBox(startVector, traceTable.min, traceTable.max, 0, 255, 0, 0, self.THINK_INTERVAL)
		if traceTable.hit --and (not traceTable.enthit or self.PROP_CLASSES[traceTable.enthit:GetClassname()] == nil)
		then
			local normalLen = offset:Dot(bound.dir)
			if normalLen > 0
			then
				offset = offset - bound.dir * normalLen 
			end
			
		end
	end
	
	local height = self:TracePlayerHeight(player)
	
	if offset.z < 0 and offset.z > height
	then
		offset.z = height
	end

	local newOrigin = offset + player:GetHMDAnchor():GetOrigin()

	if accelerate
	then
		-- Add velocity to give player momentum
		players[player].velocity = (newOrigin - players[player].prevPos) * (1 / self.THINK_INTERVAL)
	end

	player:GetHMDAnchor():SetOrigin(newOrigin)
	players[player].idle = false
	players[player].stick = true
end


function CPlayerPhysics:RemoveConstraint(player, constraint)
	
	if not players[player]
	then
		self:AddPlayer(player)
	end
	
	players[player].constraints[constraint] = nil
	
	if players[player].active == constraint
	then 
		players[player].active = nil
	end
	
	players[player].idle = false
	
end


function CPlayerPhysics:IsActive(player, constraint)
	if not player
	then 
		return false
	end
	
	if not players[player]
	then
		self:AddPlayer(player)
	end

	if players[player].active ~= nil
	then
		if players[player].active == constraint
		then
			return true
		end
	else
		return true
	end
	
	return false
end


function CPlayerPhysics:PlayerMoveFrame()

	self.traceIntervalCounter = self.traceIntervalCounter + 1
	if self.traceIntervalCounter >= self.TRACE_INTERVAL
	then
		self.traceIntervalCounter = 0	
	end
	


	for playerEnt, playerProps in pairs(players)
	do
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
					players[playerEnt].velocity = Vector(0,0,0)
					move = false
				end
			end
		end
	
		if self.traceIntervalCounter == 0
		then
			self:TracePlayerSideCollision(playerEnt)
		end
	
		if move
		then		
			
			self:CalcPlayerGravity(playerEnt, playerProps)
				
			playerProps.idle = self:CalcPlayerDrag(playerEnt, playerProps)
				
			--print(playerProps.velocity)
			if not playerProps.stick
			then		
				playerEnt:GetHMDAnchor():SetOrigin(playerEnt:GetHMDAnchor():GetOrigin() 
					+ playerProps.velocity * self.THINK_INTERVAL)
			else	
				playerProps.stick = false
			end	
			playerProps.prevPos = playerEnt:GetHMDAnchor():GetOrigin()
		end
	end
		
end


function sign(x)
	return x > 0 and 1 or x < 0 and -1 or 1
end



function CPlayerPhysics:CalcPlayerDrag(playerEnt, playerProps)

	
	if playerProps.onGround
	then
		--local groundMoveDir = playerProps.skiDirection:Cross(playerProps.groundNormal)
		--local skiMoveDir = groundMoveDir:Cross(playerProps.groundNormal)
		
		--local skiCoVelocity = playerProps.velocity:Dot(skiMoveDir)
		--local groundCoVelocity = playerProps.velocity:Dot(groundMoveDir)
		local speed = playerProps.velocity:Length()
		local dragVector = playerProps.velocity * (self.DRAG_CONSTANT + self.DRAG_DECEL * abs(speed)) * self.THINK_INTERVAL
		
		
		
		--[[if abs(dragVector:Dot(skiMoveDir)) > abs(skiCoVelocity) 
		then 
			dragVector = dragVector + skiMoveDir * (skiCoVelocity - dragVector:Dot(skiMoveDir))
		end
		
		if abs(dragVector:Dot(groundMoveDir)) > abs(groundCoVelocity) 
		then 
			dragVector = dragVector + groundMoveDir * (groundCoVelocity - dragVector:Dot(groundMoveDir))
		end]]
		--DebugDrawLine(playerEnt:GetCenter(), playerEnt:GetCenter() + playerProps.skiDirection * 10, 255, 255, 0, false, 0.02)
		--DebugDrawLine(playerEnt:GetCenter(), playerEnt:GetCenter() + dragVector, 0, 0, 255, false, 0.02)
		--DebugDrawLine(playerEnt:GetCenter(), playerEnt:GetCenter() + playerProps.velocity, 0, 255, 255, false, 0.02)
		playerProps.velocity = playerProps.velocity - dragVector
	else
		local vel = Vector(playerProps.velocity.x, playerProps.velocity.y, 0)
		local speed = vel:Length()
		local dragVector = vel * self.AIR_DRAG_DECEL * speed * self.THINK_INTERVAL
		
		if dragVector:Length() > speed
		then 
			dragVector = dragVector:Normalized() * speed
		end
		--DebugDrawLine(playerEnt:GetCenter(), playerEnt:GetCenter() + dragVector, 0, 0, 255, false, 0.02)
		--DebugDrawLine(playerEnt:GetCenter(), playerEnt:GetCenter() + playerProps.velocity, 0, 255, 255, false, 0.02)
		playerProps.velocity = playerProps.velocity - dragVector
	end
	
	--print("speed: " .. speed .. ", drag: " .. dragVector:__tostring())
	return playerProps.onGround and (playerProps.velocity:Length() < self.STOP_SPEED)
end



function CPlayerPhysics:CalcPlayerGravity(playerEnt, playerProps)

	local distanceLeft = -1024 -- Positive inside ground, negative above
	local playerOrigin = playerEnt:GetOrigin()
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
	if traceTable.hit --[[and (not traceTable.enthit 
		or (traceTable.enthit:GetClassname() ~= "prop_physics" 
		and traceTable.enthit:GetClassname() ~= "prop_physics_override"
		and traceTable.enthit:GetClassname() ~= "prop_destinations_physics"
		and traceTable.enthit:GetClassname() ~= "prop_destinations_tool"
		and traceTable.enthit:GetClassname() ~= "simple_physics_prop"))]]
	then	
		--[[if traceTable.enthit and traceTable.enthit:GetClassname() ~= "worldent"
		then
			print("Up: " .. traceTable.enthit:GetDebugName())
		end]]
	
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
			--[[if traceTable.enthit and traceTable.enthit:GetClassname() ~= "worldent"
			then
				print("Down: " .. traceTable.enthit:GetDebugName())
			end]]
		
			if self.debugDraw
			then
				DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 255, 0, false, 10)
			end		
			distanceLeft = (traceTable.pos - startVector).z
			--print(distanceLeft)	
		end	
	end
	

	if playerProps.gravity
	then
		playerProps.velocity = Vector(playerProps.velocity.x ,playerProps.velocity.y, playerProps.velocity.z 
			- (self.GRAVITY_ACC - self.GRAVITY_DRAG_COEFF 
			* playerProps.velocity.z * playerProps.velocity.z) * self.THINK_INTERVAL) 
	end
	
	-- Player close to the ground
	if ((distanceLeft >= playerProps.velocity.z * self.THINK_INTERVAL * self.TRACE_INTERVAL
		or abs(distanceLeft) <= self.FALL_GLUE_DISTANCE)) and playerProps.velocity.z <= 0
	then
	
		if distanceLeft <= 0 -- Player above ground
		then
			players[playerEnt].onGround = true
			playerEnt:GetHMDAnchor():SetOrigin(playerEnt:GetHMDAnchor():GetOrigin() + Vector(0, 0, distanceLeft))
			
			-- If the player velocity vector points through the ground, remove that part.
			if playerProps.velocity:Dot(traceTable.normal) < 0
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
			-- Player underground
			playerProps.velocity = Vector(playerProps.velocity.x, playerProps.velocity.y, 0) 
			players[playerEnt].onGround = false
			local pullUpDistance = self.PULL_UP_SPEED * self.THINK_INTERVAL * self.TRACE_INTERVAL
			playerEnt:GetHMDAnchor():SetOrigin(playerEnt:GetHMDAnchor():GetOrigin() + Vector(0, 0, pullUpDistance))
		end

	else
		players[playerEnt].onGround = false
	end		

end


function CPlayerPhysics:TracePlayerSideCollision(playerEnt)

	local playerHeadHeight = playerEnt:GetHMDAvatar():GetOrigin().z + 4 - playerEnt:GetOrigin().z
	local startVector = playerEnt:GetOrigin()

	-- Simple trace in the direction the player is moving.
	local traceTable =
	{
		startpos = startVector;
		endpos = startVector + players[playerEnt].velocity * self.THINK_INTERVAL;
		ignore = playerEnt;
		mask = 33636363; -- TRACE_MASK_PLAYER_SOLID	
		min = Vector(-3, -3, self.PLAYER_STEP_MAX_SIZE);
		max = Vector(3, 3, playerHeadHeight);
	}
	--DebugDrawBox(traceTable.startpos, traceTable.min, traceTable.max, 0, 255, 255, 0, self.THINK_INTERVAL)
	--DebugDrawBox(traceTable.endpos, traceTable.min, traceTable.max, 0, 0, 255, 0, self.THINK_INTERVAL)
	TraceHull(traceTable)

	if not traceTable.hit and not traceTable.startsolid
	then
		return
	end
	--DebugDrawBox(traceTable.pos, traceTable.min, traceTable.max, 0, 255, 0, 0, 2)

	local maxMoveDistance = 0
	
	if not players[playerEnt].idle 
	then
		maxMoveDistance = players[playerEnt].velocity:Length() *  self.THINK_INTERVAL
	end

	-- Do precise traces to find where the collsion is. 
	for _, bound in pairs(self.PLAYER_COLLISON_BOUNDS)
	do
		
		local traceTable =
		{
			startpos = startVector;
			endpos = startVector + bound.dir * (self.PLAYER_COLLISION_DEPTH + maxMoveDistance);
			ignore = playerEnt;
			mask = 33636363; -- TRACE_MASK_PLAYER_SOLID	
			min = bound.min + Vector(0, 0, self.PLAYER_STEP_MAX_SIZE);
			max = bound.max + Vector(0, 0, playerHeadHeight);
		}
		--DebugDrawBox(startVector, traceTable.min, traceTable.max, 0, 255, 0, 0, self.THINK_INTERVAL)
		--DebugDrawBox(startVector + bound.dir * self.PLAYER_COLLISION_DEPTH, traceTable.min, traceTable.max, 0, 255, 0, 0, self.THINK_INTERVAL)
		TraceHull(traceTable)
		
		-- Hack to detect if we hit something solid that isn't a prop. Not 100% reliable. 
		if traceTable.hit and (not traceTable.enthit or self.PROP_CLASSES[traceTable.enthit:GetClassname()] == nil)
		then
			local hitNormal = bound.dir
			if traceTable.normal:Length() > 0
			then
				hitNormal = -traceTable.normal
			end
		
			local normalSpeed = players[playerEnt].velocity:Dot(hitNormal)
			if normalSpeed > 0
			then
				players[playerEnt].velocity = players[playerEnt].velocity - hitNormal * normalSpeed
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

	local startVector = playerEnt:GetOrigin() + Vector(0, 0, playerEnt:GetHMDAnchor():GetOrigin().z - playerEnt:GetOrigin().z)
	local traceTable =
	{
		startpos = startVector + Vector(0, 0, self.PULL_UP_DISTANCE);
		endpos = startVector;
		ignore = playerEnt;
		min = Vector(-3, -3, 0);
		max = Vector(3, 3, 1)
	}
	
	TraceHull(traceTable)
	
	if traceTable.hit 
	then	
		return (traceTable.pos - traceTable.startpos).z
	end
	traceTable.startpos = startVector;
	traceTable.endpos = startVector - Vector(0, 0, self.FALL_DISTANCE)
	
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, 10.1)
	TraceHull(traceTable)
	
	if traceTable.hit 
	then
		--DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 255, 0, false, 10.2)
		
		local playerHeight = (traceTable.startpos - traceTable.pos).z
		
		--DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 255, 0, false, 10.2)
		return playerHeight
	end
	
	return 16384
end