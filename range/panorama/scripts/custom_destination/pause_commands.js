"use strict";

var registerEventID = 0;
var playerID = 0;
var panelID = 0;
var commandSliderPanels = {};
var commandTogglePanels = {};
var commandRadioPanels = {};
var itemToggles = {};
var playerPhysEnabled = false;
var isHost = false;

var COMMAND_TYPES =
{
	COMMAND : 0,
	SLIDER : 1,
	TOGGLE : 2,
	RADIO : 3,
	SET_VALUE : 4,
};


var mapCommands =
[
	// These commands will be replaced if a map provides its own in the map script.
	{cmd: "teleport_start", type: COMMAND_TYPES.COMMAND, text: "#Pause_Button_TeleportToStart"},
];

var quickCommands =
[
	{cmd: "locomotion_mode", type: COMMAND_TYPES.RADIO, text: "#Pause_Header_QuickLocomotion", needs_playerphys: true, values: {0: "#Pause_Button_QuickTeleport", 1: "#Pause_Button_QuickSlide", 2: "#Pause_Button_QuickGrab", 3: "#Pause_Button_QuickRing"}},
];

var toolSettings =
[
	{cmd: "show_skis", type: COMMAND_TYPES.TOGGLE, needs_playerphys: true, text: "#Pause_Setting_Tool_SkiVisibility"},
];

var locomotionSettings =
[
	{cmd: "quick_loco_slide_mode", type: COMMAND_TYPES.RADIO, text: "#Pause_Setting_Loco_SlideMode", needs_playerphys: true, values: {0: "#Pause_Setting_Loco_SlideMode_Hand", 1: "#Pause_Setting_Loco_SlideMode_Head"}},

	{cmd: "quick_loco_slide_factor", type: COMMAND_TYPES.SLIDER, needs_playerphys: true, text: "#Pause_Setting_Loco_SlideFactor", max : 3.0, min : 0.1, increment : 0.1, def : 1.0},

	//{cmd: "quick_loco_grab_mode", type: COMMAND_TYPES.RADIO, text: "#Pause_Setting_Loco_GrabMode", needs_playerphys: true, values: {0: "#Pause_Setting_Loco_GrabMode_Surface", 1: "#Pause_Setting_Loco_GrabMode_Grounded", 2: "#Pause_Setting_Loco_GrabMode_Air"}},

	{cmd: "quick_loco_ring_vert", type: COMMAND_TYPES.TOGGLE, needs_playerphys: true, text: "#Pause_Setting_Loco_RingVertical"},

	{cmd: "quick_loco_turn_mode", type: COMMAND_TYPES.RADIO, text: "#Pause_Setting_Loco_TurnMode", needs_playerphys: true, values: {0: "#Pause_Setting_Loco_TurnMode_None", 1: "#Pause_Setting_Loco_TurnMode_Snap", 2: "#Pause_Setting_Loco_TurnMode_Smooth"}},

	{cmd: "quick_loco_turn_increment", type: COMMAND_TYPES.SLIDER, needs_playerphys: true, text: "#Pause_Setting_Loco_TurnIncrement", max : 90, min : 5, increment : 5, def : 45},

	{cmd: "quick_loco_turn_speed", type: COMMAND_TYPES.SLIDER, needs_playerphys: true, text: "#Pause_Setting_Loco_TurnSpeed", max : 2.0, min : 0.1, increment : 0.1, def : 1.0},

	{cmd: "comfort_grid", type: COMMAND_TYPES.RADIO, text: "#Pause_Setting_Loco_ComfortGrid", needs_playerphys: true, values: {0: "#Pause_Setting_Loco_ComfortGridOff", 1: "#Pause_Setting_Loco_ComfortGridRotate", 2: "#Pause_Setting_Loco_ComfortGridMove", 3: "#Pause_Setting_Loco_ComfortGridAlways"}},

	//{cmd: "comfort_vignette", type: COMMAND_TYPES.TOGGLE, needs_playerphys: true, text: "#Pause_Setting_Loco_ComfortVignette"},
];

var physicsSettings =
[
	{cmd: "player_gravity", type: COMMAND_TYPES.SLIDER, needs_playerphys: true, text: "#Pause_Setting_Phys_Gravity", max : 2.0, min : -1.0, increment : 0.1, def : 1.0},

	{cmd: "player_physics_collisionmode", type: COMMAND_TYPES.RADIO, text: "#Pause_Setting_Phys_CollisionMode", needs_playerphys: true, values: {0: "#Pause_Setting_Phys_CollisionModeOff", 1: "#Pause_Setting_Phys_CollisionModeBody", 2: "#Pause_Setting_Phys_CollisionModeFull"}},

	{cmd: "player_physics_physmode", type: COMMAND_TYPES.RADIO, text: "#Pause_Setting_Phys_PhysMode", needs_playerphys: true, values: {0: "#Pause_Setting_Phys_PhysModeOff", 1: "#Pause_Setting_Phys_PhysModeDirect", 2: "#Pause_Setting_Phys_PhysModeFull"}},

	{cmd: "player_physics_forced_movement", type: COMMAND_TYPES.TOGGLE, text: "#Pause_Setting_Phys_ForcedMove", needs_playerphys: true},
];

var hostSettings =
[
	{cmd: "host_item_spawn_mode", type: COMMAND_TYPES.RADIO, text: "#Pause_Setting_Host_SpawnMode", values: {0: "#Pause_Setting_Host_SpawnMode_Noone", 1: "#Pause_Setting_Host_SpawnMode_Host", 2: "#Pause_Setting_Host_SpawnMode_Everyone"}},
];

var debugSettings =
[
	{cmd: "debug_draw", type: COMMAND_TYPES.TOGGLE, text: "#Pause_Setting_DebugVis"},

	{cmd: "debug_framerate", type: COMMAND_TYPES.TOGGLE, text: "#Pause_Setting_DebugFramerate"},

	{cmd: "player_physics_movemode", type: COMMAND_TYPES.RADIO, text: "#Pause_Setting_Phys_MoveMode", needs_playerphys: true, values: {0: "#Pause_Setting_Phys_MoveModeDynamic", 1: "#Pause_Setting_Phys_MoveModeForceDirect", 2: "#Pause_Setting_Phys_MoveModeForceEntity"}},

	{cmd: "player_phys_think_interval", type: COMMAND_TYPES.SLIDER, needs_playerphys: true, text: "#Pause_Setting_Phys_DebugThink", max : 8, min : 1, increment : 1, def : 2},

	{cmd: "player_phys_move_interval", type: COMMAND_TYPES.SLIDER, needs_playerphys: true, text: "#Pause_Setting_Phys_DebugMove", max : 4, min : 1, increment : 1, def : 1},

	{cmd: "player_phys_allow_direct_frame", type: COMMAND_TYPES.TOGGLE, needs_playerphys: true, text: "#Pause_Setting_PhysAllowDirectFrame"},

	{cmd: "force_reload_pause_panel", type: COMMAND_TYPES.COMMAND, text: "#Pause_Debug_ForceReload"},
];

function RegisterPanel(data)
{
	if(data.panel == $.GetContextPanel().GetOwnerEntityID())
	{
		playerID = data.id;
		panelID = data.panel;
		playerPhysEnabled = data.playerPhys === 0 ? false : true;
		var quickLocoEnabled = data.quickLoco === 0 ? false : true;
		isHost = data.isHost === 0 ? false : true;
		$("#PausePanel").AddClass("Visible");
		GameEvents.Unsubscribe(registerEventID);

		GameEvents.SendCustomGameEventToServer("pause_panel_registered", {id: playerID, panel: panelID});

		if(!quickLocoEnabled)
		{
			$("#QuickPane").AddClass("Hidden");
		}

		AddCommandButtons($("#MapPane"), mapCommands);
		if(quickLocoEnabled) {AddCommandButtons($("#QuickPane"), quickCommands);}
		AddCommandButtons($("#ToolSettingsPane"), toolSettings);
		AddCommandButtons($("#LocomotionSettingsPane"), locomotionSettings);
		AddCommandButtons($("#PhysicsSettingsPane"), physicsSettings);

		if(isHost)
		{
			AddCommandButtons($("#HostSettingsPane"), hostSettings);
			AddCommandButtons($("#DebugSettingsPane"), debugSettings);
		}
	}
}

function SetVisible(data)
{
	if(data.panel != panelID)
	{
		return;
	}

	if(data.visible == 1)
	{
		$("#PausePanel").AddClass("Visible");
		//$("#PausePanelDialog").AddClass("Visible");
		//$("#SettingsDialog").RemoveClass("Visible");
		//$.DispatchEvent("SetPanelSelected", $("#SettingsButton"), false);
		//$("#PausePanelSettingDescription").text = "";
	}
	else
	{
		$("#PausePanel").RemoveClass("Visible");
	}
}

function AddCommandButtons(pane, commands)
{
	pane.RemoveAndDeleteChildren()

	for(var i in commands)
	{
		var data = commands[i]

		if(!playerPhysEnabled && data.needs_playerphys) {continue;}

		if(!data.description) {data.description = "";}

		var command = commands[i].cmd
		switch(data.type)
		{
			case COMMAND_TYPES.COMMAND:

				var panel = $.CreatePanel("Button", pane, command);
				panel.BLoadLayoutSnippet("CommandButton");
				panel.FindChildInLayoutFile("CommandButtonLabel").text = $.Localize(data.text);
				panel.SetAttributeString("desc", data.text + "_Desc");
				panel.SetPanelEvent("onmouseover", MakeDescFunc(panel));
				panel.SetPanelEvent("onactivate", MakeCommandFunc(command, data.type, 0, panel));
				CheckHorizontal(panel);

				break;

			case COMMAND_TYPES.SLIDER:

				var panel = $.CreatePanel("Panel", pane, command);
				panel.BLoadLayoutSnippet("CommandSlider");
				panel.SetAttributeString("desc", data.text + "_Desc");
				panel.SetPanelEvent("onmouseover", MakeDescFunc(panel));
				var slider = panel.FindChildInLayoutFile("CommandSlider");
				var valLabel = panel.FindChildInLayoutFile("CommandSliderValue");

				slider.max = data.max;
				slider.min = data.min;
				slider.increment = data.increment;
				slider.value = data.def;
				valLabel.text = data.def;


				panel.FindChildInLayoutFile("CommandSliderLabel").text = $.Localize(data.text);
				slider.SetPanelEvent("onvaluechanged",
					function(command, commandType, slider, valLabel, panel, increment)
					{
						return function()
						{
							var newVal = Math.round(slider.value * increment) / increment;
							slider.value = newVal;
							valLabel.text = newVal;
							FireCommand(command, commandType, newVal, panel);
						};
					}(command, data.type, slider, valLabel, panel, 1.0 / data.increment)
				);

				CheckHorizontal(panel);
				commandSliderPanels[command] = slider;

				break;

			case COMMAND_TYPES.TOGGLE:

				var panel = $.CreatePanel("ToggleButton", pane, command);
				panel.BLoadLayoutSnippet("CommandToggleButton");
				panel.FindChildInLayoutFile("CommandButtonLabel").text = $.Localize(data.text);
				panel.SetAttributeString("desc", data.text + "_Desc");
				panel.SetSelected(data.def === 1);
				panel.SetPanelEvent("onmouseover", MakeDescFunc(panel));
				panel.SetPanelEvent("onselect", MakeCommandFunc(command, data.type, 1, panel));
				panel.SetPanelEvent("ondeselect", MakeCommandFunc(command, data.type, 0, panel));
				CheckHorizontal(panel);
				commandTogglePanels[command] = panel;

				break;

			case COMMAND_TYPES.RADIO:

				var container = $.CreatePanel("Panel", pane, command + "_Group");
				container.BLoadLayoutSnippet("CommandGroup");
				container.SetAttributeString("desc", data.text + "_Desc");
				container.SetPanelEvent("onmouseover", MakeDescFunc(container));
				var groupPane = container.FindChildInLayoutFile("CommandGroupButtonPane")
				commandRadioPanels[command] = groupPane;

				container.FindChildInLayoutFile("CommandGroupLabel").text = $.Localize(data.text);

				for(var value in data.values)
				{
					var panel = $.CreatePanel("RadioButton", groupPane, command + "_" + value);

					// Hack to be able to assign radio button groups from js
					panel.BLoadLayoutFromString("<root><RadioButton class=\"PausePanelButton Radio\" group=\"" + command + "\"><Label class=\"PausePanelButtonLabel Setting\" id=\"CommandButtonLabel\" /></RadioButton></root>", true, true);
					//panel.BLoadLayoutSnippet("CommandRadioButton");

					panel.FindChildInLayoutFile("CommandButtonLabel").text = $.Localize(data.values[value]);
					panel.SetAttributeString("desc", data.text + "_Desc");
					panel.SetPanelEvent("onactivate", MakeCommandFunc(command, data.type, value, panel));
					panel.SetAttributeInt("value", parseInt(value));
					CheckHorizontal(panel);
				}
				break;

			case COMMAND_TYPES.SET_VALUE:

				var panel = $.CreatePanel("Button", pane, command);
				panel.BLoadLayoutSnippet("CommandButton");
				panel.FindChildInLayoutFile("CommandButtonLabel").text = $.Localize(data.text);
				panel.SetAttributeString("desc", data.text + "_Desc");
				panel.SetPanelEvent("onmouseover", MakeDescFunc(panel));
				panel.SetPanelEvent("onactivate", MakeCommandFunc(command, data.type, data.value, panel));
				CheckHorizontal(panel);

				break;
		}
	}
	if(pane.BHasClass("GridH") && pane.GetChildCount() > 0)
	{
		var height = Math.ceil((pane.GetChildCount()) / 2) * 114 + 25;
		pane.style.height = "" + height + "px";
	}

}


function CheckHorizontal(panel)
{
	var parent = panel.GetParent();
	if(parent && parent.BHasClass("Horizontal") )
	{
		panel.AddClass("Horizontal");
	}
	else if(parent && parent.BHasClass("GridH"))
	{
		panel.AddClass("Grid");
	}
}


function AddItem(data)
{
	if(data.panel == panelID)
	{
		var spawnPane = $("#SpawnPane");
		var itemID = parseInt(data.item);

		var itemPanel = $.CreatePanel("Panel", spawnPane, "Item" + parseInt(data.item));

		itemPanel.BLoadLayoutSnippet("ItemButton");
		var button = itemPanel.FindChildInLayoutFile("ItemSpawnButton");
		button.SetAttributeInt("itemID", itemID);

		if(data.img.length > 0)
		{
			button.FindChildInLayoutFile("ItemSpawnButtonImage").SetImage(data.img);
		}

		button.FindChildInLayoutFile("ItemSpawnButtonLabel").text = $.Localize(data.name);

		var spawnItem = function(panel)
		{
			return function()
			{
				var itemID = panel.GetAttributeInt("itemID", 0);

				GameEvents.SendCustomGameEventToServer("pause_panel_spawn_item", {id: playerID, panel: panelID, itemID: itemID});
			}
		}( button );
		button.SetPanelEvent("onactivate", spawnItem);

		var invToggle = itemPanel.FindChildInLayoutFile("ItemInvToggle");
		invToggle.SetPanelEvent("onselect", MakeCommandFunc("custom_inv_add", COMMAND_TYPES.SET_VALUE, itemID));
		invToggle.SetPanelEvent("ondeselect", MakeCommandFunc("custom_inv_remove", COMMAND_TYPES.SET_VALUE, itemID));
		itemToggles[itemID] = invToggle;
	}
}

function MakeCommandFunc(command, commandType, value, panel)
{
	return function()
	{
		FireCommand(command, commandType, value, panel);
	};
}


function FireCommand(command, commandType, value, panel)
{
	ShowSettingDescription(panel);

	GameEvents.SendCustomGameEventToServer("pause_panel_command",
	{
		id: playerID,
		panel: panelID,
		cmd: command,
		type: commandType,
		val: value
	});
}

function MakeDescFunc(panel)
{
	return function()
	{
		ShowSettingDescription(panel);
	};
}

function ShowSettingDescription(panel)
{
	if(panel)
	{
		var description = panel.GetAttributeString("desc", "");
		if(description)
		{
			$("#PausePanelSettingDescription").text = $.Localize(description);
		}
	}
}

function SetQuickInv(value)
{

	var children = $("#SpawnPane").FindChildrenWithClassTraverse("PausePanelInvToggle")
	for(var i = 0; i < children.length; i++)
	{
		if(value == 1)
		{
			children[i].AddClass("ToggleEnabled")
		}
		else
		{
			children[i].RemoveClass("ToggleEnabled")
		}
	}
	FireCommand("custom_quick_inv", COMMAND_TYPES.TOGGLE, value)
}


function ApplyPlayerSettings(data)
{
	if(data.playerID != playerID && data.playerID != -1) {return;}

	for(var setting in data)
	{
		var value = data[setting];

		// Set all the quick inventory toggles
		if(setting == "playerID")
		{
			continue;
		}
		else if(setting == "debug_framerate")
		{
			var isEnabled = (value == 1);

			if(isEnabled)
			{
				$("#PausePanelTitleFramerate").RemoveClass("Hidden");
				GameEvents.Subscribe("debug_framerate_val", SetDebugFramerate);
			}
			else
			{
				$("#PausePanelTitleFramerate").AddClass("Hidden");
			}

			commandTogglePanels[setting].SetSelected(isEnabled);
		}
		else if(setting == "quick_inv_items")
		{
			var foundItems = {};

			for(var i in value)
			{
				var itemID = value[i];
				foundItems[itemID] = true;

				if(itemID in itemToggles)
				{
					itemToggles[itemID].SetSelected(true);

				}
			}

			for(var itemID in itemToggles)
			{
				if(!(itemID in foundItems))
				{
					itemToggles[itemID].SetSelected(false);
				}
			}
		}
		else if(setting in commandSliderPanels)
		{
			var slider = commandSliderPanels[setting];
			slider.value = value;
		}
		else if(setting in commandTogglePanels)
		{
			var panel = commandTogglePanels[setting];
			panel.SetSelected(value == 1);
		}
		else if(setting in commandRadioPanels)
		{

			var panel = commandRadioPanels[setting];
			var children = panel.Children();

			for(var i in children)
			{
				if(children[i].GetAttributeInt("value", NaN) === value)
				{
					$.DispatchEvent("SetPanelSelected", children[i], true);
					break;
				}
			}
		}
	}
}

function AddMapCommands(data)
{
	if(data.id != playerID) {return;}
	if("commands" in data)
	{
		AddCommandButtons($("#MapPane"), data.commands);
	}
}

function SetDebugFramerate(data)
{
	$("#PausePanelTitleFramerate").text = "FPS: " + data.val.toFixed(0);
}


(function()
{
	registerEventID = GameEvents.Subscribe("pause_panel_register", RegisterPanel);
	GameEvents.Subscribe("pause_panel_add_item", AddItem);
	GameEvents.Subscribe("pause_panel_set_visible", SetVisible);
	GameEvents.Subscribe("sync_player_settings", ApplyPlayerSettings);
	GameEvents.Subscribe("pause_panel_add_map_commands", AddMapCommands);
})();
