# Swiftmender Forever

## 1.3.0

- The target icon now glows while Swiftmend won't overheal your target (they're missing at least the
  heal amount). On by default, with a selectable colour; toggle it in the settings window or with
  `/sm glow`. It uses the raid filter's heal estimate, fixed-amount and incoming-heal settings, and works
  in combat.

## 1.2.0

- New option: only show raid-frame markers when Swiftmend won't overheal (the player is missing at
  least the heal amount). Off by default; turn it on in the settings window or with `/sm overheal`.
  - The heal is estimated from your Rejuvenation tooltip (adjustable %), or set a fixed amount.
  - Optionally counts incoming heals.
  - Works in combat: Blizzard evaluates the hidden health against a per-player threshold built from
    max health cached out of combat.

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
