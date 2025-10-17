# BarkDate Design System Guide

## 🎨 Overview

This design system is inspired by Airbnb's clean, modern aesthetic. It provides a complete set of reusable components and constants that ensure visual consistency across the entire BarkDate app.

## 📁 File Structure

```
lib/design_system/
├── app_colors.dart      - Color palette (light & dark)
├── app_spacing.dart     - 8px grid spacing system
├── app_styles.dart      - Border radius, shadows, decorations
├── app_typography.dart  - Text styles and font system
└── app_theme.dart       - Complete theme configuration

lib/widgets/
├── app_card.dart            - Card components
├── app_button.dart          - Button components
├── app_bottom_sheet.dart    - Modal bottom sheets
├── app_section_header.dart  - Section headers
└── app_empty_state.dart     - Empty and loading states
```

## 🎯 Core Principles

### 1. **8px Grid System**
All spacing uses multiples of 8px for visual rhythm:
- 4px (xs), 8px (sm), 12px (md), 16px (lg), 20px (xl), 24px (xxl), 32px (xxxl)

### 2. **Consistent Border Radius**
- Small (8px): Buttons, chips, inputs
- Medium (12px): Cards, images
- Large (16px): Large cards, containers
- XL (20px): Bottom sheets, modals

### 3. **Subtle Shadows**
- Flat design with minimal elevation
- Shadows only for cards and elevated elements
- No heavy drop shadows

### 4. **Clean Typography**
- Inter font family throughout
- Clear hierarchy (Display → Heading → Body → Label → Caption)
- Consistent letter-spacing and line-height

## 🛠️ How to Use

### Colors

```dart
import 'package:barkdate/design_system/app_colors.dart';

// Use semantic colors
Container(
  color: AppColors.primaryGreen,
  // or
  color: AppColors.success,
  // or
  color: AppColors.lightBackground, // for light mode
  color: AppColors.darkBackground,  // for dark mode
)
```

### Spacing

```dart
import 'package:barkdate/design_system/app_spacing.dart';

// Use predefined spacing
Padding(
  padding: AppSpacing.paddingLG, // 16px all sides
  child: Column(
    children: [
      Text('Title'),
      AppSpacing.verticalSpaceMD, // 12px vertical gap
      Text('Subtitle'),
    ],
  ),
)
```

### Cards

```dart
import 'package:barkdate/widgets/app_card.dart';

// Simple card
AppCard(
  child: Text('Content'),
  onTap: () {}, // optional
)

// Image card (like Airbnb listings)
AppImageCard(
  imageUrl: 'https://...',
  height: 200,
  onTap: () {},
  badges: [
    Container(...), // Top-right badges
  ],
)

// Info card (for dashboard)
AppInfoCard(
  icon: Icons.calendar_today,
  title: 'My Playdates',
  subtitle: '3 upcoming',
  color: Colors.blue,
  onTap: () {},
)
```

### Buttons

```dart
import 'package:barkdate/widgets/app_button.dart';

// Primary button
AppButton(
  text: 'Join Event',
  onPressed: () {},
  icon: Icons.check, // optional
  isFullWidth: true, // optional
)

// Secondary button
AppButton(
  text: 'Cancel',
  onPressed: () {},
  type: AppButtonType.secondary,
)

// Outline button
AppButton(
  text: 'Learn More',
  onPressed: () {},
  type: AppButtonType.outline,
)

// Text button
AppButton(
  text: 'Skip',
  onPressed: () {},
  type: AppButtonType.text,
)

// With loading state
AppButton(
  text: 'Saving...',
  onPressed: () {},
  isLoading: true,
)
```

### Bottom Sheets

```dart
import 'package:barkdate/widgets/app_bottom_sheet.dart';

// Show bottom sheet (like Airbnb modals)
AppBottomSheet.show(
  context: context,
  title: 'Filter Options',
  child: AppBottomSheetScrollable(
    children: [
      Text('Content here'),
      // ... more widgets
    ],
  ),
);
```

### Section Headers

```dart
import 'package:barkdate/widgets/app_section_header.dart';

// Section header (like Airbnb's "Popular homes in Sydney")
AppSectionHeader(
  title: 'Nearby Dogs',
  subtitle: '12 dogs within 5km',
  action: TextButton(
    onPressed: () {},
    child: Text('See all'),
  ),
)
```

### Empty States

```dart
import 'package:barkdate/widgets/app_empty_state.dart';

// Empty state (like Airbnb's "No trips yet")
AppEmptyState(
  icon: Icons.event_busy,
  title: 'No events yet',
  message: 'Browse events and join some fun activities!',
  actionText: 'Browse Events',
  onAction: () {},
)

// Loading state with skeletons
AppLoadingState(itemCount: 3)
```

## 📱 Applying to Screens

### Before (Inconsistent):
```dart
Container(
  padding: EdgeInsets.all(16), // ❌ Magic number
  decoration: BoxDecoration(
    color: Colors.white, // ❌ Hard-coded
    borderRadius: BorderRadius.circular(10), // ❌ Random radius
  ),
  child: Text(
    'Title',
    style: TextStyle(fontSize: 18), // ❌ Inconsistent
  ),
)
```

### After (Consistent):
```dart
AppCard(
  child: Text(
    'Title',
    style: AppTypography.h4(), // ✅ Consistent
  ),
)
```

## 🔄 Migration Strategy

### Step 1: Update main.dart
Replace theme with new design system:
```dart
import 'package:barkdate/design_system/app_theme.dart';

MaterialApp(
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  // ...
)
```

### Step 2: Update Each Screen
Replace custom styling with design system components:

1. **Replace padding/margins** → Use `AppSpacing` constants
2. **Replace Container cards** → Use `AppCard` or `AppImageCard`
3. **Replace buttons** → Use `AppButton`
4. **Replace bottom sheets** → Use `AppBottomSheet`
5. **Replace section titles** → Use `AppSectionHeader`
6. **Replace empty states** → Use `AppEmptyState`

### Step 3: Test Visual Consistency
- Check all screens in light mode
- Check all screens in dark mode
- Verify spacing is consistent
- Verify colors follow theme

## 🎨 Airbnb-Inspired Features

### Clean Card Design
- Minimal shadows
- Rounded corners (12px)
- White background (light mode)
- High-quality images with proper aspect ratios

### Flat, Modern Buttons
- No heavy shadows
- Clear visual hierarchy (primary, secondary, outline, text)
- Consistent sizing and padding
- Smooth hover/press states

### Consistent Spacing
- 8px grid system (like Airbnb)
- Generous whitespace
- Breathing room between elements
- Clean, uncluttered layouts

### Typography Hierarchy
- Bold headings for emphasis
- Regular weight for body text
- Consistent letter-spacing
- Proper line-height for readability

### Bottom Sheets (Modals)
- Rounded top corners (20px)
- Handle bar for drag indication
- Smooth animations
- Clean, focused content

## 🚀 Quick Reference

### Common Patterns

#### Dashboard Card
```dart
AppInfoCard(
  icon: Icons.calendar_today,
  title: 'My Playdates',
  subtitle: '3 upcoming',
  color: Colors.blue,
  onTap: () => Navigator.push(...),
)
```

#### List Item Card
```dart
AppCard(
  onTap: () {},
  child: Row(
    children: [
      CircleAvatar(...),
      AppSpacing.horizontalSpaceMD,
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title', style: AppTypography.h4()),
            AppSpacing.verticalSpaceXS,
            Text('Subtitle', style: AppTypography.bodySmall()),
          ],
        ),
      ),
    ],
  ),
)
```

#### Image Gallery Card
```dart
AppImageCard(
  imageUrl: dog.photos.first,
  height: 300,
  onTap: () {},
  badges: [
    Container(
      padding: EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppStyles.borderRadiusSM,
      ),
      child: Text('NEW'),
    ),
  ],
)
```

## 💡 Tips

1. **Always use design system constants** - Never hard-code values
2. **Use AppCard for consistency** - Don't create custom containers
3. **Follow the spacing grid** - Use AppSpacing helpers
4. **Respect the color palette** - Use AppColors, not random colors
5. **Use semantic colors** - success, error, warning, info
6. **Test in both modes** - Light and dark theme support

## 🎯 Benefits

- ✅ **Consistency**: Same look and feel everywhere
- ✅ **Maintainability**: Change once, update everywhere
- ✅ **Speed**: Pre-built components = faster development
- ✅ **Quality**: Professional, polished appearance
- ✅ **Scalability**: Easy to add new screens
- ✅ **Accessibility**: Proper contrast and sizing built-in
