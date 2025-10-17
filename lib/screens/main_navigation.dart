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

  final List<Widget> _screens = [
    const FeedScreen(),
    const MapScreen(),
    const EventsScreen(),
    const PlaydatesScreen(),
    const MessagesScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadDogAvatar();
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
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