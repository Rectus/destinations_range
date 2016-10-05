
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


local ROCKET_OFFSET = Vector(30, 0, 0)

local isCarried = false


rocketKeyvals = {
	targetname = "rocket";
	model = "models/weapons/law_rocket.vmdl";
	vscripts = "law_rocket"
	}
	
animKeyvals = {
	targetname = "law_anim";
	model = "models/weapons/law_weapon_animated.vmdl";
	--solid = 0
	}
	
function Precache(context)
	PrecacheModel(animKeyvals.model, context)
	PrecacheModel(rocketKeyvals.model, context)
	PrecacheSoundFile("soundevents/soundevents_addon.vsndevts", context)
end

g_VRScript.pickupManager:RegisterEntity(thisEntity)

function Init(self)
	animKeyvals.origin = thisEntity:GetOrigin()
	animKeyvals.angles = thisEntity:GetAngles()
	lawAnim = SpawnEntityFromTableSynchronous("prop_dynamic", animKeyvals)
	lawAnim:SetParent(thisEntity, "")
	lawAnim:SetOrigin(thisEntity:GetOrigin())
	
end

function OnTriggerPressed(self)
	
	if not rocket
	then
		StartSoundEvent("Law.Fire", lawAnim)
		print(thisEntity:GetAbsOrigin())
	
		rocketKeyvals.origin = lawAnim:GetOrigin() + RotatePosition(Vector(0,0,0), lawAnim:GetAngles(), ROCKET_OFFSET)
		rocketKeyvals.angles = lawAnim:GetAngles()
		rocket = SpawnEntityFromTableSynchronous("prop_physics_override", rocketKeyvals)
		
		rocket:GetPrivateScriptScope():Fire()
		
		DoEntFireByInstanceHandle(lawAnim, "SetBodyGroup", "fired", 0, nil, nil)
				
	end
end

function OnTriggerUnpressed(self)

end

function OnPickedUp(self, hand, player)	
	thisEntity:SetParent(hand, "")
	
	if not alreadyPickedUp
	then
		DoEntFireByInstanceHandle(lawAnim, "setSequence", "extend", 0 , nil, nil)
		alreadyPickedUp = true
	end

end

function OnDropped(self, hand, player)
	thisEntity:SetParent(nil, "")

end

