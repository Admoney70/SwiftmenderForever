# Swiftmender Forever

## 1.6.1

- Fixed "script ran too long" errors from the raid-frame scan. The scan (and `/sm frames`) now looks
  through the game's frames a batch at a time instead of all at once.

## 1.6.0

- The overheal check (raid-frame filter and target icon glow) now uses the game's **missing health**
  (`UnitHealthMissing`, what Blizzard raid frames show as "Health Missing"). It no longer needs each
  player's max health from out of combat, so it works for everyone, in combat and in instances. The old
  health-percent method is kept as a fallback.
- New `/sm health [unit]` prints the health values the addon can see for a unit (default: target), the
  heal amount it uses and whether Swiftmend would fit right now.

## 1.5.1

- Fixed a Lua error ("calling 'GetName' on bad self ... forbidden object") when the raid-frame scan
  reached a protected frame. Frames the game won't let addons read are now skipped.

## 1.5.0

- With no target or an enemy target, the target icon now tracks you: your HoTs, your name, and the
  overheal glow for your own health. On by default; toggle it in the settings window or with `/sm self`.
  Works in combat.

## 1.4.0

- Glow styles for the target icon's overheal glow: **Glow** (the static ring, as before), **Proc** (the
  ability activation glow) or **Pixel** (lines running around the border). Choose one in the settings
  window or with `/sm glow proc|pixel|glow`. They follow the glow colour and work in combat.

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
