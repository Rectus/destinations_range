
local controller = nil
local thinkInterval = 1

function EnableThink(cont, interval)
	thinkInterval = interval
	controller = cont
	thisEntity:SetThink(Think, "player_pause", thinkInterval)

end

function Think()
	if controller
	then
		controller:Think()
	end
	
	return thinkInterval
end



