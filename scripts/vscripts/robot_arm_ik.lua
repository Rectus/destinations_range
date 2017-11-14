

print("Arm IK script")

-- This is broken AF at the moment

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
		
		--[[lockInfo = 
		{	
			boneInfluenceDriver = "hand", 
			--boneInfluenceDriver = "__no_bone_yet__", 
			--reverseFootLockBone = "__no_bone_yet__", 
			--lockBoneInfluenceDriver = "", 
			maxLockDistanceToTarget = 64,
			hyperExtensionReleaseThreshold = 0.99
		};]]


	}
)

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