

print("Arm IK script")
require "utils.deepprint"

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
PrintTable(_G, 1, 10)

-- This is broken AF at the moment
--[[
local chain = model:CreateIKChain("arm_ik", 
	{
		ik_root_bone = "base",
		ik_end_effector_bone = "hand",
		ik_end_effector_target_bone = "hand",
		
		--master_blend_amount = 0, 
		target_orientation_speedlimit = 360,
		target_position_speedlimit = 10000,
		
		bones_point_along_positive_x = true,
		
		solverInfo = 
		{
			--type = "maya_two_bone"
			type = "perlin"
			--type = "fabrik"
		};

			
		rules = 
		{
			{ type="procedural_target", name = "arm_target", bone = "hand"}, 
			--{type="ground", height = 100, trace_diameter = 5},
			--{type="touch"}, 

		};
		constraints =
		{
			--{joint = "arm", type = "hinge", max_angle = 45, min_angle = -45},
			--{joint = "shoulder", type = "hinge", max_angle = 45, min_angle = -45},
		};
		]]
		--[[lockInfo = 
		{	
			boneInfluenceDriver = "hand", 
			--boneInfluenceDriver = "__no_bone_yet__", 
			--reverseFootLockBone = "__no_bone_yet__", 
			--lockBoneInfluenceDriver = "", 
			maxLockDistanceToTarget = 64,
			hyperExtensionReleaseThreshold = 0.99
		};]]

--[[
	}
)]]

--[[print(model:CreateIKControlRig("bug", 
	{
		legs = 
		{
		
		},
		
		pivot_bone = "root",
		pivot_influence = 1.0,
	
	}
))]]

--[[print(model:CreateIKControlRig("biped", 
	{
		pelvisBoneName = "",
		tiltBone = "",
		maxCenterOfMassDifference = 0,
		rightFootChain = "arm_ik",
		leftFootChain = "arm_ik",
	}
))]]

model:CreateSequence(
{
	name = "script_arm_open",
	--cmds = {
	--		{ cmd = "fetchframe", sequence = "arm_open", frame = 0, dst = 0 }
	--},
	--iklocks = {{ bone= "hand", posWeight= 0, rotWeight= 0 }}
}
)