
print("Range map script")

require("player_physics")
require("pause_manager")


g_VRScript.fallController = CPlayerPhysics()

g_VRScript.fallController:Init()

g_VRScript.pauseManager = CPauseManager()

function OnActivate()
	g_VRScript.pauseManager:Init()
	CustomGameEventManager:RegisterListener("toggle_debug_draw", ToggleDebugDraw)
end


function ToggleDebugDraw()
	g_VRScript.fallController:ToggleDebugDraw()
end


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