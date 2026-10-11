# Swiftmender Forever

## 1.1.0

- New option: fade the raid-frame markers and borders while Swiftmend is on cooldown, with an adjustable
  opacity (settings window or `/sm markerfade [0-1]`). On by default at 0.35; works in combat.

## 1.0.1

- The target icon keeps its border while greyed out (no target, no HoT, or unusable).

## 1.0.0

First release for WoW Forever.

- Swiftmend markers on Blizzard raid/party frames and Buzzard Frames whenever a group member has
  Rejuvenation or Regrowth, with optional HoT spiral, countdown, marker border and frame border.
- Works in combat: HoTs are detected through Blizzard's native aura display, so the Midnight-style
  secret aura restrictions don't hide the markers.
- Draggable target icon: greyed out when your target has no HoT, lit when it can be Swiftmended,
  with HoT time left (optional), Swiftmend cooldown spiral, red tint out of range, blue tint out of
  mana and desaturated when unusable.
- Live placement preview on raid frames while the settings window is open.
- Settings window via `/sm`, plus shortcut commands (`/sm help`).
