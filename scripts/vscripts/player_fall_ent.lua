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

local controller = nil
local thinkInterval = 1
local frameCount = 0

function EnableThink(cont, interval)
	thinkInterval = interval
	controller = cont
	
	g_VRScript.ScriptSystem_AddPerFrameUpdateFunction(FrameThink)
	
	ListenToGameEvent("player_spawn", EventPlayerSpawn, self)
end


function FrameThink()

	-- Moving the player every frame breaks hand positions.
	frameCount = frameCount + 1
	
	if frameCount >= 2 then
		frameCount = 0

		if controller
		then
			controller:PlayerMoveThink()
			controller:FrameThink()
		end
	end
	
end


function EventPlayerSpawn(params)

	local player = PlayerInstanceFromIndex(params.userid)

	-- Give players time to spawn HMD and hands
	thisEntity:SetThink(AddPlayers, "add_player", 5)
end


function AddPlayers()
	local players = Entities:FindAllByClassname("player")
	
	for _, player in pairs(players)
	do
		controller:AddPlayer(player)
	end
end