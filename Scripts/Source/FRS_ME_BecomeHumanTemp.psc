Scriptname FRS_ME_BecomeHumanTemp extends ActiveMagicEffect
{Midnight Brew: temporary human; each drink stacks more time.}

FRS_RaceSwitchQuest Property QuestScript Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
	if QuestScript
		QuestScript.StartMidnightBrew()
	endif
EndEvent
