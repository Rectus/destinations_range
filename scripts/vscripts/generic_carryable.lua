
-- Physics prop that can be picked up and thrown

g_VRScript.pickupManager:RegisterEntity(thisEntity)

THROW_VECTOR = Vector(100, 0, 0)
isCarried = false

function OnTriggerPressed(self)
	if thisEntity:GetMoveParent() and not thisEntity:GetMoveParent():IsNull()
	then
		throwImpulse = RotatePosition(Vector(0, 0, 0), thisEntity:GetMoveParent():GetAngles(), THROW_VECTOR)
		thisEntity:SetParent(nil, "")
		isCarried = false
		thisEntity:ApplyAbsVelocityImpulse(throwImpulse)
	end
end

function OnTriggerUnpressed(self)

end

function OnPickedUp(self, hand, player)
	hand:AddHandModelOverride("models/weapons/hand_dummy.vmdl")
	thisEntity:SetParent(hand, "")

end

function OnDropped(self, hand, player)
	hand:RemoveHandModelOverride("models/weapons/hand_dummy.vmdl")
	thisEntity:SetParent(nil, "")
end