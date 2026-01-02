import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/features/playdates/presentation/providers/playdate_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:barkdate/features/messages/presentation/screens/chat_screen.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:barkdate/core/presentation/widgets/cute_empty_state.dart';
import 'package:barkdate/design_system/app_typography.dart';
import 'package:barkdate/core/presentation/widgets/filter_tabs.dart';
import 'package:barkdate/supabase/supabase_config.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['All', 'Playdates', 'General'];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header OR Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: _isSearching
                  ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Search messages...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 20),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (value) => setState(() => _searchQuery = value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _isSearching = false;
                              _searchQuery = '';
                            });
                          },
                          child: const Text('Cancel'),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Messages',
                          style: AppTypography.h1().copyWith(fontSize: 32),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => setState(() => _isSearching = true),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 24),

            // 2. Filter Tabs - using shared component for consistency
            FilterTabs(
              tabs: _filters,
              selectedTab: _filters[_selectedFilterIndex],
              onTabSelected: (tab) {
                setState(() => _selectedFilterIndex = _filters.indexOf(tab));
              },
            ),

            const SizedBox(height: 24),

            // 3. Messages List
            Expanded(
              child: conversationsAsync.when(
                data: (conversations) {
                  if (conversations.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: CuteEmptyState(
                          icon: Icons.chat_bubble_outline,
                          title: 'No messages yet',
                          message: 'Start matching with other dogs to get the conversation started!',
                          actionLabel: 'Find Friends',
                          onAction: () {
                            context.go('/home');
                          },
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: conversations.length,
                    separatorBuilder: (context, index) => const Divider(height: 32, thickness: 0.5),
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      return _buildConversationTile(context, conversation);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(BuildContext context, Map<String, dynamic> conversation) {
    // Determine other user
    final currentUserId = SupabaseConfig.auth.currentUser?.id;
    final sender = conversation['sender'] as Map<String, dynamic>?;
    final receiver = conversation['receiver'] as Map<String, dynamic>?;
    
    final senderId = conversation['sender_id'];
    
    // If I am the sender, show receiver. If I am receiver, show sender.
    final otherUser = (senderId == currentUserId) ? receiver : sender;
    
    final name = otherUser?['name'] ?? 'Unknown User';
    final avatarUrl = otherUser?['avatar_url'];
    final content = conversation['content'] ?? '';
    final createdAt = DateTime.parse(conversation['created_at']);
    final isRead = conversation['is_read'] ?? false; // Note: logic for read status needs refinement based on user

    return InkWell(
      onTap: () {
         final matchId = conversation['match_id'];
         final recipientId = otherUser?['id']; // We need ID in the user object
         
         // Fallback if ID is not in the embedded object (it usually isn't by default unless selected)
         // But we can infer it from sender_id/receiver_id
         final targetId = (senderId == currentUserId) ? conversation['receiver_id'] : conversation['sender_id'];

         if (matchId != null && targetId != null) {
         if (matchId != null && targetId != null) {
           context.push('/chat', extra: {
             'matchId': matchId,
             'recipientId': targetId,
             'recipientName': name,
             'recipientAvatarUrl': avatarUrl,
           });
         }
         }
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            backgroundColor: Colors.grey[200],
            child: avatarUrl == null ? const Icon(Icons.person, color: Colors.grey) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      timeago.format(createdAt, locale: 'en_short'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600], // Always grey for preview in Airbnb style
                    fontWeight: FontWeight.normal,
                  ),
                ),
                // Status line (optional)
                // const SizedBox(height: 4),
                // Text('Response time: 1 hr', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
