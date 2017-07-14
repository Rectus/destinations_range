

--local dmgInfo = CreateDamageInfo(nil, nil, Vector(1,0,0), 
				--Vector(1,0,0),  10, DMG_BULLET)
	
print("test")	
print(Vector4D())



--[[
print(DMG_GENERIC)
		
print(DMG_CRUSH)
print(DMG_BULLET)
print(DMG_SLASH)
print(DMG_BURN)
print(DMG_BLAST)
print(DMG_SHOCK)
print(dmgInfo:GetDamage())				
print(dmgInfo:AddDamage(1))
print(dmgInfo:GetDamage())

print(dmgInfo:GetDamageType())
print(dmgInfo:AddDamageType(DMG_BURN))
print(dmgInfo:GetDamageType())

print(dmgInfo:AllowFriendlyFire())
print(dmgInfo:BaseDamageIsValid())
print(dmgInfo:CanBeBlocked())
print(dmgInfo:GetAmmoType())
print(dmgInfo:GetAttacker())
print(dmgInfo:GetBaseDamage())
print(dmgInfo:GetDamageCustom())
print(dmgInfo:GetDamageTaken())
print(dmgInfo:GetInflictor())
print(dmgInfo:GetMaxDamage())
print(dmgInfo:GetOriginalDamage())

DestroyDamageInfo(dmgInfo)
]]