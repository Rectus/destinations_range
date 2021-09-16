 --===========================================================================--
 --
 -- Flashlight Tool Script
 --
 --===========================================================================--
 
local pickupTime = 0
local PICKUP_TRIGGER_DELAY = 0.2
 
 local m_bIsEquipped = false; -- keep track of whether we are equipped or not
 local m_hHand = nil; -- keep a handle to the hand that is holding the tool
 local m_nHandID = -1; -- keep track of the hand index that is holding the tool (0==right, 1==left)
 local m_hHandAttachment = nil; -- this is the handle to the tool attachment which displays the actual model in the hand
 local m_hPlayer = nil; -- handle to the player holding the tool
 
 local m_bFlashlightOn = false; -- keep track of whether the flashlight is on or not
 local m_hFlashlightBeam = nil; -- a handle to the flashlight particle beam
 local m_particleTrackpad = nil; -- handle to the trackpad particle system
 local m_hLight = nil; -- handle to the light entity that actually illuminates the world in front of the flashlight
 
 -- we store off the trackpad position input from the player
 local m_flTrackpadX = 0; 
 local m_flTrackpadY = 0;
 
 local m_nTotalColors = 0; -- Total number of colors that can be switched between - this gets set on equip
 local m_nCurrentColor = 0; -- our current flashlight color
 
 -- this is the table of colors that we can switch between
 local m_tLightColors = {};
 m_tLightColors[0] = {255, 255, 255} -- white at the center
 
 m_tLightColors[1] = {255, 128, 0} --
 m_tLightColors[2] = {255, 0, 0} --
 m_tLightColors[3] = {255, 0, 64} -- 
 
 m_tLightColors[4] = {180, 0, 180} --
 m_tLightColors[5] = {64, 0, 180} --
 m_tLightColors[6] = {0, 0, 255} -- 
 
 m_tLightColors[7] = {0, 180, 180} -- 
 m_tLightColors[8] = {0, 255, 128} -- 
 m_tLightColors[9] = {0, 255, 0} --
 
 m_tLightColors[10] = {128, 255, 0} -- 
 m_tLightColors[11] = {255, 255, 0} --
 m_tLightColors[12] = {255, 180, 0} -- 
 
 -- this stores the min and max degrees for picking colors on the trackpad
 local m_tColorDegrees= {};
 m_tColorDegrees[0]=0;
 
 ---------------------------------------------------------------------------
 -- SetEquipped
 -- this and SetUnequipped are called by code when the tool is picked up and dropped
 ---------------------------------------------------------------------------
 function SetEquipped( self, pHand, nHandID, pHandAttachment, pPlayer )
 	print( "================  SetEquipped() ");
 
 	-- if somehow we don't have a player here, just return out
 	if ( pPlayer == nil ) then return; end
 
 	-- store these into our global scope so we can use them in other functions
 	m_hHand = pHand;
 	m_nHandID = nHandID;
 	m_hHandAttachment = pHandAttachment;
 	m_hPlayer = pPlayer;
 	m_bIsEquipped = true;
 	pickupTime = Time();
 
 	-- create the trackpad particle system
 	local particleName = "particles/tool_fx/controller_trackpad_position_dot.vpcf";
 	-- the created particle system is now stored in this handle for use elsewhere
 	m_particleTrackpad = ParticleManager:CreateParticle(particleName, PATTACH_POINT_FOLLOW, m_hHandAttachment);
 	-- set the position to be on the trackpad_center attachment on the tool model
 	ParticleManager:SetParticleControlEnt( m_particleTrackpad, 0, m_hHandAttachment, PATTACH_POINT_FOLLOW, "trackpad_center", Vector( 0, 0, 0 ), true );
 
 	-- based on the number of entries in the m_tLightColors table, set the degree values for later use 
 	local m_nTotalColors = table.getn(m_tLightColors);
 	local flDegreeChunk = 360.0/m_nTotalColors;
 	local nMinDegree = 0;
 	for i=1,m_nTotalColors do 
 		local max = i*flDegreeChunk;
 		m_tColorDegrees[i] = max;
 		print( "m_tColorDegrees["..i.."] = "..m_tColorDegrees[i] );
 	end
 
 	-- call this function once so the position of the newly created particle system is updated right away
 	UpdateTrackpadPosition();
 
 	-- this sets up our think function which will run continually
 	m_hHand:SetThink( "FlashlightThink", self, 0.0 );
 	
 	local paintColor = thisEntity:GetRenderColor()
	m_hHandAttachment:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
 
 	m_hPlayer:AllowTeleportFromHand(m_nHandID, false)
 
 	return true;
 end
 
 ---------------------------------------------------------------------------
 -- SetUnequipped
 -- called when the player drops the tool
 ---------------------------------------------------------------------------
 function SetUnequipped()
 	print( "================  SetUnequipped() ");
 	
 	m_hPlayer:AllowTeleportFromHand(m_nHandID, true)
 
 	local paintColor = m_hHandAttachment:GetRenderColor()
	thisEntity:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)
 
 	m_hHand = nil;
 	m_nHandID = -1;
 	m_hHandAttachment = nil;
 	m_hPlayer = nil;
 	m_bIsEquipped = false;
 
 	ReleaseFireButton();
 	
 	if m_bFlashlightOn then
	 	if ( m_hFlashlightBeam ~= nil ) then
	 		ParticleManager:DestroyParticle( m_hFlashlightBeam, true );
	 	end
	 	
	 	local modelAttachmentIndex = thisEntity:ScriptLookupAttachment( "flashlight_beam" );
	 	local vecStartPost = thisEntity:GetAttachmentOrigin( modelAttachmentIndex );
	 	local angAttachment = thisEntity:GetAttachmentAngles( modelAttachmentIndex );
	 	local direction = -thisEntity:GetForwardVector();	
 		local vecEndPos = (vecStartPost+(direction*190));
	 	
	 	local particleName = "particles/tool_fx/flashlight_thirdperson.vpcf";
	 	m_hFlashlightBeam = ParticleManager:CreateParticle(particleName, PATTACH_POINT_FOLLOW, thisEntity);
	 	ParticleManager:SetParticleControlEnt( m_hFlashlightBeam, 0, thisEntity, PATTACH_POINT_FOLLOW, "flashlight_beam", Vector(0,0,0), true );
	 	ParticleManager:SetParticleControlEnt( m_hFlashlightBeam, 1, thisEntity, PATTACH_POINT_FOLLOW, "flashlight_beam", Vector(0,0,0), true );
	 	ParticleManager:SetParticleControl( m_hFlashlightBeam, 2, vecEndPos );
	 	ParticleManager:SetParticleControl( m_hFlashlightBeam, 5, Vector( m_tLightColors[m_nLightColor][1], m_tLightColors[m_nLightColor][2], m_tLightColors[m_nLightColor][3] ) );
 	end
 
 	return true;
 end
 
 ---------------------------------------------------------------------------
 -- GetDegrees
 -- this is a helper function for getting the degrees of an x and y position on a 2d surface
 -- we use this to figure out which color in the color wheel the user is selecting
 ---------------------------------------------------------------------------
 function GetDegrees( x, y )
     local deltaX = 0 - x;
     local deltaY = 0 - y;
 
    local radAngle = math.atan2(deltaY, deltaX);
    local degreeAngle = radAngle * 180.0 / math.pi;
 
    return (180.0 - degreeAngle);
 end
 
 ---------------------------------------------------------------------------
 -- Precache
 -- Gets called from code when this entity is created
 -- Content that this entity uses needs to be precached before it's used
 ---------------------------------------------------------------------------
 function Precache( context )
 	--Cache the models
 	PrecacheModel("models/props_gameplay/flashlight001.vmdl", context);
 	--Cache the particles
 	PrecacheParticle("particles/tool_fx/flashlight_thirdperson.vpcf", context);
 	PrecacheParticle("particles/tool_fx/flashlight_thirdperson_beamlet.vpcf", context);
 	PrecacheParticle("particles/tool_fx/controller_trackpad_position_dot.vpcf", context);
 end
 
 ---------------------------------------------------------------------------
 -- FlashlightThink
 -- The frequency at which this think will run is based on the value that it returns
 -- Initiated from SetEquipped
 ---------------------------------------------------------------------------
 function FlashlightThink()
 
 	-- if we don't have a hand attachment, that means it's not equipped
 	if ( m_hHandAttachment == nil ) then
 		-- the tool is probably already dropped, but we call this function to make sure
 		-- everything is cleared and reset as if it were dropped normally
 		DropTool();
 		return nil;
 	end
 
 	-- get the index of the model attachment on the tool model
 	local modelAttachmentIndex = m_hHandAttachment:ScriptLookupAttachment( "flashlight_beam" );
 	-- get the position of the attachment that we just got the index for
 	local vecStartPos = m_hHandAttachment:GetAttachmentOrigin( modelAttachmentIndex );
 	-- get the forward vector of the tool (it needs to be reversed)
 	local direction = -m_hHandAttachment:GetForwardVector();
 	-- now move 140 units out from our start position in the direction than tool is facing
 	local vecEndPos = (vecStartPos+(direction*140));
 
 	-- if we've already created our flashlight beam particle
 	if ( m_hFlashlightBeam ~= nil ) then
 		-- make sure the point one is attached to the attachment point
 		ParticleManager:SetParticleControlEnt( m_hFlashlightBeam, 1, m_hHandAttachment, PATTACH_POINT_FOLLOW, "flashlight_beam", Vector(0,0,0), true );
 		-- and the second point is where we want our end position to be
 		-- the particle system draws particles between these two points along that line
 		ParticleManager:SetParticleControl( m_hFlashlightBeam, 2, vecEndPos );
 	end
 
 	-- enable this to visualize the line created between vecStartPos and vecEndPos
 	--DebugDrawLine(vecStartPos, vecEndPos, 0, 255, 0, true, 0.02);
 
 	return 0.01;
 end
 
 ---------------------------------------------------------------------------
 -- called when the player presses the trigger button (from OnHandleInput)
 ---------------------------------------------------------------------------
 function PressFireButton() 
 	ToggleFlashlight();
 end
 
 ---------------------------------------------------------------------------
 -- called when the player presses the trigger button (from OnHandleInput)
 ---------------------------------------------------------------------------
 function ReleaseFireButton()
 	-- currently nothing happens when the player releases the trigger button
 end
 
 ---------------------------------------------------------------------------
 -- When the player presses the grip button, we drop the tool
 ---------------------------------------------------------------------------
 function DropTool()
 	-- make sure we let the code know the trigger has been released
 	ReleaseFireButton();
 	-- force the flashlight to go off when we release it
 	--TurnFlashlightOff();
 	-- this calls C++ code on the prop tool entity and forces it to be dropped by the player
 	
 	-- Recreate sprite on the unheld prop
 	
 	
 	thisEntity:ForceDropTool();
 	print( "-------------------DropTool" );
 end
 
 ---------------------------------------------------------------------------
 -- Our color changing function
 ---------------------------------------------------------------------------
 function ChangeColor( nNewColor )
 	-- if this function was called, but the color we want to 
 	-- change to is the same as the one we are on don't do anything
 	-- it prevents code, sounds, etc from running unnecessarily
 	if ( m_nLightColor == nNewColor ) then
 		return;
 	end
 
 	-- store the new color we want to switch to
 	m_nLightColor = nNewColor;
 	print( "m_nLightColor = "..nNewColor );
 
 	-- if we have a valid flashlight particle beam
 	if ( m_hFlashlightBeam ~= nil ) then
 		-- tell the particle system that it should use the new color
 		ParticleManager:SetParticleControl( m_hFlashlightBeam, 5, Vector( m_tLightColors[m_nLightColor][1], m_tLightColors[m_nLightColor][2], m_tLightColors[m_nLightColor][3] ) );
 	end
 
 	-- if we have a valid handle to the light entity
 	if ( m_hLight ~= nil ) then
 		-- tell it to switch to the new light color
 		EntFireByHandle( self, m_hLight, "setlightcolor", ""..m_tLightColors[m_nLightColor][1].." "..m_tLightColors[m_nLightColor][2].." "..m_tLightColors[m_nLightColor][3].."", 0 );		
 	end
 
 	EmitSoundOn("ui_select", thisEntity);
 end
 
 ---------------------------------------------------------------------------
 -- OnHandleInput
 -- Called from C++ code
 -- This function receives input passed from the controller inputs from the player
 -- we can capture these inputs and choose to pass them back to be used by another attachment
 -- or we can clear them and "swallow" the input here
 -- other hand attachments, like the one that lets you teleport around or change your hand gesture
 -- use certain inputs from the player. if you want to prevent these actions while you have
 -- THIS tool equipped, you need to clear the input after you catch it
 ---------------------------------------------------------------------------
 function OnHandleInput( input )
 
 	-- here are all of the inputs that can be passed from code:
 --		IN_USE_HAND0,			-- when the trigger is pressed
 --		IN_USE_HAND1,
 --		IN_PAD_LEFT_HAND0,		-- when the pad is pressed on the left side
 --		IN_PAD_RIGHT_HAND0,		-- when the pad is pressed on the right side
 --		IN_PAD_UP_HAND0,		-- when the pad is pressed on the top
 --		IN_PAD_DOWN_HAND0,		-- when the pad is pressed on the bottom
 --		IN_PAD_LEFT_HAND1,
 --		IN_PAD_RIGHT_HAND1,
 --		IN_PAD_UP_HAND1,
 --		IN_PAD_DOWN_HAND1,
 --		IN_MENU_HAND0,
 --		IN_MENU_HAND1,
 --		IN_GRIP_HAND0,
 --		IN_GRIP_HAND1,
 --		IN_GRIPANALOG_HAND0,
 --		IN_GRIPANALOG_HAND1,
 --		IN_PAD_HAND0,			-- when the pad is pressed anywhere
 --		IN_PAD_HAND1,
 --		IN_PAD_TOUCH_HAND0,		-- when the pad is touched anywhere
 --		IN_PAD_TOUCH_HAND1, 
 
 	-- these are what's passed in
 	--input.buttonsDown;
 	--input.buttonsPressed;
 	--input.buttonsReleased;
 	--input.trackpadX;		-- ( -1.0 to 1.0 ) 
 	--input.trackpadY;		-- ( -1.0 to 1.0 ) 
 	--input.triggerValue;	-- ( 0 to 1.0 )
 
 	local bUpdateTrackpad = false;
 
 	-- get the current position of the player's finger on the track pad on the X axis
 	local flTrackpadX = input.trackpadX;
 	if ( flTrackpadX ~= 0 and flTrackpadX ~= m_flTrackpadX ) then
 		-- if it changed from the last time we got an input change, note it
 		m_flTrackpadX = flTrackpadX;
 		--print( "m_flTrackpadX = "..m_flTrackpadX );
 		-- and let the check down below know we should update the trackpad visuals
 		bUpdateTrackpad = true;
 	end
 
 	-- get the current position of the player's finger on the track pad on the Y axis
 	local flTrackpadY = input.trackpadY;
 	if ( flTrackpadY ~= 0 and flTrackpadY ~= m_flTrackpadY ) then
 		-- if it changed from the last time we got an input change, note it
 		m_flTrackpadY = flTrackpadY;
 		--print( "m_flTrackpadY = "..m_flTrackpadY );
 		-- and let the check down below know we should update the trackpad visuals
 		bUpdateTrackpad = true;
 	end
 
 	-- trackpad position has been changed, update the position and color picked
 	if ( bUpdateTrackpad ) then
 		UpdateTrackpadPosition();
 	end
 
 	-- this is lua's ugly version of a ternary operator
 	-- we do this because we only care about the input from the hand that is holding us
 	-- but you could check input from the other hand if you want
 	local nIN_TRIGGER = IN_USE_HAND1; if (m_nHandID == 0) then nIN_TRIGGER = IN_USE_HAND0 end;
 	local nIN_GRIP = IN_GRIP_HAND1; if (m_nHandID == 0) then nIN_GRIP = IN_GRIP_HAND0 end;
 
 	-- this checks to see if the TRIGGER has been pressed on this hand
 	-- this is only set when the trigger is first pressed
 	-- if you want to see if it's HELD, you need to keep track of that yourself
 	if ( input.buttonsPressed:IsBitSet( nIN_TRIGGER ) ) then
 		print( "TRIGGER is pressed" );
 		-- now clear it because we don't want any other tools to do anything with the trigger press
 		input.buttonsPressed:ClearBit( nIN_TRIGGER );
 
 		if Time() > pickupTime + PICKUP_TRIGGER_DELAY
		then
 			PressFireButton();
 		end
 	end
 
 	-- this checks if the TRIGGER has just been released
 	if ( input.buttonsReleased:IsBitSet( nIN_TRIGGER ) ) then
 		print( "TRIGGER is released" );
 		-- clear it!
 		input.buttonsReleased:ClearBit( nIN_TRIGGER );
 
 		ReleaseFireButton();
 	end
 
 	-- checks to see if the GRIP has been pressed this update
 	if ( input.buttonsReleased:IsBitSet( nIN_GRIP ) ) then
 		print( "GRIP is released" );
 		-- if it's pressed, clear the bit!
 		input.buttonsReleased:ClearBit( nIN_GRIP );
 
 		-- drop the tool
 		DropTool();
 	end
 
 	-- If you'd like the disable the teleporting, uncomment out the following bits     
 	-- these clear out the pad click and touch inputs so teleporting is disabled
 	--if ( input.buttonsDown:IsBitSet( nIN_PAD ) ) then
 	--	input.buttonsDown:ClearBit( nIN_PAD );
 	--end
 	--if ( input.buttonsDown:IsBitSet( nIN_PAD_TOUCH ) ) then
 	--	input.buttonsDown:ClearBit( nIN_PAD_TOUCH );
 	--end
 
 
 	-- we return the input data back to C++ code so other tools can use it
 	-- you could always return null if you want this tool to control 100% of the input....
 	return input;
 end
 
 ---------------------------------------------------------------------------
 -- Called from OnHandleInput to update the position and color of our trackpad color indicator 
 ---------------------------------------------------------------------------
 function UpdateTrackpadPosition() 
 
 	-- get the degrees of our current trackpad position
 	local deg = GetDegrees( m_flTrackpadX, m_flTrackpadY );
 	--print( "degrees = "..deg );
 
 	-- get the distance the player's finger is from the center of the trackpad'
 	local flDist = math.sqrt( (m_flTrackpadX ^ 2) + (m_flTrackpadY ^ 2) );
 	--print( "flDist = "..flDist );
 	if ( flDist < 0.24 ) then
 		-- if the player fingers is within this amount of the center - they are choosing WHITE
 		ChangeColor( 0 );
 	else
 		-- otherwise, use the degrees we stored earlier to determine which color they want to pick
 		local m_nTotalColors = table.getn(m_tLightColors);
 		for i=1,m_nTotalColors do 
 			local mindegree = m_tColorDegrees[i-1];
 			local maxdegree = m_tColorDegrees[i];
 			if ( deg >= mindegree and deg < maxdegree ) then
 				ChangeColor( i );
 				break;
 			end		
 		end
 	end
 
 	-- set the color on the trackpad particle
 	ParticleManager:SetParticleControl( m_particleTrackpad, 1, Vector( -m_flTrackpadY, m_flTrackpadX, 0 ) );
 	ParticleManager:SetParticleControl( m_particleTrackpad, 2, Vector( m_tLightColors[m_nLightColor][1], m_tLightColors[m_nLightColor][2], m_tLightColors[m_nLightColor][3] ) );
 
 end
 
 ---------------------------------------------------------------------------
 -- Called as a single toggle function to turn the flashlight on and off
 ---------------------------------------------------------------------------
 function ToggleFlashlight()
 
 	if ( m_bFlashlightOn == true ) then
 		TurnFlashlightOff()
 	else
 		TurnFlashlightOn();
 	end
 
 	-- FireHapticPulse is what makes the controller rumble
 	-- you can pass 0.1, 0.5 or 1 for light, medium and heavy
 	m_hHand:FireHapticPulse(1);
 end
 
 ---------------------------------------------------------------------------
 -- TURN ON!
 ---------------------------------------------------------------------------
 function TurnFlashlightOn()
 
 	-- if we don't have a hand holding us, just return
 	if ( m_hHand == nil ) then return; end
 
 	-- shouldn't happen, but if we dont have a player, return
 	if ( m_hPlayer == nil ) then print( "NO PLAYER!"); return; end
 
 	-- keep track of the flashlight now being ON
 	m_bFlashlightOn = true;
 
 	-- emit a SOUND on thisEntity - just borrow from the drone
 	EmitSoundOn("drone_equip", thisEntity);
 
 	-- this may not be working right now
 	EntFireByHandle( self, m_hHandAttachment, "Skin", "1", 0 );		
 
 	local modelAttachmentIndex = m_hHandAttachment:ScriptLookupAttachment( "flashlight_beam" );
 	local vecStartPost = m_hHandAttachment:GetAttachmentOrigin( modelAttachmentIndex );
 	local angAttachment = m_hHandAttachment:GetAttachmentAngles( modelAttachmentIndex );
 	local direction = -m_hHandAttachment:GetForwardVector();	
 	local vecEndPos = (vecStartPost+(direction*190));
 
 	local particleName = "particles/tool_fx/flashlight_thirdperson.vpcf";
 	m_hFlashlightBeam = ParticleManager:CreateParticle(particleName, PATTACH_POINT_FOLLOW, m_hHandAttachment);
 	ParticleManager:SetParticleControlEnt( m_hFlashlightBeam, 0, m_hHandAttachment, PATTACH_POINT_FOLLOW, "flashlight_beam", Vector(0,0,0), true );
 	ParticleManager:SetParticleControlEnt( m_hFlashlightBeam, 1, m_hHandAttachment, PATTACH_POINT_FOLLOW, "flashlight_beam", Vector(0,0,0), true );
 	ParticleManager:SetParticleControl( m_hFlashlightBeam, 2, vecEndPos );
 	ParticleManager:SetParticleControl( m_hFlashlightBeam, 5, Vector( m_tLightColors[m_nLightColor][1], m_tLightColors[m_nLightColor][2], m_tLightColors[m_nLightColor][3] ) );
 	
 	if not m_hLight or not IsValidEntity(m_hLight) then
	 	local lightTable = 
	 	{
	 		origin = vecStartPost,
	 		angles = angAttachment,
	 		targetname = "light"..thisEntity:entindex(),
	 		enabled = "1",
	 		color = ""..m_tLightColors[m_nLightColor][1].." "..m_tLightColors[m_nLightColor][2].." "..m_tLightColors[m_nLightColor][3].." 255",
	 		brightness = "1.5",
	 		range = "400",
	 		castshadows = "1",
	 		--shadowtexturewidth = "64",
	 		--shadowtextureheight = "64",
	 		style = "0",
	 		fademindist = "0",
	 		fademaxdist = "4000",
	 		bouncescale = "1.0",
	 		renderdiffuse = "1",
	 		renderspecular = "1",
	 		directlight = "2",
	 		indirectlight = "0",
	 		attenuation1 = "0.0",
	 		attenuation2 = "1.0",	
	 		innerconeangle = "20",
	 		outerconeangle = "32",
	 		lightcookie = "flashlight"
	 	}
	 	m_hLight = SpawnEntityFromTableSynchronous( "light_spot", lightTable )
	 	m_hLight:SetAngles( angAttachment[1], angAttachment[2], angAttachment[3] );
	 	m_hLight:SetParent(m_hHandAttachment, "flashlight_beam")
 	end
 end
 
 function TurnFlashlightOff()
 
 	m_bFlashlightOn = false;
 
 	EmitSoundOn("drone_equip", thisEntity);
 
 	EntFireByHandle( self, m_hHandAttachment, "Skin", "0", 0 );		
 
 	if ( m_hLight ~= nil ) then
 		m_hLight:Destroy();
 		m_hLight = nil;
 	end
 
 	if ( m_hFlashlightBeam ~= nil ) then
 		ParticleManager:DestroyParticle( m_hFlashlightBeam, true );
 		m_hFlashlightBeam = nil;
 	end
 end
