import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

class ScaffoldWithNavBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    const greenColor = Color(0xFF4CAF50);
    const unselectedColor = Color(0xFF9E9E9E);

    final navItems = [
      _NavItem(icon: Symbols.home, label: 'Feed'),
      _NavItem(icon: Symbols.map, label: 'Map'),
      _NavItem(icon: Symbols.calendar_today, label: 'Playdates'),
      _NavItem(icon: Symbols.event, label: 'Events'),
      _NavItem(icon: Symbols.chat_bubble, label: 'Messages'),
      _NavItem(icon: Symbols.person, label: 'Profile'),
    ];

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
              children: List.generate(navItems.length, (index) {
                final isSelected = navigationShell.currentIndex == index;
                final item = navItems[index];

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _goBranch(index),
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
                          weight: isSelected ? 500 : 300,
                          fill: isSelected ? 1 : 0,
                          size: 22,
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
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}
