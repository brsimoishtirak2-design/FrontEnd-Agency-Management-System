import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Standard "content enters the screen" animation: a 200ms fade
/// combined with a tiny 2% upward slide.
///
/// Use to animate the data panel into view after a skeleton loader,
/// or any chunk of content that newly appears. Wrapping is cheap —
/// flutter_animate plays the animation once per Element instance,
/// so subsequent setState rebuilds inside the wrapped subtree do
/// not retrigger it.
class AppEnter extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const AppEnter({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  Widget build(BuildContext context) {
    return child
        .animate()
        .fadeIn(duration: duration)
        .slideY(begin: 0.02, end: 0, duration: duration);
  }
}
