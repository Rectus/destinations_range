"use strict";

function UpdateDisplay(data)
{
	if(data.id == $.GetContextPanel().GetOwnerEntityID())
	{		
		$("#TextDisplay").text = "" + FormatNumber(data.speed) + "m/s\n\n" 
			+ FormatNumber(data.altitude) + "m\n\n" + FormatTime(data.hours) + ":" + FormatTime(data.minutes);
	}
}

function FormatTime(num)
{
	if(num < 10)
	{
		return "0" + num.toString();
	}
	return num.toString();
}


function FormatNumber(num)
{
	if(num > 100)
	{
		return Math.round(num);
	}
	else if(num > 10)
	{
		return Math.round(num * 10) / 10;
	}
	else
	{
		return Math.round(num * 100) / 100;
	}
}

(function()
{
	GameEvents.Subscribe("locomotion_tool_update_display", UpdateDisplay);
})();