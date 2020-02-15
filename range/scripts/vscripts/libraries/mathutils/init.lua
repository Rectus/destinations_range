
local dir = (...):gsub('%.init$', '')

--- Math utility library
-- @module MathUtils
local M =
{
	VERSION = 1.0,
	Matrix = require(dir .. ".matrix"),
	TransformMatrix  = require(dir .. ".transform_matrix")
}

local misc = require(dir .. ".misc_utils")

vlua.tableadd(M, misc)

return M