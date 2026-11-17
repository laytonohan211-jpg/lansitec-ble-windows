import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_blue/locator.dart';
import 'package:flutter_blue/utils/dio/dio_client.dart';
import 'package:flutter_blue/modules/remote/remote_page.dart';

class RecordedClient implements DioClient {
  int requests = 0;
  @override dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #get) {
      requests++;
      return Future<Response<dynamic>>.value(Response<dynamic>(requestOptions:RequestOptions(path:'/captchaImage'),data:{'code':200,'msg':'OK'}));
    }
    return super.noSuchMethod(invocation);
  }
}
void main() {
  testWidgets('Remote lookup sends nothing until explicitly approved', (tester) async {
    await tester.binding.setSurfaceSize(const Size(700,1200));
    final client=RecordedClient();
    getIt.registerSingleton<DioClient>(client);
    addTearDown(() async { await getIt.reset(); await tester.binding.setSurfaceSize(null); });
    await tester.pumpWidget(const MaterialApp(home:RemotePage()));
    await tester.enterText(find.byType(TextField).first,'test-device');
    await tester.tap(find.text('Fetch Config')); await tester.pumpAndSettle();
    expect(client.requests,0);
    expect(find.textContaining('asset.lansitec.com'),findsOneWidget);
    await tester.tap(find.text('Cancel')); await tester.pumpAndSettle();
    expect(client.requests,0);
    await tester.tap(find.text('Fetch Config')); await tester.pumpAndSettle();
    await tester.tap(find.text('Send')); await tester.pumpAndSettle();
    expect(client.requests,1);
  });
}
