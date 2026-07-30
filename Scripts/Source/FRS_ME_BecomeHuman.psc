Scriptname FRS_ME_BecomeHuman extends ActiveMagicEffect
{Permanent human form until Swamp Juice.}

FRS_RaceSwitchQuest Property QuestScript Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
	if QuestScript
		QuestScript.BecomeHuman(false)
	endif
EndEvent
