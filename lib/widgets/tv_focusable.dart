import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Reusable TV-friendly Focusable wrapper for cards, buttons and interactive elements.
/// Handles remote control D-Pad navigation, key events (Select/OK/Enter),
/// scale animation, glow effects and automatic smooth scrolling into view.
class TvFocusable extends StatefulWidget {
  final Widget? child;
  final Widget Function(BuildContext context, bool hasFocus, bool isHovered)? builder;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool canRequestFocus;
  final double focusScale;
  final BorderRadius? borderRadius;
  final bool showFocusBorder;
  final bool showFocusGlow;
  final Color? focusBorderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final Duration animationDuration;
  final Curve animationCurve;
  final bool autoScroll;

  const TvFocusable({
    super.key,
    this.child,
    this.builder,
    this.onPressed,
    this.onLongPress,
    this.focusNode,
    this.autofocus = false,
    this.canRequestFocus = true,
    this.focusScale = 1.06,
    this.borderRadius,
    this.showFocusBorder = true,
    this.showFocusGlow = true,
    this.focusBorderColor,
    this.borderWidth = 2.5,
    this.padding,
    this.animationDuration = const Duration(milliseconds: 180),
    this.animationCurve = Curves.easeOutCubic,
    this.autoScroll = true,
  }) : assert(child != null || builder != null, 'Either child or builder must be provided');

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  late FocusNode _focusNode;
  bool _internalFocusNode = false;
  bool _hasFocus = false;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode(debugLabel: 'TvFocusable');
      _internalFocusNode = true;
    }

    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant TvFocusable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      if (_internalFocusNode) {
        _focusNode.removeListener(_onFocusChanged);
        _focusNode.dispose();
      }
      if (widget.focusNode != null) {
        _focusNode = widget.focusNode!;
        _internalFocusNode = false;
      } else {
        _focusNode = FocusNode(debugLabel: 'TvFocusable');
        _internalFocusNode = true;
      }
      _focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    if (_internalFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    final hasFocus = _focusNode.hasFocus;
    if (_hasFocus != hasFocus) {
      setState(() => _hasFocus = hasFocus);

      if (hasFocus && widget.autoScroll && mounted) {
        // Smoothly ensure the focused item is visible on TV screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _focusNode.hasFocus) {
            Scrollable.ensureVisible(
              context,
              alignment: 0.5,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final isSelectKey = key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.gameButtonSelect;

    if (isSelectKey && widget.onPressed != null) {
      widget.onPressed!();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(16);
    final borderColor = widget.focusBorderColor ?? AppColors.primary;
    final scale = _isPressed
        ? 0.97
        : (_hasFocus ? widget.focusScale : (_isHovered ? 1.02 : 1.0));

    Widget content = widget.builder != null
        ? widget.builder!(context, _hasFocus, _isHovered)
        : widget.child!;

    if (widget.showFocusBorder || widget.showFocusGlow) {
      content = AnimatedContainer(
        duration: widget.animationDuration,
        curve: widget.animationCurve,
        padding: widget.padding,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: widget.showFocusBorder
              ? Border.all(
                  color: _hasFocus ? borderColor : Colors.transparent,
                  width: widget.borderWidth,
                )
              : null,
          boxShadow: (_hasFocus && widget.showFocusGlow)
              ? [
                  BoxShadow(
                    color: borderColor.withValues(alpha: 0.45),
                    blurRadius: 18,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: content,
      );
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      canRequestFocus: widget.canRequestFocus,
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          onLongPress: widget.onLongPress,
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: scale,
            duration: widget.animationDuration,
            curve: widget.animationCurve,
            child: content,
          ),
        ),
      ),
    );
  }
}
