--require "animationsystem.sequences"             

local tongueSequneces = {}
local wrapSequneces = {}

-- Creates sequences form the individual frames, and stores them in an array.
for i = 1, 11
do
	local seqName = "@tongue_" .. i
	
	model:CreateSequence(
		{
			name = seqName,
			snap = true,
			delta = true,
			hidden = true,
			cmds = {
				{ cmd = "fetchframe", sequence = "@tongue_pos", frame = i - 1, dst = 0 },
				{ cmd = "fetchframe", sequence = "@tongue_pos", frame = 5, dst = 1 },
				{ cmd = "subtract" , dst = 0, src = 1}
			}
		}
	)
	tongueSequneces[i] = seqName
end

for i = 1, 20
do
	local seqName = "@wrap_" .. i
	
	model:CreateSequence(
		{
			name = seqName,
			snap = true,
			delta = true,
			hidden = true,
			cmds = {
				{ cmd = "fetchframe", sequence = "@tongue_wrap", frame = i - 1, dst = 0 },
				{ cmd = "fetchframe", sequence = "@tongue_wrap", frame = 0, dst = 1 },
				{ cmd = "subtract", dst = 0, src = 1 }
			}
		}
	)
	wrapSequneces[i] = seqName
end

model:CreateSequence(
    {
        name = "@tongue",
        poseParamX = model:CreatePoseParameter("tongue_length", 16, 430, 0, false),
		snap = true,
		--delta = true,
		hidden = true,
		sequences = {
			tongueSequneces
		},
		
    }
)

model:CreateSequence(
    {
        name = "@wrap",
        poseParamX = model:CreatePoseParameter("tongue_wrap", 0, 1, 0, false),
		snap = true,
		--delta = true,
		hidden = true,
		sequences = {
			wrapSequneces
		},
    }
)

local finaleSeqs = {"idle01", "attack_player", "attack_smallthings", "attackplayer_transition", "barf_humanoid", "chew_humanoid", "chew_smallthings", "death", "death2", "eat_humanoid", "flinch1", "flinch2", "reset_tongue", "slurp", "taste_spit"}


for i, seq in ipairs(finaleSeqs)
do
	model:CreateSequence(
		{
			name = seq,
			sequences = {
				{ "@" .. seq }
			},
			addlayer = {
				 "@tongue", "@wrap"
			}
		}
	)
end


