
print("Range map script")
--require("new_controller")
require("pickup_manager")
require("player_physics")
g_VRScript.pickupManager = PickupManager()
g_VRScript.fallController = CPlayerPhysics()
g_VRScript.fallController:Init()

g_VRScript.precacheList = {}

function OnInit()
	--EntityFramework:InstallClasses() 

	
end


function OnPrecache(context)
	PrecacheEntityListFromTable(precacheList, context)
end


function AddEntityPrecache(keyvals)
	precacheList[keyvals] = keyvals
end


function OnGameplayStart()
	print("Range map script OnGameplayStart()")
	
end


function OnHMDAvatarAndHandsSpawned()
	--print("Enabling pickup manager...")

	--print(pickupManager)
	--if pickupManager:Initialize()
	--then
		--g_VRScript.ScriptSystem_AddPerFrameUpdateFunction(OnThink)
		--pickupManager.debug = true
	--end
	
	--PrintTable(EntityClasses, 0, 10)
end

--function OnThink()
	--pickupManager:OnThink()
--end

function PrintTable(table, level, maxlevel)

	local indent = ""
	
	for i = 0, level - 1, 1
	do
		indent = indent .. " "
	end

	for key, value in pairs(table)
	do
		if value == _G
		then
			print(indent .. type(value) .. ": " .. tostring(key))
			print(indent .. "Global table reference!")
			
		elseif value == table
		then
			print(indent .. type(value) .. ": " .. tostring(key))
			print(indent .. "Self reference!")
			
		elseif type(value) == "table"	
		then
			print(indent .. type(value) .. ": " .. tostring(key))
			if level < maxlevel
			then
				PrintTable(value, level + 1, maxlevel)
			else
				print("Max recursion!")
			end
			
		elseif type(value) == "function"
		then
			print(indent .. type(value) .. ": " .. key)
						
		elseif type(value) == "userdata"
		then
			print(indent .. type(value) .. ": " .. key)
			
		else
			print(indent .. key .. " = " .. tostring(value))
		end
	end
end