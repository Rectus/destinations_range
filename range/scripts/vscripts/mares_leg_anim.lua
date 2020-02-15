
local spinSeqs = {}

for i = 0, 12
do
	local seqName = "@spinframe0_" .. i * 30
	
	model:CreateSequence(
		{
			name = seqName,
			snap = true,
			delta = true,
			hidden = true,
			cmds = {
				{ cmd = "fetchframe", sequence = "spin_pose", frame = (i * 30), dst = 0 },
				{ cmd = "fetchframe", sequence = "spin_pose", frame = 0, dst = 1 },
				{ cmd = "subtract", dst = 0, src = 1 }
			}
		}
	)
	spinSeqs[i] = seqName
end

model:CreateSequence(
{
    name = "@spin_angle",
    poseParamX = model:CreatePoseParameter("spin_rot", 0, 360, 0, false),
	snap = true,
	delta = true,
	hidden = true,
	sequences = {
		spinSeqs
	},
})


local leverSeqs1 = {}

for i = 0, 5
do
	local seqName = "@spinframe1_" .. i * 10
	
	model:CreateSequence(
		{
			name = seqName,
			snap = true,
			delta = true,
			hidden = true,
			cmds = {
				{ cmd = "fetchframe", sequence = "lever_move", frame = (i * 10), dst = 0 },
				{ cmd = "fetchframe", sequence = "lever_move", frame = 0, dst = 1 },
				{ cmd = "subtract", dst = 0, src = 1 }
			}
		}
	)
	leverSeqs1[i] = seqName
end

model:CreateSequence(
{
    name = "@spin_lever",
    poseParamX = model:CreatePoseParameter("lever_pos", 0, 1, 0, false),
	snap = true,
	delta = true,
	hidden = true,
	sequences = {
		leverSeqs1
	},
})



local leverSeqs2 = {}

for i = 0, 5
do
	local seqName = "@spinframe2_" .. i * 10
	
	model:CreateSequence(
		{
			name = seqName,
			snap = true,
			delta = true,
			hidden = true,
			cmds = {
				{ cmd = "fetchframe", sequence = "lever_move_uncocked", frame = (i * 10), dst = 0 },
				{ cmd = "fetchframe", sequence = "lever_move_uncocked", frame = 0, dst = 1 },
				{ cmd = "subtract", dst = 0, src = 1 }
			}
		}
	)
	leverSeqs2[i] = seqName
end

model:CreateSequence(
{
    name = "@spin_lever_uncocked",
    poseParamX = model:CreatePoseParameter("lever_pos", 0, 1, 0, false),
	snap = true,
	delta = true,
	hidden = true,
	sequences = {
		leverSeqs2
	},
})



model:CreateSequence(
{
	name = "spin_posable",
	sequences = {
		{ "idle"}
	},
	addlayer = {
		"@spin_lever", "@spin_angle"
	}
})

model:CreateSequence(
{
	name = "spin_posable_uncocked",
	sequences = {
		{ "idle_uncocked"}
	},
	addlayer = {
		 "@spin_lever_uncocked", "@spin_angle"
	}
})