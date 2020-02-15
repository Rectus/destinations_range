
local gates = {}
local numGates = 0
local players = {}
local scoreBoard = {}

function SortByHeight(x, y)
	if x:GetCenter().z > y:GetCenter().z then
		return true
	else
		return false
	end
end

function Activate()
	local gateList = Entities:FindAllByName("slalom_gate")
	
	table.sort(gateList, SortByHeight)
		
	for idx, ent in ipairs(gateList) do
		gates[ent] = idx
		numGates = numGates + 1
	end	
	
end


function PassStart(params)
	
	local player = params.activator
	
	if not player then
		return
	end
	players[player] = {
		startTime = Time(),
		lastGate = 0,	
	}
	local playerID
	
	if g_VRScript.pauseManager:GetPlayerData(player).xuid
	then
		-- Get player Steam ID in order to be able to display their name
		playerID = tostring(g_VRScript.pauseManager:GetPlayerData(player).xuid)
	end
	
	if not playerID
	then
		playerID = player:GetUserID() 
	end
	
	print("Start, player: " .. playerID)
	EmitSoundOnClient("Slalom.Start", player)
end



function PassGate(params)
	
	local player = params.activator
	local gateNum = gates[params.caller] 
	
	if not player or not players[player] then
		return
	end
	
	if players[player].lastGate == gateNum - 1 then
	
		players[player].lastGate = gateNum
		
		--print("Passed: " .. gateNum)
		EmitSoundOnClient("Slalom.PassGate", player)
	elseif players[player].lastGate < gateNum - 1 then
	
		EmitSoundOnClient("Slalom.WrongGate", player)
	
	end
end



function PassFinish(params)
	local player = params.activator
	
	if not player or not players[player] then
		return
	end
	
	local playerID
	
	if g_VRScript.pauseManager:GetPlayerData(player).xuid
	then
		-- Get player Steam ID in order to be able to display their name
		playerID = tostring(g_VRScript.pauseManager:GetPlayerData(player).xuid)
	end
	
	if not playerID
	then
		playerID = player:GetUserID() 
	end

	if players[player].lastGate == numGates then
		local finishTime = Time() - players[player].startTime
		print("Finish: " .. finishTime)
		EmitSoundOnClient("Slalom.Finish", player)
		
		if scoreBoard[1] ~= nil then
			CustomGameEventManager:Send_ServerToAllClients( "slalom_time"
				, {id = playerID, time = finishTime, finished = true, prevBest = scoreBoard[1].time})
		else
			CustomGameEventManager:Send_ServerToAllClients( "slalom_time"
				, {id = playerID, time = finishTime, finished = true})
		end
		
		UpdateScoreBoard(playerID, finishTime)
	else	
		EmitSoundOnClient("Slalom.WrongGate", player)
		CustomGameEventManager:Send_ServerToAllClients( "slalom_time"
			, {id = playerID, time = 0, finished = false})
			
	end
	
	players[player] = nil
end

function UpdateScoreBoard(playerID, finishTime)

	local updated = false

	for idx, entry in ipairs(scoreBoard) do
		if entry.id == playerID then
			if finishTime < entry.time then
				scoreBoard[idx] = {id = playerID, time = finishTime}
				updated = true
			else
				return
			end
		end
	end

	if not updated then
		table.insert(scoreBoard, {id = playerID, time = finishTime})
	end
	
	table.sort(scoreBoard, function (x, y) if y.time > x.time then return true; end return false; end)
	
	for idx, entry in ipairs(scoreBoard) do
		CustomNetTables:SetTableValue("slalom_scoreboard", tostring(idx), entry)
	end
	
	CustomGameEventManager:Send_ServerToAllClients("slalom_scoreboard_update", nil)
end





