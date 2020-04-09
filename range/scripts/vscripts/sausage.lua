
local touchTime = 0
local inMouth = false
local mouthConstraint = nil
local mouthConstraintTgt = nil
local MOUTH_OFFSET = Vector(4, 0, -4)


function Activate()

	if thisEntity:GetName() == "" then
		thisEntity:SetEntityName(UniqueString("sausage"))
	end

	thisEntity:EnableUse(false)
	--thisEntity:SetThink(CheckInMouth, "mouth", 0.1)
	thisEntity:SetThink(EnablePickup, "enable", 0.2)
	touchTime = Time()
end

function EnablePickup()
	thisEntity:EnableUse(true)
end

function OnPickedUp(this, hand)

	local sausage = SpawnSausage(hand)
	if inMouth then
		EmitSoundOn("Suctioncup.Attach", sausage)
	else
		EmitSoundOn("Attempt.Grab", sausage)
	end

	if RandomInt(0, 10) > 9 then
		SpawnSausage(hand)
	end

	thisEntity:Kill()
end


function SpawnSausage(hand)
	local keyvals = {
		classname = "prop_destinations_physics";
		targetname = UniqueString("sausage");
		model = "models/props_food/sausage.vmdl";
		vscripts = "sausage"
	}
	local sausage = SpawnEntityFromTableSynchronous(keyvals.classname, keyvals)
	sausage:SetOrigin(thisEntity:GetAbsOrigin())
	local ang = thisEntity:GetAngles()
	sausage:SetAngles(ang.x, ang.y, ang.z)
	sausage:ApplyAbsVelocityImpulse(Vector(RandomFloat(-5, 5),RandomFloat(-5, 5), RandomFloat(100, 180)) + hand:GetVelocity() * 0.2)
	sausage:ApplyLocalAngularVelocityImpulse(Vector(RandomFloat(-20, 20), RandomFloat(50, 500), RandomFloat(-20, 20)))
	sausage:ApplyLocalAngularVelocityImpulse(RotationDeltaAsAngularVelocity(QAngle(0,0,-90), ang) * 0.3)

	return sausage
end

--[[function CheckInMouth()

	local player = Entities:FindByClassnameNearest("player", thisEntity:GetAbsOrigin(), 128)

	if player then
		local HMD = player:GetHMDAvatar()
		if HMD then

			local mouthPos = HMD:TransformPointEntityToWorld(MOUTH_OFFSET)
			--DebugDrawLine(thisEntity:GetAbsOrigin(), mouthPos, 255, 0, 255, false, 10)

			if (mouthPos - thisEntity:GetAbsOrigin()):Length() < 3
			and GetPhysVelocity(thisEntity):Dot(mouthPos - thisEntity:GetAbsOrigin()) > 0 then

				local HMDOrigin = HMD:TransformPointEntityToWorld(MOUTH_OFFSET)

				thisEntity:SetAbsOrigin(HMDOrigin)
				local ang = HMD:GetAngles()
				thisEntity:SetAbsAngles(ang.x, ang.y, ang.z)


				local keyvals = {
					classname = "phys_constraint";
					targetname = "sausage_constraint";
					attach1 = thisEntity:GetName();
					attach2 = player:GetName();
					enablelinearconstraint = 1;
					enableangularconstraint = 1;
					origin = HMDOrigin;
					attachpoint = thisEntity:GetAbsOrigin();
				}
				keyvals["spawnflags#0"] = "0"
				mouthConstraint = SpawnEntityFromTableSynchronous(keyvals.classname, keyvals)

				EmitSoundOn("Suctioncup.Release", thisEntity)
				inMouth = true
				return nil
			end
		end
	end

	if Time() > touchTime + 20 then
		return nil
	end

	return 0.1
end]]



function OnEaten(eater, mouthPos)

	StartSoundEvent("Attempt.Grab", thisEntity)

	thisEntity:ApplyAbsVelocityImpulse((thisEntity:GetCenter() - mouthPos):Normalized() * 100)
	thisEntity:ApplyAbsVelocityImpulse(Vector(RandomFloat(-5, 5),RandomFloat(-5, 5), RandomFloat(20, 80)))
	thisEntity:ApplyLocalAngularVelocityImpulse(Vector(RandomFloat(-20, 20), RandomFloat(50, 500), RandomFloat(-20, 20)))
	thisEntity:ApplyLocalAngularVelocityImpulse(RotationDeltaAsAngularVelocity(QAngle(0,0,-90), thisEntity:GetAngles()) * 0.3)

	return nil
end


function UpdateOnRemove()
	if mouthConstraint and IsValidEntity(mouthConstraint) then
		mouthConstraint:Kill()
		mouthConstraint = nil
	end

	if mouthConstraintTgt and IsValidEntity(mouthConstraintTgt) then
		mouthConstraintTgt:Kill()
		mouthConstraintTgt = nil
	end
end
