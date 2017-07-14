local m_bIsEquipped = false; -- keep track of whether we are equipped or not
local m_hHand = nil; -- keep a handle to the hand that is holding the tool
local m_nHandID = -1; -- keep track of the hand index that is holding the tool (0==right, 1==left)
local m_hHandAttachment = nil; -- this is the handle to the tool attachment which displays the actual model in the hand
local m_hPlayer = nil; -- handle to the player holding the tool
local m_hKnobAttachment = nil -- Global reference to the attached prop.

function Precache( context )
	--Cache the models
	PrecacheModel( "models/props_gameplay/cache_finder001_attachment.vmdl", context );
	PrecacheModel("models/props/toys/balloonicorn.vmdl", context);
end

function Activate()

	-- Find the point where to spawn the prop from the attachment "knob_attach" on the tool model.
	-- Create the attachment on the tool model in the model editor first.
	local nAttachmentID = thisEntity:ScriptLookupAttachment( "grabpoint" );
	local vSpawnPosition = thisEntity:GetAttachmentOrigin( nAttachmentID );
	
	local knobKeyvalues = {
		targetname = "knob";
		model = "models/props_gameplay/cache_finder001_attachment.vmdl";
		origin = vSpawnPosition; -- The origin found from the attachment.
		angles = thisEntity:GetAngles(); -- Give the prop the same angles as the tool.
		solid = 0; -- Make sure the collision is disabled.
	}
	
	-- This function spawns the entity in.
	m_hKnobAttachment = SpawnEntityFromTableSynchronous( "prop_dynamic", knobKeyvalues );
	
	-- Parents the prop to the tool.
	m_hKnobAttachment:SetParent(thisEntity, "grabpoint")
	
	-- Set the angles of the prop.
	local aAngles = thisEntity:GetAngles()
	m_hKnobAttachment:SetAngles(aAngles.x, aAngles.y, aAngles.z);
end

function SetEquipped( self, pHand, nHandID, pHandAttachment, pPlayer )

	m_hHand = pHand;
	m_nHandID = nHandID;
	m_hHandAttachment = pHandAttachment;
	m_hPlayer = pPlayer;
	m_bIsEquipped = true;
	
	-- Parents the prop to the hand attachment while held.
	m_hKnobAttachment:SetParent(m_hHandAttachment, "grabpoint")
	m_hKnobAttachment:SetOrigin(m_hHandAttachment:GetOrigin())
	m_hKnobAttachment:SetAngles(0, 0, 0);
	
	
		return true;

end


function SetUnequipped()
SpawnBalloonicorn()
m_hHand = nil;
	m_nHandID = -1;
	m_hHandAttachment = nil;
	m_hPlayer = nil;
	m_bIsEquipped = false;
	
	-- Parents the prop to the tool again when dropped.
	m_hKnobAttachment:SetParent(thisEntity, "grabpoint")
	m_hKnobAttachment:SetOrigin(thisEntity:GetOrigin())
	local aAngles = thisEntity:GetAngles()
	m_hKnobAttachment:SetAngles(aAngles.x, aAngles.y, aAngles.z);
	
	return true;
end

function SpawnBalloonicorn()
 

	-- Find the point where to spawn the prop from the attachment "prop_spawnpoint" on the tool model.
	-- Create the attachment on the tool model in the model editor first.
	local nAttachmentID = m_hHandAttachment:ScriptLookupAttachment( "grabpoint" );
	local vSpawnPosition = m_hHandAttachment:GetAttachmentOrigin( nAttachmentID );
 
	local balloonKeyvalues = {
		targetname = "spawned_prop";
		model = "models/props/toys/balloonicorn.vmdl";
		origin = vSpawnPosition; -- The origin found from the attachment.
		angles = m_hHandAttachment:GetAngles() -- Give the prop the same angles as the tool.
	}
 
	-- This function spawns the entity in.
	SpawnEntityFromTableSynchronous( "prop_destinations_physics", balloonKeyvalues );
 
end