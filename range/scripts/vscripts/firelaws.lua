
function Fire()
	local law = Entities:FindByModel(nil, "models/weapons/law_weapon.vmdl")
	
	while law
	do
		if law:GetPrivateScriptScope().OnTriggerPressed
		then
			law:GetPrivateScriptScope().OnTriggerPressed(law:GetPrivateScriptScope())
		end
		law = Entities:FindByModel(law, "models/weapons/law_weapon.vmdl")
	end
end