import 'package:flutter/material.dart';
import 'package:barkdate/screens/feed_screen.dart';
import 'package:barkdate/screens/map_screen.dart';
import 'package:barkdate/screens/events_screen.dart';
import 'package:barkdate/screens/playdates_screen.dart';
import 'package:barkdate/screens/messages_screen.dart';
import 'package:barkdate/screens/profile_screen.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';

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
  
  // Simple direct screen selection - no caching needed
  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return const FeedScreen();
      case 1:
        return const MapScreen();
      case 2:
        return const EventsScreen();
      case 3:
        return const PlaydatesScreen();
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
    // Don't load avatar eagerly - only load when Profile tab is accessed
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
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Feed',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Map',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.event_outlined),
            activeIcon: Icon(Icons.event),
            label: 'Events',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Playdates',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: _dogAvatarUrl != null && _dogAvatarUrl!.isNotEmpty
                ? CircleAvatar(
                    radius: 12,
                    backgroundImage: NetworkImage(_dogAvatarUrl!),
                    onBackgroundImageError: (_, __) {},
                  )
                : const Icon(Icons.pets),
            activeIcon: _dogAvatarUrl != null && _dogAvatarUrl!.isNotEmpty
                ? CircleAvatar(
                    radius: 12,
                    backgroundImage: NetworkImage(_dogAvatarUrl!),
                    onBackgroundImageError: (_, __) {},
                  )
                : const Icon(Icons.pets),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}