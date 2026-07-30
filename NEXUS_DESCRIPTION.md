# Frog Race Switch

Temporary race-switch potions for [Anthrophibians (Playable Frog Race)](https://www.nexusmods.com/skyrimspecialedition/mods/92753).

Playing as a frog is great until you remember you cannot cast spells, jump, block, shout, sneak, or ride a horse. This mod gives you potions to flip back to a normal race when you need those things, then become a frog again when you are done.

## Features

You get three potions for free when you load in. After you transform, the mod tops you back up so you do not run dry. No crafting required.

### Swamp Juice

Puts you back in frog form.

### Bipedal Brew

Makes you human until you drink Swamp Juice again.

### Midnight Brew

Makes you human for a while. It stacks, so each extra drink buys you about five more minutes.

Your original race is remembered. If you somehow start already as a frog with nothing stored, it falls back to Nord.

The item text is a little Disney on purpose. True love's kiss was taking too long.

## Requirements

* Skyrim Special Edition or Anniversary Edition
* [Anthrophibians / Playable Frog Race](https://www.nexusmods.com/skyrimspecialedition/mods/92753) (`Playable Frog.esp`)

No SKSE. No SkyUI.

## Installation

Install with Vortex or MO2, or drop these into `Data`:

* `FrogRaceSwitch.esp`
* `FrogRaceSwitch.bsa`

Load it after `Playable Frog.esp`.

## Usage

1. Load a save and you should receive one of each potion.
2. Drink **Midnight Brew** when you want a timed human form. Drink more to stack more time.
3. Drink **Bipedal Brew** when you want to stay human until you choose otherwise.
4. Drink **Swamp Juice** to go frog again. That also clears any Midnight Brew time you still had left.

## Compatibility

This uses `Actor.SetRace` under the hood. Armor might unequip or look weird until you put it back on. Race overhauls like Imperious can get confused if you swap a lot. This does not fix frog animations. It literally changes your race.

## Credits

**MON5TERMATT** made Frog Race Switch.

Huge thanks to the author of Anthrophibians / Playable Frog Race for the froggo race itself.

## Permissions

Ask before uploading this elsewhere. Feel free to use it in your load order, screenshots, and videos with credit.
