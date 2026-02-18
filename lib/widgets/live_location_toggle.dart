import 'package:flutter/material.dart';
import 'package:barkdate/services/live_location_service.dart';
import 'package:barkdate/services/location_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Toggle widget for controlling live location sharing
class LiveLocationToggle extends StatefulWidget {
  final VoidCallback? onStateChanged;

  const LiveLocationToggle({super.key, this.onStateChanged});

  @override
  State<LiveLocationToggle> createState() => _LiveLocationToggleState();
}

class _LiveLocationToggleState extends State<LiveLocationToggle> {
  String _privacy = 'off';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPrivacySetting();
  }

  Future<void> _loadPrivacySetting() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final privacy = await LocationService.getLiveLocationPrivacy(userId);
    if (mounted) {
      setState(() => _privacy = privacy);
    }
  }

  Future<void> _setPrivacy(String newPrivacy) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      if (newPrivacy == 'off') {
        // Stop tracking
        await LiveLocationService.instance.stopLiveTracking();
      } else {
        // Start or update tracking
        if (!LiveLocationService.instance.isTracking) {
          await LiveLocationService.instance
              .startLiveTracking(userId, privacy: newPrivacy);
        } else {
          await LiveLocationService.instance.updatePrivacy(newPrivacy);
        }
      }

      setState(() => _privacy = newPrivacy);
      widget.onStateChanged?.call();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  IconData _getIcon() {
    switch (_privacy) {
      case 'all':
        return Icons.public;
      case 'friends':
        return Icons.people;
      default:
        return Icons.location_off;
    }
  }

  Color _getColor() {
    switch (_privacy) {
      case 'all':
        return Colors.green;
      case 'friends':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getLabel() {
    switch (_privacy) {
      case 'all':
        return 'Live (All)';
      case 'friends':
        return 'Live (Friends)';
      default:
        return 'Live Off';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: PopupMenuButton<String>(
        onSelected: _setPrivacy,
        offset: const Offset(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        itemBuilder: (context) => [
          _buildMenuItem('off', 'Off', Icons.location_off, Colors.grey),
          _buildMenuItem(
              'friends', 'Friends Only', Icons.people, Colors.orange),
          // 'Everyone' removed for privacy - live GPS never shared publicly
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(_getIcon(), color: _getColor(), size: 20),
              const SizedBox(width: 6),
              Text(
                _getLabel(),
                style: TextStyle(
                  color: _getColor(),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, color: _getColor(), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = _privacy == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(Icons.check, color: color, size: 18),
          ],
        ],
      ),
    );
  }
}
