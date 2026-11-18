import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue/modules/remote/remote_page.dart';

void main() {
  testWidgets('Support works without a network client and has no submission form',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RemotePage()));
    expect(find.text('Support'), findsOneWidget);
    expect(find.text('alessandro.paperi@lansitec.com'), findsOneWidget);
    expect(find.textContaining('does not upload data'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Fetch Config'), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
  });
}
