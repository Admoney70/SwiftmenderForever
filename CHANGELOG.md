# Swiftmender Forever

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
