
--[[
-- Unit tests for libraries/matrix.nut
 ]]
 
local Test = {}

package.loaded["libraries/mathutils"] = nil
local MathUtils = require "libraries/mathutils"

local matrix1 = MathUtils.Matrix({ 1,2,3, 4,5,6, 7,8,9 }, 3, 3)
local invMat = MathUtils.Matrix({ 1,0,0, 4,1,0, 7,0,1 }, 3, 3)
local adjMat = MathUtils.Matrix({ 3,1,1, 1,3,-1, 2,4,1 }, 3, 3)
local nonSqr = MathUtils.Matrix({ 1,2,3, 1,0,-1,}, 2, 3)


function Test.ConstructArray()

	local pass = false
	local matrix = nil

	pass, matrix = pcall(MathUtils.Matrix, {1,2,3,4,5,6,7,8,9}, 3, 3)
	
	assert(pass, "Call failed: " .. (pass and "" or matrix))	
	assert(matrix, "Nil matrix returned")
	assert(matrix:GetCellValue(2, 1) == 4, "Invalid matrix")
end

	
function Test.ConstructTinyArray()

	local matrix = nil
	local pass = false

	pass, matrix = pcall(MathUtils.Matrix, {-1}, 1, 1)

	assert(pass, "Call failed: " .. (pass and "" or matrix))	
	assert(matrix, "Nil matrix returned")
	assert(matrix:GetCellValue(1, 1) == -1, "Invalid matrix")

end


function Test.ConstructNestedArray()

	local matrix = nil
	local pass = false

	pass, matrix = pcall(MathUtils.Matrix,{ {1,2,3}, {4,5,6} ,{7,8,9} }, 3, 3)	

	assert(pass, "Call failed: " .. (pass and "" or matrix))
	assert(matrix, "Nil matrix returned")
	assert(matrix:GetCellValue(2, 1) == 4, "Invalid matrix")
end


function Test.ConstructVectorArray()

	local matrix = nil
	local pass = false

	pass, matrix = pcall(MathUtils.Matrix, { Vector(1,2,3), Vector(4,5,6) ,Vector(7,8,9), Vector(0,0,0) }, 4, 3)	

	assert(pass, "Call failed: " .. (pass and "" or matrix))
	assert(matrix, "Nil matrix returned")
	assert(matrix:GetCellValue(4, 1) == 0, "Invalid matrix")
end


function Test.ConstructInvalidDim()

	local pass = false
	local matrix = nil

	pass, matrix = pcall(MathUtils.Matrix,{ {1,2,3}, {4,5,6} ,{7,8,9} }, 3, 0)
	
	if pass then
		assert(matrix, "1: Nil matrix returned")
		assert(nil, "1: Matrix created with invalid columns")
	end
	
	matrix = nil
	pass = false
	
	pass, matrix = pcall(MathUtils.Matrix, { {1,2,3}, {4,5,6} ,{7,8,9} }, 0, 3)

	if pass then
		assert(matrix, "2: Nil matrix returned")
		assert(nil, "2: Matrix created with invalid columns")
	end
end



function Test.TestGetCell()

	local pass = true
	local retval = nil

	pass, retval = pcall(matrix1.GetCellValue, matrix1, 1, 1)

	assert(pass, "Call failed: " .. (pass and "" or retval))
	assert(retval == 1, "1: Invalid value")
	
	pass, retval = pcall(matrix1.GetCellValue, matrix1, 3, 3)
	
	assert(pass, "Call failed: " .. (pass and "" or retval))
	assert(retval == 9, "2: Invalid value")

	pass = pcall(matrix1.GetCellValue, matrix1, 1, 0)
	assert(not pass, "3: Returned from invalid call")
	
	pass = pcall(matrix1.GetCellValue, matrix1, 0, -1)
	assert(not pass, "4: Returned from invalid call")
end


function Test.TestGetRowArray()

	local retval = nil
	local pass = false
	
	pass, retval = pcall(matrix1.GetRowArray, matrix1, 1)
	
	assert(pass, "1: Call failed: " .. (pass and "" or retval))
	
	pass, retval = pcall(matrix1.GetRowArray, matrix1, 3)

	assert(pass, "2: Call failed: " .. (pass and "" or retval))

	assert(retval[1] == 7, "3: Wrong value returned")
	assert(retval[2] == 8, "4: Wrong value returned")
	assert(retval[3] == 9, "5: Wrong value returned")
end


function Test.TestGetColArray()

	local retval = nil
	local pass = false
	
	pass, retval = pcall(matrix1.GetColArray, matrix1, 1)
	
	assert(pass, "1: Call failed: " .. (pass and "" or retval))
	
	pass, retval = pcall(matrix1.GetColArray, matrix1, 3)

	assert(pass, "2: Call failed: " .. (pass and "" or retval))

	assert(retval[1] == 3, "3: Wrong value returned")
	assert(retval[2] == 6, "4: Wrong value returned")
	assert(retval[3] == 9, "5: Wrong value returned")
end


function Test.TestGetCofactor()

	local retval = nil
	local pass = false
	
	pass, retval = pcall(matrix1.GetCofactor, matrix1, 1, 1)
	
	assert(pass, "1: Call failed: " .. (pass and "" or retval))
	
	pass, retval = pcall(matrix1.GetCofactor, matrix1, 3, 3)

	assert(pass, "2: Call failed: " .. (pass and "" or retval))

	assert(retval:GetCellValue(1, 1) == 1, "3: Wrong value returned")
	assert(retval:GetCellValue(1, 2) == 2, "4: Wrong value returned")
	assert(retval:GetCellValue(2, 1) == 4, "5: Wrong value returned")
	assert(retval:GetCellValue(2, 2) == 5, "6: Wrong value returned")
end


function Test.TestGetDeterminantNonInv()

	local det = nil
	local pass = false
	
	pass, det = pcall(matrix1.GetDeterminant, matrix1)

	assert(pass, "Call failed: " .. (pass and "" or det))

	assert(det == 0, "Wrong value returned")

end


function Test.TestGetDeterminantInv()

	local det = nil
	local pass = false
	
	pass, det = pcall(invMat.GetDeterminant, invMat)

	assert(pass, "Call failed: " .. (pass and "" or det))

	assert(det == 1, "Wrong value returned")

end


function Test.TestGetTranspose()

	local retval = nil
	local pass = false
	
	pass, retval = pcall(matrix1.GetTranspose, matrix1)

	assert(pass, "Call failed: " .. (pass and "" or retval))

	assert(retval:GetCellValue(1, 1) == 1, "1: Wrong value returned")
	assert(retval:GetCellValue(1, 3) == 7, "2: Wrong value returned")
	assert(retval:GetCellValue(3, 1) == 3, "3: Wrong value returned")
	assert(retval:GetCellValue(3, 3) == 9, "4: Wrong value returned")
end


function Test.TestGetAdjunct()

	local retval = nil
	local pass = false
	
	pass, retval = pcall(matrix1.GetAdjunct, matrix1)
	assert(pass, "Call failed: " .. (pass and "" or retval))

	pass, retval = pcall(adjMat.GetAdjunct, adjMat)
	assert(pass, "Call failed: " .. (pass and "" or retval))

	assert(retval:GetCellValue(1, 1) == 7, "1: Wrong value returned")
	assert(retval:GetCellValue(1, 3) == -4, "2: Wrong value returned")
	assert(retval:GetCellValue(3, 1) == -2, "3: Wrong value returned")
	assert(retval:GetCellValue(3, 3) == 8, "4: Wrong value returned")
end


function Test.TestGetAdjunctNonSqr()

	local retval = nil
	local pass = false
	
	pass, retval = pcall(nonSqr.GetAdjunct, nonSqr)
	assert(not pass, "Returned from invalid call")
end


function Test.TestGetInverse()

	local retval = nil
	local pass = false
	
	pass, retval = pcall(invMat.GetInverse, invMat)
	assert(pass, "Call failed: " .. (pass and "" or retval))
	
	assert(retval:GetCellValue(1, 1) == 1, "1: Wrong value returned")
	assert(retval:GetCellValue(1, 3) == 0, "2: Wrong value returned")
	assert(retval:GetCellValue(3, 1) == -7, "3: Wrong value returned")
	assert(retval:GetCellValue(3, 3) == 1, "4: Wrong value returned")
	assert(retval:GetCellValue(2, 1) == -4, "5: Wrong value returned")
end


function Test.TestGetInverseNonInvertible()

	local retval = nil
	local pass = false
	
	pass, retval = pcall(matrix1.GetInverse, matrix1)
	assert(not pass, "Non-invertible matrix inverted")
end


function Test.TestMutliplyScalar()

	local retval = nil
	local pass = false
	
	pass, retval = pcall(function() return matrix1 * 2 end)

	assert(pass, "Call failed: " .. (pass and "" or retval))

	assert(retval:GetCellValue(1, 1) == 2, "1: Wrong value returned")
	assert(retval:GetCellValue(1, 3) == 6, "2: Wrong value returned")
	assert(retval:GetCellValue(3, 1) == 14, "3: Wrong value returned")
	assert(retval:GetCellValue(3, 3) == 18, "4: Wrong value returned")
end


function Test.TestMutliplyMatrices()

	local retval = nil
	local pass = false
	
	pass, retval = pcall(function() 
		return MathUtils.Matrix({11, 3, 7, 11}, 2, 2) 
		* MathUtils.Matrix({ {8, 0, 1}, {0, 3, 5}}, 2, 3) end)

	assert(pass, "Call failed: " .. (pass and "" or retval))
	
	assert(retval:GetCellValue(1, 1) == 88, "1: Wrong value returned")
	assert(retval:GetCellValue(1, 3) == 26, "2: Wrong value returned")
	assert(retval:GetCellValue(2, 1) == 56, "3: Wrong value returned")
	assert(retval:GetCellValue(2, 3) == 62, "4: Wrong value returned")
		
end


function Test.TestMutliplyArrayVec()

	local retval = nil
	local pass = false
	
	pass, retval = pcall(function() return matrix1 * {1, 0, -1} end)

	assert(pass, "Call failed: " .. (pass and "" or retval))
	
	assert(retval[1] == -2, "1: Wrong value returned")
	assert(retval[2] == -2, "2: Wrong value returned")
	assert(retval[3] == -2, "3: Wrong value returned")
end


function Test.TestMutliplyVector()

	local retval = nil
	local pass = false
	
	pass, retval = pcall(function() return matrix1 * Vector(1, 0, -1) end)

	assert(pass, "Call failed: " .. (pass and "" or retval))
	
	assert(retval[1] == -2, "1: Wrong value returned")
	assert(retval[2] == -2, "2: Wrong value returned")
	assert(retval[3] == -2, "3: Wrong value returned")
end


function Test.ConstructTransformArray()

	local retval = nil
	local pass = false
	
	pass, retval = pcall(MathUtils.TransformMatrix, {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16})
	assert(pass, "Matrix creation failed: " .. (pass and "" or retval))	

	assert(retval, "Nil matrix returned")
	assert(retval:GetCellValue(2, 1) == 5, "Invalid matrix")
end


function Test.ConstructTransformEnt()

	local ent = Entities:FindByClassname(nil, "worldent") -- Should have a 0 transform

	local retval = nil
	local pass = false
	
	pass, retval = pcall(MathUtils.TransformMatrix, ent)
	assert(pass, "Matrix creation failed: " .. (pass and "" or retval))	
	
	assert(retval, "Nil matrix returned")
	assert(retval:GetCellValue(1, 1) == 1, "1: Wrong value returned")
	assert(retval:GetCellValue(2, 2) == 1, "2: Wrong value returned")
	assert(retval:GetCellValue(3, 3) == 1, "3: Wrong value returned")
	assert(retval:GetCellValue(4, 4) == 1, "4: Wrong value returned")
end


function Test.ConstructTransformParams()

	local retval = nil
	local pass = false
	
	pass, retval = pcall(MathUtils.TransformMatrix, Vector(10,-8,400), QAngle(6, 60, -30), Vector(1, 0.5, 10.5))
	assert(pass, "Matrix creation failed: " .. (pass and "" or retval))	

	assert(retval, "Nil matrix returned")
	assert((retval * Vector(1,0,0) - Vector(10.497261, -7.138719, 399.895477)):Length() < 0.01, "Invalid transform")
end


function Test.TestEntTransform()

	local ent = SpawnEntityFromTableSynchronous("prop_dynamic", {
		model = "models/dev/sphere.vmdl",
		origin = Vector(-600, 345.678, -1111.2222),
		angles = Vector(68, -69, 0.66),
		scales = Vector(0.5, 2, 5)
	})


	local retval = nil
	local pass = false
	
	pass, retval = pcall(MathUtils.TransformMatrix, ent)
	assert(pass, "Matrix creation failed: " .. (pass and "" or retval))	

	assert(retval, "Nil matrix returned")
	local orientationDelta = RotationDelta(retval:GetOrientation(), QAngle(68, -69, 0.66))
	assert(abs(orientationDelta.x) + abs(orientationDelta.y) + 
		abs(orientationDelta.z) < 2, "Error too high on returned orientation")
	-- TODO: That difference is huge, maybe some issue in the code
end

return Test
