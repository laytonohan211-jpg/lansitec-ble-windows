import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue/modules/guided/device_setup_page.dart';
import 'package:flutter_blue/modules/guided/device_profile.dart';
import 'package:flutter_blue/modules/guided/protocol.dart';
import 'feedback_test.dart' show FakeDevice, FakeService;
import 'device_setup_test.dart' show Setting;

void main() {
  testWidgets('optional device screen preview', (tester) async {
    final font = Platform.environment['QA_FONT_PATH'];
    if (font == null) return;
    await tester.runAsync(() async {
      await (FontLoader('Roboto')..addFont(
        File(font).readAsBytes().then((b) => ByteData.sublistView(b)),
      )).load();
    });
    await tester.binding.setSurfaceSize(const Size(360, 800));
    final d = FakeDevice(),
        c = Setting('ff11'),
        r = Setting('ff15'),
        key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF176BDA),
            ),
            scaffoldBackgroundColor: const Color(0xFFF5F7FA),
          ),
          home: DeviceSetupPage(
            device: d,
            services: [
              FakeService([c, r]),
            ],
            radioFamily: RadioFamily.cat1,
            initialModel: models[3],
            persist: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final section in ['Overview', 'Tracking']) {
      if (section != 'Overview') {
        await tester.tap(find.text(section));
        await tester.pumpAndSettle();
      }
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final picture = await boundary.toImage();
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '../../tmp/$section.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await c.values.close();
    await r.values.close();
    await d.changes.close();
  });
}
