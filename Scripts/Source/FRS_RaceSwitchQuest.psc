Scriptname FRS_RaceSwitchQuest extends Quest
{Stores the player's original race and grants transform potions.
Frog cannot cast spells/shouts, so potions (alchemy) are the trigger.
Midnight Brew stacks via duration spells shown under Active Effects.
Author: MON5TERMATT}

Race Property FrogRace Auto
{Fill with FrogRace from Playable Frog.esp.}

Race Property FallbackHumanRace Auto
{Used only if we never saw the player's original race. Default NordRace.}

Potion Property PotionBecomeFrog Auto
{Swamp Juice — become FrogRace.}

Potion Property PotionBecomeHuman Auto
{Bipedal Brew — permanent human until Swamp Juice.}

Potion Property PotionBecomeHumanTemp Auto
{Midnight Brew — temporary human; each drink stacks more time.}

float Property SecondsPerStack = 300.0 Auto
{Seconds of human form added per Midnight Brew drunk. Spells in ESP must match.}

Spell Property MidnightTimer1 Auto
Spell Property MidnightTimer2 Auto
Spell Property MidnightTimer3 Auto
Spell Property MidnightTimer4 Auto
Spell Property MidnightTimer5 Auto
Spell Property MidnightTimer6 Auto

Race Property StoredOriginalRace Auto Hidden

Actor Property PlayerRef Auto

bool _initDone = false
int _midnightStacks = 0
bool _cancelingMidnight = false

Event OnInit()
	RegisterForSingleUpdate(1.0)
EndEvent

Event OnUpdate()
	if !_initDone
		_initDone = true
		EnsurePotions()
		CaptureOriginalIfNeeded()
	endif
EndEvent

Function EnsurePotions()
	if PlayerRef == None
		PlayerRef = Game.GetPlayer()
	endif

	; One free of each on first load; transforms also top you up by 1.
	if PotionBecomeFrog && PlayerRef.GetItemCount(PotionBecomeFrog) < 1
		PlayerRef.AddItem(PotionBecomeFrog, 1, true)
	endif

	if PotionBecomeHuman && PlayerRef.GetItemCount(PotionBecomeHuman) < 1
		PlayerRef.AddItem(PotionBecomeHuman, 1, true)
	endif

	if PotionBecomeHumanTemp && PlayerRef.GetItemCount(PotionBecomeHumanTemp) < 1
		PlayerRef.AddItem(PotionBecomeHumanTemp, 1, true)
	endif
EndFunction

Function CaptureOriginalIfNeeded()
	if PlayerRef == None
		PlayerRef = Game.GetPlayer()
	endif

	Race frog = ResolveFrogRace()
	Race current = PlayerRef.GetRace()
	if current != frog && StoredOriginalRace == None
		StoredOriginalRace = current
	endif
EndFunction

Race Function GetHumanRace()
	if StoredOriginalRace
		return StoredOriginalRace
	endif
	return FallbackHumanRace
EndFunction

Spell Function GetMidnightTimerSpell(int aiStacks)
	if aiStacks <= 1
		return MidnightTimer1
	elseif aiStacks == 2
		return MidnightTimer2
	elseif aiStacks == 3
		return MidnightTimer3
	elseif aiStacks == 4
		return MidnightTimer4
	elseif aiStacks == 5
		return MidnightTimer5
	endif
	return MidnightTimer6
EndFunction

Function DispelMidnightTimers()
	if PlayerRef == None
		PlayerRef = Game.GetPlayer()
	endif

	if MidnightTimer1
		PlayerRef.DispelSpell(MidnightTimer1)
	endif
	if MidnightTimer2
		PlayerRef.DispelSpell(MidnightTimer2)
	endif
	if MidnightTimer3
		PlayerRef.DispelSpell(MidnightTimer3)
	endif
	if MidnightTimer4
		PlayerRef.DispelSpell(MidnightTimer4)
	endif
	if MidnightTimer5
		PlayerRef.DispelSpell(MidnightTimer5)
	endif
	if MidnightTimer6
		PlayerRef.DispelSpell(MidnightTimer6)
	endif
EndFunction

Function CancelMidnightTimer()
	_cancelingMidnight = true
	_midnightStacks = 0
	DispelMidnightTimers()
	_cancelingMidnight = false
EndFunction

Function OnMidnightExpired()
	; Dispel from CancelMidnightTimer should not turn the player into a frog.
	if _cancelingMidnight
		return
	endif
	if _midnightStacks <= 0
		return
	endif

	_midnightStacks = 0
	BecomeFrog(true)
EndFunction

Function StartMidnightBrew()
	if PlayerRef == None
		PlayerRef = Game.GetPlayer()
	endif

	Race target = GetHumanRace()
	bool alreadyHuman = target && PlayerRef.GetRace() == target

	if !alreadyHuman
		BecomeHuman(true, true)
	endif

	_midnightStacks += 1
	if _midnightStacks > 6
		_midnightStacks = 6
	endif

	_cancelingMidnight = true
	DispelMidnightTimers()
	_cancelingMidnight = false

	Spell timerSpell = GetMidnightTimerSpell(_midnightStacks)
	if timerSpell
		; Apply as a self combat spell so the duration shows under Active Effects.
		PlayerRef.DoCombatSpellApply(timerSpell, PlayerRef)
	else
		Debug.Notification("Frog Race Switch: Midnight timer spell is not set.")
	endif

	EnsurePotions()
EndFunction

Race Function ResolveFrogRace()
	if FrogRace
		return FrogRace
	endif
	; Survives bad/missing CK property fills and old saves where the master was absent.
	FrogRace = Game.GetFormFromFile(0x00000810, "Playable Frog.esp") as Race
	return FrogRace
EndFunction

Function BecomeFrog(bool abFromMidnightExpire = false)
	if !abFromMidnightExpire
		CancelMidnightTimer()
	endif

	if PlayerRef == None
		PlayerRef = Game.GetPlayer()
	endif

	Race frog = ResolveFrogRace()
	if frog == None
		Debug.Notification("Frog Race Switch: FrogRace not found (is Playable Frog.esp enabled?)")
		return
	endif

	Race current = PlayerRef.GetRace()
	if current == frog
		if !abFromMidnightExpire
			Debug.Notification("Already a frog.")
		endif
		EnsurePotions()
		return
	endif

	StoredOriginalRace = current
	PlayerRef.SetRace(frog)
	if !abFromMidnightExpire
		Debug.Notification("Became Frog.")
	endif
	EnsurePotions()
EndFunction

Function BecomeHuman(bool abTemporary = false, bool abSilent = false)
	if !abTemporary
		CancelMidnightTimer()
	endif

	if PlayerRef == None
		PlayerRef = Game.GetPlayer()
	endif

	Race target = GetHumanRace()
	if target == None
		Debug.Notification("Frog Race Switch: no human race stored yet.")
		return
	endif

	if PlayerRef.GetRace() == target
		if !abSilent && !abTemporary
			Debug.Notification("Already human.")
		endif
		EnsurePotions()
		return
	endif

	Race frog = ResolveFrogRace()
	if StoredOriginalRace == None && PlayerRef.GetRace() != frog
		StoredOriginalRace = PlayerRef.GetRace()
	endif

	PlayerRef.SetRace(target)
	if !abSilent && !abTemporary
		Debug.Notification("Became Human.")
	endif
	EnsurePotions()
EndFunction
