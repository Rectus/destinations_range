
local MathUtils = {}

-- Returns 1 or -1 depending on the sign of the input.
function MathUtils.Sign(value)

	if value > 0 
	then
		return 1
	else
		return -1
	end
end


-- Normalizes an angle in the range -180 to 180 degrees
function MathUtils.NormalizeAngle(angle)

	angle = angle % 360

	if angle > 180
	then
		angle = angle - 360
	elseif angle < -180 
	then
		angle = angle + 360
	end	
	
	return angle
end


-- Composes a QAngle from a forward and up vector.
function MathUtils.QAngleFromOrientation(forward, up)

	local yaw = Rad2Deg(math.atan(forward.y / forward.x))
	
	if(forward.x < 0)
	then
		yaw = yaw + 180	
	end
	
	local pitch = -Rad2Deg(math.atan(forward.z / forward:Length2D()))
	
	local rightHorizontal = Vector(-forward.y, forward.x, 0)
	local upright = forward:Cross(rightHorizontal)
	local roll = Rad2Deg(math.atan2( rightHorizontal:Dot(up) / rightHorizontal:Length() ,
		upright:Dot(up) / upright:Length() ))
		
	return QAngle(pitch, yaw, roll)
end


-- Converts a Pitch Yaw Roll Vector into an orientation QAngle. 
function MathUtils.QAngleFromPYRVector(inputVec)

	return QAngle(inputVec.x, inputVec.y, inputVec.z)
end


-- Projects the vector B onto the vector A.
function MathUtils.ProjectVector(A, B)

	return (A:Dot(B) / VectorDistanceSq(A, Vector(0,0,0))) * A
end


-- Retrive the origin and angles of the named attachment of the entity model.
function MathUtils.GetAttachment(entity, attachmentName)

	local index = entity:ScriptLookupAttachment(attachmentName)
	local absOrigin = entity:GetAttachmentOrigin(index)
	local absAngles = MathUtils.QAngleFromPYRVector(entity:GetAttachmentAngles(index))

	return {absOrigin = absOrigin, absAngles = absAngles}
end

return MathUtils




