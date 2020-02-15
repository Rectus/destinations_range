
function SpawnLaw(params)
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