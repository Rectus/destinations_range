
local KEYVALS = {
	classname = "prop_destinations_physics"; 
	targetname = "sausage";
	model = "models/props_food/sausage.vmdl";
	vscripts = "sausage"
}

function Activate()
	thisEntity:EnableUse(false)
	thisEntity:SetThink(EnablePickup, "enable", 0.2)
end

function EnablePickup()
	thisEntity:EnableUse(true)
end

function OnPickedUp(this, hand)
	
	local sausage = SpawnSausage()
	StartSoundEvent("Attempt.Grab", sausage)
	
	if RandomInt(0, 10) > 9 then
		SpawnSausage()
	end
	
	thisEntity:Kill()
end


function SpawnSausage()
	local keyvals = {
		classname = "prop_destinations_physics"; 
		targetname = "sausage";
		model = "models/props_food/sausage.vmdl";
		vscripts = "sausage"
	}
	local sausage = SpawnEntityFromTableSynchronous(keyvals.classname, keyvals)
	sausage:SetOrigin(thisEntity:GetAbsOrigin())
	local ang = thisEntity:GetAngles()
	sausage:SetAngles(ang.x, ang.y, ang.z)
	sausage:ApplyAbsVelocityImpulse(Vector(RandomFloat(-5, 5),RandomFloat(-5, 5), RandomFloat(100, 180)))
	sausage:ApplyLocalAngularVelocityImpulse(Vector(RandomFloat(-20, 20), RandomFloat(50, 500), RandomFloat(-20, 20)))
	sausage:ApplyLocalAngularVelocityImpulse(RotationDeltaAsAngularVelocity(QAngle(0,0,-90), ang) * 0.3)
	
	return sausage
end

function OnEaten(eater, mouthPos)

	StartSoundEvent("Attempt.Grab", thisEntity)
	
	thisEntity:ApplyAbsVelocityImpulse((thisEntity:GetCenter() - mouthPos):Normalized() * 100)
	thisEntity:ApplyAbsVelocityImpulse(Vector(RandomFloat(-5, 5),RandomFloat(-5, 5), RandomFloat(20, 80)))
	thisEntity:ApplyLocalAngularVelocityImpulse(Vector(RandomFloat(-20, 20), RandomFloat(50, 500), RandomFloat(-20, 20)))
	thisEntity:ApplyLocalAngularVelocityImpulse(RotationDeltaAsAngularVelocity(QAngle(0,0,-90), thisEntity:GetAngles()) * 0.3)
	
	return nil 
end