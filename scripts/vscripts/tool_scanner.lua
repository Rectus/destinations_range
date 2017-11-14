--[[
	Prop scanner script.
	
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

require("particle_system")

local PUNT_IMPULSE = 1000
local MAX_PULL_IMPULSE = 250
local MAX_PULLED_VELOCITY = 500
local PULL_EASE_DISTANCE = 32.0
local CARRY_DISTANCE = 32
local CARRY_GLUE_DISTANCE = 16
local TRACE_DISTANCE = 1024
local OBJECT_PULL_INTERVAL = 0.1
local BEAM_TRACE_INTERVAL = 0.01
local BEAM_SCAN_INTERVAL = 0.01
local SCAN_TIME = 1
local PUNT_DISTANCE = 512

local playerEnt = nil
local handID = 0
local handEnt = nil
local handAttachment = nil
local scannedEntity = nil
local beamParticle = nil
local isTargeting = false
local isScanning = false
local scanStartTime = 0
local scanDirection = nil
local screen = nil
local screenText = nil

local screenKeyvals = {
	classname = "point_clientui_world_panel";
	targetname = "scanner_panel";
	dialog_layout_name = "file://{resources}/layout/custom_destination/scanner_display.xml";
	color = "209 192 184 255";
	panel_dpi = 100;
	width = 3.15;
	height = 3.95;
	ignore_input = 1;
	horizontal_align = 0;
	vertical_align = 0;
	orientation = 0;
}

local bootMessage =
{
	"EntScan BIOS 0.3.1 Initalized";
	"Mem: 16384 Bytes OK";
	"RF Scanner On-Line";
	"Antenna Calibrated";
	"";
	"Ready to scan..."
}
local bootCounter = 1

local propClasses = {"prop_physics"; "prop_physics_override"; "simple_physics_prop";
	"prop_destinations_physics"; "prop_destinations_tool"; "steamTours_item_tool"}

function Precache(context)
	PrecacheParticle("particles/item_laser_pointer.vpcf", context)
	PrecacheSoundFile("soundevents/soundevents_addon.vsndevts", context)
end


function SetEquipped( self, pHand, nHandID, pHandAttachment, pPlayer )
	handID = nHandID
	handEnt = pHand
	playerEnt = pPlayer
	handAttachment = pHandAttachment
	isCarried = true
	
	if not screen or not IsValidEntity(screen)
	then
		screen = SpawnEntityFromTableSynchronous(screenKeyvals.classname, screenKeyvals)
		screen:SetParent(handAttachment, "screen")
		screen:SetLocalOrigin(Vector(0,0,0))
		screen:SetLocalAngles(0, 0, 0)
		
		--CustomGameEventManager:Send_ServerToAllClients("scanner_display_register", {id = thisEntity:GetEntityIndex()})
		
		if not screenText
		then
			SetPanelText(self, "bootMessage[1]")
			thisEntity:SetThink(BootMessage, "boot_panel", 0.3)
			thisEntity:EmitSound("Scanner.Track")
		else
			SetPanelText(self, screenText)
		end
	end
	
	thisEntity:EmitSound("Scanner.Equip")
	
	local paintColor = thisEntity:GetRenderColor()
	handAttachment:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	return true
end


function SetUnequipped()
		
	playerEnt = nil
	handEnt = nil
	
	if screen and IsValidEntity(screen)
	then	
		screen:Kill()
	end
	thisEntity:StopSound("Scanner.Scan")
	thisEntity:StopSound("Scanner.Track")
	
	local paintColor = handAttachment:GetRenderColor()
	thisEntity:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
	
	isTargeting = false
	
	return true
end


function OnHandleInput( input )
	if not playerEnt
	then 
		return
	end

	-- Even uglier lua ternary operator
	local IN_TRIGGER = (handID == 0 and IN_USE_HAND0 or IN_USE_HAND1)
	local IN_PAD = (handID == 0 and IN_PAD_HAND0 or IN_PAD_HAND1)
	local IN_PAD_TOUCH = (handID == 0 and IN_PAD_TOUCH_HAND0 or IN_PAD_TOUCH_HAND1)
	local IN_GRIP = (handID == 0 and IN_GRIP_HAND0 or IN_GRIP_HAND1)

	
	if input.buttonsPressed:IsBitSet(IN_TRIGGER)
	then
		input.buttonsPressed:ClearBit(IN_TRIGGER)
		TriggerPressed(self)
	end
		
	if input.buttonsReleased:IsBitSet(IN_TRIGGER) 
	then
		input.buttonsReleased:ClearBit(IN_TRIGGER)
		TriggerUnpressed(self)
	end
	
	
	--[[if input.buttonsPressed:IsBitSet(IN_PAD)
	then
		input.buttonsPressed:ClearBit(IN_PAD)

	end
	
	if input.buttonsReleased:IsBitSet(IN_PAD) 
	then
		input.buttonsReleased:ClearBit(IN_PAD)

	end]]
	
	if input.buttonsReleased:IsBitSet(IN_GRIP)
	then
		input.buttonsReleased:ClearBit(IN_GRIP)
		thisEntity:ForceDropTool();
	end
	
	-- Needed to disable teleports
	--[[if input.buttonsDown:IsBitSet(IN_PAD) 
	then
		input.buttonsDown:ClearBit(IN_PAD)
	end	
	if input.buttonsDown:IsBitSet(IN_PAD_TOUCH) 
	then
		input.buttonsDown:ClearBit(IN_PAD_TOUCH)
	end]]

	return input;
end


function BootMessage(self)

	if isTargeting or isScanning
	then
		return
	end

	local text = ""

	for i = 1, bootCounter, 1
	do
		text = text .. bootMessage[i] .."\n"
		SetPanelText(self, text)
	end
	
	if bootCounter < #bootMessage 
	then
		bootCounter = bootCounter + 1	
		return 0.3
	end
	thisEntity:EmitSound("Scanner.Beep")
	thisEntity:StopSound("Scanner.Track")
	return
end


function SetPanelText(self, text)
	screenText = text
	CustomGameEventManager:Send_ServerToAllClients("scanner_update_display", 
		{id = screen:GetEntityIndex(); displayText = screenText})
end



function TriggerPressed(self)
	SetPanelText(self, "Scanning...")

	thisEntity:EmitSound("Scanner.Start")
	thisEntity:EmitSound("Scanner.Track")
	
	beamParticle = ParticleManager:CreateParticle("particles/item_laser_pointer.vpcf", 
		PATTACH_CUSTOMORIGIN, handAttachment)
	ParticleManager:SetParticleControlEnt(beamParticle, 0, handAttachment,
		PATTACH_POINT_FOLLOW, "beam", Vector(0,0,0), true)
	ParticleManager:SetParticleControl(beamParticle, 1, GetMuzzlePos())
		
	-- Control point 3 sets the color of the beam.
	ParticleManager:SetParticleControl(beamParticle, 3, Vector(0.4, 0.4, 0.6))


	isTargeting = true
	isScanning = false
	scannedEntity = nil
	thisEntity:SetThink(TraceBeam, "trace_beam", 0)

	
end


function TriggerUnpressed(self)
	if isTargeting or isScanning
	then
		SetPanelText(self, "Ready to scan...")
		thisEntity:StopSound("Scanner.Scan")
		thisEntity:StopSound("Scanner.Track")
		--thisEntity:EmitSound("Scanner.Stop")
		thisEntity:EmitSound("Scanner.Beep")
	end

	if beamParticle
	then
		ParticleManager:DestroyParticle(beamParticle, true)
	end
	beamParticle = nil
	isTargeting = false
	isScanning = false
end


function TraceBeam(self)
	if not isTargeting
	then 
		return nil
	end
	
	
	if isScanning and scannedEntity and IsValidEntity(scannedEntity)
	then
		if Time() >= scanStartTime + SCAN_TIME
		then
			isTargeting = false
			isScanning = false
			ParticleManager:DestroyParticle(beamParticle, true)
			beamParticle = nil

			thisEntity:StopSound("Scanner.Track")
			thisEntity:EmitSound("Scanner.Beep")
			ScanEntity(self, scannedEntity)
			scannedEntity = nil
			return nil
		end
		
		local scanDirection = (scannedEntity:GetCenter() - GetMuzzlePos()):Normalized()
		
		if GetMuzzleAng():Forward():Dot(scanDirection) > 0.8
		then
			ParticleManager:SetParticleControl(beamParticle, 1, scannedEntity:GetCenter())
			return BEAM_SCAN_INTERVAL
		end

	end

	local traceTable =
	{
		startpos = GetMuzzlePos();
		endpos = GetMuzzlePos() + GetMuzzleAng():Forward() * TRACE_DISTANCE;
		ignore = playerEnt

	}
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, 0.1)
	TraceLine(traceTable)
	
	ParticleManager:SetParticleControl(beamParticle, 1, traceTable.pos)	
	
	if traceTable.hit 
	then
		--DebugDrawLine(traceTable.startpos, GetMuzzlePos() + RotatePosition(Vector(0,0,0), 
				--RotateOrientation(thisEntity:GetAngles(), MUZZLE_ANGLES_OFFSET), Vector(TONGUE_MAX_DISTANCE * traceTable.fraction, 0, 0)), 0, 255, 255, false, 0.5)
		
		
		
		if traceTable.enthit and traceTable.enthit:GetEntityIndex() > 0
		then
			
			ParticleManager:SetParticleControl(beamParticle, 3, Vector(0.8, 0.8, 0.5))
			ParticleManager:SetParticleControl(beamParticle, 1, traceTable.enthit:GetCenter())	
			isScanning = true
			scannedEntity = traceTable.enthit
			scanStartTime = Time()
			thisEntity:EmitSound("Scanner.Scan")

			return BEAM_TRACE_INTERVAL
		else
			ParticleManager:SetParticleControl(beamParticle, 3, Vector(0.5, 0.5, 0.8))
			ParticleManager:SetParticleControl(beamParticle, 1, traceTable.pos)	
		end
				
		

	else
		ParticleManager:SetParticleControl(beamParticle, 3, Vector(0.4, 0.4, 0.6))
		ParticleManager:SetParticleControl(beamParticle, 1, traceTable.endpos)	
	end
	
	isScanning = false
	
	return BEAM_TRACE_INTERVAL
end

function ScanEntity(self, entity)
	local text = "Class: " .. entity:GetClassname()
		.. "\nName: " .. entity:GetName()
		.. "\nModel: " .. entity:GetModelName()
		.. "\nCenter: " .. VectorCoords(entity:GetCenter())
		.. "\nAngles: " .. VectorCoords(entity:GetAnglesAsVector())
		.. "\nVelocity: " .. VectorCoords(GetPhysVelocity(entity))
		.. "\nMass: " .. Round(entity:GetMass(), 2) .. " kg"
		.. "\nHealth: " .. entity:GetHealth()
		
		
	for _, entClass in ipairs(propClasses)
	do
		if entity:GetClassname() == entClass
		then
			text = text
				.. "\nScale: " .. Round(entity:GetModelScale(), 2)
				.. "\nColor: " .. VectorCoords(entity:GetRenderColor())
				.. "\nSequence: " .. entity:GetSequence()
		end
	end
		
	local scope = entity:GetPrivateScriptScope()
	
	if scope and scope.GetScannerText
	then
		text = text .. "\n" .. scope.GetScannerText()
	end
		
	SetPanelText(self, text)
end


function VectorCoords(vec)
	return "" .. Round(vec.x, 1) .. "  " .. Round(vec.y, 1) .. "  " .. Round(vec.z, 1)
end

function Round(val, decimal)
	if decimal
	then
		return math.floor((val * 10 ^ decimal) + 0.5) / (10 ^ decimal)
	else
		return math.floor(val + 0.5)
	end
end


function GetMuzzlePos()
	local idx = handAttachment:ScriptLookupAttachment("muzzle")
	return handAttachment:GetAttachmentOrigin(idx)
end

function GetMuzzleAng()
	local idx = handAttachment:ScriptLookupAttachment("muzzle")
	vec = handAttachment:GetAttachmentAngles(idx)
	return QAngle(vec.x, vec.y, vec.z)
end
