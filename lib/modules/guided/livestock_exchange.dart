import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'livestock_protocol.dart';

Future<List<int>> livestockExchange(BluetoothCharacteristic c, List<int> request,
    {required bool Function(List<int>) accepts, Duration timeout = const Duration(seconds: 3)}) async {
  final result=Completer<List<int>>();
  var pending=<int>[];
  final subscription=c.onValueReceived.listen((wire){
    if(result.isCompleted)return;
    final single=livestockResponse(wire);
    if(accepts(single)){result.complete(single);return;}
    if(lsHex(single)==lsHex(request)){pending=[];return;}
    pending.addAll(wire);
    if(pending.length>512){pending=[];return;}
    final combined=livestockResponse(pending);
    if(accepts(combined))result.complete(combined);
    // Full unsolicited frames or echoes must not prefix the next response.
    if(single.length>=2 && (single.first==0x6a || single.first==0x6c))pending=[];
  });
  try {
    if(!c.isNotifying && (c.properties.notify || c.properties.indicate)) await c.setNotifyValue(true,timeout:5);
    await c.write(utf8.encode(lsHex(request)), withoutResponse: !c.properties.write, timeout:5);
    return await result.future.timeout(timeout);
  } finally { unawaited(subscription.cancel()); }
}
