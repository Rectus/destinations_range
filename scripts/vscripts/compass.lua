
local NORTH_ANGLES = QAngle(0,20,0)


function Activate()
	thisEntity:SetThink(Orient, "orient", 0.02)
end

function Orient()

	thisEntity:SetAngles(NORTH_ANGLES.x, NORTH_ANGLES.y, NORTH_ANGLES.z)

	return 0.02
end