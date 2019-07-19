

local dir = (...):gsub('%.[^%.]+$', '')
local MathUtils = require(dir .. '.misc_utils')


--- Matrix class
-- An arbitrarily sized immutable floating point matrix.
-- 
-- @module MathUtils.Matrix
-- @class table
local Matrix = class( 

	{
		_values = {},
		_rows = 0,
		_cols = 0,
		_det = nil, -- cached determinant
		_cache = {}, --  Weak reference for the inverse matrix
	},	
	{},	
	nil
)
	
	
--- Creates a numRows x numCols matrix from a set of values.
--
-- Throws an error on invalid input.
-- 
-- @param values The matrix values as a flat array ordered by rows, nested row arrays, or row arrays of Vector objects.
-- @param numRows Amout of rows
-- @param numColums Amount of columns
--  
function Matrix.constructor(self, values, numRows, numCols)
	
	if numRows < 1 or numCols < 1 
	then
		error("Invalid matrix dimensions")
	end
	
	-- Add the overloaded operators
	local mt = getmetatable(self)
	mt.__tostring = self.__tostring
	if not mt.__mul then
		mt.__mul = self.__mul
	end
	
	self._rows = numRows
	self._cols = numCols
	self._cache = {}
	setmetatable(self._cache, {__mode = "v"})

	local numVals = numRows * numCols

	if type(values) == "table"  -- Either a flat array or one filled with other structures
	then
		self._values = self:_parseArrayValues(values, numVals)		
		return		
	else		
			error("Matrix values of type " .. type(values) .. " not supported")
	end
	

end


--- @return The matrix contents as a row ordered array
function Matrix:GetValuesFlatArray()

	return self._values
end


--- @return The number of rows
function Matrix:GetNumRows()

	return self._rows
end


--- @return The number of columns
function Matrix:GetNumColumns()

	return self._cols
end


--- Get the value in the specified cell.
--
-- Throws an error on invalid input.
--
-- @param row Row of the value
-- @param col Column of the value
-- @return 
function Matrix:GetCellValue(row, col)

	if row < 1 or col < 1 or row > self._rows or col > self._cols
	then
		error("Invalid cell")
	end

	return self._values[col + ( (row - 1) * self._cols)]
end
	
	

--- Get the specified row as an array.
--
-- Throws an error on invalid input.
--
-- @param row The row to return
function Matrix:GetRowArray(row)

	if row < 1 or row > self._rows
	then
		error("Invalid cell")
	end

	local start = (row - 1) * self._cols + 1
	return vlua.slice(self._values, start, start + self._cols)
end


--- Get the specified column as an array.
--
-- Throws an error on invalid input.
--
-- @param col The colunm to return
function Matrix:GetColArray(col)

	if col < 1 or col > self._cols 
	then
		error("Invalid cell")
	end
	
	local retval = {}
	
	for i = 1, self._rows
	do
		retval[i] = self:GetCellValue(i, col)
	end

	return retval
end


--- Get the specified matrix cofactor.
--
-- Throws an error on invalid input.
--
function Matrix:GetCofactor(row, col)

	if self._rows <= 1 or self._cols <= 1 
	then
		error("Matrix too small to extract cofactor")
	end

	local vals = {}
	
	for i = 1, self._rows
	do
		for  j = 1, self._cols
		do
			if i ~= row and j ~= col
			then
				vals[#vals + 1] = self:GetCellValue(i, j)
			end
		end
	end
	
	return getclass(self)(vals, self._rows - 1, self._cols - 1)
end


--- Returns the determinant for a square matrix.
--
-- Throws an error on non square matrices.
--
function Matrix:GetDeterminant()

	if self._det  then return self._det end
	
	if self._rows ~= self._cols then error("No determinant for non-square matrix") end
	
	
	if self._rows == 1
	then
		self._det = self._values[1]
		return self._det
			
	elseif self._rows == 2
	then
		self._det = (self._values[1] * self._values[4]) - (self._values[2] * self._values[3])
		return self._det	
	else
		self._det = 0
		local sign = 1
		
		for i = 1, self._cols
		do
			local cf = self:GetCofactor(1, i)
			self._det = self._det + sign * self:GetCellValue(1, i) * cf:GetDeterminant()
			sign = -sign
		end
	
		return self._det
	end
end


--- Returns the transpose of the matrix.
--
--
function Matrix:GetTranspose()

	local vals = {}
	
	for  i = 1, self._cols
	do
		vals[#vals + 1] = self:GetColArray(i)
	end
	
	return getclass(self)(vals, self._cols, self._rows)
end


--- Returns the adjunct for a square matrix.
--
-- Throws an error on non square matrices.
--
function Matrix:GetAdjunct()

	if self._rows ~= self._cols  then error("No adjunct for non-square matrix") end
	
	local vals = {}
	
	for i = 1, self._rows
	do
		for j = 1, self._cols
		do
			local cf = self:GetCofactor(i, j)
			local sign = (((i + j) % 2 == 0) and 1 or -1)
			vals[#vals + 1] = sign * cf:GetDeterminant()
		end
	end
	
	return getclass(self)(vals, self._rows, self._cols):GetTranspose()
end


--- Returns the inverse for a square matrix.
--
-- Throws an error on non-invertible matrices.
--
function Matrix:GetInverse()

	if self._cache._inv  then return self._cache._inv end
	
	if self._rows ~= self._cols then error("No inverse for non-square matrix") end
	
	local det = self:GetDeterminant()
	
	if det == 0 then error("Singular matrix" )end
	
	local adj = self:GetAdjunct()
	
	local vals = {}
	
	for i = 1, self._rows
	do
		for j = 1, self._cols
		do
			vals[#vals + 1] = adj:GetCellValue(i, j) / det
		end
	end
	
	local inv = getclass(self)(vals, self._rows, self._cols)
	
	self._cache._inv = inv
	inv._cache._inv = self
	return inv
end


--- Overloaded multiplication. Does matrix multiplication, 
-- linear transforms with vectors and arrays and scalar multiplication with other values.
--
function Matrix:__mul(other)

	return self:_basemul(other)
end


--- Overloaded string conversion
--
function Matrix:__tostring()

	local retval = ""
	
	for i = 1, self._rows
	do
		for j = 1, self._cols
		do
			retval = retval .. self:GetCellValue(i, j) .. " "
		end
		retval = retval .. "\n"
	end
	return retval
end


--- Private functions
	

function Matrix:_basemul(other)

	if type(other) == "table"
	then
		
		if getclass(other)
		then
			if not instanceof(other, getclass(self))
				then error("Unknown class for matrix multiplication") end
			if other:GetNumRows() ~= self._cols  
				then error("Invalid matrix dimensions for multiplication") end
			
			local newVals = {}
			
			for j = 1, self._rows
			do
				for i = 1, other:GetNumColumns()
				do
					local cellVal = 0
				
					for k = 1, self._cols
					do
						cellVal = cellVal + self:GetCellValue(j, k) * other:GetCellValue(k, i)
					end
					
					newVals[#newVals + 1] = cellVal
				end
			end
			
			return getclass(self)(newVals, self._rows, other:GetNumColumns())
			
		else	
			if #other ~= self._cols
				then error("Invalid vector dimensions for multiplication") end
			
			local newVals = {}
				
			for j = 1, self._rows
			do
				local cellVal = 0
			
				for k = 1, self._cols
				do
					cellVal = cellVal + self:GetCellValue(j, k) * other[k]
				end
				
				newVals[#newVals + 1] = cellVal
			end
	
			return newVals
		end
			
	else if type(other) == "userdata" and vlua.split(other:__tostring(), " ")[1] == "Vector"
	then
		if self._cols ~= 3  then error("Invalid vector dimensions for multiplication") end
		
		local newVals = {}
			
		for j = 1, self._rows
		do	
			local cellVal = self:GetCellValue(j, 1) * other.x
				+ self:GetCellValue(j, 2) * other.y
				+ self:GetCellValue(j, 3) * other.z
			
			newVals[#newVals + 1] = cellVal
		end
		
		return Vector(newVals[1], newVals[2], newVals[3])
	end
	
		-- Assuming scalar values for unknown types
		local newVals = {}
		for i, val in ipairs(self._values)
		do
			newVals[i] = val * other
		end
		
		return getclass(self)(newVals, self._rows, self._cols)			
	end
end


function Matrix:_parseArrayValues(values, numVals)

	if type(values[1]) == "table" -- Nested arrays of individual rows.
	then
		if #values ~= self._rows then error("Invalid amount of rows") end
		
		local outVals = {}
		
		-- Recursively parse inner arrays
		for _, row in ipairs(values)
		do
			vlua.extend(outVals, self:_parseArrayValues(row, self._cols))
		end
	
		return outVals	
		
	elseif type(values[1]) == "userdata" and vlua.split(values[1]:__tostring(), " ")[1] == "Vector"
	then
		if #values ~= self._rows then error("Invalid amount of rows") end

		local outVals = {}
		-- Recursively parse inner arrays
		for _, row in ipairs(values)
		do
			vlua.extend(outVals, {row.x, row.y, row.z})
		end
		
		return outVals
		
	elseif type(values[1]) == "number"
	then	
		if #values ~= numVals then error("Invalid array length") end
				
		return vlua.clone(values)
	
	else
		error("Matrix inner values of type " .. type(values[1]) .. " not supported")
	end
end


return Matrix

