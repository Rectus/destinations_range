--[[
	Boxing glove script.
	
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




local playerEnt = nil
local handEnt = nil
local handID = 0
local handAttachment = nil
local isCarried = false
local physGlove = nil
local toolTarget = nil
local physConstraint = nil
local lastFireTime = 0


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
	--physdamagescale = 100	
}


function Activate()
	thisEntity:SetRenderColor(255, 0, 0)
	
	gloveKeyvals.model = thisEntity:GetModelName()
	gloveKeyvals.angles = thisEntity:GetAngles()
	gloveKeyvals.origin = thisEntity:GetAbsOrigin()
	
	physGlove = SpawnEntityFromTableSynchronous(gloveKeyvals.classname, gloveKeyvals)
	physGlove:EnableUse(false)
	physGlove:SetRenderColor(255, 0, 0)
	
	thisEntity:SetEntityName(DoUniqueString("glove_ent"))	
	physGlove:SetEntityName(DoUniqueString("glove_phys"))
	
	constraintKeyvals.origin = thisEntity:GetAbsOrigin()
	constraintKeyvals.attach2 = thisEntity:GetName()
	constraintKeyvals.attach1 = physGlove:GetName()

	physConstraint = SpawnEntityFromTableSynchronous(constraintKeyvals.classname, constraintKeyvals)
	physConstraint:SetEntityName(DoUniqueString("glove_const"))
	physGlove:SetParent(thisEntity, "")
	physGlove:AddEffects(32)
end



function SetEquipped(self, pHand, nHandID, pHandAttachment, pPlayer)

	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	isCarried = true
	
	handAttachment:AddEffects(32)
	
	physGlove:SetParent(nil, "")
	physGlove:RemoveEffects(32)
	DoEntFireByInstanceHandle(physConstraint, "TurnOn", "", 0, nil, nil)
	
	local paintColor = thisEntity:GetRenderColor()
	handAttachment:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	physGlove:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	--thisEntity:SetThink(GloveThink, "glove", 0)
	return true
end




function SetUnequipped()

	local paintColor = handAttachment:GetRenderColor()
	thisEntity:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	
	physGlove:AddEffects(32)
	DoEntFireByInstanceHandle(physConstraint, "TurnOff", "", 0, nil, nil)
	physGlove:SetParent(thisEntity, "")
	
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
		OnTriggerPressed(self)
	end
	
	if input.buttonsReleased:IsBitSet(IN_TRIGGER) 
	then
		input.buttonsReleased:ClearBit(IN_TRIGGER)
	end
	
	if input.buttonsReleased:IsBitSet(IN_GRIP)
	then
		input.buttonsReleased:ClearBit(IN_GRIP)
		thisEntity:ForceDropTool()
	end
	


	-- Needed to disable teleports
	--[[if input.buttonsDown:IsBitSet(IN_PAD) 
	then
		input.buttonsDown:ClearBit(IN_PAD)
	
	end	
	if input.buttonsDown:IsBitSet(IN_PAD_TOUCH) 
	then
		input.buttonsDown:ClearBit(IN_PAD_TOUCH)
	end]]

	return input
end



function OnTriggerPressed()
	if Time() > lastFireTime + 0.3 then
		lastFireTime = Time()
		physGlove:ApplyAbsVelocityImpulse(thisEntity:GetAngles():Forward():Normalized() * 500)
	end
end


