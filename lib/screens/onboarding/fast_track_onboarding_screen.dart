import 'package:flutter/material.dart';
import 'package:barkdate/services/dog_breed_service.dart';
import 'package:barkdate/services/photo_upload_service.dart';
import 'package:barkdate/services/selected_image.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/widgets/supabase_auth_wrapper.dart';
import 'package:barkdate/design_system/app_typography.dart';
import 'package:barkdate/screens/onboarding/location_permission_screen.dart';

class FastTrackOnboardingScreen extends StatefulWidget {
  final String? userId;
  final String? userName;

  const FastTrackOnboardingScreen({
    super.key,
    this.userId,
    this.userName,
  });

  @override
  State<FastTrackOnboardingScreen> createState() =>
      _FastTrackOnboardingScreenState();
}

class _FastTrackOnboardingScreenState extends State<FastTrackOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Step 1
  final _dogNameController = TextEditingController();
  final _dogNameFocusNode = FocusNode();

  // Step 2
  final _dogBreedController = TextEditingController();
  final _dogBreedFocusNode = FocusNode();
  bool _breedSelected = false;

  // Step 3
  SelectedImage? _photo;
  String _dogSize = 'Medium';
  String _dogGender = 'Male';
  bool _isFinishing = false;

  @override
  void dispose() {
    _pageController.dispose();
    _dogNameController.dispose();
    _dogNameFocusNode.dispose();
    _dogBreedController.dispose();
    _dogBreedFocusNode.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _nextStep() {
    if (_currentStep < 2) _goToStep(_currentStep + 1);
  }

  void _prevStep() {
    if (_currentStep > 0) _goToStep(_currentStep - 1);
  }

  Future<void> _finishOnboarding() async {
    if (_photo == null || _isFinishing) return;

    setState(() => _isFinishing = true);

    try {
      final userId = widget.userId ?? SupabaseConfig.auth.currentUser?.id;
      if (userId == null || userId.trim().isEmpty) {
        throw Exception('No authenticated user found for dog setup');
      }

      // Upload photo
      final photoUrl = await PhotoUploadService.uploadImage(
        bytes: _photo!.bytes,
        bucketName: 'dog-photos',
        filePath: '$userId/main_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // Insert dog record
      await BarkDateUserService.addDog(userId, {
        'name': _dogNameController.text.trim(),
        'breed': _dogBreedController.text.trim(),
        'age': 1,
        'size': _dogSize,
        'gender': _dogGender,
        'bio': '',
        'main_photo_url': photoUrl,
        'extra_photo_urls': <String>[],
        'photo_urls': photoUrl != null ? [photoUrl] : <String>[],
        'is_public': true,
      });

      // Clear cache so auth wrapper knows onboarding is complete
      SupabaseAuthWrapper.clearProfileCache(userId);

      if (mounted) {
        // Navigate to permissions screen (next step in onboarding)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LocationPermissionScreen(),
          ),
        );
      }
    } catch (e) {
      debugPrint('FastTrack onboarding error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dog setup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isFinishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentStep > 0) {
          _prevStep();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: _currentStep > 0
              ? IconButton(
                  icon: Icon(Icons.arrow_back,
                      color: Theme.of(context).colorScheme.onSurface),
                  onPressed: _prevStep,
                )
              : const SizedBox.shrink(),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep1(),
                    _buildStep2(),
                    _buildStep3(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          final isActive = index == _currentStep;
          final isDone = index < _currentStep;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive || isDone
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  // ── Step 1: Dog Name ─────────────────────────────────────────────────────────

  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 1),
          Text(
            "What's your\ndog's name?",
            style: AppTypography.display2(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _dogNameController,
            focusNode: _dogNameFocusNode,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            style: AppTypography.h2(),
            decoration: InputDecoration(
              hintText: 'e.g. Buddy',
              hintStyle: AppTypography.h2(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
              ),
              border: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            onSubmitted: (_) {
              if (_dogNameController.text.trim().isNotEmpty) _nextStep();
            },
            onChanged: (_) => setState(() {}),
          ),
          const Spacer(flex: 2),
          _buildNextButton(
            label: 'Next',
            enabled: _dogNameController.text.trim().isNotEmpty,
            onPressed: _nextStep,
          ),
        ],
      ),
    );
  }

  // ── Step 2: Dog Breed ────────────────────────────────────────────────────────

  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 1),
          Text(
            "What breed\nis ${_dogNameController.text.trim().isEmpty ? 'your dog' : _dogNameController.text.trim()}?",
            style: AppTypography.display2(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 32),
          Autocomplete<String>(
            optionsBuilder: (textEditingValue) async {
              if (textEditingValue.text.isEmpty) return [];
              return DogBreedService.searchBreeds(textEditingValue.text);
            },
            onSelected: (selection) {
              _dogBreedController.text = selection;
              // Don't auto-advance — just mark as selected
              setState(() => _breedSelected = true);
            },
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
              // Sync to our controller for validation
              controller.text = _dogBreedController.text;
              controller.addListener(() {
                final newText = controller.text;
                if (newText != _dogBreedController.text) {
                  _dogBreedController.text = newText;
                  // If user is typing (not selecting), reset the selected flag
                  setState(() => _breedSelected = false);
                }
              });
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: _breedSelected
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: _breedSelected
                    ? const EdgeInsets.symmetric(horizontal: 12)
                    : EdgeInsets.zero,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  style: AppTypography.h2(),
                  decoration: InputDecoration(
                    hintText: 'e.g. Golden Retriever',
                    hintStyle: AppTypography.h2(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.3),
                    ),
                    suffixIcon: _breedSelected
                        ? Icon(Icons.check_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24)
                        : null,
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  onSubmitted: (_) {
                    if (_dogBreedController.text.trim().isNotEmpty) _nextStep();
                  },
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Text(
                              option,
                              style: AppTypography.bodyLarge(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const Spacer(flex: 2),
          _buildNextButton(
            label: 'Next',
            enabled: _dogBreedController.text.trim().isNotEmpty,
            onPressed: _nextStep,
          ),
        ],
      ),
    );
  }

  // ── Step 3: Photo, Size & Gender ─────────────────────────────────────────────

  Widget _buildStep3() {
    final dogName = _dogNameController.text.trim();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Add a photo\nof ${dogName.isEmpty ? 'your dog' : dogName}",
            style: AppTypography.display2(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 36),

          // Photo upload
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _photo != null
                      ? Colors.transparent
                      : Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.3),
                  image: _photo != null
                      ? DecorationImage(
                          image: MemoryImage(_photo!.bytes),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _photo == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 36,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap to add',
                            style: AppTypography.labelSmall(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      )
                    : Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          margin: const EdgeInsets.all(6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit,
                              size: 16, color: Colors.white),
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 36),

          // Size
          Text(
            'Size',
            style: AppTypography.h4(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _buildFlatToggle(
            options: ['Small', 'Medium', 'Large'],
            selected: _dogSize,
            onChanged: (val) => setState(() => _dogSize = val),
          ),

          const SizedBox(height: 28),

          // Gender
          Text(
            'Boy or girl?',
            style: AppTypography.h4(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _buildFlatToggle(
            options: ['Male', 'Female'],
            labels: ['Boy', 'Girl'],
            icons: [Icons.male, Icons.female],
            selected: _dogGender,
            onChanged: (val) => setState(() => _dogGender = val),
          ),

          const SizedBox(height: 40),

          // Finish button
          _buildNextButton(
            label: 'Finish',
            enabled: _photo != null && !_isFinishing,
            isLoading: _isFinishing,
            onPressed: _finishOnboarding,
          ),

          if (_photo == null) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Add a photo to continue',
                style: AppTypography.bodySmall(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Flat pill-style toggle (replaces SegmentedButton)
  Widget _buildFlatToggle({
    required List<String> options,
    List<String>? labels,
    List<IconData>? icons,
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFECECEC),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(options.length, (index) {
          final isSelected = options[index] == selected;
          final label = labels != null ? labels[index] : options[index];
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(options[index]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icons != null) ...[
                        Icon(
                          icons[index],
                          size: 18,
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        label,
                        style: AppTypography.labelMedium(
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final image = await context.showImagePicker();
    if (image != null) setState(() => _photo = image);
  }

  Widget _buildNextButton({
    required String label,
    required bool enabled,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                enabled ? const Color(0xFF4CAF50) : const Color(0xFFECECEC),
            foregroundColor: enabled ? Colors.white : const Color(0xFFB6B6B6),
            disabledBackgroundColor: const Color(0xFFECECEC),
            disabledForegroundColor: const Color(0xFFB6B6B6),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: AppTypography.button(
                    color: enabled ? Colors.white : const Color(0xFFB6B6B6),
                  ),
                ),
        ),
      ),
    );
  }
}
