

print("Mech IK script")

model:CreateIKChain("l_foot", 
	{
		ik_root_bone = "body",
		ik_end_effector_bone = "l_foot",
		ik_end_effector_target_bone = "l_foot",
	
		solverInfo = {type = "perlin"};
		rules = 
		{
			--{name = "a", type="touch"}, 
			--{name = "b", type="procedural_target", bone="l_foot"}, 
			{type="ground", height = 20, trace_diameter=5}
		};
		

		lockInfo = 
		{	
			boneInfluenceDriver = "__no_bone_yet__", 
			reverseFootLockBone = "__no_bone_yet__", 
			--lockBoneInfluenceDriver = "", 
			maxLockDistanceToTarget = 10,
			hyperExtensionReleaseThreshold = 0.99
		};

		constraints = {
				{ type="hinge", joint="l_calf", min_angle=-90, max_angle=20 }
		};

		bones_point_along_positive_x = true
	}
)

model:CreateIKChain("r_foot", 
	{
		ik_root_bone = "body",
		ik_end_effector_bone = "r_foot",
		solverInfo = {type = "perlin"};
		rules = 
		{
			{type="ground", height = 20, trace_diameter=5}
		};
		
		
		lockInfo = 
		{	
			boneInfluenceDriver = "__no_bone_yet__", 
			reverseFootLockBone = "__no_bone_yet__", 
			--lockBoneInfluenceDriver = "", 
			maxLockDistanceToTarget = 10,
			hyperExtensionReleaseThreshold = 0.99
		};
		
		constraints = {
				{ type="hinge", joint="r_calf", min_angle=0, max_angle=90 }
		};
		
		bones_point_along_positive_x = true
	}
)

model:CreateIKControlRig("biped", 
	{
		pelvisBoneName = "body",
		tiltBone = "body",
		maxCenterOfMassDifference = 0,
		rightFootChain = "r_foot",
		leftFootChain = "l_foot",
	}
)

--seq = model:CreateSequence({name="iktest", ikLocks = {{bone = "l_foot"}}})
