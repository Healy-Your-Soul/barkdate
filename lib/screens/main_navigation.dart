import 'package:flutter/material.dart';
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
import 'dart:async';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();

  /// Helper to switch tabs from nested screens without pushing new routes
  static void switchTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_MainNavigationState>();
    state?._onItemTapped(index);
  }
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  String? _dogAvatarUrl;
  int _unreadMessageCount = 0;
  StreamSubscription? _messageSubscription;
  
  // Feature flag: set to true to use new map_v2, false for old map
  static const bool _useMapV2 = true;
  
  // Simple direct screen selection - no caching needed
  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return const FeedScreen();
      case 1:
        return _useMapV2 ? const MapTabScreenV2() : const MapScreen();
      case 2:
        return const PlaydatesScreen();
      case 3:
        return const EventsScreen();
      case 4:
        return const MessagesScreen();
      case 5:
        return const ProfileScreen();
      default:
        return const FeedScreen();
    }
  }

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
          // Count unread messages (handle null is_read as false/unread if desired, or true/read)
          // Usually is_read is false by default. safely check booleans.
          final unreadCount = messages.where((m) => m['is_read'] == false).length;
          debugPrint('📫 Unread messages count: $unreadCount (total matched: ${messages.length})');
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

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    
    // Load avatar only when Profile tab (index 5) is first accessed
    if (index == 5 && _dogAvatarUrl == null) {
      _loadDogAvatar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getScreen(_selectedIndex), // Only create and show the active screen
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Symbols.home, weight: 300),
            activeIcon: Icon(Symbols.home, weight: 500, fill: 1),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Symbols.map, weight: 300),
            activeIcon: Icon(Symbols.map, weight: 500, fill: 1),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Symbols.calendar_today, weight: 300),
            activeIcon: Icon(Symbols.calendar_today, weight: 500, fill: 1),
            label: 'Playdates',
          ),
          BottomNavigationBarItem(
            icon: Icon(Symbols.event, weight: 300),
            activeIcon: Icon(Symbols.event, weight: 500, fill: 1),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _unreadMessageCount > 0,
              label: Text('$_unreadMessageCount'),
              child: Icon(Symbols.chat_bubble, weight: 300),
            ),
            activeIcon: Badge(
              isLabelVisible: _unreadMessageCount > 0,
              label: Text('$_unreadMessageCount'),
              child: Icon(Symbols.chat_bubble, weight: 500, fill: 1),
            ),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: _dogAvatarUrl != null && _dogAvatarUrl!.isNotEmpty
                ? CircleAvatar(
                    radius: 12,
                    backgroundImage: NetworkImage(_dogAvatarUrl!),
                    onBackgroundImageError: (_, __) {},
                  )
                : Icon(Symbols.person, weight: 300),
            activeIcon: _dogAvatarUrl != null && _dogAvatarUrl!.isNotEmpty
                ? CircleAvatar(
                    radius: 12,
                    backgroundImage: NetworkImage(_dogAvatarUrl!),
                    onBackgroundImageError: (_, __) {},
                  )
                : Icon(Symbols.person, weight: 500, fill: 1),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}