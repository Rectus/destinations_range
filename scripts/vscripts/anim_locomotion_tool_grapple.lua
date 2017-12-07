model:CreateSequence(
    {
        name = "idle",
        poseParamX = model:CreatePoseParameter("claw_open", 0, 1, 0, false),
        --delta = true,
        fadeintime = 0.2,
        fadeouttime = 0.2,
        --autoplay = true,
        looping = true,
        sequences = 
		{
            {"claw_closed", "claw_pulled_out", "claw_half_open", "claw_tq_open", "claw_open"}
        }
    }
)
