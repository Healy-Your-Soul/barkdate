# BarkDate Theme Colors Reference

> **Status**: Light mode active. Dark mode colors preserved for future implementation.

## Current Theme: Light Mode

### Primary Colors
| Color Name | Hex Code | Usage |
|------------|----------|-------|
| Primary (Airbnb Red) | `#FF385C` | Buttons, links, accents |
| Secondary (Teal) | `#008489` | Secondary actions, variety |

### Background & Surface
| Color Name | Hex Code | Usage |
|------------|----------|-------|
| Background | `#FFFFFF` | Screen backgrounds |
| Surface | `#FFFFFF` | Cards, dialogs |
| Surface Variant | `#F5F5F5` | Subtle containers |

### Text Colors
| Color Name | Hex Code | Contrast Ratio | Usage |
|------------|----------|----------------|-------|
| Primary Text | `#222222` | 15.1:1 ✅ | Headings, body text |
| Secondary Text | `#717171` | 5.0:1 ✅ | Subtitles, captions |
| Tertiary Text | `#9E9E9E` | 3.5:1 ⚠️ | Hints (large text only) |

### Semantic Colors
| Color Name | Hex Code | Usage |
|------------|----------|-------|
| Success | `#4CAF50` | Success states, confirmations |
| Warning | `#FFA726` | Warnings, attention |
| Error | `#EF5350` | Errors, destructive actions |
| Info | `#42A5F5` | Informational |

### Borders & Dividers
| Color Name | Hex Code | Usage |
|------------|----------|-------|
| Border | `#E0E0E0` | Card borders, outlines |
| Divider | `#EEEEEE` | Section dividers |

---

## Reserved: Dark Mode Colors (Coming Soon)

### Background & Surface
| Color Name | Hex Code | Usage |
|------------|----------|-------|
| Background | `#121212` | Screen backgrounds |
| Surface | `#1E1E1E` | Cards, dialogs |
| Surface Variant | `#2C2C2C` | Subtle containers |

### Text Colors
| Color Name | Hex Code | Contrast Ratio | Usage |
|------------|----------|----------------|-------|
| Primary Text | `#E0E0E0` | 13.5:1 ✅ | Headings, body text |
| Secondary Text | `#B0B0B0` | 8.6:1 ✅ | Subtitles, captions |
| Tertiary Text | `#808080` | 5.3:1 ✅ | Hints |

### Borders & Dividers
| Color Name | Hex Code | Usage |
|------------|----------|-------|
| Border | `#3A3A3A` | Card borders |
| Divider | `#2A2A2A` | Section dividers |
| Outline | `#444444` | Outlines, focus rings |

---

## Usage Guidelines

### ✅ DO
```dart
// Use theme colors
Theme.of(context).colorScheme.surface
Theme.of(context).colorScheme.onSurface
Theme.of(context).colorScheme.primary
Theme.of(context).scaffoldBackgroundColor
```

### ❌ DON'T
```dart
// Avoid hardcoded colors
Colors.white  // Use colorScheme.surface instead
Colors.black  // Use colorScheme.onSurface instead
Colors.grey   // Use colorScheme.outline instead
Color(0xFFXXXXXX)  // Define in AppColors/AppTheme instead
```

### Contrast Requirements (WCAG AA)
- Normal text: **4.5:1** minimum
- Large text (18px+ or 14px+ bold): **3:1** minimum
- UI components: **3:1** minimum

---

## Implementation Notes

### When Adding Dark Mode:
1. Change `app.dart`: `themeMode: ThemeMode.system`
2. Update settings screen to re-enable theme toggle
3. Audit all files for remaining hardcoded colors
4. Test each screen in both modes

### Files With Known Hardcoded Colors:
These files need attention when enabling dark mode:
- `map_bottom_sheets.dart`
- `profile_screen.dart`
- `feed_screen.dart`
- `admin_screen.dart`
- `onboarding/*.dart`
- `widgets/app_card.dart`
- `widgets/photo_gallery.dart`
