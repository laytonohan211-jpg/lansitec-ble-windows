import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue/modules/guided/help_page.dart';

void main() {
  testWidgets(
    'beacon guide requires manual model selection and validates interval',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: BeaconGuide())),
        ),
      );
      expect(find.text('Create interval value'), findsNothing);
      await tester.tap(find.text('Select beacon model'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('B003').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('116321'), findsOneWidget);
      await tester.ensureVisible(find.text('Create interval value'));
      await tester.tap(find.text('Create interval value'));
      await tester.pumpAndSettle();
      expect(find.text('05000000'), findsOneWidget);
      await tester.ensureVisible(find.byType(TextFormField));
      await tester.enterText(find.byType(TextFormField), '155');
      await tester.ensureVisible(find.text('Create interval value'));
      await tester.tap(find.text('Create interval value'));
      await tester.pumpAndSettle();
      expect(find.text('05000000'), findsNothing);
      expect(
        find.text('Use 100–10000 milliseconds in steps of 100.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
