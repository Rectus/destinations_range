
-- Based on Valves tagmarker code

local m_bIsEquipped = false;
local m_hHand = nil;
local m_nHandID = -1;
local m_hHandAttachment = nil;
local m_nControllerType = VR_CONTROLLER_TYPE_UNKNOWN
local m_hPlayer = nil;
local m_bIsFireButtonPressed = false;
local m_flTrackpadX = 0;
local m_flTrackpadY = 0;

local m_hColorWheelPanel = nil

local BRUSH_HAPTIC_DELAY = 0.2;
local m_flNextHapticBuzz = 0;
local m_bIsPainting = false

local m_hPaintDrawingEntity = nil;
local m_hPaintParticleSpray = nil;
local m_hPaintedProp = nil;
local m_vPropInitialColor = nil;
local m_vPropSetColor = nil;
local m_flPropPaintStartTime = 0;
local m_flPropPaintDuration = 0;

local m_particleColored = "particles/tools/spraypaint_stroke_colored.vpcf";

local m_lastPointPos = nil;
local m_lastPointTime = Time();

local m_particleTrackpad = nil;

local m_isBreakable = false;
local m_isDead = false;

local m_vPaintColor = Vector(0,0,0)
local SPRAY_COLOR_MULTIPLIER = 0.7

local SPRAY_DISTANCE = 16
local SPARY_MAX_RADIUS = 1.0
local EXPLOSION_RANGE = 48
local EXPLOSION_MAX_IMPULSE = 50

local pickupTime = 0
local PICKUP_TRIGGER_DELAY = 0.5

local startSound = "tagmarker_start";
local loopSound = "tagmarker_loop";
local stopSound = "tagmarker_stop";


function SpawnPanel()
	
	local panelAttachmentIndex = m_hHandAttachment:ScriptLookupAttachment( "color_wheel" )
	local panelLocation = m_hHandAttachment:GetAttachmentOrigin( panelAttachmentIndex )
	local panelTable = 
	{
		origin = panelLocation,
		model = "models/tools/spraycan_colorwheel.vmdl",
		solid = 0
	}
	m_hColorWheelPanel = SpawnEntityFromTableSynchronous( "prop_dynamic", panelTable )
	m_hColorWheelPanel:SetParent(m_hHandAttachment, "color_wheel")
	
	m_hColorWheelPanel:SetLocalAngles(180, 90 - 30, 0)
	m_hColorWheelPanel:SetLocalOrigin(Vector(0, 0, -0.1))
	m_hColorWheelPanel:SetModelScale(0.8)
	m_hColorWheelPanel:AddEffects(32)


end


function ForceDestroyPanel()
	if ( m_hColorWheelPanel ~= nil ) then
		UTIL_Remove(m_hColorWheelPanel);
	end
	m_hColorWheelPanel = nil;
end

function Spawn(keys)
	local health = keys:GetValue("health")
	
	if health then
		m_isBreakable = true
		thisEntity:SetHealth(health)
		thisEntity:SetMaxHealth(health)
	end
end


function Activate()
	m_vPaintColor = thisEntity:GetRenderColor()
end

function OnBreak(param)
	print("Break:" .. param)
end



function OnTakeDamage(damageTable)

	if not m_isBreakable then
		return false
	end

	-- Don't let launching cans with the gravity gun pop them. TODO: check damage type instead if possible
	if damageTable.inflictor and damageTable.inflictor:GetModelName() == "models/weapons/hl2/gravity_gun_new/gravity_gun.vmdl" then
		return false
	end

	thisEntity:SetHealth(thisEntity:GetHealth() - damageTable.damage)
	if thisEntity:GetHealth() <= 0 and not m_isDead then
		m_isDead = true
		local explosion = ParticleManager:CreateParticle("particles/tools/spraypaint_pop.vpcf", PATTACH_CUSTOMORIGIN, thisEntity)
		ParticleManager:SetParticleControl(explosion, 0, thisEntity:GetCenter())
		ParticleManager:SetParticleControl(explosion, 3, thisEntity:GetRenderColor())
		EmitSoundOn("Balloon.Explode", thisEntity)
	
		local entities = Entities:FindAllInSphere(thisEntity:GetOrigin(), EXPLOSION_RANGE)
	
		for _,dmgEnt in ipairs(entities) 
		do
			if IsValidEntity(dmgEnt) and dmgEnt:IsAlive() and dmgEnt ~= thisEntity
			then
				local distance = (dmgEnt:GetCenter() - thisEntity:GetCenter()):Length()
					
				local magnitude = (EXPLOSION_MAX_IMPULSE - EXPLOSION_MAX_IMPULSE * distance / EXPLOSION_RANGE)			
				local impulse = (dmgEnt:GetCenter() - thisEntity:GetCenter()):Normalized() * magnitude
				
				dmgEnt:ApplyAbsVelocityImpulse(impulse)
				
				local color = SplineVectors(dmgEnt:GetRenderColor(), 
					thisEntity:GetRenderColor(), 2 - 2 * distance / EXPLOSION_RANGE )
				dmgEnt:SetRenderColor(color.x, color.y, color.z)
	
			end
		end
	
		thisEntity:AddEffects(32)	
		DoEntFireByInstanceHandle(thisEntity, "Kill", "", 2, nil, nil)
	end
	return true
end

-- SetEquipped and SetUnequipped are expected by code and rely on these arguments matching
-- if you update arguments passed from code, you need to update it here as well
function SetEquipped( this, pHand, nHandID, pHandAttachment, pPlayer )
	--print( "================  SetEquipped() ");
	if ( pPlayer == nil ) then return; end

	m_hHand = pHand;
	m_nHandID = nHandID;
	m_hHandAttachment = pHandAttachment;
	m_hPlayer = pPlayer;
	m_bIsEquipped = true;
	m_bIsFireButtonPressed = false;
	pickupTime = Time();

	-- create the trackpad particle system
	
	
	m_vPaintColor = thisEntity:GetRenderColor()
	m_hHandAttachment:SetRenderColor(m_vPaintColor.x, m_vPaintColor.y, m_vPaintColor.z)

	if g_VRScript.pauseManager
	then
		g_VRScript.pauseManager:SetTeleportControlsAllowed(playerEnt, m_nHandID, false)
	else
		playerEnt:AllowTeleportFromHand(m_nHandID, false)
	end
	m_nControllerType = m_hPlayer:GetVRControllerType()

	SpawnPanel();

	return true;
end

function SetUnequipped()
	--print( "================  SetUnequipped() ");

	ReleaseFireButton();

	if g_VRScript.pauseManager
	then
		g_VRScript.pauseManager:SetTeleportControlsAllowed(playerEnt, handID, true)
	else
		playerEnt:AllowTeleportFromHand(handID, true)
	end

	m_hHand = nil;
	m_nHandID = -1;
	m_hHandAttachment = nil;
	m_hPlayer = nil;
	m_bIsEquipped = false;
	m_bIsFireButtonPressed = false;
	m_nControllerType = VR_CONTROLLER_TYPE_UNKNOWN

	m_hPaintDrawingEntity = nil;
	
	ForceDestroyPanel()

	return true;
end

---------------------------------------------------------------------------
-- Precache
---------------------------------------------------------------------------
function Precache( context )
	--print("Precaching Resources")
	--Cache the models
	PrecacheModel( "models/props_gameplay/airbrush_tool.vmdl", context );
	PrecacheModel( "models/development/invisiblebox.vmdl", context );
	PrecacheModel("models/tools/spraycan_colorwheel.vmdl", context );

	--Cache the particles
	PrecacheParticle( m_particleColored, context );	
	PrecacheParticle( "particles/tool_fx/Paintinator_button_up.vpcf", context );
	PrecacheParticle( "particles/tool_fx/controller_trackpad_position.vpcf", context );
	PrecacheParticle( "particles/tool_fx/brush_spray.vpcf", context );
	PrecacheParticle("particles/tools/spraypaint_pop.vpcf", context );
end

function StartPainting()

	--print("Adding a particle trail")

	local modelAttachmentIndex = m_hHandAttachment:ScriptLookupAttachment( "spray_nozzle" );
	m_lastPointPos = nil;
	m_lastPointTime = Time();

	if ( m_hHand:IsNull() == false ) then
		m_hHand:FireHapticPulse(0.65);
	end
	
	m_hPaintParticleSpray = ParticleManager:CreateParticle("particles/tool_fx/brush_spray.vpcf", PATTACH_CUSTOMORIGIN, m_hPlayer);
	ParticleManager:SetParticleControlEnt( m_hPaintParticleSpray, 0, m_hHandAttachment, PATTACH_POINT_FOLLOW, "spray_nozzle", Vector( 0, 0, 0 ), true );
	ParticleManager:SetParticleControl( m_hPaintParticleSpray, 2, m_vPaintColor);

	m_bIsPainting = true;
	EmitSoundOn(startSound, m_hHandAttachment);
	EmitSoundOn(loopSound, m_hHandAttachment);
end

function StopPainting()

	m_bIsPainting = false;
	--print("Stopping a particle trail")
	
	if m_hPaintDrawingEntity ~= nil and IsValidEntity( m_hPaintDrawingEntity) then		
		m_hPaintDrawingEntity:EndStroke();
	end
	m_hPaintedProp = nil;
	m_lastPointPos = nil;

	if ( m_hPaintParticleSpray ~= nil ) then
		ParticleManager:DestroyParticle( m_hPaintParticleSpray, false );
		m_hPaintParticleSpray = nil;
	end
	
	EmitSoundOn(stopSound, m_hHandAttachment);
	StopSoundOn(loopSound, m_hHandAttachment);
end

function PressFireButton()
	--GameRules:GetGameModeEntity():SetThink("MarkerThink", self, 0.0);
	m_bIsFireButtonPressed = true;

	if ( m_bIsPainting == false ) then
		StartPainting();
	else
		if ( m_flNextHapticBuzz < Time() ) then
			if ( m_hHand:IsNull() == false ) then
				m_hHand:FireHapticPulse(0.1);
				m_flNextHapticBuzz = Time() + BRUSH_HAPTIC_DELAY;
			end
		end	
	end

end

function ReleaseFireButton()
	m_bIsFireButtonPressed = false;

	if ( m_bIsPainting == true ) then
		StopPainting();
	end

end

function DropTool()
	ReleaseFireButton();

	if ( m_hPaintDrawingEntity ~= nil ) then
		m_hPaintDrawingEntity:Finalize();
	end

	thisEntity:ForceDropTool();
	ForceDestroyPanel();
	--print( "-------------------DropTool" );
end

function GetDegrees( x, y )
    local deltaX = 0 - x;
    local deltaY = 0 - y;

    local radAngle = math.atan2(deltaY, deltaX);
    local degreeAngle = radAngle * 180.0 / math.pi;

    return (180.0 - degreeAngle);
end

function OnHandleInput( input )


	local nIN_TRIGGER = IN_USE_HAND1; if (m_nHandID == 0) then nIN_TRIGGER = IN_USE_HAND0 end;
	local nIN_GRIP = IN_GRIP_HAND1; if (m_nHandID == 0) then nIN_GRIP = IN_GRIP_HAND0 end;

	local nIN_PAD = IN_PAD_HAND1; if (m_nHandID == 0) then nIN_PAD = IN_PAD_HAND0 end;
	local nIN_PAD_TOUCH = IN_PAD_TOUCH_HAND1; if (m_nHandID == 0) then nIN_PAD_TOUCH = IN_PAD_TOUCH_HAND0 end;
	local nIN_PAD_UP = IN_PAD_UP_HAND1; if (m_nHandID == 0) then nIN_PAD_UP = IN_PAD_UP_HAND0 end;
	local nIN_PAD_DOWN = IN_PAD_DOWN_HAND1; if (m_nHandID == 0) then nIN_PAD_DOWN = IN_PAD_DOWN_HAND0 end;
	local nIN_PAD_LEFT = IN_PAD_LEFT_HAND1; if (m_nHandID == 0) then nIN_PAD_LEFT = IN_PAD_LEFT_HAND0 end;
	local nIN_PAD_RIGHT = IN_PAD_RIGHT_HAND1; if (m_nHandID == 0) then nIN_PAD_RIGHT = IN_PAD_RIGHT_HAND0 end;

	local bUpdateTrackpad = false
	local bUpdateColor = true

	
	if ( input.buttonsPressed:IsBitSet( nIN_PAD ) ) then
		m_hColorWheelPanel:RemoveEffects(32)
		
		m_particleTrackpad = ParticleManager:CreateParticle(
			"particles/tool_fx/controller_trackpad_position.vpcf", PATTACH_POINT_FOLLOW, m_hHandAttachment);
		ParticleManager:SetParticleControlEnt( m_particleTrackpad, 
			0, m_hHandAttachment, PATTACH_POINT_FOLLOW, "color_wheel", Vector( 0, 0, 0 ), true );
		
	end
	
	if ( input.buttonsReleased:IsBitSet( nIN_PAD ) ) then
		m_hColorWheelPanel:AddEffects(32)
		
		if ( m_particleTrackpad ~= nil ) then
			ParticleManager:DestroyParticle( m_particleTrackpad, true );
		m_particleTrackpad = nil;
	end
		
	end
	
	if ( input.buttonsDown:IsBitSet( nIN_PAD ) ) then

		bUpdateColor = true
	else
		bUpdateColor = false
	end


	local flTrackpadX = input.trackpadX;
	if ( flTrackpadX ~= 0 and flTrackpadX ~= m_flTrackpadX ) then
		m_flTrackpadX = flTrackpadX;
		--print( "m_flTrackpadX = "..m_flTrackpadX );
		bUpdateTrackpad = true;
	end

	local flTrackpadY = input.trackpadY;
	if ( flTrackpadY ~= 0 and flTrackpadY ~= m_flTrackpadY ) then
		m_flTrackpadY = flTrackpadY;
		--print( "m_flTrackpadY = "..m_flTrackpadY );
		bUpdateTrackpad = true;
	end

	-- trackpad position has been changed, update the position and color picked
	if ( bUpdateTrackpad and bUpdateColor ) then
		UpdateTrackpadPosition();
	end

	if ( input.buttonsPressed:IsBitSet( nIN_TRIGGER ) ) then
		--print( "TRIGGER is pressed" );
		input.buttonsPressed:ClearBit( nIN_TRIGGER );
		if Time() > pickupTime + PICKUP_TRIGGER_DELAY
		then
			PressFireButton();
		end
	end

	if ( input.buttonsReleased:IsBitSet( nIN_TRIGGER ) ) then
		--print( "TRIGGER is released" );
		input.buttonsReleased:ClearBit( nIN_TRIGGER );
		ReleaseFireButton();
	end

	if ( input.buttonsReleased:IsBitSet( nIN_GRIP ) ) then
		--print( "GRIP is released" );
		input.buttonsReleased:ClearBit( nIN_GRIP );
		DropTool();
	end

	if m_bIsPainting then
		UpdatePainting();
	end

	return true;
end


function UpdatePainting()

	local modelAttachmentIndex = m_hHandAttachment:ScriptLookupAttachment( "spray_nozzle" );
	local startPos = m_hHandAttachment:GetAttachmentOrigin( modelAttachmentIndex );
	local angVec = m_hHandAttachment:GetAttachmentAngles( modelAttachmentIndex );
	local ang = QAngle(angVec.x, angVec.y, angVec.z)
	
	local radius = 0
	local pos = nil
	local hitSurface = false

	local traceTable =
	{
		startpos = startPos;
		endpos = startPos + ang:Forward() * SPRAY_DISTANCE;
		ignore = m_hPlayer

	}
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, 0.1)
	TraceLine(traceTable)
	
	if traceTable.hit then
	
		-- Move the hit spot out by the paint radius
		if traceTable.fraction > 0.5 then
		
			radius = (1 - traceTable.fraction) * SPARY_MAX_RADIUS * 2 
		else
			radius = traceTable.fraction * SPARY_MAX_RADIUS * 2
		end
		 
		pos = startPos + ang:Forward() * (SPRAY_DISTANCE * traceTable.fraction - radius)
		
		if traceTable.enthit and traceTable.enthit:GetEntityIndex() > 0 then
			UpdatePaintedProp(traceTable.enthit)

		else		
			m_hPaintedProp = nil
			hitSurface = true
			
			if m_hPaintDrawingEntity == nil or not IsValidEntity( m_hPaintDrawingEntity ) 
				or m_hPaintDrawingEntity:IsFinalized() then
				
				local propTable = 
				{
					origin = pos,
				}
				m_hPaintDrawingEntity = SpawnEntityFromTableSynchronous( "prop_destinations_drawing", propTable )
				m_hPaintDrawingEntity:SetCreator( m_hPlayer )
				
				
			end
			if m_lastPointPos == nil then
			
				m_hPaintDrawingEntity:BeginStroke( pos, m_particleColored );
				m_lastPointPos = pos;
			end
		end
		
	end
	


	if hitSurface then
		
		local diff = pos - m_lastPointPos;
		local dist = diff:Length();

		local curtime = Time();
		local dt = curtime - m_lastPointTime;

		if ( dist > 0.1 and dt > 0.02 ) then
			local speed = dist / dt;
			
			m_hPaintDrawingEntity:AddPointGlobal( pos, radius, m_vPaintColor * SPRAY_COLOR_MULTIPLIER );
			m_lastPointPos = pos;
			m_lastPointTime = curtime;
		end
	else
		if m_hPaintDrawingEntity ~= nil and IsValidEntity( m_hPaintDrawingEntity) then		
			m_hPaintDrawingEntity:EndStroke();
			m_lastPointPos = nil;
		end
	end
end

function UpdatePaintedProp(prop)
	if m_hPaintedProp ~= prop then
		m_hPaintedProp = prop
	
		m_vPropInitialColor = prop:GetRenderColor()
		m_vPropSetColor = m_vPaintColor
		m_flPropPaintStartTime = Time()
		m_flPropPaintDuration = (m_vPropInitialColor - m_vPropSetColor):Length() / 255
		
	elseif m_vPropSetColor and (m_vPropSetColor - m_vPaintColor):Length() ~= 0 then
		m_vPropInitialColor = prop:GetRenderColor()
		m_vPropSetColor = m_vPaintColor
		m_flPropPaintStartTime = Time()
		m_flPropPaintDuration = (m_vPropInitialColor - m_vPropSetColor):Length() / 255
	
	elseif m_vPropSetColor then
		local frac = (Time() - m_flPropPaintStartTime) / m_flPropPaintDuration
		local color = SplineVectors(m_vPropInitialColor, m_vPropSetColor, frac)
		m_hPaintedProp:SetRenderColor(color.x, color.y, color.z)
	end
end


function HSLToRGB(H, S, L)

	local R, G, B = L * 255
	local v1, v2 = 0

	if S ~= 0 then
		if L < 0.5 then
			v2 = L * (1 + S) 
		else
			v2 = (L + S) - (S * L)
		end
		
		v1 = 2 * L - v2
		
		R = 255 * HueToRGB( v1, v2, H + 1/3 )
		G = 255 * HueToRGB( v1, v2, H )
		B = 255 * HueToRGB( v1, v2, H - 1/3 )
	end
	
	return Vector(R, G, B)
end


function HueToRGB( v1, v2, H )
	if H < 0 then H = H + 1 end
	if H > 1 then H = H - 1 end
	if (6 * H) < 1 then 
		return v1 + (v2 - v1) * 6 * H 
	end
	if (2 * H) < 1 then
		return v2
	end
	if (3 * H) < 2 then
		return v1 + (v2 - v1) * ( (2/3) - H) * 6
	end
	return v1
end


function UpdateTrackpadPosition()

	local deg = GetDegrees( m_flTrackpadX, m_flTrackpadY );
	--print( "degrees = "..deg );


	local flDist = math.sqrt( (m_flTrackpadX ^ 2) + (m_flTrackpadY ^ 2) );
	--print( "flDist = "..flDist );
	
	flDist = flDist * 1.25 - 0.125
	if flDist > 1 then flDist = 1
	elseif flDist < 0 then flDist = 0 end
		
	
	m_vPaintColor = HSLToRGB(deg / 360, 1, flDist)

	ParticleManager:SetParticleControl( m_particleTrackpad, 1, Vector( -m_flTrackpadY, m_flTrackpadX, 0 ) );
	ParticleManager:SetParticleControl( m_particleTrackpad, 2, m_vPaintColor );

	thisEntity:SetRenderColor(m_vPaintColor.x, m_vPaintColor.y, m_vPaintColor.z)
	m_hHandAttachment:SetRenderColor(m_vPaintColor.x, m_vPaintColor.y, m_vPaintColor.z)
	
	if m_hPaintParticleSpray ~= nil then
		ParticleManager:SetParticleControl( m_hPaintParticleSpray, 2, m_vPaintColor * SPRAY_COLOR_MULTIPLIER );
	end

end

