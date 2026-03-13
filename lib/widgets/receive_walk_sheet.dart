import 'package:flutter/material.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/core/router/app_router.dart';
import 'package:go_router/go_router.dart';

class ReceiveWalkSheet extends StatefulWidget {
  final String requestId;
  final String organizerName;
  final String dogName;
  final String? dogPhotoUrl;
  final String location;
  final DateTime scheduledAt;

  const ReceiveWalkSheet({
    super.key,
    required this.requestId,
    required this.organizerName,
    required this.dogName,
    this.dogPhotoUrl,
    required this.location,
    required this.scheduledAt,
  });

  @override
  State<ReceiveWalkSheet> createState() => _ReceiveWalkSheetState();
}

class _ReceiveWalkSheetState extends State<ReceiveWalkSheet> {
  bool _isLoading = false;

  Future<void> _handleResponse(String status) async {
    setState(() => _isLoading = true);

    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final success = await PlaydateRequestService.respondToPlaydateRequest(
        requestId: widget.requestId,
        userId: userId,
        response: status,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pop(context); // Close sheet
        if (status == 'accepted') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Walk Confirmed! 🎉 They have been added to your chat.'),
              backgroundColor: Color(0xFFE89E5F),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (status == 'declined') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Walk declined.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update request status.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleMaybeLater() {
    // Propose counter offer or open chat. For now, pop and go to chat
    // If request is pending, usually we accept it then chat, but here we can just open chat if conversation exists or start one
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message feature to be linked...')),
    );
  }

  String _formatDateTime(DateTime dt) {
    final time = TimeOfDay.fromDateTime(dt);
    return '${dt.day}/${dt.month} at ${time.format(context)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHandleBar(),
          const SizedBox(height: 24),
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: widget.dogPhotoUrl != null
                  ? NetworkImage(widget.dogPhotoUrl!)
                  : null,
              backgroundColor: Colors.grey[200],
              child: widget.dogPhotoUrl == null
                  ? const Icon(Icons.pets, size: 40, color: Colors.grey)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              'Walk Invite from ${widget.dogName}',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${_formatDateTime(widget.scheduledAt)} • ${widget.location}',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ]),
          const SizedBox(height: 32),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Column(
              children: [
                // Accept
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _handleResponse('accepted'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE89E5F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Yes, let's walk!",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),

                // Maybe Later
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _handleMaybeLater,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFFE89E5F)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Maybe later",
                        style: TextStyle(
                            color: Color(0xFFE89E5F),
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),

                // Decline
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => _handleResponse('declined'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text("Paws are tied right now",
                        style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHandleBar() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// Global helper to show the sheet directly given a notification JSON payload
void showReceiveWalkSheetFromPayload(
    BuildContext context, Map<String, dynamic> data) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ReceiveWalkSheet(
      requestId: data['playdate_id'] ??
          '', // Assume this maps to request_id logically if needed
      organizerName: data['organizer_name'] ?? 'BarkDate User',
      dogName: data['organizer_dog_name'] ?? 'A dog',
      location: data['location'] ?? 'Unknown location',
      scheduledAt: data['scheduled_at'] != null
          ? DateTime.tryParse(data['scheduled_at']) ?? DateTime.now()
          : DateTime.now(),
    ),
  );
}
