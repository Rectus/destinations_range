model:CreateSequence(
	{
		name = "contract",
		poseParamX = model:CreatePoseParameter("spring", 0, 12, 0, false),
		sequences = {
			{
				"idle",
				"contracted"
			}
		},
	}
)