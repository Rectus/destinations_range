

model:CreateSequence(
	{
		name = "extended_pose",
		looping = true,
		poseParamX = model:CreatePoseParameter("pole_length", 0, 110.1, 0, false),
		sequences = {
			{
				"retracted",
				"extended"
			}
		},
	}
)