/// Welcome logo written letter by letter (motion spec «Logo de Welcome», §1–§8).
///
/// One bitmap, seven rectangular clips (M-O-N-E-T-T-A) revealed left to right
/// in 1000 ms with the house curve. Plays once per install: when it finishes
/// or is cut short, `logoWritten` is persisted and it never plays again.
/// Nothing here blocks input — tapping «Comenzar» jumps to the final frame.
library;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'motion.dart';
import 'theme.dart';

const Duration kLogoWrite = Duration(milliseconds: 1000);

/// Left edge of each letter as a fraction of the asset width, measured on
/// `assets/images/3.0x/logo_monetta.png` (396 px). Cuts sit on the column of
/// least alpha mass between neighbours (spec §3): 92, 151, 205, 260, 304, 325.
const List<double> kLogoLetterStarts = [
  0,
  92 / 396,
  151 / 396,
  205 / 396,
  260 / 396,
  304 / 396,
  325 / 396,
];

/// Per-letter windows in ms (spec §4). M carries the teardrop, so it is longer.
const List<int> kLogoLetterTimesMs = [0, 220, 350, 480, 610, 740, 870, 1000];

const double kLogoAspect = 396 / 113;

enum WelcomeLogoPhase { notStarted, playing, done }

abstract interface class LogoWrittenStore {
  Future<bool> read();
  Future<void> markWritten();
}

class SharedPreferencesLogoWrittenStore implements LogoWrittenStore {
  static const String key = 'welcome.logoWritten';

  @override
  Future<bool> read() async =>
      (await SharedPreferences.getInstance()).getBool(key) ?? false;

  @override
  Future<void> markWritten() async =>
      (await SharedPreferences.getInstance()).setBool(key, true);
}

/// App-level state that outlives Welcome rebuilds and remounts (spec §6).
class WelcomeLogoController extends ChangeNotifier {
  WelcomeLogoController({LogoWrittenStore? store})
      : _store = store ?? SharedPreferencesLogoWrittenStore();

  final LogoWrittenStore _store;
  WelcomeLogoPhase _phase = WelcomeLogoPhase.notStarted;
  double _progress = 0;
  bool _restored = false;

  WelcomeLogoPhase get phase => _phase;
  double get progress => _progress;
  bool get restored => _restored;

  Future<void> restore() async {
    bool written;
    try {
      written = await _store.read();
    } catch (_) {
      written = false;
    }
    _restored = true;
    if (written) _setDone(persist: false);
  }

  void start() {
    if (_phase != WelcomeLogoPhase.notStarted) return;
    // Same pixels as notStarted (empty clip), so no listener needs a rebuild;
    // this also keeps start() safe to call during build.
    _phase = WelcomeLogoPhase.playing;
    // Persist on entering playing (spec §12): a cold start after this point
    // never replays, even if the app dies mid-write.
    _store.markWritten().catchError((Object _) {});
  }

  void advance(double progress) {
    if (_phase != WelcomeLogoPhase.playing) return;
    if (progress >= 1) {
      finish();
      return;
    }
    _progress = progress;
    notifyListeners();
  }

  /// Jumps to the final frame (tap, geometry change, background, reduce
  /// motion, unmount, or natural end). Idempotent.
  void finish() => _setDone(persist: _phase == WelcomeLogoPhase.notStarted);

  void _setDone({required bool persist}) {
    if (_phase == WelcomeLogoPhase.done) return;
    _phase = WelcomeLogoPhase.done;
    _progress = 1;
    notifyListeners();
    if (persist) _store.markWritten().catchError((Object _) {});
  }
}

class WelcomeLogoScope extends InheritedNotifier<WelcomeLogoController> {
  const WelcomeLogoScope({
    required WelcomeLogoController super.notifier,
    required super.child,
    super.key,
  });

  static WelcomeLogoController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WelcomeLogoScope>()?.notifier;
}

/// Revealed width of each letter for an overall [progress] (0..1).
List<double> logoLetterReveal(double progress) {
  final t = progress.clamp(0.0, 1.0) * kLogoWrite.inMilliseconds;
  return [
    for (var i = 0; i < 7; i++)
      () {
        final a = kLogoLetterTimesMs[i], b = kLogoLetterTimesMs[i + 1];
        if (t <= a) return 0.0;
        if (t >= b) return 1.0;
        return kMotionCurve.transform((t - a) / (b - a));
      }(),
  ];
}

class _LetterClipper extends CustomClipper<Path> {
  _LetterClipper(this.progress);
  final double progress;

  @override
  Path getClip(Size size) {
    final path = Path();
    final reveal = logoLetterReveal(progress);
    for (var i = 0; i < 7; i++) {
      if (reveal[i] <= 0) continue;
      final left = kLogoLetterStarts[i] * size.width;
      final right = (i == 6 ? 1.0 : kLogoLetterStarts[i + 1]) * size.width;
      path.addRect(
        Rect.fromLTRB(left, 0, left + (right - left) * reveal[i], size.height),
      );
    }
    return path;
  }

  @override
  bool shouldReclip(_LetterClipper old) => old.progress != progress;
}

/// Pure render of the logo at [progress]. At 1 it is the unclipped asset.
class MonettaLogoWrite extends StatelessWidget {
  const MonettaLogoWrite({required this.progress, this.height = 48, super.key});

  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    final image = MonettaWordmark(height: height);
    return Semantics(
      label: 'Monetta',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: height * kLogoAspect,
          child: progress >= 1
              ? image
              : ClipPath(clipper: _LetterClipper(progress), child: image),
        ),
      ),
    );
  }
}

/// Welcome's logo: drives [WelcomeLogoController] with a ticker and applies
/// the jump-to-end rules. Without a controller in scope it is static.
class WelcomeLogo extends StatefulWidget {
  const WelcomeLogo({this.height = 48, super.key});
  final double height;

  @override
  State<WelcomeLogo> createState() => _WelcomeLogoState();
}

class _WelcomeLogoState extends State<WelcomeLogo>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  WelcomeLogoController? _controller;
  Duration? _tickBase;
  double _progressAtBase = 0;
  Size? _windowSize;
  bool _forceFinal = false;

  bool get _motion => !reduceMotion(context);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = WelcomeLogoScope.maybeOf(context);
    _controller = controller;
    if (controller == null) return;
    // Fold, rotation, resize or Split View change the window and so the
    // logo's final box: jump to the end (spec §6). Inset-only snapshots keep
    // the window size, so the write finishes normally.
    final window = MediaQuery.sizeOf(context);
    final previous = _windowSize;
    _windowSize = window;
    if (previous != null && previous != window) {
      if (controller.phase == WelcomeLogoPhase.playing) _finishSoon();
      return;
    }
    if (!_motion) {
      // Reduce motion, including when it turns on mid-write: full logo.
      if (controller.phase != WelcomeLogoPhase.done) _finishSoon();
      return;
    }
    if (controller.phase == WelcomeLogoPhase.notStarted &&
        controller.restored) {
      controller.start();
    }
    if (controller.phase == WelcomeLogoPhase.playing && !_ticker.isActive) {
      // Resume (remount / rebuild) from where the app-level state is.
      _tickBase = null;
      _progressAtBase = controller.progress;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final controller = _controller;
    if (controller == null || controller.phase != WelcomeLogoPhase.playing) {
      _ticker.stop();
      return;
    }
    _tickBase ??= elapsed;
    final ms = (elapsed - _tickBase!).inMicroseconds / 1000;
    controller.advance(_progressAtBase + ms / kLogoWrite.inMilliseconds);
    if (controller.phase == WelcomeLogoPhase.done) _ticker.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _finish();
  }

  /// Paints the final frame now and commits `done` after this build.
  void _finishSoon() {
    _ticker.stop();
    _forceFinal = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _finish();
    });
  }

  void _finish() {
    _ticker.stop();
    _controller?.finish();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    // Unmount cancels and marks done — but a remount within the same frame
    // (rebuild with a new key, theme change) must not; only the controller
    // knows, so we leave it playing and the next mount resumes it. If no
    // Welcome remounts, the gate finishes it on dismiss.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final height = widget.height;
    if (controller == null || !controller.restored) {
      return MonettaLogoWrite(progress: 1, height: height);
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final progress = _forceFinal
            ? 1.0
            : switch (controller.phase) {
                WelcomeLogoPhase.done => 1.0,
                WelcomeLogoPhase.notStarted => 0.0,
                WelcomeLogoPhase.playing => controller.progress,
              };
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _finish,
          child: MonettaLogoWrite(progress: progress, height: height),
        );
      },
    );
  }
}
