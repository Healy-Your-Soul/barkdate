import 'package:flutter/material.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/widgets/app_button.dart';

class PlaydateResponseModal extends StatefulWidget {
  final Map<String, dynamic> playdateRequest;
  final Function(String response)? onResponse;

  const PlaydateResponseModal({
    super.key,
    required this.playdateRequest,
    this.onResponse,
  });

  @override
  State<PlaydateResponseModal> createState() => _PlaydateResponseModalState();
}

class _PlaydateResponseModalState extends State<PlaydateResponseModal> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _counterLocationController = TextEditingController();
  final TextEditingController _counterTimeController = TextEditingController();
  bool _isProcessing = false;
  String _selectedResponse = 'accepted';
  DateTime? _counterDateTime;

  @override
  void dispose() {
    _messageController.dispose();
    _counterLocationController.dispose();
    _counterTimeController.dispose();
    super.dispose();
  }

  Future<void> _handleResponse() async {
    if (_isProcessing) return;
    
    setState(() => _isProcessing = true);

    try {
      Map<String, dynamic>? counterProposal;
      
      if (_selectedResponse == 'counter_proposed') {
        counterProposal = {
          if (_counterLocationController.text.isNotEmpty)
            'location': _counterLocationController.text,
          if (_counterDateTime != null)
            'scheduled_at': _counterDateTime!.toIso8601String(),
        };
      }

      final success = await PlaydateRequestService.respondToPlaydateRequest(
        requestId: widget.playdateRequest['id'],
        userId: SupabaseAuth.currentUser!.id,
        response: _selectedResponse,
        message: _messageController.text.isNotEmpty ? _messageController.text : null,
        counterProposal: counterProposal,
      );

      if (mounted) {
        if (success) {
          widget.onResponse?.call(_selectedResponse);
          Navigator.pop(context, true);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_getSuccessMessage()),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to respond to playdate request'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error responding to playdate: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  String _getSuccessMessage() {
    switch (_selectedResponse) {
      case 'accepted':
        return 'Playdate accepted! 🎉';
      case 'declined':
        return 'Playdate declined';
      case 'counter_proposed':
        return 'Counter-proposal sent!';
      default:
        return 'Response sent';
    }
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null && mounted) {
        setState(() {
          _counterDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
          _counterTimeController.text = 
              '${_counterDateTime!.day}/${_counterDateTime!.month} at ${time.format(context)}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playdate = widget.playdateRequest['playdate'] as Map<String, dynamic>?;
    final requester = widget.playdateRequest['requester'] as Map<String, dynamic>?;
    
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Playdate Request',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Request details
            if (playdate != null) ...[
              _buildDetailRow(Icons.title, playdate['title'] ?? 'Playdate'),
              const SizedBox(height: 8),
              _buildDetailRow(Icons.location_on, playdate['location'] ?? 'TBD'),
              const SizedBox(height: 8),
              if (playdate['scheduled_at'] != null)
                _buildDetailRow(
                  Icons.access_time,
                  _formatDateTime(DateTime.parse(playdate['scheduled_at'])),
                ),
              const SizedBox(height: 8),
              if (requester != null)
                _buildDetailRow(Icons.person, 'From: ${requester['name']}'),
            ],
            
            const Divider(height: 32),

            // Response options
            Text(
              'Your Response',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Response type selector
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'accepted',
                  label: Text('Accept'),
                  icon: Icon(Icons.check_circle, size: 20),
                ),
                ButtonSegment(
                  value: 'declined',
                  label: Text('Decline'),
                  icon: Icon(Icons.cancel, size: 20),
                ),
                ButtonSegment(
                  value: 'counter_proposed',
                  label: Text('Counter'),
                  icon: Icon(Icons.edit, size: 20),
                ),
              ],
              selected: {_selectedResponse},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedResponse = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 20),

            // Counter-proposal fields
            if (_selectedResponse == 'counter_proposed') ...[
              TextField(
                controller: _counterLocationController,
                decoration: InputDecoration(
                  labelText: 'Suggest different location',
                  hintText: 'e.g., Central Park Dog Run',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _counterTimeController,
                readOnly: true,
                onTap: _selectDateTime,
                decoration: InputDecoration(
                  labelText: 'Suggest different time',
                  hintText: 'Tap to select',
                  prefixIcon: const Icon(Icons.access_time),
                  suffixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Message field
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: _selectedResponse == 'accepted' 
                    ? 'Add a message (optional)' 
                    : 'Reason or message',
                hintText: _selectedResponse == 'accepted'
                    ? 'Looking forward to it!'
                    : _selectedResponse == 'declined'
                        ? 'Sorry, I can\'t make it because...'
                        : 'How about this instead...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  text: 'Cancel',
                  type: AppButtonType.text,
                  onPressed: _isProcessing ? null : () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                AppButton(
                  text: _selectedResponse == 'accepted'
                      ? 'Accept Playdate'
                      : _selectedResponse == 'declined'
                          ? 'Decline Playdate'
                          : 'Send Counter-Proposal',
                  onPressed: _isProcessing ? null : _handleResponse,
                  isLoading: _isProcessing,
                  customColor: _selectedResponse == 'accepted'
                      ? Colors.green
                      : _selectedResponse == 'declined'
                          ? Colors.red
                          : null,
                ),
              ],
            ),
          ],
        ),
      ),
      ), // Close GestureDetector
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    
    if (difference.inDays == 0) {
      return 'Today at ${TimeOfDay.fromDateTime(dateTime).format(context)}';
    } else if (difference.inDays == 1) {
      return 'Tomorrow at ${TimeOfDay.fromDateTime(dateTime).format(context)}';
    } else {
      return '${dateTime.day}/${dateTime.month} at ${TimeOfDay.fromDateTime(dateTime).format(context)}';
    }
  }
}