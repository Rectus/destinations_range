"use strict";

var panelID = $.GetContextPanel().GetOwnerEntityID();
var cursorX = 0;
var cursorY = 0;

var selected = [3,4,2,0];
var padFactor = 1.0;
var grabFactor = 1.0;

var CONFIG_TYPES = 
{
	PAD : 1,
	TRIGGER : 2,
	ROTATE : 3,
	TARGET : 4,
	PAD_FACTOR : 5,
	GRAB_FACTOR : 6
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
	],
	[
		"PadFactor"
	],
	[
		"GrabFactor"
	],
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
	
	for(var key in data)
	{
		if(data[key] == null) {$.Msg("Invalid menu value received."); return;}
	}
	
	SetSelectedButton(0, data.trigger - 1);
	SetSelectedButton(1, data.pad);
	SetSelectedButton(2, data.rotate);
	SetSelectedButton(3, data.target - 1);
	
	$("#PadFactorSlider").value = padFactor;
	$("#PadFactorValue").text = padFactor.toFixed(1);
	$("#GrabFactorSlider").value = grabFactor;
	$("#GrabFactorValue").text = grabFactor.toFixed(1);
	
	selected.forEach(function(val, idx) {$("#" + SELECTION_BUTTONS[idx][val]).AddClass("Selected")});
	$("#" +SELECTION_BUTTONS[cursorY][cursorX]).AddClass("Cursor");
	HoverTrigger(1);
}


function UICommand(data)
{
	if(data.id != panelID)
	{
		return;
	}
	
	var XDir = 0;
	if(!(data.command & UI_COMMANDS.ENTER))
	{
		$("#" + SELECTION_BUTTONS[cursorY][cursorX]).RemoveClass("Cursor");
		
		if(data.command & UI_COMMANDS.UP)
		{
			cursorY -= 1;
			if(cursorY < 0) cursorY = SELECTION_BUTTONS.length - 1;
			
			if(cursorY < selected.length)
			{
				cursorX = selected[cursorY]
			}
		}
		if(data.command & UI_COMMANDS.DOWN)
		{
			$.DispatchEvent("MovePanelDown", 1)
			cursorY += 1;
			if(cursorY >= SELECTION_BUTTONS.length) cursorY = 0;
			
			if(cursorY < selected.length)
			{
				cursorX = selected[cursorY]
			}
		}
		
		if(cursorX >= SELECTION_BUTTONS[cursorY].length) cursorX = 0;
		
		if(data.command & UI_COMMANDS.LEFT)
		{
			cursorX -= 1;
			XDir = -1;
			if(cursorX < 0) cursorX = SELECTION_BUTTONS[cursorY].length - 1;
		}
		if(data.command & UI_COMMANDS.RIGHT)
		{
			$.DispatchEvent("MovePanelRight", 1)
			cursorX += 1;
			XDir = 1;
			if(cursorX >= SELECTION_BUTTONS[cursorY].length) cursorX = 0;
		}
		$("#" + SELECTION_BUTTONS[cursorY][cursorX]).AddClass("Cursor");
		
		switch(cursorY)
		{
			case 0:
				HoverTrigger(cursorX + 1);
				break;
			case 1:
				HoverPad(cursorX);
				break;
			case 2:
				HoverRotation(cursorX);
				break;
			case 3:
				HoverTargeting(cursorX + 1);
				break;
			case 4:
				HoverPadFactor(XDir);
				break;
			case 5:
				HoverGrabFactor(XDir);
				break;
		}	
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


function HoverPad(val)
{
	switch(val)
	{
		case 0:
			$("#Description").text = "Disable trackpad/joystick locomotion.";
			break;
		case 1:
			$("#Description").text = "Use the standard SteamVR Home teleport.";
			break;
		case 2:
			$("#Description").text = "Trackpad/joystick movement activated by touching the pad or pushing the stick.";
			break;
		case 3:
			$("#Description").text = "Trackpad/joystick movement activated by pressing down on the pad or clicking the stick.";
			break;
		case 4:
			$("#Description").text = "Trackpad/joystick movement activated by touching the pador pushing the stick.\n\nPressing down on the pad or clicking the stick makes you move faster.";
			break;
	}
}

function SetPad(val)
{	
	HoverPad(val)
	SetSelectedButton(1, val)

	GameEvents.SendCustomGameEventToServer("locomotion_tool_config", {panel: panelID, conf: CONFIG_TYPES.PAD, val: val});
}

function HoverTrigger(val)
{
	switch(val)
	{
		case 1:
			$("#Description").text = "Hold the trigger to grab onto surfaces and and pull the controller to move yourself around.\n\nGrabbing onto props will move you along them. Letting go of the trigger while pulling on the controller lets you fling yourself in the air.";
			break;
		case 2:
			$("#Description").text = "Grab anywhere and pull to move yourself around.\n\nGrabbing onto props will move you along them. Letting go of the trigger while pulling on the controller lets you fling yourself in the air.";
			break;
		case 3:
			$("#Description").text = "Grab anywhere to move yourself around. Moves you along the ground unless a surface is grabbed.\n\nGrabbing onto props will move you along them. Letting go of the trigger while pulling on the controller lets you fling yourself in the air.";
			break;
		case 4:
			$("#Description").text = "Grappling hook activated by holding down the trigger. The targeting laser turns green when aimed at a valid surface. When the laser turns yellow the aimed at prop can be pulled toward you.\nHold the touchpad or touch the joystick to rappel down slowly.";
			break;
		case 5:
			$("#Description").text = "Hold the trigger for vertical flight. Using pad/stick movement propels you horizontally.\n\nAnalog speed control.";
			break;
		case 6:
			$("#Description").text = "Fly in the controller or head direction by holding town the trigger.\n\nAnalog speed control.";
			break;
	}
}

function SetTrigger(val)
{	
	HoverTrigger(val)
	SetSelectedButton(0, val - 1)

	GameEvents.SendCustomGameEventToServer("locomotion_tool_config", {panel: panelID, conf: CONFIG_TYPES.TRIGGER, val: val});
}


function HoverRotation(val)
{
	switch(val)
	{
		case 0:
			$("#Description").text = "Rotation disabled.";
			break;
		case 1:
			$("#Description").text = "Rotate by rotating the controller while the trigger is pressed.";
			break;
		case 2:
			$("#Description").text = "Rotate relative to both controllers while both triggers are pressed.";
			break;
	}
}

function SetRotation(val)
{	
	HoverRotation(val)
	SetSelectedButton(2, val)
	
	GameEvents.SendCustomGameEventToServer("locomotion_tool_config", {panel: panelID, conf: CONFIG_TYPES.ROTATE, val: val});
}

function HoverTargeting(val)
{
	switch(val)
	{
		case 1:
			$("#Description").text = "Uses controller facing for movement direction.";
			break;
		case 2:
			$("#Description").text = "Uses controller facing for movement direction.\n\nAlways uses the same speed regardless of the controller pitch.";
			break;
		case 3:
			$("#Description").text = "Uses head facing for movement direction.";
			break;

	}
}

function SetTargeting(val)
{	
	HoverTargeting(val)
	SetSelectedButton(3, val - 1)

	GameEvents.SendCustomGameEventToServer("locomotion_tool_config", {panel: panelID, conf: CONFIG_TYPES.TARGET, val: val});
}

function HoverPadFactor(dir)
{
	$("#Description").text = "Movement sensitivity of the joystick/touchpad.";
	
	if(dir != 0)
	{
		$("#PadFactorSlider").value += parseFloat(dir) * 0.1
		padFactor = ClampSliderValue($("#PadFactorSlider"))
		GameEvents.SendCustomGameEventToServer("locomotion_tool_config", {panel: panelID, conf: CONFIG_TYPES.PAD_FACTOR, val: padFactor});
	}
}

function SetPadFactor()
{
	$("#PadFactorSlider").value = Math.round($("#PadFactorSlider").value * 10) / 10;
	padFactor = ClampSliderValue($("#PadFactorSlider"))
	$("#PadFactorValue").text = padFactor.toFixed(1)
	$("#Description").text = "Movement sensitivity of the joystick/touchpad.";
	GameEvents.SendCustomGameEventToServer("locomotion_tool_config", {panel: panelID, conf: CONFIG_TYPES.PAD_FACTOR, val: padFactor});
}

function HoverGrabFactor(dir)
{
	$("#Description").text = "How much to multiply the movement when grabbing. Set to 1 for 1:1 movement.";
	if(dir != 0)
	{
		$("#GrabFactorSlider").value += parseFloat(dir) * 1.0
		grabFactor = ClampSliderValue($("#GrabFactorSlider"))
		GameEvents.SendCustomGameEventToServer("locomotion_tool_config", {panel: panelID, conf: CONFIG_TYPES.GRAB_FACTOR, val: grabFactor});
	}
}

function SetGrabFactor()
{
	$("#GrabFactorSlider").value = Math.round($("#GrabFactorSlider").value * 10) / 10;
	grabFactor = ClampSliderValue($("#GrabFactorSlider"))
	$("#GrabFactorValue").text = grabFactor.toFixed(1)
	$("#Description").text = "How much to multiply the movement when grabbing. Set to 1 for 1:1 movement.";
	GameEvents.SendCustomGameEventToServer("locomotion_tool_config", {panel: panelID, conf: CONFIG_TYPES.GRAB_FACTOR, val: grabFactor});
}

function ClampSliderValue(slider)
{
	if(slider.value > slider.max) {slider.value = slider.max;}
	else if(slider.value < slider.min) {slider.value = slider.min;}
	return slider.value;
}

(function()
{
	selected.forEach(function(val, idx) {$("#" + SELECTION_BUTTONS[idx][val]).AddClass("Selected")});
	$("#" +SELECTION_BUTTONS[cursorY][cursorX]).AddClass("Cursor");
	HoverTrigger(1);
	
	$("#PadFactorSlider").min = 0.1;
	$("#PadFactorSlider").max = 2.0;
	$("#PadFactorSlider").increment = 0.1;

	
	$("#GrabFactorSlider").min = 1.0;
	$("#GrabFactorSlider").max = 10.0;
	$("#GrabFactorSlider").increment = 0.1;
	
	GameEvents.Subscribe("locomotion_tool_sync_selection", SyncSelection);
	GameEvents.Subscribe("locomotion_tool_ui_command", UICommand);
	GameEvents.Subscribe("locomotion_tool_set_visible", SetVisible);
})();