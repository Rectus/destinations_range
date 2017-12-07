model:CreateSequence(
    {
        name = "idle",
        poseParamX = model:CreatePoseParameter("spin", -1, 1, 0, false),
        --delta = true,
        fadeintime = 0.2,
        fadeouttime = 0.2,
        --autoplay = true,
        looping = true,
        sequences = 
		{
            {"@spin_ccw", "@spin_ccw_slow","@idle", "@spin_cw_slow","@spin_cw"}
        }
    }
)