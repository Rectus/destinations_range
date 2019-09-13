
local controller = nil

function EnableThink(cont)
	controller = cont
	g_VRScript.ScriptSystem_AddPerFrameUpdateFunction(Think)
end

function Think()
	if controller
	then
		controller:Think()
	end
end



