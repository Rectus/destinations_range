require "utils.deepprint"
--[[
print(model:CreatePoseParameter("pparam", 0, 1, 1, false))


print(model:CreateWeightlist("a", model))
print(model:GetAnimationList())
print(model:GetModelName())
print(model:GetSequence("in_anim"))
print(model:GetSequenceList())
print(model:LookupAnimation("in_anim"))
print(model:LookupSequence("in_anim"))
print(model:LookupPoseParameter("pparam"))
print(model:LookupWeightlist("in_anim"))
print(model:SequenceGetName(model:LookupSequence("in_anim")))

--print(type(model:CreateTransitionGraph({model, "ttext"})))
--print(type(model:CreateTransitionStateGraph({model, "ttext"})))

local seq = model:GetSequence("in_anim")

print(seq:GetName())
print(seq:IsVScript())]]

model:CreateSequence({name="aaaa"})

DeepPrintTable(model:CreateSequence(
	{
		name="seq1",
		autoplay = true,
		--2dtri = true,
		--weightlist = 0,
		sequences = {{"aaaa"}},
		activities = {{name = "", weight = 0.5}, {name = "act2", weight = 1.5}},
		--ikLocks = {{bone = "gold_bar_gold_bar", posWeight = 3, rotweight = -1}},
		cmds = 
		{
			{cmd = "nop"},
			--{cmd = "lineardelta"},
			--{cmd = "fetchframerange"},
			--{cmd = "slerp"},
			--{cmd = "add"},
			--{cmd = "subtract"},
			--{cmd = "scale"},
			--{cmd = "copy"},
			--{cmd = "blend"},
			--{cmd = "worldspace"},
			--{cmd = "sequence"},
			--{cmd = "fetchcycle"},
			--{cmd = "fetchframe"},
			--{cmd = "iklockinplace"},
			--{cmd = "ikrestoreall"},
			--{cmd = "reversesequence"},
			--{cmd = "transform"},
			
			--{cmd = "spline"},
			--{cmd = "var1"},
			--{cmd = "weightlist"},
			--{cmd = "src"},
			--{cmd = "var2"},
			--{cmd = "dst"},
			--{cmd = "bone"},
			--{cmd = "frame"},
			--{cmd = "cycle"}
		},
		--animevents = "",
		--blendlayer = "",
		--cycletoweightbias = "",
		--end = "",
		--  endframe = "",
		--entry = "",
		--event = "",
		--exit = "",
		fadeintime = "",
		fadeouttime = "",
		fps = "",
		framecacheable = 1,
		--framerangesequence = 1,
		--local = "",
		--noblend = "",
		node = "",
		numframes = "",
		--option = "",
		--peak = "",
		--peakframe = "",
		--poseparameter = "",
		--posetocycle = "",
		--rotate = "",
		--start = "",
		--startframe = "",
		--tail = "",
		--   tailframe = "",
		--  transition = {entry = "$", exit = "$"},
		--transitions = {{entry = "$", exit = "$"}},
		--translate = "",
		--xfade = ""
	}
))







