import 'package:flutter/material.dart';
import 'package:barkdate/core/router/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/features/playdates/presentation/providers/playdate_provider.dart';
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

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
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
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onChanged: (value) =>
                                  setState(() => _searchQuery = value),
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
                            onPressed: () =>
                                setState(() => _isSearching = true),
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
                    // Apply filters
                    var filteredConversations = conversations.where((c) {
                      // Apply category filter
                      if (_selectedFilterIndex == 1) {
                        // Playdates - filter by is_playdate or has playdate_id
                        final isPlaydate = c['is_playdate'] == true ||
                            c['playdate_id'] != null;
                        if (!isPlaydate) return false;
                      } else if (_selectedFilterIndex == 2) {
                        // General - exclude playdates
                        final isPlaydate = c['is_playdate'] == true ||
                            c['playdate_id'] != null;
                        if (isPlaydate) return false;
                      }

                      // Apply search filter
                      if (_searchQuery.isNotEmpty) {
                        final content =
                            (c['content'] as String? ?? '').toLowerCase();
                        final sender = c['sender'] as Map<String, dynamic>?;
                        final receiver = c['receiver'] as Map<String, dynamic>?;
                        final senderName =
                            (sender?['name'] as String? ?? '').toLowerCase();
                        final receiverName =
                            (receiver?['name'] as String? ?? '').toLowerCase();
                        final query = _searchQuery.toLowerCase();

                        if (!content.contains(query) &&
                            !senderName.contains(query) &&
                            !receiverName.contains(query)) {
                          return false;
                        }
                      }

                      return true;
                    }).toList();

                    // Sprint 7b: sort unread conversations to the top,
                    // then by recency within each group.
                    filteredConversations.sort((a, b) {
                      final aUnread = a['has_unread'] == true;
                      final bUnread = b['has_unread'] == true;
                      if (aUnread && !bUnread) return -1;
                      if (!aUnread && bUnread) return 1;
                      final aTime = a['created_at'] as String? ?? '';
                      final bTime = b['created_at'] as String? ?? '';
                      return bTime.compareTo(aTime);
                    });

                    if (filteredConversations.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: CuteEmptyState(
                            icon: Icons.chat_bubble_outline,
                            title: _selectedFilterIndex == 0
                                ? 'No messages yet'
                                : _selectedFilterIndex == 1
                                    ? 'No playdate messages'
                                    : 'No general messages',
                            message:
                                'Start matching with other dogs to get the conversation started!',
                            actionLabel: 'Find Friends',
                            onAction: () {
                              const HomeRoute().go(context);
                            },
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: filteredConversations.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 32, thickness: 0.5),
                      itemBuilder: (context, index) {
                        final conversation = filteredConversations[index];
                        return _buildConversationTile(context, conversation);
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(child: Text('Error: $error')),
                ),
              ),
            ],
          ),
        ),
      ), // Close GestureDetector
    );
  }

  Widget _buildConversationTile(
      BuildContext context, Map<String, dynamic> conversation) {
    // Determine other user
    final currentUserId = SupabaseConfig.auth.currentUser?.id;
    final sender = conversation['sender'] as Map<String, dynamic>?;
    final receiver = conversation['receiver'] as Map<String, dynamic>?;

    final senderId = conversation['sender_id'];
    final hasUnread = conversation['has_unread'] == true;
    final unreadCount = conversation['unread_count'] as int? ?? 0;

    // If I am the sender, show receiver. If I am receiver, show sender.
    final otherUser = (senderId == currentUserId) ? receiver : sender;

    final userName = otherUser?['name'] ?? 'Unknown User';
    final dogName = conversation['other_user_dog_name'];
    // Format as "Username (DogName's human)" if dog name is available
    final displayName =
        dogName != null ? "$userName ($dogName's human)" : userName;
    final avatarUrl = otherUser?['avatar_url'];
    final content = conversation['content'] ?? '';
    final createdAt = DateTime.parse(conversation['created_at']);
    // Note: read status logic needs refinement based on user

    return InkWell(
      onTap: () {
        final matchId = conversation['match_id'];
        // ID is inferred from sender_id/receiver_id since it's not in embedded object by default
        final targetId = (senderId == currentUserId)
            ? conversation['receiver_id']
            : conversation['sender_id'];

        if (matchId != null && targetId != null) {
          ChatRoute(
            matchId: matchId,
            recipientId: targetId,
            recipientName: displayName,
            recipientAvatarUrl: avatarUrl ?? '',
          ).push(context);
        }
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                backgroundColor: Colors.grey[200],
                child: avatarUrl == null
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
              if (hasUnread)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D47A1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              hasUnread ? FontWeight.w800 : FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (unreadCount > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D47A1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          timeago.format(createdAt, locale: 'en_short'),
                          style: TextStyle(
                            fontSize: 12,
                            color: hasUnread
                                ? const Color(0xFF0D47A1)
                                : Colors.grey[600],
                            fontWeight:
                                hasUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
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
                    color: hasUnread ? Colors.black87 : Colors.grey[600],
                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
