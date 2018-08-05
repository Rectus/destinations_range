--[[
	Locomotion tool script.
	
	Copyright (c) 2017 Rectus
	
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



local IS_WORLD_GRABBER = true
local GRAB_MAX_DISTANCE = 2
local GRAB_PULL_MIN_DISTANCE = 0.1
local GRAB_MOVE_INTERVAL = 0.02
local PAD_MOVE_INTERVAL = 0.02
local MOVE_CAP_FACTOR = 0.7
local MOVE_SPEED = 300
local AIR_CONTROL_FACTOR = 0.5

local GRAB_PULL_PLAYER_SPEED = 24
local GRAB_PULL_PLAYER_EASE_DISTANCE = 32
local GRAB_TRACE_INTERVAL = 0.02
local ROATATION_ANGLE_MAX_RATE = 10
local MIN_ROTATE_DISTANCE = 4

local MAX_PULL_IMPULSE = 150
local MAX_PULLED_VELOCITY = 100
local PULL_EASE_DISTANCE = 48.0
local CARRY_GLUE_DISTANCE = 16
local OBJECT_PULL_INTERVAL = 0.05

local CARRY_OFFSET = Vector(28, 0, -0.5)
local CARRY_ANGLES = QAngle(-90, 0, 0)

local PICKUP_PROPS = 
{
	"prop_destinations_physics",
	"prop_physics",
	"prop_physics_override"
}

local heldProp = nil

local isCarried = false
local playerEnt = nil
local handEnt = nil
local otherHandObj = nil
local handID = 0
local handAttachment = nil

local grabEndpoint = nil
local playerMoved = false


local rumbleTime = 0
local rumbleFreq = 0
local rumbleInt = 0


local isGrabbing = false
local grabAngles = nil
local grabEnt = nil
local entGrabbed = false
local startRotateVec = nil
local startAngles = nil
local padMovement = false
local padVector = Vector(0,0,0)

local originEnt = nil




function SetEquipped( self, pHand, nHandID, pHandAttachment, pPlayer )
	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	isCarried = true
	otherHandObj = nil
	
	if not originEnt
	then
		
		-- Parenting an entity to the hand gives a less janky position than using the tool or attachment. 
		originEnt = SpawnEntityFromTableSynchronous("info_target", {origin = thisEntity:GetOrigin()})
		originEnt:SetParent(handEnt, "")
	end
	
	local paintColor = thisEntity:GetRenderColor()
	handAttachment:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	
	return true
end

function SetUnequipped()
	if isGrabbing
	then
		ReleaseHold(self)
		isGrabbing = false
	end
	
	playerEnt = nil
	handEnt = nil
	isCarried = false
	
	local paintColor = handAttachment:GetRenderColor()
	thisEntity:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	return true
end


function OnHandleInput( input )
	if not playerEnt
	then 
		return
	end

	-- Even uglier ternary operator
	local IN_TRIGGER = (handID == 0 and IN_USE_HAND0 or IN_USE_HAND1)
	local IN_GRIP = (handID == 0 and IN_GRIP_HAND0 or IN_GRIP_HAND1)
	local IN_PAD = (handID == 0 and IN_PAD_HAND0 or IN_PAD_HAND1)
	local IN_PAD_TOUCH = (handID == 0 and IN_PAD_TOUCH_HAND0 or IN_PAD_TOUCH_HAND1)

	
	if input.buttonsPressed:IsBitSet(IN_TRIGGER)
	then
		input.buttonsPressed:ClearBit(IN_TRIGGER)
		OnTriggerPressed(self)
	end
	
	if input.buttonsReleased:IsBitSet(IN_TRIGGER) 
	then
		input.buttonsReleased:ClearBit(IN_TRIGGER)
		OnTriggerUnpressed(self)
	end
	
	if input.buttonsReleased:IsBitSet(IN_GRIP)
	then
		input.buttonsReleased:ClearBit(IN_GRIP)
		thisEntity:ForceDropTool();
	end

	if input.buttonsPressed:IsBitSet(IN_PAD)
	then
		input.buttonsPressed:ClearBit(IN_PAD)
		padMovement = true
		thisEntity:SetThink(PadMove, "pad_move")
	end
	
	if input.buttonsReleased:IsBitSet(IN_PAD) 
	then
		input.buttonsReleased:ClearBit(IN_PAD)
		padMovement = false
	end

	-- Needed to disable teleports
	if input.buttonsDown:IsBitSet(IN_PAD) 
	then
		input.buttonsDown:ClearBit(IN_PAD)
	end	
	if input.buttonsDown:IsBitSet(IN_PAD_TOUCH) 
	then
		input.buttonsDown:ClearBit(IN_PAD_TOUCH)
	end
	
	if padMovement
	then	
		padVector = Vector(input.trackpadX, input.trackpadY, 0)
	end

	return input;
end


function OnTriggerPressed(self)


	isGrabbing = true

	if TraceGrab()
	then
		
		return
	end

	thisEntity:SetThink(GrabRotateFrame, "grab_move")
	
	
end


function OnTriggerUnpressed(self)

	if isGrabbing
	then
		ReleaseHold(self)
		isGrabbing = false
	end
end


function ReleaseHold(self)
	startRotateVec = nil
	startAngles = nil
	RumbleController(thisEntity, 2, 0.4, 20)
	
	g_VRScript.playerPhysController:RemoveConstraint(playerEnt, thisEntity)
	
end


function PadMove(self)

	if not padMovement or isGrabbing or not g_VRScript.playerPhysController:IsActive(playerEnt, thisEntity)
	then
		return
	end

	local toolForward = RotateOrientation(handAttachment:GetAngles(), QAngle(0, 90, 0))
	local moveVector = RotatePosition(Vector(0,0,0), toolForward, padVector)
	
	--DebugDrawLine(handAttachment:GetOrigin(), handAttachment:GetOrigin() + padVector * 10, 255, 255, 0, false, 0.02)
	--DebugDrawLine(handAttachment:GetOrigin(), handAttachment:GetOrigin() + moveVector * 10, 0, 0, 255, false, 0.02)
	
	moveVector = Vector(moveVector.x, moveVector.y, 0)
	
	if moveVector:Length() > MOVE_CAP_FACTOR
	then
		moveVector = moveVector:Normalized() * MOVE_CAP_FACTOR
	end
	
	if g_VRScript.playerPhysController:IsPlayerOnGround(playerEnt)
	then
		g_VRScript.playerPhysController:MovePlayer(playerEnt, moveVector * MOVE_SPEED * PAD_MOVE_INTERVAL, true)
	else
		g_VRScript.playerPhysController:AddVelocity(playerEnt, moveVector * MOVE_SPEED * PAD_MOVE_INTERVAL * AIR_CONTROL_FACTOR)
	end
	
	
	
	return PAD_MOVE_INTERVAL
end


function GetPlayerEnt()
	return playerEnt
end

function GetOriginEnt()
	return originEnt
end


function GetGrabStatus(self)
	return isGrabbing
end

function FindTool(handID)
	local tool = Entities:FindByClassname(nil, "prop_destinations_tool")
	while tool 
	do
		if tool ~= thisEntity
		then
			local scope = tool:GetPrivateScriptScope()
			if scope.GetPlayerEnt and scope.GetPlayerEnt() == playerEnt
			then
				return tool
			end		
		end
		tool = Entities:FindByClassname(tool, "prop_destinations_tool")
	end
	
	return nil	 
end


function TraceGrab()

	local traceTable =
	{
		startpos = GetMuzzlePos();
		endpos = GetMuzzlePos() + GetMuzzleAng():Forward();
		ignore = playerEnt;
		--mask = 33636363; -- Hopefully TRACE_MASK_PLAYER_SOLID	
		min = Vector(-4, -4, -4);
		max = Vector(4, 4, 4)
	}

	TraceHull(traceTable)
	
	--DebugDrawBox(traceTable.startpos, traceTable.min, traceTable.max, 0, 255, 0, 0, 2)
	
	if traceTable.hit 
	then

		--DebugDrawBox(traceTable.pos, traceTable.min, traceTable.max, 0, 0, 255, 0, 2)
		
		grabEndpoint = GetMuzzlePos()
		g_VRScript.playerPhysController:AddConstraint(playerEnt, thisEntity, true)
		thisEntity:SetThink(GrabMoveFrame, "grab_move")
		
		
		--print(traceTable.enthit:GetDebugName())
		
		
		if traceTable.enthit and traceTable.enthit:GetEntityIndex() > 0
		then
			entGrabbed = true
			if not grabEnt or not IsValidEntity(grabEnt)
			then
				grabEnt = SpawnEntityFromTableSynchronous("info_target", {origin = traceTable.pos})
			end
			grabEnt:SetParent(traceTable.enthit, "")
			grabEnt:SetAbsOrigin(traceTable.pos)
		else
			entGrabbed = false
		end
		
		return true
	end
	return false
end


function GrabRotateFrame(self)
	if not isGrabbing
	then
		return nil
	end
	
	if not g_VRScript.playerPhysController:IsActive(playerEnt, thisEntity)
	then
		return GRAB_MOVE_INTERVAL
	end
	
	
	if not otherHandObj or otherHandObj:IsNull() or otherHandObj:GetPrivateScriptScope():GetPlayerEnt() ~= playerEnt
	then
		otherHandObj = FindTool((handID == 0 and 1 or 0))
	end
	
	if otherHandObj ~= nil
	then
		local otherHandScope = otherHandObj:GetPrivateScriptScope()
	
		if otherHandScope ~= nil and otherHandScope.GetGrabStatus and otherHandScope:GetGrabStatus()
		then
			local origin2D = Vector(originEnt:GetOrigin().x, originEnt:GetOrigin().y, 0)
			local otherOrigin2D = Vector(otherHandScope:GetOriginEnt():GetOrigin().x, otherHandScope:GetOriginEnt():GetOrigin().y, 0)
			--DebugDrawLine(originEnt:GetOrigin(), otherHandScope:GetOriginEnt():GetOrigin(), 255, 0, 0, false, 0.02)
			
			local rotateVector = otherOrigin2D - origin2D 
			
			if rotateVector:Length() > MIN_ROTATE_DISTANCE
			then
				if not startRotateVec
				then
					startRotateVec = rotateVector
					startAngles = playerEnt:GetHMDAnchor():GetAngles()
				end
					
				local rotateOrigin = origin2D + rotateVector * 0.5
	
				local rotAng = NormalizeAngle((VectorToAngles(startRotateVec).y - VectorToAngles(rotateVector).y)) / 5
				
				if abs(rotAng) < 0.1
				then
					rotAng = 0
				elseif rotAng > ROATATION_ANGLE_MAX_RATE
				then
					rotAng = ROATATION_ANGLE_MAX_RATE
				elseif rotAng < -ROATATION_ANGLE_MAX_RATE
				then
					rotAng = -ROATATION_ANGLE_MAX_RATE
				end
				
				if abs(rotAng) > 0.5
				then
					handEnt:FireHapticPulse(0)
					playerEnt:GetHMDAvatar():GetVRHand((handID == 0 and 1 or 0)):FireHapticPulse(0)
				end
				
				local rotation = QAngle(0, rotAng, 0)
	
				local playerAng = playerEnt:GetHMDAnchor():GetAngles()
				local endRot = RotateOrientation(playerAng, rotation)
				playerEnt:GetHMDAnchor():SetAngles(endRot.x, endRot.y, endRot.z)
				local moveVector = RotatePosition(rotateOrigin, rotation, playerEnt:GetHMDAnchor():GetOrigin())
				playerEnt:GetHMDAnchor():SetOrigin(moveVector)
			end
			
		else
			startRotateVec = nil
		end
	end
	
	return GRAB_MOVE_INTERVAL
end


function GrabMoveFrame()

	if not isGrabbing
	then
		return nil
	end
	
	if not g_VRScript.playerPhysController:IsActive(playerEnt, thisEntity)
	then
		return GRAB_MOVE_INTERVAL
	end
	
	local pullVector = nil
	local pullPos = GetMuzzlePos()
	
	if entGrabbed
	then
		if not IsValidEntity(grabEnt) or IsParentedTo(grabEnt, playerEnt)
		then
			ReleaseHold(self)
			isGrabbing = false
			return
		end
	
		grabEndpoint = grabEnt:GetAbsOrigin()
	end
	
	local gunRelativePos = pullPos - playerEnt:GetHMDAnchor():GetOrigin()
	
	
	pullVector = (grabEndpoint - pullPos)
	 
	local distance = pullVector:Length()
	
	if(distance > GRAB_PULL_PLAYER_SPEED)
	then
		pullVector = pullVector:Normalized() * GRAB_PULL_PLAYER_SPEED
	end
	
	-- This would put force back on the prop grabbed
	--[[if entGrabbed
	then
		grabEnt:GetMoveParent():ApplyAbsVelocityImpulse(-pullVector)
	end]]
	
	if distance > GRAB_PULL_MIN_DISTANCE
	then
		if distance < GRAB_PULL_PLAYER_EASE_DISTANCE
		then 
			pullVector = pullVector * distance / GRAB_PULL_PLAYER_EASE_DISTANCE
		end
		-- Prevent player from going through floors
		if pullVector.z < 0 and g_VRScript.playerPhysController:TracePlayerHeight(playerEnt) <= 0
		then
			pullVector = pullVector - Vector(0, 0, pullVector.z)
		end
			
		g_VRScript.playerPhysController:MovePlayer(playerEnt, pullVector, false)
	end
		
	return GRAB_MOVE_INTERVAL
end


function NormalizeAngle(angle)
	if angle > 180
	then 
		return angle - 360
	elseif angle < -180
	then
		return angle + 360
	end
	
	return angle
end


function RumbleController(self, intensity, length, frequency)
	if handEnt
	then
		if rumbleTime == 0
		then
			rumbleTime = length
			rumbleFreq = frequency
			rumbleInt = intensity
		end
		
		handEnt:FireHapticPulse(rumbleInt)
		
		local interval = 1 / rumbleFreq
		
		rumbleTime = rumbleTime - interval
		if rumbleTime < interval
		then
			rumbleTime = 0
			return nil
		end
	
		return interval
	end
	
	rumbleTime = 0
	return nil
end


function IsParentedTo(entity, testEnt)
	local parent = entity:GetMoveParent()
	
	while parent
	do
		if parent == testEnt
		then
			return true
		end
		parent = parent:GetMoveParent()
	end
	return false
end


function GetMuzzlePos()
	local idx = thisEntity:ScriptLookupAttachment("grabpoint")
	return thisEntity:GetAttachmentOrigin(idx)
end

function GetMuzzleAng()
	local idx = handAttachment:ScriptLookupAttachment("muzzle")
	vec = handAttachment:GetAttachmentAngles(idx)
	return QAngle(vec.x, vec.y, vec.z)
end
