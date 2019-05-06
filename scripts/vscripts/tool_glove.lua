--[[
	Boxing glove script.
	
	Copyright (c) 2016-2019 Rectus
	
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




local playerEnt = nil
local handEnt = nil
local handID = 0
local handAttachment = nil
local isCarried = false
local physGlove = nil
local originEnt = nil
local physConstraint = nil
local lastFireTime = 0
local pickupTime = 0
local PICKUP_TRIGGER_DELAY = 0.5


local constraintKeyvals = {
	classname = "phys_constraint";
	targetname = "";
	attach1 = "";
	attach2 = "";
	linearfrequency = 10;
	lineardampingratio = 2.0;
	enablelinearconstraint = 1;
	enableangularconstraint = 1
}
constraintKeyvals["spawnflags#0"] = "1"

local gloveKeyvals = {
	classname = "prop_destinations_physics";
	physdamagescale = 5	
}

local originKeyvals = {
	classname = "prop_dynamic";
	solid = 0;
}



function Activate()
	thisEntity:SetRenderColor(255, 0, 0)
end


function SetEquipped(self, pHand, nHandID, pHandAttachment, pPlayer)

	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	isCarried = true
	pickupTime = Time()
	
	SpawnPhysProp()
	handAttachment:AddEffects(32)
	
	local paintColor = thisEntity:GetRenderColor()
	handAttachment:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	physGlove:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	return true
end


function SpawnPhysProp()

	gloveKeyvals.model = handAttachment:GetModelName()
	gloveKeyvals.angles = handAttachment:GetAngles()
	gloveKeyvals.origin = handAttachment:GetAbsOrigin()
	
	physGlove = SpawnEntityFromTableSynchronous(gloveKeyvals.classname, gloveKeyvals)
	physGlove:EnableUse(false)
	
	originKeyvals.model = handAttachment:GetModelName()
	originKeyvals.angles = handAttachment:GetAngles()
	originKeyvals.origin = handAttachment:GetAbsOrigin()
	originEnt = SpawnEntityFromTableSynchronous(originKeyvals.classname, originKeyvals)
	originEnt:AddEffects(32)	
	originEnt:SetParent(handAttachment, "")
	
	originEnt:SetEntityName(DoUniqueString("glove_ent"))	
	physGlove:SetEntityName(DoUniqueString("glove_phys"))
	
	constraintKeyvals.origin = handAttachment:GetAbsOrigin()
	constraintKeyvals.attach2 = originEnt:GetName()
	constraintKeyvals.attach1 = physGlove:GetName()

	physConstraint = SpawnEntityFromTableSynchronous(constraintKeyvals.classname, constraintKeyvals)
end


function SetUnequipped()

	local paintColor = handAttachment:GetRenderColor()
	thisEntity:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	if physConstraint and IsValidEntity(physConstraint) then physConstraint:Destroy() end
	if originEnt and IsValidEntity(originEnt) then originEnt:Destroy() end
	if physGlove and IsValidEntity(physGlove) then physGlove:Destroy() end
	
	playerEnt = nil
	handEnt = nil
	isCarried = false
	handAttachment = nil
	
	return true
end


function OnHandleInput( input )
	if not playerEnt
	then 
		return
	end

	-- Even uglier ternary operator
	local IN_TRIGGER = (handID == 0 and IN_USE_HAND0 or IN_USE_HAND1)
	local IN_GRIP = (handID == 0 and IN_GRIP_HAND0 or IN_GRIP_HAND1)
	local IN_PAD = (handID == 0 and IN_PAD_HAND0 or IN_PAD_HAND1)
	local IN_PAD_TOUCH = (handID == 0 and IN_PAD_TOUCH_HAND0 or IN_PAD_TOUCH_HAND1)
	
	
	if input.buttonsPressed:IsBitSet(IN_TRIGGER)
	then
		input.buttonsPressed:ClearBit(IN_TRIGGER)
		if Time() > pickupTime + PICKUP_TRIGGER_DELAY
		then
			OnTriggerPressed(self)
		end
	end
	
	if input.buttonsReleased:IsBitSet(IN_TRIGGER) 
	then
		input.buttonsReleased:ClearBit(IN_TRIGGER)
	end

	return input
end



function OnTriggerPressed()
	if Time() > lastFireTime + 0.3 then
		lastFireTime = Time()
		physGlove:ApplyAbsVelocityImpulse(handAttachment:GetAngles():Forward() * 800)
	end
end


