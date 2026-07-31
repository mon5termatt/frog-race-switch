Scriptname FRS_ME_MidnightTimer extends ActiveMagicEffect
{Visible Active Effects timer for Midnight Brew. On expire, return to frog.}

FRS_RaceSwitchQuest Property QuestScript Auto

Event OnEffectFinish(Actor akTarget, Actor akCaster)
	if QuestScript
		QuestScript.OnMidnightExpired()
	endif
EndEvent
