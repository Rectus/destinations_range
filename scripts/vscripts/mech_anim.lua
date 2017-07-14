

print("Mech IK script")

model:CreateIKChain("lfoot", "l_foot", 
	{
		solverInfo = {type = "perlin"};
		rules = 
		{
			--{name = "a", type="touch"}, 
			--{name = "b", type="procedural_target", bone="l_foot"}, 
			{name = "walk_l", type="ground", height = 0, trace_diameter=5}
		};
		
		--lockInfo = {boneInfluenceDriver = "l_foot", reverseFootLockBone = ""};

		--bones_point_along_positive_x = true
	}
)

model:CreateIKChain("rfoot", "r_foot", 
	{
		solverInfo = {type = "perlin"};
		rules = 
		{
			{name = "walk_r", type="ground", height = 0, trace_diameter=5}
		};
	}
)

--seq = model:CreateSequence({name="iktest", ikLocks = {{bone = "l_foot"}}})
