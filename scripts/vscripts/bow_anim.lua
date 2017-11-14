DoIncludeScript( "animation/sequence_functions/sequence_functions", getfenv(1) )

print("Bow pose script")
--[[local poseSequneces = {}


-- Creates sequences form the individual frames, and stores them in an array.
for i = 1, 9
do
	local seqName = "pose_" .. i
	
	model:CreateSequence(
		{
			name = seqName,
			snap = true,
			--delta = true,
			hidden = true,
			--numframes = 1,
			cmds = {
				{ cmd = "fetchframe", sequence = "rotate_pose", frame = i - 1, dst = 0 },
				{ cmd = "fetchframe", sequence = "rotate_pose", frame = 4, dst = 1 },
				{ cmd = "subtract" , dst = 0, src = 1}
			}
		}
	)
	poseSequneces[i] = seqName
end

model:CreateSequence(
    {
        name = "@rotation",
        poseParamX = model:CreatePoseParameter("rotate_yaw", -179.9, 179.9, 0, false),
        poseParamY = model:CreatePoseParameter("rotate_pitch", -90, 90, 0, false),
        --delta = true,
        fadeintime = 0,
        fadeouttime = 0,
        autoplay = true,
        --hidden = true,
        sequences = 
		{
           {poseSequneces[1], poseSequneces[2], poseSequneces[3]},
           {poseSequneces[4], poseSequneces[5], poseSequneces[6]},
           {poseSequneces[7], poseSequneces[8], poseSequneces[9]}
        }
    }
)]]





--[[model:CreateSequence(
    {
        name = "@rotation_pitch",
        poseParamX = model:CreatePoseParameter("rotate_y", -90, 90, 0, false),
        --delta = true,
        fadeintime = 0,
        fadeouttime = 0,
        --numframes = 1,
        --hidden = true,
        sequences = 
		{
           {poseSequneces[2], poseSequneces[5], poseSequneces[8]}
        },

    }
)]]



model:CreateSequence(
    {
        name = "bow_draw",
        poseParamX = model:CreatePoseParameter("draw", 0, 20.5, 0, false),
        --delta = true,
        fadeintime = 0,
        fadeouttime = 0,
        --autoplay = true,
        sequences = 
		{
            {"undrawn", "drawn_half", "drawn"}
        }
    }
)



