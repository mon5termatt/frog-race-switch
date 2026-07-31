Scriptname FRS_RaceSwitchQuest extends Quest
{Stores the player's original race and grants transform potions.
Frog cannot cast spells/shouts, so potions (alchemy) are the trigger.
Midnight Brew stacks: each drink adds another duration chunk.
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
{Seconds of human form added per Midnight Brew drunk.}

Race Property StoredOriginalRace Auto Hidden

Actor Property PlayerRef Auto

bool _initDone = false
bool _midnightPending = false
int _midnightStacks = 0

Event OnInit()
	RegisterForSingleUpdate(1.0)
EndEvent

Event OnUpdate()
	if _midnightPending
		_midnightStacks -= 1
		if _midnightStacks > 0
			float chunk = SecondsPerStack
			if chunk < 10.0
				chunk = 10.0
			endif
			RegisterForSingleUpdate(chunk)
			Debug.Notification("Midnight holds... " + _midnightStacks + " stack(s) left.")
			return
		endif

		_midnightPending = false
		_midnightStacks = 0
		BecomeFrog()
		return
	endif

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

Function CancelMidnightTimer()
	if _midnightPending || _midnightStacks > 0
		_midnightPending = false
		_midnightStacks = 0
		UnregisterForUpdate()
	endif
EndFunction

Function StartMidnightBrew()
	if PlayerRef == None
		PlayerRef = Game.GetPlayer()
	endif

	Race target = GetHumanRace()
	bool alreadyHuman = target && PlayerRef.GetRace() == target

	if !alreadyHuman
		BecomeHuman(true)
	endif

	float chunk = SecondsPerStack
	if chunk < 10.0
		chunk = 10.0
	endif

	_midnightStacks += 1

	if !_midnightPending
		_midnightPending = true
		RegisterForSingleUpdate(chunk)
	endif

	int totalSec = (_midnightStacks * chunk) as int
	Debug.Notification("Midnight Brew x" + _midnightStacks + " (~" + totalSec + "s).")
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

Function BecomeFrog()
	CancelMidnightTimer()

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
		Debug.Notification("Already a frog.")
		EnsurePotions()
		return
	endif

	StoredOriginalRace = current
	PlayerRef.SetRace(frog)
	Debug.Notification("Became Frog.")
	EnsurePotions()
EndFunction

Function BecomeHuman(bool abTemporary = false)
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
		Debug.Notification("Already human.")
		EnsurePotions()
		return
	endif

	Race frog = ResolveFrogRace()
	if StoredOriginalRace == None && PlayerRef.GetRace() != frog
		StoredOriginalRace = PlayerRef.GetRace()
	endif

	PlayerRef.SetRace(target)
	if abTemporary
		Debug.Notification("Became Human — until midnight.")
	else
		Debug.Notification("Became Human.")
	endif
	EnsurePotions()
EndFunction
