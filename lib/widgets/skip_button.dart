import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'tv_focusable.dart';

class SkipButton extends StatefulWidget {
  final VoidCallback onSkip;
  final String label;
  final bool show;

  const SkipButton({
    super.key,
    required this.onSkip,
    required this.label,
    required this.show,
  });

  @override
  State<SkipButton> createState() => _SkipButtonState();
}

class _SkipButtonState extends State<SkipButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    if (widget.show) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant SkipButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      _controller.forward();
    } else if (!widget.show && oldWidget.show) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shouldRender = widget.show || _controller.value > 0;
    if (!shouldRender) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Semantics(
          button: true,
          label: widget.label,
          child: TvFocusable(
            onPressed: widget.onSkip,
            focusScale: 1.08,
            borderRadius: BorderRadius.circular(12),
            showFocusBorder: true,
            showFocusGlow: true,
            builder: (context, hasFocus, isHovered) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    constraints: const BoxConstraints(
                      minHeight: 44,
                      minWidth: 44,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: hasFocus
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasFocus ? AppColors.primaryLight : Colors.white.withValues(alpha: 0.12),
                        width: hasFocus ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: hasFocus
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : Colors.black.withValues(alpha: 0.35),
                          blurRadius: hasFocus ? 18 : 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
