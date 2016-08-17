--[[
	Prop_dynamic version of LAW.
	
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

ROCKET_OFFSET = Vector(30, 0, 0)

isCarried = false


rocketKeyvals = {
	targetname = "rocket";
	model = "models/weapons/law_rocket.vmdl";
	vscripts = "law_rocket"
	}

PrecacheEntityFromTable("prop_physics_override", rocketKeyvals, thisEntity)

g_VRScript.pickupManager:RegisterEntity(thisEntity)

function Init(self)
print("law_d: Init()")
	DoEntFireByInstanceHandle(thisEntity, "setSequence", "folded", 0, nil, nil)
end

function OnTriggerPressed(self)
	print("law: OnTriggerPressed()")
	
	if not rocket
	then
		rocketKeyvals.origin = thisEntity:GetOrigin() + RotatePosition(Vector(0,0,0), thisEntity:GetAngles(), ROCKET_OFFSET)
		rocketKeyvals.angles = thisEntity:GetAngles()
		rocket = SpawnEntityFromTableSynchronous("prop_physics_override", rocketKeyvals)
		
		rocket:GetPrivateScriptScope():Fire()
		
		DoEntFireByInstanceHandle(thisEntity, "SetBodyGroup", "fired", 0, nil, nil)
				
	end
end

function OnTriggerUnpressed(self)
	print("law: OnTriggerUnpressed()")
end

function OnPickedUp(self, hand, player)
	print("law: OnPickedUp()")
	thisEntity:SetParent(hand, "")
	
	if not alreadyPickedUp
	then
		DoEntFireByInstanceHandle(thisEntity, "setSequence", "extend", 0, nil, nil)
		alreadyPickedUp = true
	end

end

function OnDropped(self, hand, player)
	print("law: OnDropped()")

	thisEntity:SetParent(nil, "")
	DoEntFireByInstanceHandle(thisEntity, "enablemotion", "", .1, nil, nil)
end
