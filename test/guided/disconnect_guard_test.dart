import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue/modules/guided/disconnect_guard.dart';

void main() {
  testWidgets('back asks, cancel keeps connection, confirm leaves', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        home: const Scaffold(body: Text('Devices')),
      ),
    );
    key.currentState!.push(
      MaterialPageRoute(
        builder:
            (_) => const DisconnectGuard(
              connected: true,
              pending: 2,
              child: Scaffold(appBar: null, body: Text('Connected device')),
            ),
      ),
    );
    await tester.pumpAndSettle();
    key.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Disconnect device?'), findsOneWidget);
    expect(find.text('2 unsent changes will be discarded.'), findsOneWidget);
    await tester.tap(find.text('Stay connected'));
    await tester.pumpAndSettle();
    expect(find.text('Connected device'), findsOneWidget);
    key.currentState!.maybePop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(find.text('Devices'), findsOneWidget);
    expect(find.text('Connected device'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
