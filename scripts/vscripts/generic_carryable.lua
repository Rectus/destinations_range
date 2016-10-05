
--[[
	Physics prop that can be picked up and thrown.
	
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

-- Registers the entity with the pickup manager.
g_VRScript.pickupManager:RegisterEntity(thisEntity)

-- Varables local to the script.
local THROW_VECTOR = Vector(100, 0, 0)
local isCarried = false

-- Called when the trigger is pressed while this entity is held.
function OnTriggerPressed(self)
	if thisEntity:GetMoveParent() and not thisEntity:GetMoveParent():IsNull()
	then
		throwImpulse = RotatePosition(Vector(0, 0, 0), thisEntity:GetMoveParent():GetAngles(), THROW_VECTOR)
		thisEntity:SetParent(nil, "")
		isCarried = false
		thisEntity:ApplyAbsVelocityImpulse(throwImpulse)
	end
end

-- Called when the trigger is released while this entity is held.
function OnTriggerUnpressed(self)

end

-- Called when this entity is picked up. This script is responsible for attaching the entity to the player.
function OnPickedUp(self, hand, player)

	thisEntity:SetParent(hand, "")

end

-- Called when this entity is picked up. This script is responsible for releasing the entity from the player.
function OnDropped(self, hand, player)

	thisEntity:SetParent(nil, "")
end