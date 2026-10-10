# Swiftmender Forever

A World of Warcraft: **Forever** addon for Restoration Druids. It shows you at a glance who can be
**Swiftmended**, meaning who currently has **Rejuvenation** or **Regrowth** on them.

## Features

- **Raid frame markers:** a Swiftmend icon and a green border on every group member who can be
  Swiftmended, with a countdown for the last 10 seconds of the HoT.
  - Blizzard raid and party frames (`CompactRaidFrame…`, `CompactPartyFrame…`, `CompactRaidGroup…`)
  - [Buzzard Frames](https://www.curseforge.com/wow/addons/buzzard-frames) (frames named `Buzzard…` / `BF_…`)
- **Draggable alert icon:** lights up and glows when someone can be Swiftmended.
  - If your friendly **target** can be Swiftmended, it shows their name and how long the HoT has left.
  - Otherwise it shows **how many** group members can be Swiftmended.
  - It also shows Swiftmend's cooldown.
- Works with the Midnight-style "secret value" addon API that WoW Forever uses. Auras are looked up by
  spell name, which keeps working in combat, so every rank of Rejuvenation and Regrowth is detected.

## Install

Copy this folder into your WoW Forever AddOns folder, so that the path is
`…/AddOns/SwiftmenderForever/SwiftmenderForever.toc`. Then `/reload`.

The TOC declares `## Interface: 16001, 120105, 120100` (WoW Forever plus Midnight). If the game lists
the addon as out of date, check the client's number with `/dump select(4, GetBuildInfo())` and add it
to the `## Interface:` line.

## Usage

The alert icon starts **unlocked**. Drag it where you want it, then right-click it or type `/sm lock`.

| Command | What it does |
|---|---|
| `/sm lock` / `/sm unlock` | Lock the alert icon, or unlock it so you can move it |
| `/sm icon` | Turn the alert icon on or off |
| `/sm iconsize <n>` | Set the alert icon size (default 48) |
| `/sm mode target\|group\|both` | Choose what the icon watches: your target, your group, or both (default) |
| `/sm mine` | Only count Rejuvenation and Regrowth that you cast |
| `/sm blizzard` / `/sm buzzard` | Turn markers on or off for each raid frame addon |
| `/sm size <n>` | Set the raid frame marker size (default 14) |
| `/sm anchor <point> [x y]` | Move the marker, e.g. `/sm anchor TOPRIGHT -2 -2` |
| `/sm marker` / `/sm border` | Turn the marker icon or the green border on or off |
| `/sm pattern add\|remove\|list <blizzard\|buzzard> <lua pattern>` | Change which frame names get markers |
| `/sm frames` | List unit frames that don't have a marker yet, to help find their names |
| `/sm scan`, `/sm status`, `/sm reset` | Rescan for frames, show the current settings, or reset to defaults |

`/swiftmender` works as well as `/sm`.

### If markers don't show on Buzzard Frames

Buzzard Frames' internal frame names aren't documented. If no markers appear on them:

1. Join a group and type `/sm frames`.
2. Find the name of a Buzzard frame in the list.
3. Add its prefix, e.g. `/sm pattern add buzzard ^BuzzardRaid`.

## Files

- `Core.lua`: aura detection, settings, and the event and refresh loop
- `Frames.lua`: raid frame markers for Blizzard and Buzzard frames
- `Icon.lua`: the draggable alert icon
- `Options.lua`: slash commands
