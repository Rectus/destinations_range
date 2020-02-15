
require("pause_manager")

local WATER_IMPULSE_INTERVAL = 2
local waterImpulseCounter = 0
local WATER_MAX_IMPULSE = 20
local WATER_MAX_IMPULSE_LEVEL = 20.0
local WATER_LEVEL = 0.0
local VOLUME_FACTOR = 400
local MAX_VOLUME_IMPULSE = 3
local ENTITY_SIZE_FACTOR = 0.2
local DRAG_FACTOR = 10.1
local COUNTER_IMPULSE_FACTOR = 0.05
local ROTATION_DAMPING_FACTOR = 0.05
local SPLASH_MIN_SPEED = 80
local RIPPLE_MIN_SPEED = 20
local SPLASH_INTERVAL = 0.5

local splashEnts = {}

local propTypes = 
{
	"prop_destinations_physics",
	"prop_physics_override",
	"prop_physics",
	"prop_destinations_tool"
}

-- List of items spawnable from the spawn menu.
local SPAWN_ITEMS = 
{
	{
		name = "Fireworks",
		img = "",
		isTool = false,
		keyvals =
		{
			targetname = "",
			model = "models/props_toys/fireworks_rocket.vmdl";
			vscripts = "prop_fireworks_rocket";
		},
		modelPrecache = 
		{
			"models/props_toys/fireworks_rocket_fuse.vmdl"
		}
	},
	{
		name = "Flashlight (Valve)",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/props_gameplay/flashlight001.vmdl";
			vscripts = "fl_test";
			HasCollisionInHand = 1;
		}
	},
	{
		name = "Flashlight (rusty)",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/props_beach/flashlight.vmdl";
			vscripts = "tool_flashlight";
			skin = "unlit";
			HasCollisionInHand = 1;
		}
	},
	{
		name = "Paper plane",
		img = "",
		isTool = false,
		keyvals =
		{
			targetname = "",
			model = "models/props_toys/paper_plane1.vmdl";
			vscripts = "prop_paper_plane";
		}
	},
	{
		name = "MAC-10 'n Beans",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/weapons/mac10/mac10.vmdl";
			vscripts = "tool_mac10";
			HasCollisionInHand = 1;
		}
	},
	{
		name = "Laser pistol",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/weapons/laser_pistol.vmdl";
			vscripts = "tool_laser_pistol";
			HasCollisionInHand = 1;
		}
	},
	{
		name = "Round bomb",
		img = "",
		isTool = false,
		keyvals =
		{
			targetname = "",
			model = "models/props_toys/bomb.vmdl";
			vscripts = "prop_bomb";
			rendercolor = "40 39 39";
		},
		modelPrecache = 
		{
			"models/props_toys/bomb_fuse.vmdl"
		}
	},
	{
		name = "Longsword",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/weapons/longsword.vmdl";
			vscripts = "tool_sword";
			rendercolor = "240 240 160";
			HasCollisionInHand = 0;
		}
	},
	{
		name = "Spraypaint can",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/tools/spraycan.vmdl";
			vscripts = "tool_spraycan";
			health = 100;
			--physdamagescale = 1;
			
		},
		modelPrecache = 
		{
			"models/tools/spraycan_colorwheel.vmdl";
			"models/development/invisiblebox.vmdl"
		}
	},
	{
		name = "Recurve bow",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/weapons/bow.vmdl";
			vscripts = "tool_bow";
			HasCollisionInHand = 0;
		},
		modelPrecache = 
		{
			"models/weapons/bow_drawguide.vmdl",
			"models/weapons/arrow.vmdl"
		}
	},
	{
		name = "Boxing glove (left)",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/props_gameplay/boxing_gloves001_left.vmdl";
			vscripts = "tool_glove";
			HasCollisionInHand = 0;
		}
	},
	{
		name = "Boxing glove (right)",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/props_gameplay/boxing_gloves001_right.vmdl";
			vscripts = "tool_glove";
			HasCollisionInHand = 0;
		}
	},
	{
		name = "Gravity Gun",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/weapons/hl2/w_physics_reference.vmdl";
			vscripts = "tool_gravity_gun";
			massScale = 0.2;
			HasCollisionInHand = 1;
		}
	},
	{
		name = "M72 LAW Rocket launcher",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/weapons/law_weapon.vmdl";
			vscripts = "tool_law";
			HasCollisionInHand = 1;
		},
		modelPrecache = 
		{
			"models/weapons/law_rocket.vmdl",
			"models/weapons/law_rocket_packed.vmdl"
		}
	},
	{
		name = "Nailgun",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/tools/nailgun.vmdl";
			vscripts = "tool_nailgun";
			HasCollisionInHand = 1;
		}
	},
	{
		name = "Mare's leg",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/weapons/mares_leg.vmdl";
			vscripts = "tool_mares_leg";
			HasCollisionInHand = 1;
		}
	},
	{
		name = "Entity scanner",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/tools/scanner.vmdl";
			vscripts = "tool_scanner";
			HasCollisionInHand = 1;
		}
	},
	{
		name = "Sunlight adjustment tool",
		img = "",
		isTool = true,
		keyvals =
		{
			targetname = "",
			model = "models/tools/sun_tool.vmdl";
			vscripts = "sun_tool";
		},
		modelPrecache = 
		{
			"models/tools/sun_tool_sun.vmdl"
		}
	},
	{
		name = "LAW Rocket (deployed)",
		img = "",
		isTool = false,
		keyvals =
		{
			targetname = "rocket",
			vscripts = "law_rocket";
			model = "models/weapons/law_rocket.vmdl";	
		}
	},
	{
		name = "Gold bar",
		img = "",
		isTool = false,
		keyvals =
		{
			targetname = "",
			model = "models/props_range/gold_bar.vmdl";
		}
	},
}

-- Any map specific player settings to load into the settigns manager 
local MAP_PLAYER_DEFAULT_SETTINGS =
{
	-- What custom quick inventory items to use by default, indexed from the above array.
	quick_inv_items = {1, 3, 4, 10};
}

-- Enables pausng player movement and the spawn menu.
g_VRScript.pauseManager = CPauseManager(SPAWN_ITEMS, MAP_PLAYER_DEFAULT_SETTINGS, nil)

-- Precache all the assets used by the spawn menu. 
function OnPrecache(context)
	g_VRScript.pauseManager:DoPrecache(context)
	
	PrecacheParticle("particles/splash.vpcf", context)
	PrecacheParticle("particles/splash_ripple.vpcf", context)
	PrecacheParticle("particles/tools/spraypaint_stroke_colored.vpcf", context)
	PrecacheSoundFile("soundevents_addon.vsndevts", context)
end

function OnActivate()
	g_VRScript.pauseManager:Init()
	g_VRScript.debugEnabled = false
end


function OnGameplayStart()

	g_VRScript.ScriptSystem_AddPerFrameUpdateFunction(OnThink)
end


function OnThink()
	
	waterImpulseCounter = waterImpulseCounter + 1
	if waterImpulseCounter < WATER_IMPULSE_INTERVAL
	then
		return
	end
	
	waterImpulseCounter = 0
	
	for _, propType in pairs(propTypes)
	do
		local entity = Entities:FindByClassname(nil, propType)
		while entity
		do
			if not entity:IsNull()
			then
				local scale = entity:GetModelScale()
			
				local level = entity:GetCenter().z - GetMinDimension(entity) * ENTITY_SIZE_FACTOR * scale
				if level < WATER_LEVEL
				then
					--print("under water level")
					local boundMin = entity:GetBoundingMins()
					local boundMax = entity:GetBoundingMaxs()
					local velocity = GetPhysVelocity(entity)
					local speed = velocity:Length()
					
					if speed > RIPPLE_MIN_SPEED
					then
						if splashEnts[entity] == nil or (splashEnts[entity] + SPLASH_INTERVAL) < Time()
						then			
							splashEnts[entity] = Time()
							local splash
							local pos = Vector(entity:GetCenter().x, entity:GetCenter().y, 0)
							
							if speed > SPLASH_MIN_SPEED
							then
								StartSoundEventFromPosition("Beach.Splash", pos)
								splash = ParticleManager:CreateParticle("particles/splash.vpcf", PATTACH_CUSTOMORIGIN, nil)
							else
								splash = ParticleManager:CreateParticle("particles/splash_ripple.vpcf", PATTACH_CUSTOMORIGIN, nil)
							end
							
							ParticleManager:SetParticleControl(splash, 0, pos)						
						end
					end

					--Really crude approximation of volume.
					local volume = abs((boundMax.x - boundMin.x) * (boundMax.y - boundMin.y) * (boundMax.z - boundMin.z)) * scale * scale * scale 
					
					local impulse = (abs(level + WATER_LEVEL) / WATER_MAX_IMPULSE_LEVEL) * WATER_MAX_IMPULSE * min( volume / VOLUME_FACTOR, MAX_VOLUME_IMPULSE)
					entity:ApplyAbsVelocityImpulse(Vector(0, 0, impulse))
					
					local fractionUnderwater = Clamp(abs(2 * (entity:GetCenter().z + WATER_LEVEL)) / (boundMax.z - boundMin.z), 0, 1)
					
					-- Apply underwater drag
					local drag = volume * fractionUnderwater / entity:GetMass()
					local dragFactor = (drag / (drag + DRAG_FACTOR))
					entity:ApplyAbsVelocityImpulse(velocity * -COUNTER_IMPULSE_FACTOR * dragFactor)
					
					-- Apply underwater rotational damping
					SetPhysAngularVelocity(entity, (1 - dragFactor * ROTATION_DAMPING_FACTOR) * GetPhysAngularVelocity(entity))
				end
			end
		
			entity = Entities:FindByClassname(entity, propType)
		end
	end
end

-- Utility function for passing call through to functions if debug mode is enabled.
-- Note that arguments are evaluated regardless of if the function gets called.
function _G.DebugCall(func, ...)
	if g_VRScript.debugEnabled
	then
		return func(...)
	end
	return nil
end

function Clamp(val, min, max)
	if val > max then return max end
	if val < min then return min end
	return val	
end

function GetMinDimension(entity)
	local boundMin = entity:GetBoundingMins()
	local boundMax = entity:GetBoundingMaxs()
	
	return min(abs(boundMax.x - boundMin.x), abs(boundMax.y - boundMin.y), abs(boundMax.z - boundMin.z))
end

function PrintTable(table)
	for key, value in pairs(table)
	do
		
		if(type(value) == "table")
		
		then
			print(type(value) .. ": " .. key)
			for key2, value2 in pairs(value)
			do
				print("  " .. type(value2) .. ": " .. key2)
			end
		end
	end
end