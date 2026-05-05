import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:barkdate/services/feature_flags.dart';

class ScaffoldWithNavBar extends ConsumerWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const greenColor = Color(0xFF4CAF50);
    const unselectedColor = Color(0xFF9E9E9E);

    final useSlimBottomNav = ref.watch(featureFlagsProvider).useSlimBottomNav;

    // Define all possible items with their original index.
    final allItems = [
      _NavItem(index: 0, icon: Icons.home, label: 'Feed'),
      _NavItem(index: 1, icon: Icons.map, label: 'Map'),
      _NavItem(index: 2, icon: Icons.calendar_today, label: 'Playdates'),
      _NavItem(index: 3, icon: Icons.event, label: 'Events'),
      _NavItem(index: 4, icon: Icons.chat_bubble, label: 'Messages'),
      _NavItem(index: 5, icon: Icons.pets, label: 'Profile'),
    ];

    final List<_NavItem> navItems;
    if (useSlimBottomNav) {
      const slimLabels = ['Feed', 'Map', 'Messages', 'Profile'];
      navItems =
          allItems.where((item) => slimLabels.contains(item.label)).toList();
    } else {
      navItems = allItems;
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 56,
            child: Row(
              children: navItems.map((item) {
                final isSelected = navigationShell.currentIndex == item.index;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _goBranch(item.index),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top indicator line (Facebook style)
                        Container(
                          height: 3,
                          width: 40,
                          decoration: BoxDecoration(
                            color: isSelected ? greenColor : Colors.transparent,
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Icon
                        Icon(
                          item.icon,
                          weight: isSelected ? 300 : 200,
                          grade: 0,
                          opticalSize: 24,
                          size: 24,
                          color: isSelected ? greenColor : unselectedColor,
                        ),
                        const SizedBox(height: 2),
                        // Label
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? greenColor : unselectedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final int index;
  final IconData icon;
  final String label;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.label,
  });
}
