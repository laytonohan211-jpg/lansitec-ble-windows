import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue/modules/guided/guided_page.dart';
import 'package:flutter_blue/modules/guided/protocol.dart';

void main() {
  testWidgets(
    'offline workflow generates command without enabling Bluetooth send',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(480, 1100));
      await tester.pumpWidget(const MaterialApp(home: GuidedPage()));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '3. Create command'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('1. Select your exact device'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(models.first).last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('3. Create command'));
      await tester.tap(find.text('3. Create command'));
      await tester.pumpAndSettle();
      expect(find.text('A00100780001'), findsOneWidget);
      expect(find.text('4. Send by Bluetooth'), findsNothing);
      expect(find.text('Network & MQTT'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
