
function SpawnLaw(params)

	if not params.activator or not g_VRScript.pauseManager:IsPlayerAllowedToSpawnItems(params.activator) then
		return
	end

	local spawnPoint = Entities:FindByName(nil, "law_spawned")
	
	local lawKeyvals = 
	{
		targetname = DoUniqueString("law");
		model = "models/weapons/law_weapon.vmdl";
		vscripts = "tool_law";
		
		origin = spawnPoint:GetOrigin();
		angles = spawnPoint:GetAngles();
		HasCollisionInHand = 1;
	}

	local law = SpawnEntityFromTableSynchronous("prop_destinations_tool", lawKeyvals)
	
end