
--[[
	Resets the firing range entities.
	
	Copyright (c) 2016 Rectus
	
	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:
	
	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.
	
	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
]]--

local barrels = {} 

function Store()
	local barrelEnt = Entities:FindByName(nil, "barrel")
	
	while barrelEnt
	do
		barrels[barrelEnt] = {origin = barrelEnt:GetOrigin(); angles = barrelEnt:GetAngles()} 
		
		barrelEnt = Entities:FindByName(barrelEnt, "barrel")
	end
end


function Reset()
	local barrelEnt = Entities:FindByName(nil, "barrel")
	while barrelEnt
	do
		barrelEnt:SetOrigin(barrels[barrelEnt].origin)
		local angles = barrels[barrelEnt].angles
		barrelEnt:SetAngles(angles.x, angles.y, angles.z)
		
		barrelEnt = Entities:FindByName(barrelEnt, "barrel")
	end
	
	DoEntFire("target", "SetAnimation", "reset", 0, nil, nil)
	DoEntFire("target", "SetDefaultAnimation", "idle", 0, nil, nil)
end