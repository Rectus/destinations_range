--[[
	Rocket script.
	
	Copyright (c) 2016 Rectus
	
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


local ROCKET_INITVELOCITY = 3000
local ROCKET_ADDVELOCITY = 1000
local THINK_INTERVAL = 0.02
local armCounter = 0
local ARM_DELAY = 1 
local TRACE_DISTANCE = 48
local prevAngles = null
local ANGLE_TOLERANCE = 0.1

local EXPLOSION_RANGE = 600
local EXPLOSION_MAX_IMPULSE = 10000

local exploded = false

local explosionKeyvals = {
	fireballsprite = "sprites/zerogxplode.spr";
	iMagnitude = 100;
	rendermode = "kRenderTransAdd"
}

function Precache(context)
	PrecacheEntityFromTable("env_explosion", explosionKeyvals, context)
end

function Fire(self)
	thisEntity:ApplyAbsVelocityImpulse(thisEntity:GetAngles():Forward() * ROCKET_INITVELOCITY)
	thisEntity:ApplyLocalAngularVelocityImpulse(Vector(1000, 0, 0))
	thisEntity:SetThink(Think, "ent_think", THINK_INTERVAL)
end

function Think(self)	
	if exploded 
	then 
		return false
	end
	
	armCounter = armCounter + 1
	if armCounter < ARM_DELAY
	then
		return THINK_INTERVAL
	end
	
	if TraceDirectHit(self)
	then
		Explode(self)
		return false
	end	
	
	return THINK_INTERVAL
end

function TraceDirectHit(self)
	local traceTable =
	{
		startpos = thisEntity:GetOrigin();
		endpos = thisEntity:GetOrigin() + RotatePosition(Vector(0,0,0), thisEntity:GetAngles(), Vector(TRACE_DISTANCE, 0, 0));
		ignore = thisEntity

	}
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 0, 255, 0, false, 0.11)
	TraceLine(traceTable)
	
	if traceTable.hit
	then
		return true
	end
	
	return false
end

function Explode(self)
	exploded = true
	
	local pushEnt = Entities:FindByClassname(nil, "prop_physics_override")
	
	while pushEnt 
	do
		if pushEnt ~= thisEntity
		then
			local distance = (pushEnt:GetCenter() - thisEntity:GetCenter()):Length()
			
			if distance < EXPLOSION_RANGE
			then
				local magnitude = (EXPLOSION_MAX_IMPULSE - EXPLOSION_MAX_IMPULSE * distance / EXPLOSION_RANGE)
				local impulse = (pushEnt:GetCenter() - thisEntity:GetCenter()):Normalized() * magnitude
				pushEnt:ApplyAbsVelocityImpulse(impulse)
			end
		end
		pushEnt = Entities:FindByClassname(pushEnt, "prop_physics_override")
	end
	
	local explosion = SpawnEntityFromTableSynchronous("env_explosion", explosionKeyvals)
	explosion:SetOrigin(thisEntity:GetOrigin())
	DoEntFireByInstanceHandle(explosion, "Explode", "", 0, nil, nil)
	DoEntFireByInstanceHandle(explosion, "Kill", "", 20, nil, nil)
	
	StartSoundEventFromPosition("Law.Explode", thisEntity:GetOrigin())
	print(thisEntity:GetOrigin())
	thisEntity:Kill()
	
end