


function OnScoreboardChanged(table_name, key, data)
{	
	$.Msg( "Table ", table_name, " changed: '", key, "' = ", data );

}

function UpdateScoreboard(data)
{
	var leaderTime = CustomNetTables.GetTableValue("slalom_scoreboard", "1").time;
	
	for(var idx = 1; idx <= 4; idx++)
	{
		var score = CustomNetTables.GetTableValue("slalom_scoreboard", idx.toString());
		
		if(!score)
		{
			continue;
		}
		
		var timediff = leaderTime - score.time;
		
		$("#ScoreName" + idx).text = "Player " + score.id; // Needs player name
		
		$("#ScoreTime" + idx).text = TimeString(score.time);
		if(idx == 1)
		{
			$("#ScoreDiff" + idx).text = ""
		}
		else
		{
			$("#ScoreDiff" + idx).text = "-" + TimeString(Math.abs(timediff));
		}
	}
}


function UpdateTime(data)
{
	$("#TimeName").text = "Player " + data.id; // Needs player name
	if(data.finished)
	{
		$("#CurrentTime").text = TimeString(data.time);
		
		if(data.prevBest)
		{
			var timediff = data.prevBest - data.time;
			
			var sign = "-"
			
			if(timediff > 0) sign = "+";
			
			$("#CurrentTimeDiff").text = sign + TimeString(Math.abs(timediff));
		}
		else
		{
			$("#CurrentTimeDiff").text = "";
		}
	}
	else
	{
		$("#CurrentTime").text = "X"
		$("#CurrentTimeDiff").text = "";
	}
}

function ClearScoreboard()
{
	for(var idx = 1; idx <= 4; idx++)
	{
		$("#ScoreName" + idx).text = "";
		$("#ScoreTime" + idx).text = "";
		$("#ScoreDiff" + idx).text = "";
	}
	$("#TimeName").text = "";
	$("#CurrentTime").text = "";
	$("#CurrentTimeDiff").text = "";
}


function TimeString(time)
{
	return ZeroPad(Math.floor(time / 60), 2)
		+ ":" + ZeroPad(Math.floor(time % 60), 2) 
		+ "." + ZeroPad(Math.round((time - Math.floor(time)) * 1000), 3);
}


function ZeroPad(num, digits)
{
	var numStr = num.toString();
	
	while(numStr.length < digits)
	{
		numStr = "0" + numStr;
	}
	
	return numStr;
}


function DumpScope(scope)
{
	$.Msg("\nKeys\n")
	var keys = Object.keys(scope), value;

	for(var i = 0; i < keys.length; i++) 
	{
		value = scope[keys[ i ]];
		$.Msg(keys[ i ] + ": " + value );
	}

	$.Msg("\nProperties\n")
	var keys = Object.getOwnPropertyNames(scope), value;

	for(var i = 0; i < keys.length; i++) 
	{
		value = scope[keys[ i ]];
		$.Msg(keys[ i ] + ": " + value );
	}
}

(function()
{
	ClearScoreboard();
	GameEvents.Subscribe("slalom_time", UpdateTime);
	GameEvents.Subscribe("slalom_scoreboard_update", UpdateScoreboard);
	//CustomNetTables.SubscribeNetTableListener("slalom_scoreboard", OnScoreboardChanged);
})();