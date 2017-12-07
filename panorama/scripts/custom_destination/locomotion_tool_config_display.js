"use strict";

var panelID = $.GetContextPanel().GetOwnerEntityID();
var cursorX = 0
var cursorY = 0

var selected = [3,4,2,0];

var CONFIG_TYPES = 
{
	PAD : 1,
	TRIGGER : 2,
	ROTATE : 3,
	TARGET : 4
};

var UI_COMMANDS = 
{
	UP : 1,
	DOWN : 2,
	LEFT : 4,
	RIGHT : 8,
	ENTER : 16
};

var SELECTION_BUTTONS = 
[
	[
		"TriggerSurfaceGrab",
		"TriggerAirGrab",
		"TriggerAirGrabGround",
		"TriggerGrapple",
		"TriggerJetpack",
		"TriggerFly"
	],
	[
		"PadDisable",
		"PadTeleport",
		"PadTouch",
		"PadPush",
		"PadDual"
	],
	[
		"RotateDisable",
		"RotateOneYaw",
		"RotateTwo"
	],
	[
		"TargetingHand",
		"TargetingHandNormal",
		"TargetingHead"
	]
];

function SetVisible(data)
{
	if(data.id != panelID)
	{
		return;
	}
	
	if(data.visible)
	{
		$("#ConfigPanel").AddClass("Visible");
	}
	else
	{
		$("#ConfigPanel").RemoveClass("Visible");
	}
}


function SyncSelection(data)
{
	if(data.id != panelID)
	{
		return;
	}
	
	SetSelectedButton(0, data.trigger - 1);
	SetSelectedButton(1, data.pad);
	SetSelectedButton(2, data.rotate);
	SetSelectedButton(3, data.target - 1);
}


function UICommand(data)
{
	if(data.id != panelID)
	{
		return;
	}
	
	if(!(data.command & UI_COMMANDS.ENTER))
	{
		$("#" + SELECTION_BUTTONS[cursorY][cursorX]).RemoveClass("Cursor");
		
		if(data.command & UI_COMMANDS.UP)
		{
			cursorY -= 1;
			if(cursorY < 0) cursorY = SELECTION_BUTTONS.length - 1;
		}
		if(data.command & UI_COMMANDS.DOWN)
		{
			cursorY += 1;
			if(cursorY >= SELECTION_BUTTONS.length) cursorY = 0;
		}
		
		if(cursorX >= SELECTION_BUTTONS[cursorY].length) cursorX = 0;
		
		if(data.command & UI_COMMANDS.LEFT)
		{
			cursorX -= 1;
			if(cursorX < 0) cursorX = SELECTION_BUTTONS[cursorY].length - 1;
		}
		if(data.command & UI_COMMANDS.RIGHT)
		{
			cursorX += 1;
			if(cursorX >= SELECTION_BUTTONS[cursorY].length) cursorX = 0;
		}
		$("#" +SELECTION_BUTTONS[cursorY][cursorX]).AddClass("Cursor");
	}
	else
	{
		switch(cursorY)
		{
			case 0:
				SetTrigger(cursorX + 1);
				break;
			case 1:
				SetPad(cursorX);
				break;
			case 2:
				SetRotation(cursorX);
				break;
			case 3:
				SetTargeting(cursorX + 1);
				break;
		}	
	}
}

function SetSelectedButton(row, col)
{
	$("#" + SELECTION_BUTTONS[row][selected[row]]).RemoveClass("Selected");
	selected[row] = col;
	$("#" + SELECTION_BUTTONS[row][col]).AddClass("Selected");
}


function SetPad(val)
{	
	switch(val)
	{
		case 0:
			$("#Description").text = "Disable trackpad locomotion.";
			break;
		case 1:
			$("#Description").text = "Use the standard SteamVR Home teleport.";
			break;
		case 2:
			$("#Description").text = "Trackpad movement activated by touching the pad.";
			break;
		case 3:
			$("#Description").text = "Trackpad movement activated by pressing the pad.";
			break;
		case 4:
			$("#Description").text = "Trackpad movement activated by touching the pad.\n\nPressing the pad makes you move faster.";
			break;
	}
	
	SetSelectedButton(1, val)

	GameEvents.SendCustomGameEventToServer("locomotion_tool_config", {panel: panelID, conf: CONFIG_TYPES.PAD, val: val});
}

function SetTrigger(val)
{	
	switch(val)
	{
		case 1:
			$("#Description").text = "Hold the trigger to grab onto surfaces and move yourself around.\n\nGrabbing onto props will move you along them.";
			break;
		case 2:
			$("#Description").text = "Grab anywhere to move yourself around.";
			break;
		case 3:
			$("#Description").text = "Grab anywhere to move yourself around.\n\nMoves you along the ground unless a surface is grabbed.";
			break;
		case 4:
			$("#Description").text = "Grappling hook activated by holding down the trigger. The targeting laser turns green when aimed at a valid surface. When the laser turns yellow the aimed at prop can be pulled toward you.\nHold the touchpad to rappel down slowly.";
			break;
		case 5:
			$("#Description").text = "Hold the trigger for vertical flight.\n\nAnalog speed control.";
			break;
		case 6:
			$("#Description").text = "Fly in the controller or head direction by holding town the trigger.\n\nAnalog speed control.";
			break;
	}
	SetSelectedButton(0, val - 1)

	GameEvents.SendCustomGameEventToServer("locomotion_tool_config", {panel: panelID, conf: CONFIG_TYPES.TRIGGER, val: val});
}

function SetRotation(val)
{	
	switch(val)
	{
		case 0:
			$("#Description").text = "Rotation disabled.";
			break;
		case 1:
			$("#Description").text = "Rotates by the controller while the trigger is pressed.";
			break;
		case 2:
			$("#Description").text = "Rotates relative to both controllers while both triggers are pressed.";
			break;
	}
	SetSelectedButton(2, val)
	
	GameEvents.SendCustomGameEventToServer("locomotion_tool_config", {panel: panelID, conf: CONFIG_TYPES.ROTATE, val: val});
}

function SetTargeting(val)
{	
	switch(val)
	{
		case 1:
			$("#Description").text = "Use the controller facing for movement direction.";
			break;
		case 2:
			$("#Description").text = "Use the controller facing for movement direction.\n\nAlways uses the same speed regardless of the controller pitch.";
			break;
		case 3:
			$("#Description").text = "Use head facing for movement direction.";
			break;

	}
	SetSelectedButton(3, val - 1)

	GameEvents.SendCustomGameEventToServer("locomotion_tool_config", {panel: panelID, conf: CONFIG_TYPES.TARGET, val: val});
}


(function()
{
	selected.forEach(function(val, idx) {$("#" + SELECTION_BUTTONS[idx][val]).AddClass("Selected")});
	$("#" +SELECTION_BUTTONS[cursorY][cursorX]).AddClass("Cursor");
	
	GameEvents.Subscribe("locomotion_tool_sync_selection", SyncSelection);
	GameEvents.Subscribe("locomotion_tool_ui_command", UICommand);
	GameEvents.Subscribe("locomotion_tool_set_visible", SetVisible);
})();