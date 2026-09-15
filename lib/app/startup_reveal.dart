import 'package:flutter/material.dart';

import 'theme.dart';

/// Keeps an opaque launch surface above the first frame of the ready app.
class StartupReveal extends StatefulWidget {
  const StartupReveal({required this.ready, required this.child, super.key});

  final bool ready;
  final Widget child;

  @override
  State<StartupReveal> createState() => _StartupRevealState();
}

class _StartupRevealState extends State<StartupReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) setState(() {});
    });
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _revealWhenReady();
  }

  @override
  void didUpdateWidget(covariant StartupReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    _revealWhenReady();
  }

  void _revealWhenReady() {
    if (!widget.ready || _scheduled) return;
    _scheduled = true;
    // The navigator and home screen paint under the opaque splash first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finished = _controller.isCompleted;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            excluding: !finished,
            child: ExcludeFocus(
              excluding: !finished,
              // Let home entrance animations settle beneath the splash.
              child: widget.child,
            ),
          ),
          if (!finished)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final reveal =
                    const Interval(0, 0.55, curve: Curves.easeInOutCubic)
                        .transform(_controller.value);
                final fade = const Interval(0.75, 1, curve: Curves.easeInOut)
                    .transform(_controller.value);
                return AbsorbPointer(
                  child: Opacity(
                    opacity: 1 - fade,
                    child: ColoredBox(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: Center(
                        child: Semantics(
                          label: 'Monetta',
                          image: true,
                          child: ExcludeSemantics(
                            child: ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                // The first 30px of the 132px brand asset are M.
                                // Reveal the same bitmap so the letter never swaps.
                                widthFactor: 30 / 132 + (1 - 30 / 132) * reveal,
                                heightFactor: 1,
                                child: const SizedBox(
                                  width: 132 / 38 * 48,
                                  height: 48,
                                  child: MonettaWordmark(height: 48),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
