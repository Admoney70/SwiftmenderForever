# Swiftmender Forever

A World of Warcraft: **Forever** addon for Restoration Druids. It shows you at a glance who can be
**Swiftmended**, meaning who currently has **Rejuvenation** or **Regrowth** on them.

## Features

- **Raid frame markers:** a Swiftmend icon and a green border (adjustable thickness) on every group
  member who can be Swiftmended. The icon can show a spiral and a countdown for the HoT's remaining duration;
  each can be turned off.
  - Blizzard raid and party frames (`CompactRaidFrame…`, `CompactPartyFrame…`, `CompactRaidGroup…`)
  - [Buzzard Frames](https://www.curseforge.com/wow/addons/buzzard-frames) (frames named `Buzzard…` / `BF_…`)
- **Draggable alert icon:** tracks your **target** only. It lights up when your friendly target
  (including yourself, when you target yourself) can be Swiftmended, showing their name and how long the HoT has left.
  - While Swiftmend is on cooldown, the icon fades.
  - Optional green border around the icon, with adjustable thickness.
  - When your target can't be Swiftmended, the icon is hidden.
- **Works in combat.** WoW Forever uses the Midnight addon rules, which hide buffs from addons during
  combat, encounters, M+ and PvP. Swiftmender doesn't try to read them. It gives Blizzard's own aura
  display (`Blizzard_AuraContainer`) a slot that matches only Rejuvenation and Regrowth. The game then
  shows and hides the marker, spiral and timer itself. All ranks are matched, plus any spell ID the
  addon sees on a Rejuvenation or Regrowth out of combat.
  - Settings you change during combat take effect when combat ends.
  - `/sm status` shows "combat tracking: native" when this is active. On a client without the native
    aura display, it falls back to out-of-combat-only tracking.

## Install

Copy this folder into your WoW Forever AddOns folder, so that the path is
`…/AddOns/SwiftmenderForever/SwiftmenderForever.toc`. Then `/reload`.

The TOC declares `## Interface: 16001, 120105, 120100` (WoW Forever plus Midnight). If the game lists
the addon as out of date, check the client's number with `/dump select(4, GetBuildInfo())` and add it
to the `## Interface:` line.

## Usage

Type **`/sm`** (or `/swiftmender`) to open the settings window. You can also reach it from
Esc > Options > AddOns > Swiftmender Forever. The window covers the target icon (show, lock, size,
cooldown fade, border and thickness, reset position), the raid frame markers (Blizzard and Buzzard on/off, marker icon,
HoT spiral, countdown timer, border and thickness, size, position, offsets) and whether to count only your own HoTs.

The target icon starts **unlocked**. Drag it where you want it, then right-click it or tick
"Lock position".

### Shortcut commands

| Command | What it does |
|---|---|
| `/sm lock` / `/sm unlock` | Lock the target icon, or unlock it so you can move it |
| `/sm icon` | Turn the target icon on or off |
| `/sm iconsize <n>` | Set the target icon size (default 48) |
| `/sm fade <0-1>` | Set how faded the icon is while Swiftmend is on cooldown (default 0.35) |
| `/sm mine` | Only count Rejuvenation and Regrowth that you cast |
| `/sm blizzard` / `/sm buzzard` | Turn markers on or off for each raid frame addon |
| `/sm size <n>` | Set the raid frame marker size (default 14) |
| `/sm anchor <point> [x y]` | Move the marker, e.g. `/sm anchor TOPRIGHT -2 -2` |
| `/sm marker` / `/sm border` | Turn the marker icon or the green border on or off |
| `/sm bordersize <1-10>` | Set the raid frame border thickness (default 2) |
| `/sm iconborder [1-10]` | Turn the target icon border on or off, or set its thickness |
| `/sm spiral` / `/sm timer` | Turn the marker's HoT duration spiral or countdown timer on or off |
| `/sm pattern add\|remove\|list <blizzard\|buzzard> <lua pattern>` | Change which frame names get markers |
| `/sm frames` | List unit frames that don't have a marker yet, to help find their names |
| `/sm legacy` | Switch to the old out-of-combat-only tracking, or back (reloads the UI) |
| `/sm scan`, `/sm status`, `/sm reset` | Rescan for frames, show the current settings, or reset to defaults |

`/sm help` lists these shortcuts in game.

### If markers don't show on Buzzard Frames

Buzzard Frames' internal frame names aren't documented. If no markers appear on them:

1. Join a group and type `/sm frames`.
2. Find the name of a Buzzard frame in the list.
3. Add its prefix, e.g. `/sm pattern add buzzard ^BuzzardRaid`.

## Files

- `Core.lua`: settings, out-of-combat aura checks, and the event and refresh loop
- `Native.lua`: combat-safe HoT sensors built on Blizzard's native aura display
- `Frames.lua`: raid frame markers for Blizzard and Buzzard frames
- `Icon.lua`: the draggable alert icon
- `Options.lua`: slash commands
