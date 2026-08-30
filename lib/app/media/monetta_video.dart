/// Campaign film. Plays once, then holds the last frame. Poster first.
library;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../domain/campaign.dart';
import '../motion.dart';
import '../theme.dart';

class MonettaVideo extends StatefulWidget {
  const MonettaVideo({
    required this.campaign,
    required this.playing,
    this.onEnded,
    super.key,
  });

  final CampaignMedia campaign;
  final bool playing;
  final VoidCallback? onEnded;

  @override
  State<MonettaVideo> createState() => _MonettaVideoState();
}

class _MonettaVideoState extends State<MonettaVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    if (inWidgetTest) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _markEnded());
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _markEnded() {
    if (_ended) return;
    _ended = true;
    widget.onEnded?.call();
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    if (!mounted) return;
    if (reduceMotion(context)) {
      _markEnded();
      return;
    }
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.campaign.videoUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;
    controller.addListener(_onTick);
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(0);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _ready = true);
      if (widget.playing) await controller.play();
    } catch (_) {
      controller.removeListener(_onTick);
      await controller.dispose();
      if (_controller == controller) _controller = null;
      if (mounted) setState(() => _ready = false);
      _markEnded();
    }
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration;
    final position = controller.value.position;
    if (duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 80)) {
      _markEnded();
    }
  }

  @override
  void didUpdateWidget(covariant MonettaVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _controller;
    if (_ended || controller == null || !controller.value.isInitialized) {
      return;
    }
    if (widget.playing && !controller.value.isPlaying) {
      controller.play();
    } else if (!widget.playing && controller.value.isPlaying) {
      controller.pause();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    final controller = _controller;
    final showVideo =
        _ready && controller != null && controller.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          widget.campaign.posterAsset,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) =>
              ColoredBox(color: colors.mediaPlaceholder),
        ),
        if (showVideo)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
      ],
    );
  }
}
