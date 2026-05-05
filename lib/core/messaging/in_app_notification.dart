import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Top-of-screen in-app notification banner used for foreground FCM
/// pushes. Slides down from below the status bar, auto-dismisses, and
/// can be swiped up to close. Replaces SnackBars which collide with
/// the task-detail FAB stack and bottom action bar.
class InAppNotification {
  InAppNotification._();

  static OverlayEntry? _current;
  static Timer? _dismissTimer;

  /// Show a top banner anchored under the status bar.
  ///
  /// [navigatorKey] is the app's root navigator key. We use it instead
  /// of [BuildContext] because the navigator's own context doesn't
  /// always sit beneath an Overlay on every Flutter version.
  ///
  /// [onTap] fires when the user taps the body; [actionLabel] + [onAction]
  /// render an inline action chip on the right. Both are optional.
  static void show({
    required GlobalKey<NavigatorState> navigatorKey,
    required String title,
    String? actionLabel,
    VoidCallback? onTap,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 5),
  }) {
    final overlay = _resolveOverlay(navigatorKey);
    if (overlay == null) {
      if (kDebugMode) {
        debugPrint(
          'InAppNotification: no Overlay available — banner skipped.',
        );
      }
      return;
    }

    _dismiss();

    final entry = OverlayEntry(
      builder: (ctx) => _BannerHost(
        title: title,
        actionLabel: actionLabel,
        onTap: onTap,
        onAction: onAction,
        onDismiss: _dismiss,
      ),
    );

    _current = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(duration, _dismiss);
  }

  /// Try every reasonable path to the app-wide Overlay. The Navigator
  /// owns one directly; if that's not yet ready, fall back to the
  /// nearest Overlay above the navigator's context.
  static OverlayState? _resolveOverlay(
    GlobalKey<NavigatorState> navigatorKey,
  ) {
    final navState = navigatorKey.currentState;
    final direct = navState?.overlay;
    if (direct != null) return direct;
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return null;
    return Overlay.maybeOf(ctx, rootOverlay: true) ?? Overlay.maybeOf(ctx);
  }

  static void _dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _current?.remove();
    _current = null;
  }
}

class _BannerHost extends StatefulWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onTap;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _BannerHost({
    required this.title,
    required this.actionLabel,
    required this.onTap,
    required this.onAction,
    required this.onDismiss,
  });

  @override
  State<_BannerHost> createState() => _BannerHostState();
}

class _BannerHostState extends State<_BannerHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;
  late final Animation<double> _opacity;

  /// Accumulated upward drag (in logical pixels). When it crosses
  /// [_dismissThreshold], we treat the gesture as a flick-to-dismiss.
  double _dragDy = 0;
  static const double _dismissThreshold = 24;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _animateOutAndDismiss() async {
    if (!mounted) return;
    if (_controller.status == AnimationStatus.reverse) return;
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _offset,
        child: FadeTransition(
          opacity: _opacity,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, mq.padding.top > 0 ? 4 : 8, 12, 0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (d) {
                  if (d.delta.dy < 0) {
                    _dragDy += -d.delta.dy;
                    if (_dragDy > _dismissThreshold) {
                      _dragDy = 0;
                      _animateOutAndDismiss();
                    }
                  }
                },
                onVerticalDragEnd: (_) => _dragDy = 0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap == null
                        ? null
                        : () {
                            widget.onTap!();
                            _animateOutAndDismiss();
                          },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.brandPrimaryDark,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.notifications_active_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ),
                          if (widget.actionLabel != null &&
                              widget.onAction != null) ...[
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                widget.onAction!();
                                _animateOutAndDismiss();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.14),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                widget.actionLabel!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
