
print("Range map script")
require("pickup_manager")
g_VRScript.pickupManager = PickupManager()

function OnInit()
	

	
end

function OnGameplayStart()
	print("Range map script OnGameplayStart()")
	
end


function OnHMDAvatarAndHandsSpawned()
	print("Enabling pickup manager...")

	print(pickupManager)
	if pickupManager:Initialize()
	then
		g_VRScript.ScriptSystem_AddPerFrameUpdateFunction(OnThink)
	end
end

function OnThink()
	pickupManager:OnThink()
end

function PrintTable(table)
	for key, value in pairs(table)
	do
		
		if(type(value) == "table")
		
		then
			print(type(value) .. ": " .. key)
			for key2, value2 in pairs(value)
			do
				print("  " .. type(value2) .. ": " .. key2)
			end
		end
	end
end