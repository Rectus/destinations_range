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

local controller = nil


function EnableThink(cont)
	controller = cont
	
	g_VRScript.ScriptSystem_AddPerFrameUpdateFunction(FrameThink)
	
	ListenToGameEvent("player_spawn", EventPlayerSpawn, thisEntity)
	-- Give players time to spawn HMD and hands
	thisEntity:SetThink(AddPlayers, "add_player", 0.5)
end


function FrameThink()

	if controller
	then
		controller:PlayerMoveThink()
		controller:FrameThink()
	end
end


function EventPlayerSpawn(thisEntity, params)

	local player = PlayerInstanceFromIndex(params.userid)
	controller:AddPlayer(player)
end


function AddPlayers()
	local players = Entities:FindAllByClassname("player")
	
	for _, player in pairs(players)
	do
		controller:AddPlayer(player)
	end
end