
local THINK_INTERVAL = 0.02
local DECAY_TIME = 60 
local user = nil
local tracing = false
local decay = true
local carrier = nil

function GetCarryingPlayer()
	return carrier
end

function Activate()
	local arrowColors =
	{
		{255, 0, 0},
		{0, 127, 255},
		{127, 255, 0},
		{255, 216, 51},
		{230, 0, 179},
		{0, 255, 255}
	}
	
	local color = arrowColors[RandomInt(1, #arrowColors)]
	thisEntity:SetRenderColor(color[1], color[2], color[3])
end

function EnableDamage(usingPlayer)
	user = usingPlayer
	tracing = true
	thisEntity:SetThink(ArrowDecay, "decay", DECAY_TIME)
	thisEntity:SetThink(ArrowThink, "think", THINK_INTERVAL)
	ArrowThink(true)
end

function ArrowThink(ignoreSpeed)
	if not tracing
	then 
		return
	end
	
	local idx = thisEntity:ScriptLookupAttachment("tip")	
	local tipOrigin = thisEntity:GetAttachmentOrigin(idx)
	local dir = thisEntity:GetAngles()
	
	local vel = GetPhysVelocity(thisEntity)
	local speed = vel:Length()
	local distanceInterval = speed  * THINK_INTERVAL
	
	if not ignoreSpeed and speed < 20
	then
		tracing = false
		return nil
	end
	
	local traceTable =
	{
		startpos = tipOrigin ;
		endpos = tipOrigin + vel:Normalized() * distanceInterval * 1.1;
		ignore = thisEntity

	}
	--DebugDrawLine(traceTable.startpos, t5raceTable.endpos, 0, 255, 0, false, 10)
	
	TraceLine(traceTable)
	
	if traceTable.hit and thisEntity:GetAngles():Forward():Dot(-traceTable.normal) > 0.5
	then
		if traceTable.enthit and traceTable.enthit:GetEntityIndex() > 0
		then
			
			local dmg = CreateDamageInfo(thisEntity, user, vel * thisEntity:GetMass(), traceTable.pos, speed, DMG_SLASH)
			traceTable.enthit:TakeDamage(dmg)
			DestroyDamageInfo(dmg)
			if IsValidEntity(traceTable.enthit) and traceTable.enthit:IsAlive()
			then
				thisEntity:SetParent(traceTable.enthit, CheckParentAttachment(traceTable.enthit))
			else
				thisEntity:ApplyAbsVelocityImpulse(-vel)
				tracing = false
				thisEntity:SetThink(ArrowDecay, "decay", DECAY_TIME)
				return nil
			end
		else
			DoEntFireByInstanceHandle(thisEntity, "disablemotion", "", 0 , thisEntity, thisEntity)		
		end
		thisEntity:SetOrigin(traceTable.pos - (tipOrigin - thisEntity:GetOrigin()) * (1 - speed * 0.00001))
		
		StartSoundEvent("Arrow.Impact", thisEntity)
		tracing = false
		thisEntity:SetThink(ArrowDecay, "decay", DECAY_TIME)
		return nil
	end
	
	return THINK_INTERVAL
end

function ArrowDecay()
	if decay
	then
		thisEntity:Kill()
	end
end

function CheckParentAttachment(ent)
	if ent:GetName() == "Target"
	then
		return "target"
	end
	return ""
end

function OnPickedUp(this, hand)
	tracing = false
	decay = false
	carrier = hand:GetPlayer()
	thisEntity:SetParent(nil, "")
	DoEntFireByInstanceHandle(thisEntity, "enablemotion", "", 0 , thisEntity, thisEntity)
end

function OnDropped(this, hand)
	carrier = nil
end



