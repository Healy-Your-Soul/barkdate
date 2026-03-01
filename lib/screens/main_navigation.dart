import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:barkdate/screens/feed_screen.dart';
import 'package:barkdate/screens/map_screen.dart';
import 'package:barkdate/screens/map_v2/map_tab_screen.dart'; // New map
import 'package:barkdate/screens/events_screen.dart';
import 'package:barkdate/screens/playdates_screen.dart';
import 'package:barkdate/screens/messages_screen.dart';
import 'package:barkdate/screens/profile_screen.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/services/feature_flags.dart';
import 'dart:async';

class NavigationItem {
  final Widget icon;
  final Widget activeIcon;
  final String label;
  final Widget screen;

  const NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.screen,
  });
}

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();

  /// Helper to switch tabs from nested screens without pushing new routes
  /// [index] corresponds to the logical index (Full mode indices):
  /// 0: Feed, 1: Map, 2: Playdates, 3: Events, 4: Messages, 5: Profile
  static void switchTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_MainNavigationState>();
    state?._switchToLogicalIndex(index);
  }
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _selectedIndex = 0; // This is the VISIBLE index
  String? _dogAvatarUrl;
  int _unreadMessageCount = 0;
  StreamSubscription? _messageSubscription;

  // Feature flag: set to true to use new map_v2, false for old map
  static const bool _useMapV2 = true;

  @override
  void initState() {
    super.initState();
    _subscribeToUnreadMessages();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToUnreadMessages() {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) return;

    // Subscribe to unread message count
    _messageSubscription = SupabaseConfig.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', user.id)
        .listen((messages) {
          if (!mounted) return;
          // Count unread messages
          final unreadCount =
              messages.where((m) => m['is_read'] == false).length;
          debugPrint(
              '📫 Unread messages count: $unreadCount (total matched: ${messages.length})');
          setState(() => _unreadMessageCount = unreadCount);
        }, onError: (error) {
          debugPrint('❌ Error subscribing to messages: $error');
        });
  }

  Future<void> _loadDogAvatar() async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) return;

      final dogs = await BarkDateUserService.getUserDogs(user.id);
      if (dogs.isNotEmpty && mounted) {
        setState(() {
          _dogAvatarUrl = dogs.first['main_photo_url']?.toString();
        });
      }
    } catch (e) {
      debugPrint('Error loading dog avatar: $e');
    }
  }

  // Handle tap from BottomNavigationBar (Visible Index)
  void _onItemTapped(int visibleIndex) {
    setState(() => _selectedIndex = visibleIndex);
  }

  // Handle programmatic switch request (Logical Index)
  void _switchToLogicalIndex(int logicalIndex) {
    // Current behavior: if target is hidden, do nothing.
    final useSlim = ref.read(featureFlagsProvider).useSlimBottomNav;

    debugPrint('useSlim: $useSlim');

    int? visibleIndex;

    if (useSlim) {
      // Map Logical to Visible in Slim Mode
      // Logical: 0:Feed, 1:Map, 2:Playdates, 3:Events, 4:Messages, 5:Profile
      // Slim:    0:Feed, 1:Map, 2:Profile
      switch (logicalIndex) {
        case 0:
          visibleIndex = 0;
          break;
        case 1:
          visibleIndex = 1;
          break;
        case 5:
          visibleIndex = 2;
          break; // Profile
        default:
          debugPrint('Tab $logicalIndex is hidden in Slim mode');
          return;
      }
    } else {
      // Full mode: 1-to-1 mapping
      visibleIndex = logicalIndex;
    }

    setState(() => _selectedIndex = visibleIndex!);
  }

  List<NavigationItem> _buildNavigationItems() {
    return [
      NavigationItem(
        icon: const Icon(Symbols.home, weight: 300),
        activeIcon: const Icon(Symbols.home, weight: 500, fill: 1),
        label: 'Feed',
        screen: const FeedScreen(),
      ),
      NavigationItem(
        icon: const Icon(Symbols.map, weight: 300),
        activeIcon: const Icon(Symbols.map, weight: 500, fill: 1),
        label: 'Map',
        screen: _useMapV2 ? const MapTabScreenV2() : const MapScreen(),
      ),
      NavigationItem(
        icon: const Icon(Symbols.calendar_today, weight: 300),
        activeIcon: const Icon(Symbols.calendar_today, weight: 500, fill: 1),
        label: 'Playdates',
        screen: const PlaydatesScreen(),
      ),
      NavigationItem(
        icon: const Icon(Symbols.event, weight: 300),
        activeIcon: const Icon(Symbols.event, weight: 500, fill: 1),
        label: 'Events',
        screen: const EventsScreen(),
      ),
      NavigationItem(
        icon: Badge(
          isLabelVisible: _unreadMessageCount > 0,
          label: Text('$_unreadMessageCount'),
          child: const Icon(Symbols.chat_bubble, weight: 300),
        ),
        activeIcon: Badge(
          isLabelVisible: _unreadMessageCount > 0,
          label: Text('$_unreadMessageCount'),
          child: const Icon(Symbols.chat_bubble, weight: 500, fill: 1),
        ),
        label: 'Messages',
        screen: const MessagesScreen(),
      ),
      NavigationItem(
        icon: _dogAvatarUrl != null && _dogAvatarUrl!.isNotEmpty
            ? CircleAvatar(
                radius: 12,
                backgroundImage: NetworkImage(_dogAvatarUrl!),
                onBackgroundImageError: (_, __) {},
              )
            : const Icon(Symbols.person, weight: 300),
        activeIcon: _dogAvatarUrl != null && _dogAvatarUrl!.isNotEmpty
            ? CircleAvatar(
                radius: 12,
                backgroundImage: NetworkImage(_dogAvatarUrl!),
                onBackgroundImageError: (_, __) {},
              )
            : const Icon(Symbols.person, weight: 500, fill: 1),
        label: 'Profile',
        screen: const ProfileScreen(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final featureFlags = ref.watch(featureFlagsProvider);
    final useSlimBottomNav = featureFlags.useSlimBottomNav;

    final allItems = _buildNavigationItems();

    // Filter items based on flag
    final List<NavigationItem> items;
    if (useSlimBottomNav) {
      const slimLabels = ['Feed', 'Map', 'Profile'];
      items =
          allItems.where((item) => slimLabels.contains(item.label)).toList();
    } else {
      items = allItems;
    }

    // Ensure selected index is valid
    if (_selectedIndex >= items.length) {
      _selectedIndex = 0; // Reset to first item if out of bounds
    }

    // Check if we need to load avatar (if current item is Profile)
    if (items[_selectedIndex].screen is ProfileScreen &&
        _dogAvatarUrl == null) {
      // Defer execution to avoid set state during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDogAvatar();
      });
    }

    return Scaffold(
      body: items[_selectedIndex].screen,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor:
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        items: items
            .map((item) => BottomNavigationBarItem(
                  icon: item.icon,
                  activeIcon: item.activeIcon,
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }
}
