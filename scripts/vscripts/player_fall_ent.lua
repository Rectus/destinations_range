
local controller = nil
local thinkInterval = 1

function EnableThink(cont, interval)
	thinkInterval = interval
	controller = cont
	thisEntity:SetThink(Think, "player_fall", thinkInterval)
	ListenToGameEvent("player_spawn", EventPlayerSpawn, self)
end

function Think()
	if controller
	then
		controller:PlayerMoveFrame()
	end
	
	return thinkInterval
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