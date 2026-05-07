import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:barkdate/services/places_service.dart';
import 'package:barkdate/services/checkin_service.dart';
import 'package:barkdate/services/park_activity_service.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/models/checkin.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:barkdate/screens/map_v2/widgets/dog_mini_card.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/services/dog_friendship_service.dart';
import 'package:barkdate/widgets/plan_walk_sheet.dart';
import 'package:barkdate/widgets/app_button.dart';
import 'package:barkdate/design_system/app_colors.dart';
import 'package:barkdate/design_system/app_styles.dart';
import 'package:geolocator/geolocator.dart';

/// Shows a simple place details sheet (DEPRECATED - use PlaceSheetContent instead)
void showPlaceSheet(BuildContext context, PlaceResult place) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => PlaceSheetContent(
        place: place,
        scrollController: scrollController,
        onClose: () => Navigator.pop(context),
      ),
    ),
  );
}

/// The actual content widget - can be used in Stack with external scrollController
class PlaceSheetContent extends StatefulWidget {
  final PlaceResult place;
  final ScrollController scrollController;
  final VoidCallback? onClose;
  final VoidCallback? onCheckInChanged; // Callback when check-in state changes
  final VoidCallback? onParkActivityReported; // Callback after activity report
  final Position? userPosition;
  final int? parkActivityCount;

  const PlaceSheetContent({
    super.key,
    required this.place,
    required this.scrollController,
    this.onClose,
    this.onCheckInChanged,
    this.onParkActivityReported,
    this.userPosition,
    this.parkActivityCount,
  });

  @override
  State<PlaceSheetContent> createState() => _PlaceSheetContentState();
}

class _PlaceSheetContentState extends State<PlaceSheetContent> {
  CheckIn? _currentCheckIn;
  bool _isLoading = true;
  bool _isCheckingInOut = false;
  bool _isReportingActivity = false;
  int _dogCount = 0;
  int _reportDogCount = 3;
  List<Map<String, dynamic>> _checkedInDogs = []; // Dogs with their details
  List<Map<String, dynamic>> _amenities = []; // Amenities with counts
  bool _showAllAmenities = false;
  double? _distanceToPlaceMeters;
  bool _isAdminUser = false;

  @override
  void initState() {
    super.initState();
    if (widget.parkActivityCount != null && widget.parkActivityCount! > 0) {
      _reportDogCount = widget.parkActivityCount!.clamp(1, 15);
    }
    _loadCheckInState();
    _loadAmenities();
    _loadDistanceToPlace();
    _loadAdminStatus();
  }

  @override
  void didUpdateWidget(PlaceSheetContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload check-in state when viewing a different place
    if (widget.place.placeId != oldWidget.place.placeId) {
      _loadCheckInState();
      _loadAmenities();
      _loadDistanceToPlace();
    }
    if (widget.userPosition != oldWidget.userPosition) {
      _loadDistanceToPlace();
    }
  }

  Future<void> _loadCheckInState() async {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final checkIn = await CheckInService.getActiveCheckIn(user.id);
      final dogsHere =
          await CheckInService.getActiveCheckInsAtPlace(widget.place.placeId);

      if (mounted) {
        setState(() {
          _currentCheckIn = checkIn;
          _checkedInDogs = dogsHere;
          _dogCount = dogsHere.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading check-in state: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCheckIn() async {
    if (_isCheckingInOut) return;

    setState(() => _isCheckingInOut = true);

    try {
      final isHere = _currentCheckIn?.parkId == widget.place.placeId;
      debugPrint(
          '🔄 Check-in button tapped. isHere=$isHere, currentCheckIn=${_currentCheckIn?.parkId}');

      if (isHere) {
        // Check out
        debugPrint('🚪 Attempting to check out...');
        final success = await CheckInService.checkOut();
        debugPrint('🚪 Checkout result: $success');
        if (success && mounted) {
          setState(() => _currentCheckIn = null);
          _showMessage('Checked out! See you next time 🐾', Colors.green);
        } else {
          _showMessage('Checkout failed. Try again.', Colors.red);
        }
      } else if (_currentCheckIn != null) {
        // Already checked in elsewhere
        _showMessage(
          'You\'re checked in at ${_currentCheckIn!.parkName}. Check out first!',
          Colors.orange,
        );
      } else {
        // Check in
        final checkIn = await CheckInService.checkInAtPark(
          parkId: widget.place.placeId,
          parkName: widget.place.name,
          latitude: widget.place.latitude,
          longitude: widget.place.longitude,
        );

        if (checkIn != null && mounted) {
          setState(() => _currentCheckIn = checkIn);
          _showMessage('Checked in at ${widget.place.name}! 🐕', Colors.green);
        }
      }

      // Refresh dog count AND dog avatars list
      await _loadCheckInState();

      // Notify parent of check-in change
      widget.onCheckInChanged?.call();
    } catch (e) {
      debugPrint('Check-in error: $e');
      _showMessage('Something went wrong. Try again.', Colors.red);
    } finally {
      if (mounted) setState(() => _isCheckingInOut = false);
    }
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Load amenities for this place
  Future<void> _loadAmenities() async {
    try {
      final data = await SupabaseConfig.client.rpc(
        'get_place_amenities',
        params: {'p_place_id': widget.place.placeId},
      );
      if (mounted && data != null) {
        setState(() {
          _amenities = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error loading amenities: $e');
    }
  }

  Future<void> _loadAdminStatus() async {
    try {
      final isAdmin = await ParkActivityService.isAdminUser();
      if (mounted) {
        setState(() => _isAdminUser = isAdmin);
      }
    } catch (e) {
      debugPrint('Error loading admin status: $e');
    }
  }

  Future<void> _loadDistanceToPlace() async {
    try {
      final position = widget.userPosition ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        widget.place.latitude,
        widget.place.longitude,
      );

      if (mounted) {
        setState(() => _distanceToPlaceMeters = distance);
      }
    } catch (e) {
      debugPrint('Error loading distance to place: $e');
      if (mounted) {
        setState(() => _distanceToPlaceMeters = null);
      }
    }
  }

  bool _isWithinReportDistance() {
    return _distanceToPlaceMeters != null && _distanceToPlaceMeters! <= 500;
  }

  void _changeReportDogCount(int delta) {
    setState(() {
      _reportDogCount = (_reportDogCount + delta).clamp(1, 15);
    });
  }

  Future<void> _reportParkActivity() async {
    if (_isReportingActivity) return;
    setState(() => _isReportingActivity = true);

    try {
      final isAdmin = _isAdminUser || await ParkActivityService.isAdminUser();
      final canReport = isAdmin || _isWithinReportDistance();

      if (!canReport) {
        _showMessage('You must be within 500m to report', Colors.orange);
        return;
      }

      final success = await ParkActivityService.reportDogCount(
        parkId: widget.place.placeId,
        dogCount: _reportDogCount,
        isAdminOverride: isAdmin,
      );

      if (success) {
        _showMessage(
            'Thanks! Reported $_reportDogCount dogs here.', Colors.green);
        widget.onParkActivityReported?.call();
      } else {
        _showMessage('Failed to report activity. Try again.', Colors.red);
      }
    } catch (e) {
      debugPrint('Error reporting park activity: $e');
      _showMessage('Something went wrong. Try again.', Colors.red);
    } finally {
      if (mounted) setState(() => _isReportingActivity = false);
    }
  }

  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: AppStyles.borderRadiusFull,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isEnabled ? Colors.white : Colors.grey.shade200,
          borderRadius: AppStyles.borderRadiusFull,
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: isEnabled ? AppStyles.shadowSM : null,
        ),
        child: Icon(
          icon,
          size: 18,
          color: isEnabled ? AppColors.primaryGreen : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildActivityCountPill(int activityCount) {
    final label =
        activityCount == 1 ? '1 dog spotted' : '$activityCount dogs spotted';

    return InkWell(
      onTap: () => _showMessage('$label playing here recently', Colors.black87),
      borderRadius: AppStyles.borderRadiusFull,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accentOrange.withValues(alpha: 0.12),
          borderRadius: AppStyles.borderRadiusFull,
          border: Border.all(
            color: AppColors.accentOrange.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.pets,
              size: 16,
              color: AppColors.secondaryBrownDark,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryBrownDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParkActivitySection() {
    final canReport = _isAdminUser || _isWithinReportDistance();
    final activityCount = widget.parkActivityCount ?? 0;
    final distanceText = _distanceToPlaceMeters == null
        ? 'Location required to report'
        : '${_distanceToPlaceMeters!.toStringAsFixed(0)} m away';
    final helperText = _isAdminUser
        ? 'Admin override enabled'
        : (_distanceToPlaceMeters == null
            ? 'Location required to report'
            : (canReport ? distanceText : 'You must be within 500m to report'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 26),
        const Text(
          'Spotted dogs here?',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 18),
        if (activityCount > 0) ...[
          _buildActivityCountPill(activityCount),
          const SizedBox(height: 18),
        ],
        Row(
          children: [
            _buildStepperButton(
              icon: Icons.remove,
              onTap:
                  _reportDogCount > 1 ? () => _changeReportDogCount(-1) : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightSurfaceVariant,
                  borderRadius: AppStyles.borderRadiusFull,
                  border: Border.all(color: AppColors.lightBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.pets,
                      size: 17,
                      color: AppColors.secondaryBrown,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_reportDogCount dogs',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildStepperButton(
              icon: Icons.add,
              onTap:
                  _reportDogCount < 15 ? () => _changeReportDogCount(1) : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: canReport ? _reportParkActivity : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: _isReportingActivity
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'SPOTTED',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Divider(height: 1),
        const SizedBox(height: 26),
        Text(
          helperText,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  /// Build amenities section with chips
  Widget _buildAmenitiesSection() {
    // Filter to amenities that have been suggested at least once
    final suggestedAmenities = _amenities
        .where((a) => (a['suggested_count'] as int? ?? 0) > 0)
        .toList();

    if (suggestedAmenities.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Amenities',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          Text('No amenities reported yet',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      );
    }

    final displayCount = _showAllAmenities ? suggestedAmenities.length : 4;
    final displayList = suggestedAmenities.take(displayCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Amenities',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ...displayList.map((amenity) => Chip(
                  avatar: Text(amenity['icon'] ?? '✓',
                      style: const TextStyle(fontSize: 14)),
                  label: Text(
                    amenity['name'] ?? '',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.green.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )),
            if (suggestedAmenities.length > 4 && !_showAllAmenities)
              ActionChip(
                label: Text('+${suggestedAmenities.length - 4} more'),
                onPressed: () => setState(() => _showAllAmenities = true),
                backgroundColor: Colors.grey.shade100,
              ),
          ],
        ),
      ],
    );
  }

  /// Show report dialog
  Future<void> _showReportDialog() async {
    final reasons = [
      'Not dog-friendly',
      'Permanently closed',
      'Wrong location',
      'Other issue',
    ];
    String? selectedReason;
    final messageController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What\'s wrong with ${widget.place.name}?'),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setDialogState) => RadioGroup<String>(
                groupValue: selectedReason,
                onChanged: (v) => setDialogState(() => selectedReason = v),
                child: Column(
                  children: reasons
                      .map((reason) => RadioListTile<String>(
                            title: Text(reason,
                                style: const TextStyle(fontSize: 14)),
                            value: reason,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                hintText: 'Additional details (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selectedReason == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a reason')),
                );
                return;
              }
              Navigator.pop(context);
              await _submitReport(selectedReason!, messageController.text);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    messageController.dispose();
  }

  /// Submit the report to database
  Future<void> _submitReport(String reason, String message) async {
    try {
      await SupabaseConfig.client.rpc('submit_place_report', params: {
        'p_place_id': widget.place.placeId,
        'p_place_name': widget.place.name,
        'p_report_type': reason.toLowerCase().replaceAll(' ', '_'),
        'p_message': message.isNotEmpty ? message : null,
      });
      _showMessage('Report submitted. Thank you! 🙏', Colors.green);
    } catch (e) {
      debugPrint('Error submitting report: $e');
      if (e.toString().contains('already reported')) {
        _showMessage('You already reported this place recently', Colors.orange);
      } else {
        _showMessage('Failed to submit report', Colors.red);
      }
    }
  }

  /// Submit dog-friendly vote and notify admins
  Future<void> _submitDogFriendlyVote(bool isDogFriendly) async {
    try {
      // Submit using the same report system with a different type
      final reportType =
          isDogFriendly ? 'confirmed_dog_friendly' : 'not_dog_friendly';
      await SupabaseConfig.client.rpc('submit_place_report', params: {
        'p_place_id': widget.place.placeId,
        'p_place_name': widget.place.name,
        'p_report_type': reportType,
        'p_message': isDogFriendly
            ? 'User confirmed as dog-friendly'
            : 'User marked as not dog-friendly',
      });

      _showMessage(
        isDogFriendly
            ? 'Thanks! Your feedback helps other dog owners 🐕'
            : 'Thanks for letting us know! We\'ll review this.',
        Colors.green,
      );
    } catch (e) {
      debugPrint('Error submitting vote: $e');
      if (e.toString().contains('already reported')) {
        _showMessage('You already voted for this place', Colors.orange);
      } else {
        _showMessage('Thanks for your feedback!', Colors.green);
      }
    }
  }

  /// Get crowdedness label based on dog count
  String _getCrowdednessLabel(int dogCount) {
    if (dogCount == 0) return 'Empty';
    if (dogCount < 3) return 'Quiet';
    if (dogCount < 6) return 'Moderate';
    return 'Busy';
  }

  /// Get crowdedness color based on dog count
  Color _getCrowdednessColor(int dogCount) {
    if (dogCount == 0) return Colors.grey;
    if (dogCount < 3) return Colors.green;
    if (dogCount < 6) return Colors.orange;
    return Colors.red;
  }

  /// Get color for category to match marker colors
  Color _getCategoryColor(PlaceCategory category) {
    switch (category) {
      case PlaceCategory.park:
        return Colors.green;
      case PlaceCategory.restaurant:
        return Colors.orange;
      case PlaceCategory.petStore:
        return Colors.blue;
      case PlaceCategory.veterinary:
        return Colors.red;
      default:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHere = _currentCheckIn?.parkId == widget.place.placeId;
    final isElsewhere = _currentCheckIn != null && !isHere;

    // Container with scrollable content
    // Gesture absorption is handled at the parent level in map_tab_screen.dart
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: widget.scrollController,
          primary: false,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            // Handle bar removed - wrapper already has one

            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.place.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose ?? () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildCheckInButton(isHere, isElsewhere),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final walkCreated = await showPlanWalkSheet(
                        context,
                        parkId: widget.place.placeId,
                        parkName: widget.place.name,
                        latitude: widget.place.latitude,
                        longitude: widget.place.longitude,
                      );
                      // Collapse the place sheet after walk is scheduled
                      if (walkCreated == true) {
                        widget.onClose?.call();
                      }
                    },
                    icon: const Icon(Icons.schedule),
                    label: const Text('Plan a Walk'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D47A1),
                      side: const BorderSide(color: Color(0xFF0D47A1)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // DOG COUNT & CROWDEDNESS - Always visible
            Row(
              children: [
                Icon(Icons.pets,
                    color: _getCrowdednessColor(_dogCount), size: 18),
                const SizedBox(width: 6),
                Text(
                  _dogCount == 0
                      ? 'No checked-in dogs here right now'
                      : '$_dogCount ${_dogCount == 1 ? 'dog' : 'dogs'} here now',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (_dogCount > 0) ...[
                  const SizedBox(width: 8),
                  // Crowdedness badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getCrowdednessColor(_dogCount)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: _getCrowdednessColor(_dogCount)),
                    ),
                    child: Text(
                      _getCrowdednessLabel(_dogCount),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getCrowdednessColor(_dogCount),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // PARK ACTIVITY REPORT (crowdsourced)
            _buildParkActivitySection(),
            const SizedBox(height: 12),

            // WHO'S HERE - Dog Avatars Carousel (only if dogs present)
            if (_checkedInDogs.isNotEmpty) ...[
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _checkedInDogs.length,
                  itemBuilder: (context, index) {
                    final checkIn = _checkedInDogs[index];
                    final dog = checkIn['dog'] as Map<String, dynamic>?;
                    final user = checkIn['user'] as Map<String, dynamic>?;
                    final checkedInAt = checkIn['checked_in_at'] as String?;

                    // Calculate freshness (green=recent, orange=1h+, red=2h+)
                    Color borderColor = Colors.green;
                    if (checkedInAt != null) {
                      final checkInTime = DateTime.tryParse(checkedInAt);
                      if (checkInTime != null) {
                        final hoursAgo =
                            DateTime.now().difference(checkInTime).inMinutes /
                                60.0;
                        if (hoursAgo >= 2) {
                          borderColor = Colors.red;
                        } else if (hoursAgo >= 1) {
                          borderColor = Colors.orange;
                        }
                      }
                    }

                    final photoUrl = dog?['main_photo_url'] as String? ??
                        user?['avatar_url'] as String?;
                    final dogName = dog?['name'] as String? ?? 'Unknown';

                    return GestureDetector(
                      onTap: () {
                        // Show dog mini card in a dialog
                        // Calculate time ago string
                        String timeAgoStr = 'Just now';
                        if (checkedInAt != null) {
                          final checkInTime = DateTime.tryParse(checkedInAt);
                          if (checkInTime != null) {
                            timeAgoStr = timeago.format(checkInTime);
                          }
                        }

                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            child: DogMiniCard(
                              dogName: dogName,
                              humanName: user?['name'],
                              dogPhotoUrl: photoUrl,
                              timeAgo: timeAgoStr,
                              isFriend:
                                  false, // We check friendship status if available, default false. Ideally fetch this.
                              isOwnDog: user?['id'] ==
                                  Supabase.instance.client.auth.currentUser?.id,
                              onAddToPack: () async {
                                // Close dialog first
                                // Navigator.pop(context); // Optional: keep open or close? User might want to see success.
                                // Let's keep it open and show snackbar on top.

                                try {
                                  final currentUser =
                                      Supabase.instance.client.auth.currentUser;
                                  if (currentUser == null) return;

                                  final dogs =
                                      await BarkDateUserService.getUserDogs(
                                          currentUser.id);
                                  if (dogs.isEmpty) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Please create a dog profile first')),
                                      );
                                    }
                                    return;
                                  }
                                  final myDogId = dogs.first['id'] as String;

                                  final targetDogId = dog?['id'] as String?;
                                  if (targetDogId == null) return;

                                  final success =
                                      await DogFriendshipService.sendBark(
                                    fromDogId: myDogId,
                                    toDogId: targetDogId,
                                  );

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(success
                                            ? 'Request sent! 🐾'
                                            : 'Could not send request'),
                                      ),
                                    );
                                  }

                                  // Close dialog on success
                                  if (success && context.mounted) {
                                    Navigator.pop(context);
                                  }
                                } catch (e) {
                                  debugPrint(
                                      'Error sending friend request: $e');
                                }
                              },
                              onBark: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('🐕 You barked at $dogName!'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                Navigator.pop(context);
                              },
                              onClose: () => Navigator.pop(context),
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Tooltip(
                          message: dogName,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: borderColor, width: 3),
                            ),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundImage: photoUrl != null
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: photoUrl == null
                                  ? Text(dogName[0].toUpperCase(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold))
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // STATUS ROW
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.place.isOpen
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.place.isOpen ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Text(
                    widget.place.isOpen ? 'Open Now' : 'Closed',
                    style: TextStyle(
                      color: widget.place.isOpen
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (widget.place.rating > 0) ...[
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    widget.place.rating.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // CATEGORY
            Text(
              'Categories:',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _getCategoryColor(widget.place.category)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.place.category.displayName,
                style: TextStyle(
                    color: _getCategoryColor(widget.place.category),
                    fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),

            // DOG FRIENDLY STATUS
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.place.isDogFriendly
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.place.isDogFriendly
                      ? Colors.green.shade200
                      : Colors.red.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.place.isDogFriendly
                            ? Icons.check_circle
                            : Icons.help_outline,
                        color: widget.place.isDogFriendly
                            ? Colors.green
                            : Colors.red.shade700,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.place.isDogFriendly
                                  ? 'Dog Friendly'
                                  : 'Check if dog-friendly',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if (!widget.place.isDogFriendly)
                              Text(
                                'Call ahead to confirm dogs are welcome',
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Voting section for unverified places
                  if (!widget.place.isDogFriendly) ...[
                    const Divider(height: 20),
                    Row(
                      children: [
                        Text(
                          'Is this place dog-friendly?',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade700),
                        ),
                        const Spacer(),
                        // Yes button
                        IconButton(
                          onPressed: () => _submitDogFriendlyVote(true),
                          icon: const Icon(Icons.check_circle_outline),
                          color: Colors.green,
                          tooltip: 'Yes, dog-friendly',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 16),
                        // No button
                        IconButton(
                          onPressed: () => _submitDogFriendlyVote(false),
                          icon: const Icon(Icons.cancel_outlined),
                          color: Colors.red,
                          tooltip: 'Not dog-friendly',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // AMENITIES SECTION
            _buildAmenitiesSection(),
            const SizedBox(height: 12),

            // REPORT BUTTON
            TextButton.icon(
              onPressed: () => _showReportDialog(),
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: const Text('Report issue with this place'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 16),

            // PHOTO
            if (widget.place.photoReference != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  PlacesService.getPhotoUrl(widget.place.photoReference!,
                      maxWidth: 600),
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 150,
                    color: Colors.grey.shade200,
                    child: const Center(child: Icon(Icons.image, size: 40)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // DIRECTIONS BUTTON
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final url = Uri.parse(
                    'https://www.google.com/maps/dir/?api=1&destination=${widget.place.latitude},${widget.place.longitude}',
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.directions),
                label: const Text('Get Directions'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ), // Close GestureDetector
    );
  }

  Widget _buildCheckInButton(bool isHere, bool isElsewhere) {
    if (_isLoading) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (isElsewhere) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You\'re at ${_currentCheckIn!.parkName}',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isCheckingInOut
                    ? null
                    : () async {
                        setState(() => _isCheckingInOut = true);
                        await CheckInService.checkOut();
                        _showMessage('Checked out!', Colors.green);
                        await _loadCheckInState();
                        setState(() => _isCheckingInOut = false);
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade700,
                  side: BorderSide(color: Colors.orange.shade400),
                ),
                child: _isCheckingInOut
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Check Out First'),
              ),
            ),
          ],
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: _isCheckingInOut ? null : _handleCheckIn,
      style: ElevatedButton.styleFrom(
        backgroundColor: isHere ? Colors.red : const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: _isCheckingInOut
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Icon(isHere ? Icons.logout : Icons.pets),
      label: Text(
        isHere ? 'Check Out' : 'Check In',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}
