
--[[
	Flashlight script.
	
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

local turnedOn = false
local lightEnt = nil

local lightKeyvals = {
	classname = "light_spot";
	targetname = "flashlight_light";
	enabled = 0;
	color = "209 192 184 255";
	brightness = 3;
	range = 3000;
	indirectlight = 0;
	attenuation1 = 0.3;
	attenuation2 = 0;
	falloff = 10;
	innerconeangle = 10;
	outerconeangle = 20;
}

function Init(self)
	lightEnt = SpawnEntityFromTableSynchronous(lightKeyvals.classname, lightKeyvals)
	lightEnt:SetParent(thisEntity, "light")
	
	lightEnt:SetOrigin(thisEntity:GetOrigin())
	local lightAngles = thisEntity:GetAngles()
	lightEnt:SetAngles(lightAngles.x, lightAngles.y, lightAngles.z)
end

function OnTriggerPressed(self)
	if turnedOn
	then
		turnedOn = false
		DoEntFireByInstanceHandle(thisEntity, "Skin", "0", 0 , nil, nil)
		DoEntFireByInstanceHandle(lightEnt, "TurnOff", "", 0 , nil, nil)
	else
		turnedOn = true
		DoEntFireByInstanceHandle(thisEntity, "Skin", "1", 0 , nil, nil)
		DoEntFireByInstanceHandle(lightEnt, "TurnOn", "", 0 , nil, nil)
	end
end

function OnTriggerUnpressed(self)

end

function OnPickedUp(self, hand, player)

	thisEntity:SetParent(hand, "")

end

function OnDropped(self, hand, player)

	thisEntity:SetParent(nil, "")
end