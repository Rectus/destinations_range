require "animationsystem.sequences"             


model:CreateSequence(
    {
        name = "aim",
        poseParamX = model:CreatePoseParameter("dot_x", -1, 1, 0, false),
        poseParamY = model:CreatePoseParameter("dot_y", -1, 1, 0, false),
        --delta = true,
        sequences = 
		{
            {"xy_ul", "y_u", "xy_ur"}, {"x_l", "mid", "x_r"}, { "xy_dl", "y_d", "xy_dr"}
        },
    }
)

model:CreateSequence(
	{
		name = "idle",
		sequences = {
			{ "mid" }
		},
		addlayer = {
			 "aim"
		}
	}
)