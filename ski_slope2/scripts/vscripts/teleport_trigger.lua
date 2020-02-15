
function TeleportPlayer(params)

	if params.activator and params.activator:GetClassname() == "player"
	then		
		local destination = Entities:FindByName(nil, "teleport_dest_top")
		
		local localPlayerOrigin = params.activator:GetAbsOrigin() - params.caller:GetAbsOrigin()

		g_VRScript.playerPhysController:SetPlayerPosition(params.activator, 
			localPlayerOrigin + destination:GetAbsOrigin(), true, true)
	end
end
