
--[[
	M72 LAW rocket launcer script.
	
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
	
animKeyvals = {
	targetname = "law_anim";
	model = "models/weapons/law_weapon_animated.vmdl";
	solid = 0
	}
	

PrecacheEntityFromTable("prop_physics_override", rocketKeyvals, thisEntity)
PrecacheEntityFromTable("prop_dynamic", animKeyvals, thisEntity)
thisEntity:PrecacheScriptSound("Law.Fire")

g_VRScript.pickupManager:RegisterEntity(thisEntity)

function Init(self)
print("law: Init()")
	animKeyvals.origin = thisEntity:GetOrigin()
	animKeyvals.angles = thisEntity:GetAngles()
	lawAnim = SpawnEntityFromTableSynchronous("prop_dynamic", animKeyvals)
	lawAnim:SetParent(thisEntity, "")
	lawAnim:SetOrigin(thisEntity:GetOrigin())
end

function OnTriggerPressed(self)
	print("law: OnTriggerPressed()")
	
	if not rocket
	then
		StartSoundEvent("Law.Fire", lawAnim)
		print(thisEntity:GetAbsOrigin())
	
		rocketKeyvals.origin = lawAnim:GetOrigin() + RotatePosition(Vector(0,0,0), lawAnim:GetAngles(), ROCKET_OFFSET)
		rocketKeyvals.angles = lawAnim:GetAngles()
		rocket = SpawnEntityFromTableSynchronous("prop_physics_override", rocketKeyvals)
		
		rocket:GetPrivateScriptScope():Fire()
		
		--lawAnim:SetBodygroupByName("fired", 1)
		DoEntFireByInstanceHandle(lawAnim, "SetBodyGroup", "fired", 0, nil, nil)
				
	end
end

function OnTriggerUnpressed(self)
	print("law: OnTriggerUnpressed()")
end

function OnPickedUp(self, hand, player)
	print("law: OnPickedUp()")
	thisEntity:SetParent(nil, "")
	lawAnim:SetParent(hand, "")
	thisEntity:SetOrigin(Vector(0,0, -100000))
	thisEntity:DisableMotion()
	
	if not alreadyPickedUp
	then
		DoEntFireByInstanceHandle(lawAnim, "setSequence", "extend",0 , nil, nil)
		alreadyPickedUp = true
	end

end

function OnDropped(self, hand, player)
	print("law: OnDropped()")
	
	local origin = lawAnim:GetOrigin()
	local angles = lawAnim:GetAngles()
	
	thisEntity:SetOrigin(origin)
	thisEntity:SetAngles(angles.x, angles.y, angles.z)
	lawAnim:SetParent(thisEntity, "")

	--thisEntity:SetAngles(angles.x + 90, angles.y -90, angles.z)
	thisEntity:EnableMotion()
end

