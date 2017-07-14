

print("Arm IK script")

local chain = model:CreateIKChain("arm_ik", "hand", 
	{
		--solverInfo = {type = "maya_two_bone",bones_point_along_positive_x = true};
		solverInfo = {type = "perlin", bones_point_along_positive_y = true};
		rules = 
		{
			{name = "arm_target", type="procedural_target", bone="hand"}, 

		};
		
		--lockInfo = {boneInfluenceDriver = "l_foot", reverseFootLockBone = ""};

		bones_point_along_positive_y = true
	}
)

model:CreateSequence(
{
	name = "script_arm_open",
	--cmds = {
	--		{ cmd = "fetchframe", sequence = "arm_open", frame = 0, dst = 0 }
	--},
	iklocks = {{ bone= "hand", posWeight= 0, rotWeight= 0 }}
}
)