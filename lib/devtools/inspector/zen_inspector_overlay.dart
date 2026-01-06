// lib/devtools/inspector/zen_inspector_overlay.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'widgets/debug_panel.dart';

/// Developer tools overlay for inspecting Zenify state
///
/// This widget provides an in-app inspector for debugging:
/// - Scope hierarchies
/// - Query cache contents
/// - Registered dependencies
/// - Performance metrics
///
/// ## Safety
///
/// This overlay is designed to be safe for production builds:
/// - Defaults to [kDebugMode] (automatically disabled in release)
/// - Multiple runtime guards prevent accidental activation
/// - Tree-shakes out when disabled (zero bytes in release)
///
/// ## Architecture
///
/// Wraps your app BEFORE MaterialApp to provide debugging across all routes.
/// Uses only basic widgets (Stack, Container, GestureDetector) to avoid dependencies.
/// The debug panel is wrapped with Directionality + MediaQuery when shown.
///
/// ## Usage
///
/// ```dart
/// void main() {
///   runApp(
///     ZenInspectorOverlay(
///       child: MaterialApp(home: HomePage()),
///     ),
///   );
/// }
/// ```
///
/// ## WARNING
///
/// Never enable in production:
/// ```dart
/// ZenInspectorOverlay(
///   enabled: true,  // ❌ DANGEROUS in release builds!
///   child: child,
/// )
/// ```
class ZenInspectorOverlay extends StatefulWidget {
  /// The app to wrap with inspector overlay
  final Widget child;

  /// Whether to enable the inspector
  ///
  /// Defaults to [kDebugMode] for safety.
  /// When false, this widget renders only [child] with zero overhead.
  ///
  /// ⚠️ WARNING: Never set to true in production builds!
  final bool enabled;

  /// Initial visibility of the debug panel
  final bool initiallyOpen;

  /// Whether to show the floating toggle button
  final bool showToggleButton;

  /// Position of the toggle button
  final Alignment toggleButtonAlignment;

  const ZenInspectorOverlay({
    super.key,
    required this.child,
    this.enabled = kDebugMode,
    this.initiallyOpen = false,
    this.showToggleButton = true,
    this.toggleButtonAlignment = Alignment.bottomRight,
  });

  @override
  State<ZenInspectorOverlay> createState() => _ZenInspectorOverlayState();
}

class _ZenInspectorOverlayState extends State<ZenInspectorOverlay> {
  bool _isPanelVisible = false;

  @override
  void initState() {
    super.initState();
    _isPanelVisible = widget.initiallyOpen;

    // Assert to catch mistakes during development
    assert(
      !kReleaseMode || !widget.enabled,
      '❌ ZenInspectorOverlay should not be enabled in release mode!\n'
      'This is a development tool and should only be used during debugging.\n'
      'Either remove the overlay or set enabled: false in production.',
    );

    // Log warning if enabled in release (shouldn't happen due to assert)
    if (kReleaseMode && widget.enabled) {
      debugPrint(
        '⚠️ WARNING: ZenInspectorOverlay is enabled in RELEASE mode!\n'
        'This should never happen in production. Disabling...',
      );
    }
  }

  void _togglePanel() {
    setState(() {
      _isPanelVisible = !_isPanelVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Safety layer 1: Check enabled flag
    if (!widget.enabled) return widget.child;

    // Safety layer 2: Double-check release mode
    if (kReleaseMode) return widget.child;

    // Wrap entire Stack with Directionality + MediaQuery to provide context
    // before MaterialApp exists
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Stack(
          children: [
            // Main app content - positioned to fill entire stack
            Positioned.fill(
              child: widget.child,
            ),

            // Debug panel (slides in from bottom)
            if (_isPanelVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  color: Colors.transparent,
                  home: ZenDebugPanel(
                    onClose: _togglePanel,
                  ),
                ),
              ),

            // Toggle button (only show when panel is hidden)
            if (widget.showToggleButton && !_isPanelVisible)
              Positioned(
                bottom: widget.toggleButtonAlignment == Alignment.bottomRight ||
                        widget.toggleButtonAlignment == Alignment.bottomLeft
                    ? 16
                    : null,
                top: widget.toggleButtonAlignment == Alignment.topRight ||
                        widget.toggleButtonAlignment == Alignment.topLeft
                    ? 16
                    : null,
                right: widget.toggleButtonAlignment == Alignment.bottomRight ||
                        widget.toggleButtonAlignment == Alignment.topRight
                    ? 16
                    : null,
                left: widget.toggleButtonAlignment == Alignment.bottomLeft ||
                        widget.toggleButtonAlignment == Alignment.topLeft
                    ? 16
                    : null,
                child: _ToggleButton(
                  onPressed: _togglePanel,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Floating toggle button to open the inspector
/// Uses only basic widgets (no Material dependencies)
class _ToggleButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _ToggleButton({required this.onPressed});

  @override
  State<_ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends State<_ToggleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _isHovered ? Colors.black : Colors.black87,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Zen logo / icon
              Text(
                'Z',
                style: TextStyle(
                  color: Colors.purple[300],
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Badge indicator
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
