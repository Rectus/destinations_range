

local dir = (...):gsub('%.[^%.]+$', '')
local Matrix = require(dir .. '.matrix')
local MathUtils = require(dir .. '.misc_utils')

--- Represents a transformation, or mapping between different coordinate systems.
-- 
-- Passing an entity to the constructor uses the entitys location, rotation and scale to 
-- generate a transformation from its local space to the world space or its parents space if parented.
--
-- Multiplying a TransformMatrix with a Vector or QAngle as the right hand operand transforms them
-- between the coordinate systems.
-- 
-- @module MathUtils.TransformMatrix
-- @class table
local TransformMatrix = class({}, nil, Matrix)


--- Creates a 4 x 4 transformation matrix.
--
-- Valid call formats are:
--
-- TransformMatrix(array [16]) - Pass matrix cell values as an array.
-- TransformMatrix(CBaseEntity entity) - Creates a matrix of the transform of the specified entity.
-- TransformMatrix(Vector location, QAngle rotation, Vector scale) - Creates a matrix from the specified transform.
function TransformMatrix.constructor(self, ...)

	local mt = getmetatable(self)
	mt.__mul = self.__mul
	
	local numArgs = #{...}
	local firstArg = select(1, ...)

	if numArgs < 1 then error("Too few parameters in constructor") end
	
	local values = {}

	if type(firstArg) == "table"
	then
		if firstArg.__self and IsValidEntity(firstArg)
		then		
			local ent = firstArg
			local loc = ent:GetAbsOrigin()
			local rot = ent:GetAngles()
			local scale = ent:GetAbsScale() 
				
			values = self:_TransformFromLocRotScale(loc, rot, Vector(scale, scale, scale))
		
			return getbase(self).constructor(self, values, 4, 4)

		else -- Table of values
	
			if numArgs == 3
			then
				return getbase(self).constructor(self, ...)
			end
			
			return getbase(self).constructor(self, firstArg, 4, 4)
		end
			
	elseif type(firstArg) == "userdata" and vlua.split(firstArg:__tostring(), " ")[1] == "Vector"
	then
		 -- Vector
		local loc = firstArg
		local rot = QAngle(0,0,0)
		local scale = Vector(1, 1, 1)
		
		if(numArgs >= 2)
		then
			rot = select(2, ...)
			if vlua.split(rot:__tostring(), " ")[1] ~= "QAngle" then error("Expected QAngle on parameter 2") end
		end
		if(numArgs >= 3) 
		then
			scale = select(3, ...)
			if vlua.split(scale:__tostring(), " ")[1] ~= "Vector" then error("Expected Vector on parameter 2") end
		end

		values = self:_TransformFromLocRotScale(loc, rot, scale)
	
		return getbase(self).constructor(self, values, 4, 4)
			
	else
		error("Unknown parameter in constructor")
	end
end
	

--- Returns the inverse of the transformation.
-- This can be used to get a world space to local space mapping.
function TransformMatrix:GetInverse()

	if self._cache._inv  then return self._cache._inv end
	
	local det = self:GetDeterminant()
	
	if det == 0  then error("Singular matrix") end
	
	local adj = self:GetAdjunct()
	
	local vals = {}
	
	for i = 1, self._rows
	do
		for j = 1, self._cols
		do
			vals[#vals + 1] = adj:GetCellValue(i, j) / det
		end
	end

	local inv = getclass(self)(vals)

	self._cache._inv = inv
	inv._cache._inv = self
	return inv
end


--- Returns the orienation of this transform as a QAngle
--
--
function TransformMatrix:GetOrientation()

	local fwd = self:TransformDirection(Vector(1, 0, 0))
	local up = self:TransformDirection(Vector(0, 0, 1))
	
	return MathUtils.QAngleFromOrientation(fwd, up)
end


--- Transforms an orientation QAngle
--
--
function TransformMatrix:TransformOrientation(orientation)

	return RotateOrientation(self:GetOrientation(), orientation)
end


--- Transforms a direction Vector
--
--
function TransformMatrix:TransformDirection(direction)

	return self:_DoMultiply(direction, 0.0)
end


--- Transforms a position Vector
--
-- The same function as multiplying the matrix with a vector.
--
function TransformMatrix:TransformPosition(position)

	return self:_DoMultiply(position, 1.0)
end


--- Overloaded multiplication. Does matrix multiplication, 
-- linear transforms with vectors and arrays and scalar multiplication with other values.
--
-- Multiplying a local space position vector transforms it into world space.
--
function TransformMatrix:__mul(other)

	return self:_DoMultiply(other, 1.0)
end


-- Private functions

-- w is the fourth component of a coordinate, set to 1.0 to enable translation or 0.0 to disable.
function TransformMatrix:_DoMultiply(other, w)

	if type(other) == "userdata" and vlua.split(other:__tostring(), " ")[1] == "Vector" -- Transforms a 3D Vector object.
	then
		local values = {other.x, other.y, other.z, w}
		
		local retArray = self:_basemul(values)
		
		return Vector(retArray[1], retArray[2], retArray[3])
		
	elseif type(other) == "table"
	then
		if(#other == 3)
		then
			local values = vlua.clone(other)
			values[4] = w
			
			local retArray = self:_basemul(values)
			table.remove(retArray, #retArray)
			return retArray
		else
			return self:_basemul(other)
		end
	
	else
		return self:_basemul(other)
	end
end

	
function TransformMatrix:_TransformFromLocRotScale(loc, rot, scale)

	local roll = Deg2Rad(rot.z)
	local pitch = Deg2Rad(rot.x)
	local yaw = Deg2Rad(rot.y)
	
	local baseMat = getbase(self)
	local cos = math.cos
	local sin = math.sin

	local Rz = baseMat({ -- Roll
		{1.0, 	0, 			0, 				0},  
		{0, 	cos(roll), 	-sin(roll), 	0}, 
		{0, 	sin(roll), 	cos(roll) ,		0}, 
		{0, 	0, 			0, 				1.0} }, 4, 4)
		
	local Rx = baseMat({ -- Pitch
		{cos(pitch), 	0, 		sin(pitch), 0},  
		{0, 			1.0, 	0, 			0}, 
		{-sin(pitch), 	0, 		cos(pitch), 0}, 
		{0, 			0, 		0, 			1.0} }, 4, 4)
		
	local Ry = baseMat({ --Yaw
		{cos(yaw), 		-sin(yaw), 	0, 		0},  
		{sin(yaw), 		cos(yaw), 	0, 		0}, 
		{0, 			0, 			1.0, 	0}, 
		{0, 			0, 			0, 		1.0} }, 4, 4)

	local scaleMat = baseMat({ 
		{scale.x, 	0, 			0, 			0},  
		{0, 		scale.y, 	0, 			0}, 
		{0, 		0,			scale.z, 	0}, 
		{0, 		0, 			0, 			1.0} }, 4, 4)
		
	local locMat = baseMat({ 
		{1.0, 0, 0, loc.x	},  
		{0, 1.0, 0, loc.y	}, 
		{0, 0, 1.0, loc.z	}, 
		{0, 0, 0, 	1.0		} }, 4, 4)

	local rotMat = Ry * Rx * Rz -- The correct rotation order for Source angles seems to be Roll, Pitch, Yaw
	local result = locMat * rotMat * scaleMat
	
	return result:GetValuesFlatArray()
end


return TransformMatrix