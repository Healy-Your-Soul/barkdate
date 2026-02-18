import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'dart:math' as math;

/// A cute dog-themed loading widget using Lottie animations
class DogLoadingWidget extends StatelessWidget {
  final double size;
  final String? message;

  const DogLoadingWidget({
    super.key,
    this.size = 120,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Lottie.network(
            // Cute dog walking animation from LottieFiles
            'https://lottie.host/9946c90c-1c13-4180-8ae0-a8b66354acbf/zIDozkNyfw.json',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to paw animation on error
              return _buildFallbackAnimation(context);
            },
            frameBuilder: (context, child, composition) {
              if (composition == null) {
                return _buildFallbackAnimation(context);
              }
              return child;
            },
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFallbackAnimation(BuildContext context) {
    // Animated paw print as fallback
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Icon(
        Icons.pets,
        size: size * 0.6,
        color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
      ),
      onEnd: () {
        // This will cause a rebuild with the animation continuing
      },
    );
  }
}

/// Small inline loading indicator with paw
class PawLoadingIndicator extends StatefulWidget {
  final double size;
  final Color? color;

  const PawLoadingIndicator({
    super.key,
    this.size = 24,
    this.color,
  });

  @override
  State<PawLoadingIndicator> createState() => _PawLoadingIndicatorState();
}

class _PawLoadingIndicatorState extends State<PawLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Icon(
              Icons.pets,
              size: widget.size,
              color: color,
            ),
          ),
        );
      },
    );
  }
}

/// A subtle wiggling paw icon that animates when it comes into view
class AnimatedPawIcon extends StatefulWidget {
  final double size;
  final Color? color;

  const AnimatedPawIcon({
    super.key,
    this.size = 24,
    this.color,
  });

  @override
  State<AnimatedPawIcon> createState() => _AnimatedPawIconState();
}

class _AnimatedPawIconState extends State<AnimatedPawIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  bool _hasanimated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Wiggle: 0 -> -0.2 -> 0.2 -> -0.1 -> 0.1 -> 0
    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.2), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.2, end: 0.2), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.2, end: -0.1), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.1), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: const Key('animated-paw-icon'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.5 && !_hasanimated) {
          _controller.forward(from: 0);
          _hasanimated = true; // Only animate once per session/view
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationAnimation.value,
            child: Icon(
              Icons.pets,
              size: widget.size,
              color: widget.color ?? Theme.of(context).colorScheme.primary,
            ),
          );
        },
      ),
    );
  }
}

/// Replacement for CircularProgressIndicator with dog theme
class DogCircularProgress extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;

  const DogCircularProgress({
    super.key,
    this.size = 40,
    this.strokeWidth = 3,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: strokeWidth,
              valueColor: AlwaysStoppedAnimation(progressColor),
            ),
          ),
          Icon(
            Icons.pets,
            size: size * 0.4,
            color: progressColor.withOpacity(0.6),
          ),
        ],
      ),
    );
  }
}
