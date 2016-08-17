
--[[
	Makes a drivable platform that controls similarly to Hover Junkers.
	
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

g_VRScript.pickupManager:RegisterEntity(thisEntity)

controller = nil
controllerBasePos = nil
moving = false

function OnTriggerPressed(self)
	moving = true
	controllerBasePos = controller:GetAbsOrigin() - thisEntity:GetOrigin()
	thisEntity:SetThink(ThinkMove, "move", 0.02)
end

function OnTriggerUnpressed(self)
	moving = false
end

function OnPickedUp(self, hand, player)
	playerEnt = player
	controller = hand
	playerEnt:GetHMDAnchor():SetOrigin(thisEntity:GetOrigin() + Vector(0, 0, -16))
	playerEnt:GetHMDAnchor():SetParent(thisEntity, "")

end

function OnDropped(self, hand, player)
	moving = false
	player = nil
	playerEnt:GetHMDAnchor():SetParent(nil, "")
end

function ThinkMove(self)
	if not moving
	then
		thisEntity:SetAngularVelocity(0, 0, 0)
		thisEntity:SetAngles(0, 0, 0)
		
		return nil
	end
	
	-- To work fully this would need to get the proper local vector of the controller relative to the platform. 
	local moveVector = (controller:GetAbsOrigin() - thisEntity:GetOrigin() - controllerBasePos) * 0.5
	
	moveVector = moveVector - Vector(0, 0, moveVector.z)
	
	if moveVector:Length() > 100
	then
		moveVector = moveVector:Normalized() * 100
	end
	
	print(controller:GetAbsOrigin())
	DebugDrawLine(controllerBasePos + thisEntity:GetOrigin(), controller:GetAbsOrigin(), 255, 0, 0, false, 0.1)
	
	--thisEntity:ApplyAbsVelocityImpulse(moveVector) -- Applying impulses breaks the prediction on controllers.
	thisEntity:SetOrigin(thisEntity:GetOrigin() + moveVector)
	thisEntity:SetAngularVelocity(0, 0, 0)
	thisEntity:SetAngles(0, 0, 0)
	
	-- Clamp velocity (not needed unless ApplyAbsVelocityImpulse is enabled).
	if thisEntity:GetVelocity():Length() > 10
	then
		local vec = thisEntity:GetVelocity():Normalized() * 10
		thisEntity:SetVelocity(vec)
	end
	return 0.02
end