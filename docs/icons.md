# Icon Usage Guide

## Two Icon Systems

This project uses two icon systems side by side:

| | `Symbols` (Material Symbols) | `Icons` (Flutter built-in) |
|---|---|---|
| **Package** | `material_symbols_icons` | Flutter SDK (no package needed) |
| **Import** | `package:material_symbols_icons/symbols.dart` | `package:flutter/material.dart` |
| **Style** | Modern, Material Design 3 | Older, Material Design 2 |
| **Customisation** | `weight`, `grade`, `opticalSize` | None |
| **Reliability** | ⚠️ Depends on font bundling | ✅ Always available |

---

## Rule: Prefer `Symbols`, fall back to `Icons`

Use `Symbols` by default because it supports richer visual customisation (e.g. thinner strokes when unselected, thicker when selected).

Only fall back to `Icons` when a `Symbols` glyph is confirmed to render blank on a real device.

```dart
// ✅ Preferred — supports weight/grade/opticalSize
icon: Symbols.home

// ✅ Acceptable fallback — when the Symbol glyph is missing from the font subset
icon: Icons.home
```

---

## Why a Symbol can go blank

`material_symbols_icons` loads icons through a **variable font file**. Not every glyph in the Symbols catalogue is included in the font subset that ships with the package by default. If a glyph is absent, it renders silently as a blank square — no error, no warning.

Common culprits:
- Niche or newly-added glyphs (e.g. `Symbols.sound_detection_dog_barking`)
- Any symbol not in the [core subset listed in the package README](https://pub.dev/packages/material_symbols_icons)

Common glyphs (home, map, chat, calendar, etc.) are generally safe.

---

## How to tell if a Symbol is safe

1. Run on a **physical iOS device** (not the Simulator — the Simulator is less strict about font loading).
2. If the icon renders correctly → keep `Symbols`.
3. If it renders blank → look up the equivalent in `Icons` and use that instead, leaving a comment explaining why.

```dart
// Symbols.person renders blank on iOS (glyph not in variable-font subset).
// Using Icons.person as a reliable fallback.
_NavItem(index: 5, icon: Icons.person, label: 'Profile'),
```

---

## The `--no-tree-shake-icons` fix

Flutter's tree-shaker can strip icon glyphs it thinks are unused. Running with this flag disables that behaviour and forces all glyphs to be included:

```bash
flutter run --no-tree-shake-icons
flutter build ios --no-tree-shake-icons
```

This is a valid alternative to using `Icons` as a fallback, but it increases app size. The icon fallback approach is lighter and more targeted.

---

## Current nav bar icons

| Tab | Icon used | Notes |
|---|---|---|
| Feed | `Symbols.home` | Safe core glyph |
| Map | `Symbols.map` | Safe core glyph |
| Playdates | `Symbols.calendar_today` | Safe core glyph |
| Events | `Symbols.event` | Safe core glyph |
| Messages | `Symbols.chat_bubble` | Safe core glyph |
| Profile | `Symbols.pets` | Paw print — verified or use `Icons.pets` as fallback |
