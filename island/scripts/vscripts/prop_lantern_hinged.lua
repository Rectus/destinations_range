
local handle = nil
local hinge = nil
local isHeld = false

handleKeyvals = 
{
	classname = "prop_physics_override";
	model = "models/props_misc/lantern_hinged_handle.vmdl";
	targetname = "";
	
}

hingeKeyvals = 
{
	classname = "phys_hinge_local";
	targetname = "";
	attach1 = "";
	attach2 = "";
	hingeaxis = "0 0 -1,  0 0 1";
	hingefriction = 0.1
}


function Precache(context)
	
	PrecacheModel(handleKeyvals.model, context)
	PrecacheEntityFromTable(handleKeyvals.classname, handleKeyvals, context)
	PrecacheEntityFromTable(hingeKeyvals.classname, hingeKeyvals, context)
end

function Activate(keyvals)

	if activateType == ACTIVATE_TYPE_ONRESTORE -- on game load
	then
		EntFireByHandle(thisEntity, thisEntity, "CallScriptFunction", "RestoreState")
	else
		if thisEntity:GetName():len() < 1 then
			thisEntity:SetEntityName(DoUniqueString(tostring(thisEntity:GetEntityIndex())))
		end
	
		CreateHandle()
		--thisEntity:SetThink(Think)
	end

end


function RestoreState()

	thisEntity:GetOrCreatePrivateScriptScope() -- Script scopes do not seem to be properly created on restore
	
	handle = Entities:FindByName(nil, thisEntity:GetName() .. "_handle")
	hinge = Entities:FindByName(nil, thisEntity:GetName() .. "_hinge")
	
	if handle == nil or hinge == nil then
		CreateHandle()
	end
	
	thisEntity:SetThink(Think)
end


function CreateHandle()


	handleKeyvals["origin"] = thisEntity:GetAbsOrigin()
	handleKeyvals["angles"] = thisEntity:GetAngles()
	handle = SpawnEntityFromTableSynchronous(handleKeyvals.classname, handleKeyvals)
	handle:SetAbsScale(thisEntity:GetAbsScale())
	handle:SetEntityName(thisEntity:GetName() .. "_handle") 
	
	
	hingeKeyvals["attach1"] = thisEntity:GetName()
	hingeKeyvals["attach2"] = handle:GetName()
	
	local hingeAtt = thisEntity:ScriptLookupAttachment("hinge")
	hingeKeyvals["angles"] = thisEntity:GetAttachmentAngles(hingeAtt)
	hingeKeyvals["origin"] = thisEntity:GetAttachmentOrigin(hingeAtt)
	
	hinge = SpawnEntityFromTableSynchronous(hingeKeyvals.classname, hingeKeyvals)

	hinge:SetEntityName(thisEntity:GetName() .. "_hinge") 
	EntFireByHandle(thisEntity, hinge, "TurnOn")
	
end


function OnPickedUp(self, hand)

	isHeld = true
end


function OnDropped(self, hand)

	isHeld = false
end


function Think()

	if handle and IsValidEntity(handle) then
	
		local scale = thisEntity:GetAbsScale()
		local handleScale = handle:GetAbsScale()
	
		if scale ~= handleScale then
		
			if isHeld then
				handle:SetAbsScale(scale)
			else
				thisEntity:SetAbsScale(handleScale)
			end
			
			--HingeUpdate()
		end
	end

	return FrameTime() * 4
end


function OnChangeScale(newScale)

	if handle and IsValidEntity(handle) then
		
		handle:SetAbsScale(newScale)
		--HingeUpdate()
	end

end


function HingeUpdate()
	local hingeAtt = thisEntity:ScriptLookupAttachment("hinge")
	local angVec = thisEntity:GetAttachmentAngles(hingeAtt)
	EntFireByHandle(thisEntity, hinge, "TurnOff")
	hinge:SetAbsAngles(angVec.x, angVec.y, angVec.z) 
	hinge:SetAbsOrigin(thisEntity:GetAttachmentOrigin(hingeAtt))
	EntFireByHandle(thisEntity, hinge, "TurnOn", 0.001)
end


function UpdateOnRemove() 
	if handle and IsValidEntity(handle) then
	
		handle:Kill()
	end
	
	if hinge and IsValidEntity(hinge) then
	
		hinge:Kill()
	end
end

