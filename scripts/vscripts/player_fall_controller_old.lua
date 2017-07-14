require "utils.deepprint"

PlayerFallContoller = class(
	{
		players;
		thinkEnt;
		traceIntervalCounter = 0;
		gravConstraintCounter = 0
	}, 
	
	{
		THINK_INTERVAL = 0.02;
		TRACE_INTERVAL = 1; -- Trace every n thinks
		GRAVITY_ACC = 386; -- 9.8 m/s2
		PLAYER_FALL_TERMINAL_SPEED = 2200; -- 56 m/s
		DRAG_COEFF = 7.795e-5; -- 56 m/s ^2 * x = 9.8 m/s2
		FALL_DISTANCE = 4096;
		PULL_UP_DISTANCE = 16;
		PULL_UP_SPEED = 50;
		SIDE_DRAG_DECEL = 100;
		PLAYER_STEP_MAX_SIZE = 12;
		PLAYER_COLLISON_BOUNDS = 
		{
			{dir = Vector(0, 1, 0), min = Vector(-3, 0, 0), max = Vector(3, 6, 72)},
			{dir = Vector(1, 0, 0), min = Vector(0, -3, 0), max = Vector(6, 3, 72)},
			{dir = Vector(0, -1, 0), min = Vector(-3, -6, 0), max = Vector(3, 0, 72)},
			{dir = Vector(-1, 0, 0), min = Vector(-6, -3, 0), max = Vector(0, 3, 72)}
		}
	},
	nil
)


function PlayerFallContoller:constructor()
	players = {}
	thinkEnt = SpawnEntityFromTableSynchronous("logic_script", {targetname = "fall_think_ent", vscripts = "player_fall_ent"})
end


function PlayerFallContoller:Init()
	thinkEnt:GetPrivateScriptScope().EnableThink(self, self.THINK_INTERVAL)
end

function PlayerFallContoller:AddPlayer(player)
	players[player] = {idle = true, constraints = {}, active = nil, fallTime = 0, velocity = Vector(0,0,0), stick = false, gravity = true}
	
end


function PlayerFallContoller:AddConstraint(player, constraint, isRigid)
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


function PlayerFallContoller:AddVelocity(player, inVelocity)
	if not players[player]
	then
		self:AddPlayer(player)
	end
		
	players[player].velocity = players[player].velocity + inVelocity
	
	-- Limit to terminal velocity
	local speed = players[player].velocity:Length()
	if speed > self.PLAYER_FALL_TERMINAL_SPEED
	then
		players[player].velocity = players[player].velocity:Normalized() * self.PLAYER_FALL_TERMINAL_SPEED
	end
	
	players[player].idle = false
end

-- Locks the player on the spot for a frame
function PlayerFallContoller:StickFrame(player)
	players[player].velocity = Vector(0,0,0)
	players[player].stick = true
	
end

function PlayerFallContoller:EnableGravity(player)
	self.gravConstraintCounter = self.gravConstraintCounter - 1
	if self.gravConstraintCounter <= 0
	then
		self.gravConstraintCounter = 0
		players[player].gravity = true
	end
end

function PlayerFallContoller:DisableGravity(player)
	self.gravConstraintCounter = self.gravConstraintCounter + 1

	players[player].gravity = false

end

-- Move the player, while testing for world collisions in the move direction
function PlayerFallContoller:MovePlayer(player, offset)

	local playerGroundHeight = Vector(0, 0, player:GetHMDAnchor():GetOrigin().z - player:GetCenter().z + self.PLAYER_STEP_MAX_SIZE)

	for _, bound in pairs(self.PLAYER_COLLISON_BOUNDS)
	do
		local startVector = player:GetCenter()
		local traceTable =
		{
			startpos = startVector;
			endpos = startVector + bound.dir;
			ignore = player;
			mask = 33636363; -- Hopefully TRACE_MASK_PLAYER_SOLID	
			min = bound.min + playerGroundHeight;
			max = bound.max
		}

		TraceHull(traceTable)

		-- Hack to detect if we hit something solid that isn't a prop. Not 100% reliable. 
		if traceTable.hit and (not traceTable.enthit 
			or (traceTable.enthit:GetClassname() ~= "prop_physics" 
			and traceTable.enthit:GetClassname() ~= "prop_physics_override"
			and traceTable.enthit:GetClassname() ~= "simple_physics_prop")) 
		then
			local normalLen = offset:Dot(bound.dir)
			if normalLen > 0
			then
				offset = offset - bound.dir * normalLen 
			end
			--DebugDrawBox(startVector, bound.min + playerGroundHeight, bound.max, 0, 255, 0, 0, self.THINK_INTERVAL)
		end
	end
	
	local height = self:TracePlayerHeight(player)
	
	if offset.z < 0 and offset.z > height
	then
		offset.z = height
	end

	player:GetHMDAnchor():SetOrigin(offset +  player:GetHMDAnchor():GetOrigin())
end

function PlayerFallContoller:RemoveConstraint(player, constraint)
	
	players[player].constraints[constraint] = nil
	
	if players[player].active == constraint
	then 
		players[player].active = nil
	end
	
	players[player].fallTime = 0
	players[player].idle = false
	
end


function PlayerFallContoller:IsActive(player, constraint)
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


function PlayerFallContoller:PlayerFallFrame()

	self.traceIntervalCounter = self.traceIntervalCounter + 1
	if self.traceIntervalCounter >= self.TRACE_INTERVAL
	then
		self.traceIntervalCounter = 0	
	end

	for playerEnt, playerProps in pairs(players)
	do
		local move = not playerProps.idle
		
		if playerProps.stick
		then
			playerProps.stick = false
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
	
		if move
		then		
			if playerProps.gravity
			then
				self:CalcPlayerGravity(playerEnt, playerProps)
			end
			
			if self.traceIntervalCounter == 0
			then
				self:TracePlayerSideCollision(playerEnt)
			end
			
			local zeroVel = false
			local speed = playerProps.velocity:Length()
			if speed > self.SIDE_DRAG_DECEL * self.THINK_INTERVAL
			then
				local dragFactor = (speed - self.SIDE_DRAG_DECEL * self.THINK_INTERVAL) / speed
				playerProps.velocity = playerProps.velocity * dragFactor
			else
				playerProps.velocity = Vector(0,0,0)
				zeroVel = true
			end
			
			
			if zeroVel
			then
				playerProps.idle = true
			end
			--print(playerProps.velocity)
			playerEnt:GetHMDAnchor():SetOrigin(playerEnt:GetHMDAnchor():GetOrigin() + playerProps.velocity * self.THINK_INTERVAL)
		end
	end
		
end


function sign(x)
	return x > 0 and 1 or x < 0 and -1 or 1
end


function PlayerFallContoller:CalcPlayerGravity(playerEnt, playerProps)

	local distanceLeft = 0
	local startVector = playerEnt:GetOrigin() + Vector(0, 0, playerEnt:GetHMDAnchor():GetOrigin().z - playerEnt:GetOrigin().z + 1)
	local traceTable =
	{
		startpos = startVector + Vector(0, 0, self.PULL_UP_DISTANCE);
		endpos = startVector;
		ignore = playerEnt;
		min = Vector(-3, -3, 0);
		max = Vector(3, 3, 2)
	}
	
	TraceLine(traceTable)
	
	if traceTable.hit and (not traceTable.enthit 
		or (traceTable.enthit:GetClassname() ~= "prop_physics" 
		and traceTable.enthit:GetClassname() ~= "prop_physics_override"
		and traceTable.enthit:GetClassname() ~= "simple_physics_prop"))
	then	
		distanceLeft = self.PULL_UP_DISTANCE - (traceTable.startpos - traceTable.pos).z
	else
		traceTable.startpos = startVector;
		traceTable.endpos = startVector - Vector(0, 0, self.FALL_DISTANCE)
		
		TraceLine(traceTable)

		if traceTable.hit 
		then
			--DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 255, 0, false, 10.2)		
			distanceLeft = (traceTable.pos - traceTable.startpos).z		
		end	
	end
	
	if distanceLeft > 0
	then
		-- Pull player upwards
		local factor = distanceLeft / self.PULL_UP_DISTANCE
		playerEnt:GetHMDAnchor():SetOrigin(playerEnt:GetHMDAnchor():GetOrigin() + Vector(0, 0, self.PULL_UP_SPEED * factor))
		
		playerProps.velocity = Vector(playerProps.velocity.x , playerProps.velocity.y, 0)
				+ (-traceTable.normal):Cross(Vector(0, 0, playerProps.velocity.z)):Cross(-traceTable.normal)
		
	else
		playerProps.velocity = Vector(playerProps.velocity.x ,playerProps.velocity.y, playerProps.velocity.z 
			- (self.GRAVITY_ACC * self.THINK_INTERVAL - self.DRAG_COEFF 
			* playerProps.velocity.z * playerProps.velocity.z)) 
		
		if distanceLeft >= playerProps.velocity.z * self.THINK_INTERVAL 
			or distanceLeft >= self.PULL_UP_DISTANCE
		then
			playerEnt:GetHMDAnchor():SetOrigin(playerEnt:GetHMDAnchor():GetOrigin() + Vector(0, 0, distanceLeft))
			
			playerProps.velocity = Vector(playerProps.velocity.x , playerProps.velocity.y, 0)
				+ (-traceTable.normal):Cross(Vector(0, 0, playerProps.velocity.z)):Cross(-traceTable.normal)
		end		
	end
end


function PlayerFallContoller:TracePlayerSideCollision(playerEnt)

	local playerGroundHeight = Vector(0, 0, playerEnt:GetHMDAnchor():GetOrigin().z - playerEnt:GetCenter().z + self.PLAYER_STEP_MAX_SIZE)

	for _, bound in pairs(self.PLAYER_COLLISON_BOUNDS)
	do
		local startVector = playerEnt:GetCenter()
		local traceTable =
		{
			startpos = startVector;
			endpos = startVector + bound.dir;
			ignore = playerEnt;
			mask = 33636363; -- Hopefully TRACE_MASK_PLAYER_SOLID	
			min = bound.min + playerGroundHeight;
			max = bound.max
		}

		TraceHull(traceTable)
		
		-- Hack to detect if we hit something solid that isn't a prop. Not 100% reliable. 
		if traceTable.hit and (not traceTable.enthit 
			or (traceTable.enthit:GetClassname() ~= "prop_physics" 
			and traceTable.enthit:GetClassname() ~= "prop_physics_override"
			and traceTable.enthit:GetClassname() ~= "simple_physics_prop")) 
		then
			local normalSpeed = players[playerEnt].velocity:Dot(bound.dir)
			if normalSpeed > 0
			then
				players[playerEnt].velocity = players[playerEnt].velocity - bound.dir * normalSpeed
			end
			--DebugDrawBox(startVector, bound.min + playerGroundHeight, bound.max, 0, 255, 0, 0, self.THINK_INTERVAL)
		end
	end
end


function PlayerFallContoller:TracePlayerHeight(playerEnt)

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
	
	return 0
end