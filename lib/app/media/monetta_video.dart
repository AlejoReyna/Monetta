/// Muted looping campaign film. Poster first; stream never leaves a grey void.
library;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../domain/campaign.dart';
import '../motion.dart';

class MonettaVideo extends StatefulWidget {
  const MonettaVideo({
    required this.campaign,
    required this.playing,
    super.key,
  });

  final CampaignMedia campaign;
  final bool playing;

  @override
  State<MonettaVideo> createState() => _MonettaVideoState();
}

class _MonettaVideoState extends State<MonettaVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (!inWidgetTest) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  Future<void> _start() async {
    if (!mounted || reduceMotion(context)) return;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.campaign.videoUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _ready = true);
      if (widget.playing) await controller.play();
    } catch (_) {
      await controller.dispose();
      if (_controller == controller) _controller = null;
      if (mounted) setState(() => _ready = false);
    }
  }

  @override
  void didUpdateWidget(covariant MonettaVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (widget.playing && !controller.value.isPlaying) {
      controller.play();
    } else if (!widget.playing && controller.value.isPlaying) {
      controller.pause();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFF5F5F5)),
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
