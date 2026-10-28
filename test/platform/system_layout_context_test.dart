import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/platform/system_layout_context.dart';

void main() {
  test(
      'active regions exclude controls; inactive division does not reserve space',
      () {
    const area = Rect.fromLTWH(31, 47, 920, 600);
    const fold = Rect.fromLTWH(410, 0, 38, 800);
    const camera = Rect.fromLTWH(760, 47, 60, 72);
    const geometry = SystemLayoutContext(
      supported: true,
      divisions: [ReservedRegion(bounds: fold, active: true)],
      occlusions: [ReservedRegion(bounds: camera, active: true)],
    );
    final regions = geometry.usableRegions(area);
    expect(regions, isNotEmpty);
    for (final rect in regions) {
      expect(area.contains(rect.topLeft), isTrue);
      expect(rect.overlaps(fold), isFalse);
      expect(rect.overlaps(camera), isFalse);
    }
    const inactive = SystemLayoutContext(
      supported: true,
      divisions: [ReservedRegion(bounds: fold, active: false)],
    );
    expect(inactive.usableRegions(area), [area]);
  });

  testWidgets(
    'native listener delivers current snapshots and cancels on disposal',
    (tester) async {
      const channel = 'mx.monetta/system_layout';
      const codec = StandardMethodCodec();
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel(channel),
        (call) async {
          calls.add(call.method);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel(channel), null),
      );
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: MediaQueryData(size: Size(800, 600)),
            child: SystemLayoutHost(child: SizedBox()),
          ),
        ),
      );
      await tester.pump();
      expect(calls, ['listen']);
      void event(int sequence, {double width = 800, String edge = 'right'}) {
        ServicesBinding.instance.channelBuffers.push(
          channel,
          codec.encodeSuccessEnvelope({
            'sequence': sequence,
            'supported': true,
            'width': width,
            'height': 600.0,
            'barEdge': edge,
            'safeInsets': {
              'left': 11.0,
              'right': 63.0,
              'top': 0.0,
              'bottom': 21.0,
            },
            'divisions': [
              {
                'x': 390.0,
                'y': 0.0,
                'width': 0.0,
                'height': 600.0,
                'active': false,
              }
            ],
            'occlusions': <Object?>[],
          }),
          (_) {},
        );
      }

      event(2);
      await tester.pumpAndSettle();
      SystemLayoutContext current() => tester
          .widget<SystemLayoutScope>(find.byType(SystemLayoutScope))
          .geometry;
      expect(current().barEdge, SystemBarEdge.right);
      expect(current().safeInsets, const EdgeInsets.fromLTRB(11, 0, 63, 21));
      expect(current().divisions.single.active, isFalse);
      event(1, edge: 'left');
      await tester.pumpAndSettle();
      expect(
        current().barEdge,
        SystemBarEdge.right,
        reason: 'late snapshot is rejected',
      );
      event(3, width: 600);
      await tester.pumpAndSettle();
      expect(
        current().supported,
        isFalse,
        reason: 'old rotation basis cannot be applied',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(calls, ['listen', 'cancel']);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
