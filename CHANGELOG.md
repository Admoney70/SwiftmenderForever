# Swiftmender Forever

## 1.9.3

- Fixed the "Anchoring disallowed ... forbidden aspects" errors from the raid-marker cooldown timer. The
  game doesn't let addon frames anchor to aura buttons, so the countdown now lives in its own aura button
  (shown, like the marker, only on players with your HoT) instead of an anchored layer.
- With **Timer**, a marker on Swiftmend cooldown shows only the seconds left (no icon). If the game
  refuses to update the countdown in combat, that marker fades instead of showing a frozen number;
  `/sm debug` reports it.

## 1.9.2

- New `/sm debug`: shows whether the raid-marker cooldown timer and the overheal check have what they
  need on this client (Swiftmend cooldown, aura buttons, duration bar, missing health), to help get the
  "Timer" style working.

## 1.9.1

- Reworked 1.9.0's cooldown timer into one raid-marker setting, **On Swiftmend cooldown**:
  - **Fade:** the marker fades (as before; the default).
  - **Timer:** the marker is replaced by the seconds left, with no icon.
  - **None:** the marker stays as it is.
  This replaces the "Fade markers while Swiftmend is on cooldown" checkbox and 1.9.0's "Cooldown
  timer" setting (the "Over icon" mode is gone); your current choice carries over. Set it in `/sm` or
  with `/sm oncd fade|timer|none`.

## 1.9.0

- New "Cooldown timer" option for the raid-frame markers while Swiftmend is on cooldown:
  - **Over icon:** the icon with a dark cooldown sweep and the seconds left on it.
  - **Timer only:** just the seconds left, in place of the marker.
  - **Off** (default): as before.
  It only shows on players with your HoT, and works in combat. Set it in `/sm` (Raid frames) or with
  `/sm cdtimer off|over|only`. With a timer on, the fade-on-cooldown option no longer dims the timer.
- The settings window shrinks to fit short screens.

## 1.8.0

- The name under the target icon is now hidden. Turn it back on with "Show name under the icon" in `/sm`,
  or `/sm name`.

## 1.7.0

- Only your own Rejuvenation and Regrowth count now, on the raid frames and the target icon. This is the
  new default and existing settings are switched over once. To count other druids' HoTs again, untick
  "Only count my own Rejuvenation / Regrowth" in `/sm` or type `/sm mine`.

## 1.6.2

- Shapeshifting (feral forms) no longer rescans the raid frames. The form change fired the game's
  "spells changed" event, which started a full scan each time; it now just refreshes.

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
