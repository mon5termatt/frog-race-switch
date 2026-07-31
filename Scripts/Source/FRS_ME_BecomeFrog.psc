Scriptname FRS_ME_BecomeFrog extends ActiveMagicEffect
{Potion effect: switch player to FrogRace, remembering current race.}

FRS_RaceSwitchQuest Property QuestScript Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
	if QuestScript
		QuestScript.BecomeFrog()
	else
		Debug.Notification("Frog Race Switch: potion effect has no QuestScript.")
	endif
EndEvent
