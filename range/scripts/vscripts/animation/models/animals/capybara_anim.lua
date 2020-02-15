DoIncludeScript( "animation/sequence_functions/sequence_functions", getfenv(1) )

model:CreatePoseParameter( "look_pitch", 60, -50, 0, false ) 
model:CreatePoseParameter( "look_yaw", -70, 70, 0, false ) 

PoseMatrixFromSequence( { model = model, name = "look", 
	pose_x = "look_yaw", pose_y = "look_pitch", subtract = "look_matrix", 
	subtractframe = 4, source = "look_matrix", hidden = false, autoplay = true, righttoleft = false } )
	
model:CreatePoseParameter( "turn_pitch", 30, -30, 0, false ) 
model:CreatePoseParameter( "turn_yaw", -45, 45, 0, false ) 
	
PoseMatrixFromSequence( { model = model, name = "turn", 
	pose_x = "turn_yaw", pose_y = "turn_pitch", subtract = "turn_matrix", 
	subtractframe = 4, source = "turn_matrix", hidden = false, autoplay = true, righttoleft = false } )

model:CreatePoseParameter( "move_x", -25, 25, 0, false ) 
model:CreatePoseParameter( "move_y", -90, 90, 0, false )
	
EightWaySequence({ model = model, name = "move", 
	pose_x = "move_x", pose_y = "move_y", subtract = "move_center", source = "move_center",
	subtractframe = 0, hidden = false,  righttoleft = false, looping = true,
	sequences = {	{"turn_left","turn_left","turn_left", "turn_left", "turn_left",}, 
					{"walk_back", "walk_back_slow", "move_nofps", "walk_forward_slow", "walk_forward",},
					{"turn_right","turn_right", "turn_right", "turn_right","turn_right" }
				},
	animevents = {	{name = "AE_CL_PLAYSOUND", frame = 59, option = "clock_tick"},
					--{name = "AE_CL_PLAYSOUND", frame = 29, option = "clock_tick"},
					{name = "AE_CL_PLAYSOUND", frame = 119, option = "clock_tick"},
					--{name = "AE_CL_PLAYSOUND", frame = 59, option = "clock_tick"},
					}	
})

--[[
model:CreatePoseParameter( "ear_wiggle", 0, 1, 0, true )
DeltaSequence( { model = model, name = "wiggle_off", source = "ear_wiggle_loop_nofps", subtract = "ear_wiggle_loop_nofps", hidden = true, } )
DeltaSequence( { model = model, name = "wiggle_on", source = "ear_wiggle_loop", subtract = "ear_wiggle_loop_nofps", hidden = true, } )

model:CreateSequence( 
{ 
	name = "ear_wiggle_pose", 
	poseParamX = "ear_wiggle",  
	delta = true, 
	hidden = false, 
	autoplay = true,
	sequences = {{"wiggle_off", "wiggle_on"}},
				
})
]]