


g_VRScript.pickupManager:RegisterEntity(thisEntity)

local CARRY_OFFSET = Vector(3.5, 0, -0.5)
local CARRY_ANGLES = QAngle(0, 0, 0)

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
	castshadows = 1;
}

function Init(self)
	lightEnt = SpawnEntityFromTableSynchronous(lightKeyvals.classname, lightKeyvals)
	lightEnt:SetParent(thisEntity, "light")
	
	lightEnt:SetOrigin(thisEntity:GetOrigin())
	local lightAngles = thisEntity:GetAngles()
	lightEnt:SetAngles(lightAngles.x, lightAngles.y, lightAngles.z)
	PrecacheSoundFile("soundevents/soundevents_addon.vsndevts", context)
end

function OnTriggerPressed(self)
	StartSoundEvent("Flashlight.Button", thisEntity)
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
	hand:AddHandModelOverride("models/weapons/hand_dummy.vmdl")

	thisEntity:SetParent(hand, "")
	thisEntity:SetOrigin(hand:GetOrigin() + RotatePosition(Vector(0,0,0), hand:GetAngles(), CARRY_OFFSET))
	local carryAngles = RotateOrientation(hand:GetAngles(), CARRY_ANGLES)
	thisEntity:SetAngles(carryAngles.x, carryAngles.y, carryAngles.z)

end

function OnDropped(self, hand, player)
	hand:RemoveHandModelOverride("models/weapons/hand_dummy.vmdl")
	thisEntity:SetParent(nil, "")
end