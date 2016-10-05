--[[
	Class that manages player falling.
	
	Copyright (c) 2016 Rectus
	
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


PlayerFallContoller = class(
	{
		players;
		thinkEnt
	}, 
	
	{
		THINK_INTERVAL = 0.02;
		PLAYER_FALL_SPEED = 8;
		FALL_DISTANCE = 4096
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
	players[player] = {idle = true, constraints = {}}
	
end


function PlayerFallContoller:AddConstraint(player, constraint)
	if not players[player]
	then
		self:AddPlayer(player)
	
	end
	players[player].constraints[constraint] = true
end

-- Tahe plaeyr falls to the ground once when all constraints have been removed.
function PlayerFallContoller:RemoveConstraint(player, constraint)
	
	players[player].constraints[constraint] = nil
	players[player].idle = false
	
end


function PlayerFallContoller:PlayerFallFrame()
	for playerEnt, properties in pairs(players)
	do
		local fall = not properties.idle
		
		if fall
		then
			for _, constraint in pairs(properties.constraints)
			do
				if constraint
				then
					fall = false
				end
			end
		end
	
		if fall
		then
			local distanceLeft = self:TracePlayerHeight(playerEnt)
		
			if distanceLeft <= self.PLAYER_FALL_SPEED
			then
				playerEnt:GetHMDAnchor():SetOrigin(playerEnt:GetHMDAnchor():GetOrigin() - Vector(0, 0, distanceLeft))
				
				properties.idle = true
			else
				distanceLeft = distanceLeft - self.PLAYER_FALL_SPEED
				playerEnt:GetHMDAnchor():SetOrigin(playerEnt:GetHMDAnchor():GetOrigin() - Vector(0, 0, self.PLAYER_FALL_SPEED))
			end
			
			
		end
	end
		
end



function PlayerFallContoller:TracePlayerHeight(playerEnt)

	local startVector = playerEnt:GetOrigin() + Vector(0, 0, playerEnt:GetHMDAnchor():GetOrigin().z - playerEnt:GetOrigin().z)
	local traceTable =
	{
		startpos = startVector;
		endpos = startVector - Vector(0, 0, self.FALL_DISTANCE);
		ignore = playerEnt
	}
	
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, 10.1)
	TraceLine(traceTable)
	
	if traceTable.hit 
	then
		--DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 255, 0, false, 10.2)
		
		local playerHeight = (traceTable.startpos - traceTable.pos).z
		
		--DebugDrawLine(traceTable.startpos, traceTable.pos, 0, 255, 0, false, 10.2)
		return playerHeight
	end
	
	return 0
end