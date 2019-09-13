DoIncludeScript( "animation/sequence_functions/sequence_functions", getfenv(1) )

model:CreatePoseParameter( "trigger", 0, 1, 0, false ) 

PoseMatrixFromSequence( { model = model, name = "@trigger", 
	pose_x = "trigger", subtract = "trigger_pose", numRows = 2, numColumns = 1, 
	subtractframe = 0, source = "trigger_pose", hidden = true, autoplay = true, righttoleft = true } )