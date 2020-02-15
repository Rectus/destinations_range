
model:CreateSequence(
{
    name = "@idle_sub",
	snap = true,
	delta = true,
	hidden = true,
	cmds = {
		{ cmd = "fetchframe", sequence = "laser_pistol_idle", frame = 0, dst = 1 },
		{ cmd = "subtract", dst = 0, src = 1 }
	},
})


model:CreateSequence(
{
    name = "@trigger",
    poseParamX = model:CreatePoseParameter("trigger", 0, 1, 0, false),
	snap = true,
	delta = true,
	hidden = true,
	sequences = {
		{"laser_pistol_idle", "laser_pistol_trigger_pose"}
	},
	addlayer = {"@idle_sub"}
})

model:CreateSequence(
{
    name = "@safety",
    poseParamX = model:CreatePoseParameter("safety", 0, 1, 0, false),
	snap = true,
	delta = true,
	hidden = true,
	
	sequences = {
		{"laser_pistol_idle", "laser_pistol_safety_pose"}
	},
	addlayer = {"@idle_sub"}
})



model:CreateSequence(
{
	name = "idle",
	snap = true,
	addlayer = {
		"@trigger", "@safety"
	}
})