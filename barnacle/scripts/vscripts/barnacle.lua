
local STATE_IDLE = 1
local STATE_RESETTING_TONGUE = 2
local STATE_PULLING_PLAYER = 3
local STATE_PULLING_PROP = 4
local STATE_EATING_PLAYER = 5
local STATE_EATING_PROP = 6
local STATE_CHEWING_PROP = 7
local STATE_SPITTING_PROP = 8
local STATE_CHEWING_PLAYER = 9

local state = STATE_RESETTING_TONGUE

local TONGUE_SPEED = 24
local TONGUE_MOVE_INTERVAL = 0.02
local TONGUE_GRAB_PULL_DELAY = 1
local TONGUE_MIN_LENGTH = 16
local TONGUE_MAX_LENGTH = 390
local TONGUE_OFFSET_SPEED = 1
local TONGUE_PLAYER_OFFSET = Vector(2, -4, 0)
local TONGUE_WRAP_TIME = 0.2

local TONGUE_TWITCH_MIN = 5
local TONGUE_TWITCH_MAX = 15
local TONGUE_TWITCH_RETURN_MIN = 0.5
local TONGUE_TWITCH_RETURN_MAX = 2

local tongueLen = 350
local tongueLenTarget = 0
local tongueWrap = 0
local tongueWrapTarget = 0

local pullSoundTimer = 0
local PULL_SOUND_INTERVAL = 2

local grabbedEnt = nil
local grabOffset = 0

local tastedProps = {}

function Precache(context)
	PrecacheSoundFile("soundevents/soundevents_addon.vsndevts", context)
end


function SetToungueLength(length, delay, ignoreAnim)
	delay = delay or 0
	tongueLenTarget = length
	thisEntity:SetThink(TongueMoveThink, "tongue_move", delay)
	pullSoundTimer = PULL_SOUND_INTERVAL
	
	if not ignoreAnim
	then
		if tongueLen < tongueLenTarget
		then
			DoEntFireByInstanceHandle(thisEntity, "SetAnimation", "reset_tongue", 0, thisEntity, ThisEntity)
		else
			DoEntFireByInstanceHandle(thisEntity, "SetAnimation", "slurp", 0, thisEntity, ThisEntity)
		end
	end
end

function TongueMoveThink()
	local moveTick = TONGUE_SPEED * TONGUE_MOVE_INTERVAL
	
	if abs(tongueLen - tongueLenTarget) <= moveTick
	then
		tongueLen = tongueLenTarget
		thisEntity:SetPoseParameter("tongue_length", tongueLen)
		
		if state == STATE_PULLING_PLAYER
		then
			if not IsValidEntity(grabbedEnt)
			then
				state = STATE_RESETTING_TONGUE
				SetToungueLength(TONGUE_MAX_LENGTH)
				DoEntFireByInstanceHandle(thisEntity, "SetAnimation", "reset_tongue", 0, thisEntity, ThisEntity)
				return TONGUE_MOVE_INTERVAL
			end
		
			state = STATE_EATING_PLAYER
			DoEntFireByInstanceHandle(thisEntity, "SetAnimation", "eat_humanoid", 0, thisEntity, ThisEntity)
			thisEntity:EmitSound("NPC_Barnacle.Scream")
			thisEntity:SetThink(MouthGrabPlayer, "mouth_grab", 0.5)
			SetToungueLength(TONGUE_MIN_LENGTH, 0.05, true)
			SetToungueWrap(0)
			
		elseif state == STATE_PULLING_PROP
		then
			if not IsValidEntity(grabbedEnt)
			then
				state = STATE_RESETTING_TONGUE
				SetToungueLength(TONGUE_MAX_LENGTH)
				DoEntFireByInstanceHandle(thisEntity, "SetAnimation", "reset_tongue", 0, thisEntity, ThisEntity)
				return TONGUE_MOVE_INTERVAL
			end
		
			SetToungueWrap(0)
			print(GetMaxDimension(grabbedEnt))
			if GetMaxDimension(grabbedEnt) > 19
			then
				state = STATE_SPITTING_PROP
				tastedProps[grabbedEnt] = true
				DoEntFireByInstanceHandle(thisEntity, "SetAnimation", "taste_spit", 0, thisEntity, ThisEntity)
				local origin = grabbedEnt:GetAbsOrigin()
				grabbedEnt:SetParent(thisEntity, "mouth")
				grabbedEnt:SetAbsOrigin(origin)
				thisEntity:SetThink(MouthPropSpit, "spit", 1.95)
			else
				state = STATE_EATING_PROP
				tastedProps[grabbedEnt] = true
				DoEntFireByInstanceHandle(thisEntity, "SetAnimation", "attack_smallthings", 0, thisEntity, ThisEntity)
				local origin = grabbedEnt:GetAbsOrigin()
				grabbedEnt:SetParent(thisEntity, "mouth")
				grabbedEnt:SetAbsOrigin(origin + Vector(0, 0, 32))
				thisEntity:SetThink(MouthGrabProp, "mouth_grab", 0.5)
			end
			
		elseif state == STATE_RESETTING_TONGUE
		then
			state = STATE_IDLE
			AnimationDone(nil)
			thisEntity:SetThink(CheckTrigger, "trigger", 0.5)
		end
		
		
		return nil
	end
	
	if tongueLen < tongueLenTarget
	then
		tongueLen = tongueLen + moveTick
	else
		tongueLen = tongueLen - moveTick
		
		if pullSoundTimer <= 0
		then
			pullSoundTimer = PULL_SOUND_INTERVAL
			thisEntity:EmitSound("NPC_Barnacle.PullPant")
		else
			pullSoundTimer = pullSoundTimer - TONGUE_MOVE_INTERVAL
		end
	end
	
	if state == STATE_PULLING_PLAYER
	then
		if not IsValidEntity(grabbedEnt)
		then
			state = STATE_RESETTING_TONGUE
			SetToungueLength(TONGUE_MAX_LENGTH)
			DoEntFireByInstanceHandle(thisEntity, "SetAnimation", "reset_tongue", 0, thisEntity, ThisEntity)
			return TONGUE_MOVE_INTERVAL
		end
	
		MoveGrabbed(grabbedEnt:GetHMDAvatar(), grabbedEnt:GetHMDAnchor())
		
	elseif state == STATE_PULLING_PROP
	then
		if not IsValidEntity(grabbedEnt)
		then
			state = STATE_RESETTING_TONGUE
			SetToungueLength(TONGUE_MAX_LENGTH)
			DoEntFireByInstanceHandle(thisEntity, "SetAnimation", "reset_tongue", 0, thisEntity, ThisEntity)
			return TONGUE_MOVE_INTERVAL
		end
	
		if grabbedEnt:GetMoveParent()
		then
			grabbedEnt:SetParent(nil, nil)
		end
		
		MoveGrabbed(grabbedEnt)
	end
	
	
	thisEntity:SetPoseParameter("tongue_length", tongueLen)
	
	return TONGUE_MOVE_INTERVAL
end


function MouthGrabPlayer()
	grabbedEnt:GetHMDAnchor():SetParent(thisEntity, "mouth")
	thisEntity:EmitSound("NPC_Barnacle.FinalBite")

	thisEntity:SetThink(PlayerNeckSnap, "neck_snap", 1.5)
	return nil
end

function PlayerNeckSnap()	
	grabbedEnt:GetHMDAnchor():SetOrigin(Entities:FindByName(nil, "deathtarget"):GetOrigin())
	grabbedEnt:EmitSound("NPC_Barnacle.BreakNeck")
	grabbedEnt:GetHMDAnchor():SetParent(nil, nil)
end 


function MouthGrabProp()
	--grabbedEnt:SetParent(thisEntity, "mouth")
	thisEntity:EmitSound("NPC_Barnacle.FinalBite")

	local dmg = CreateDamageInfo(thisEntity, thisEntity, Vector(0, 0, -100), grabbedEnt:GetAbsOrigin(), 1000, 1)
	grabbedEnt:TakeDamage(dmg)
	DestroyDamageInfo(dmg)

	--thisEntity:SetThink(MouthPropSpit, "neck_snap", 1.5)
	return nil
end

function MouthPropSpit()
	grabbedEnt:SetParent(nil, nil)
	grabbedEnt:ApplyAbsVelocityImpulse(GetAttachment("mouth").angles:Forward():Normalized() * -500)
	--thisEntity:EmitSound("NPC_Barnacle.Digest")
end 


function TongueTwitch()
	if state ~= STATE_IDLE
	then
		return nil
	end
	
	if tongueWrapTarget < 0.01
	then
		SetToungueWrap(0.4)
		return RandomFloat(TONGUE_TWITCH_RETURN_MIN, TONGUE_TWITCH_RETURN_MAX)
	else
		SetToungueWrap(0)
		return RandomFloat(TONGUE_TWITCH_MIN, TONGUE_TWITCH_MAX)
	end
end


function SetToungueWrap(factor)
	tongueWrapTarget = factor
	thisEntity:SetThink(ToungueWrapThink, "tongue_wrap")
end


function ToungueWrapThink()
	if abs(tongueWrap - tongueWrapTarget) <= TONGUE_WRAP_TIME * TONGUE_MOVE_INTERVAL
	then
		tongueWrap = tongueWrapTarget
		thisEntity:SetPoseParameter("tongue_wrap", tongueWrap)
		return nil
	end
	
	if tongueWrap < tongueWrapTarget
	then
		tongueWrap = tongueWrap + TONGUE_WRAP_TIME * TONGUE_MOVE_INTERVAL
	else
		tongueWrap = tongueWrap - TONGUE_WRAP_TIME * TONGUE_MOVE_INTERVAL
	end
	thisEntity:SetPoseParameter("tongue_wrap", tongueWrap)
	return TONGUE_MOVE_INTERVAL
end


function MoveGrabbed(ent, moveEnt)
	moveEnt = moveEnt or ent
	
	local barnaclePos = thisEntity:GetCenter()
	if state == STATE_PULLING_PLAYER
	then
		barnaclePos = barnaclePos + TONGUE_PLAYER_OFFSET 
	end
	
	local offset = Vector(ent:GetCenter().x, ent:GetCenter().y, 0) - Vector(barnaclePos.x, barnaclePos.y, 0)
	local pullDist = (GetAttachment("tongue_tip").origin.z + grabOffset) - ent:GetCenter().z
	
	local distTick = TONGUE_OFFSET_SPEED * TONGUE_MOVE_INTERVAL * offset:Length() * offset:Length() 

	if offset:Length() > distTick
	then
		moveEnt:SetOrigin(moveEnt:GetOrigin() + offset:Normalized() * (-distTick) + Vector(0, 0, pullDist))
	else
		moveEnt:SetOrigin(moveEnt:GetOrigin() - offset + Vector(0, 0, pullDist))
	end

end


function TongueTouched(trigger)
	if state ~= STATE_IDLE
	then
		return
	end
	
	if trigger.activator
	then
		--
		grabbedEnt = trigger.activator
	
		if trigger.activator:GetClassname() == "player"
		then
			local playerHeight = grabbedEnt:GetHMDAvatar():GetOrigin().z
			grabOffset = playerHeight - GetAttachment("tongue_tip").origin.z 
			SetToungueLength(playerHeight + 42, TONGUE_GRAB_PULL_DELAY)
			SetToungueWrap(1)
			state = STATE_PULLING_PLAYER
		else
			if tastedProps[grabbedEnt]
			then
				thisEntity:SetThink(CheckTrigger, "trigger", 0.3)
				return
			end
			
			local propHeight = trigger.activator:GetCenter().z
			grabOffset = propHeight - GetAttachment("tongue_tip").origin.z 
			SetToungueWrap(0)
			state = STATE_PULLING_PROP
			SetToungueLength(propHeight + 24 - GetMinDimension(grabbedEnt), TONGUE_GRAB_PULL_DELAY)
			grabbedEnt:SetParent(thisEntity, "tongue_tip")

		end
		
		thisEntity:EmitSound("NPC_Barnacle.TongueStretch")
	end
end


function PlayPullSound()
	if RandomFloat(0, 1) > 0.5
	then
		thisEntity:EmitSound("NPC_Barnacle.PullPant")
	else
		thisEntity:EmitSound("NPC_Barnacle.TongueStretch")
	end
end


function CheckTrigger()
	local trigger = Entities:FindByName(nil, "barnacle_trigger")
	local ent = Entities:First()
	
	while ent
	do
		if trigger:IsTouching(ent) and (tastedProps[ent] == nil)
		then
			print(ent:GetClassname())
			TongueTouched({activator = ent})
			return
		end
		ent = Entities:Next(ent)
	end
end

function AnimationDone(params)

	if state == STATE_IDLE
	then
		DoEntFireByInstanceHandle(thisEntity, "SetAnimation", "idle01", 0, thisEntity, ThisEntity)
		local delay = RandomFloat(TONGUE_TWITCH_MIN, TONGUE_TWITCH_MAX)
		thisEntity:SetThink(TongueTwitch, "tongue_twitch", delay)
		
	elseif state == STATE_EATING_PLAYER
	then
		state = STATE_CHEWING_PLAYER
		DoEntFireByInstanceHandle(thisEntity, "SetAnimation", "chew_humanoid", 0, thisEntity, ThisEntity)
		
	elseif state == STATE_CHEWING_PLAYER
	then
		state = STATE_SPITTING_PROP
		DoEntFireByInstanceHandle(thisEntity, "SetAnimation", "barf_humanoid", 0, thisEntity, ThisEntity)
		thisEntity:EmitSound("NPC_Barnacle.Digest")
	
	elseif state == STATE_EATING_PROP
	then
		DoEntFireByInstanceHandle(thisEntity, "SetAnimation", "chew_smallthings", 0, thisEntity, ThisEntity)
		thisEntity:EmitSound("NPC_Barnacle.Digest")
		state = STATE_CHEWING_PROP
		
	elseif state == STATE_CHEWING_PROP
	then
		if not grabbedEnt:IsNull()
		then
			grabbedEnt:SetParent(nil, nil)
		end
		SetToungueLength(TONGUE_MAX_LENGTH)
		state = STATE_RESETTING_TONGUE
	
	elseif state == STATE_SPITTING_PROP
	then
		SetToungueLength(TONGUE_MAX_LENGTH)
		state = STATE_RESETTING_TONGUE
		
	elseif state == STATE_RESETTING_TONGUE
	then
		DoEntFireByInstanceHandle(thisEntity, "SetAnimation", "reset_tongue", 0, thisEntity, ThisEntity)
	else
		--DoEntFireByInstanceHandle(thisEntity, "SetAnimation", "idle01", 0, thisEntity, ThisEntity)
	end
end


function GetAttachment(name)
	local idx = thisEntity:ScriptLookupAttachment(name)
	
	local table = {}
	table.origin = thisEntity:GetAttachmentOrigin(idx)
	table.angles = VectorToAngles(thisEntity:GetAttachmentAngles(idx))
	
	return table
end


function GetMaxDimension(entity)
	local boundMin = entity:GetBoundingMins()
	local boundMax = entity:GetBoundingMaxs()
	
	return max(abs(boundMax.x - boundMin.x), abs(boundMax.y - boundMin.y), abs(boundMax.z - boundMin.z))
end


function GetMinDimension(entity)
	local boundMin = entity:GetBoundingMins()
	local boundMax = entity:GetBoundingMaxs()
	
	return min(abs(boundMax.x - boundMin.x), abs(boundMax.y - boundMin.y), abs(boundMax.z - boundMin.z))
end

