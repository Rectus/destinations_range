
DoIncludeScript( "animation/sequence_functions/sequence_functions", getfenv(1) )

local needleParam = model:CreatePoseParameter("needle", -1, 1, 0, false)

PoseMatrixFromSequence(
	{
		model = model,
		name = "@needle",
		pose_x = needleParam,
		subtract = "idle",
		numRows = 5,
		numColumns = 1,
		subtractframe = 2,
		source = "needle_pose",
		hidden = true,
		autoplay = true,
		righttoleft = true
	}
)

local pullParam = model:CreatePoseParameter("pull", -1, 1, 0, false)
local openParam = model:CreatePoseParameter("open", 0, 1, 0, false)

PoseMatrixFromSequence(
	{
		model = model,
		name = "@arms",
		pose_x = pullParam,
		pose_y = openParam,
		subtract = "idle",
		numRows = 3,
		numColumns = 3,
		subtractframe = 0,
		source = "arms_pose",
		hidden = true,
		autoplay = true,
		righttoleft = true
	}
)

--[[local twoHandedYaw = model:CreatePoseParameter("two_handed_yaw", -45, 45, 0, false)
local twoHandedRoll = model:CreatePoseParameter("two_handed_roll", -45, 45, 0, false)

PoseMatrixFromSequence(
	{
		model = model,
		name = "@two_handed",
		pose_x = twoHandedYaw,
		pose_y = twoHandedRoll,
		subtract = "idle",
		numRows = 3,
		numColumns = 3,
		subtractframe = 0,
		source = "two_handed_pose",
		hidden = true,
		autoplay = true,
		righttoleft = true
	}
)]]