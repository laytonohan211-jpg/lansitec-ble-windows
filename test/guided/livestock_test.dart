import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_blue/modules/guided/livestock_protocol.dart';
import 'package:flutter_blue/modules/guided/livestock_exchange.dart';
import 'package:flutter_blue/modules/guided/livestock_setup_page.dart';
import 'package:flutter_blue/modules/guided/lora_catalog_page.dart';
import 'package:flutter_blue/modules/guided/lorawan_protocol.dart';
import 'feedback_test.dart' show FakeDevice,FakeService;

class LivestockGatt extends BluetoothCharacteristic {
  LivestockGatt():super(remoteId:const DeviceIdentifier('test-device'),serviceUuid:Guid('fff0'),characteristicUuid:Guid('ff84'));
  final stream=StreamController<List<int>>.broadcast(sync:true);
  final sent=<String>[];
  final stored=<int,List<int>>{for(final p in livestockParameters)p.id:p.width==16?List.filled(16,0):p.encode('${p.min*p.step}')};
  bool silent=false;
  @override CharacteristicProperties get properties=>const CharacteristicProperties(write:true,notify:true);
  @override bool get isNotifying=>true;
  @override Stream<List<int>> get onValueReceived=>stream.stream;
  @override Future<void> write(List<int> bytes,{bool withoutResponse=false,bool allowLongWrite=false,int timeout=15}) async {
    final text=utf8.decode(bytes);sent.add(text);if(silent)return;
    final b=lsBytes(text),id=b[1];
    if(b[0]==0xa0){stored[id]=b.sublist(2);stream.add(utf8.encode('6A${lsHex([id])}'));}
    else if(b[0]==0xb0){final v=id==12?lsBytes('1203000502001E'):id==48?[0]:stored[id]!;stream.add(utf8.encode(lsHex([0x6b,id,...v])));}
  }
}
void main(){
  test('Livestock v1.2 scalar vectors, bounds and independent positioning',(){
    final heartbeat=livestockParameters.firstWhere((p)=>p.id==6);
    expect(lsHex([0xa0,6,...heartbeat.encode('600')]),'A00614');
    expect(heartbeat.decode([0x14]),'600');
    expect(()=>heartbeat.encode('0'),throwsFormatException);
    expect(()=>heartbeat.encode('601'),throwsFormatException);
    final period=livestockParameters.firstWhere((p)=>p.id==4);
    expect(period.encode('129600'),[0x65,0x40]);
    expect(()=>period.encode('129605'),throwsFormatException);
    expect(livestockResponse(utf8.encode('6B0614\u0000')),[0x6b,6,0x14]);
    expect(livestockResponse([0x6b,6,0x14]),[0x6b,6,0x14]);
    expect(()=>validateLivestockRelations(16,'70',{17:'80'}),throwsFormatException);
    expect(()=>validateLivestockRelations(21,'11',{22:'10'}),throwsFormatException);
    expect(()=>validateLivestockRelations(23,'1',{}),throwsFormatException);
  });
  test('Polygon documented vector and invalid geometry',(){
    final b=livestockPolygon('120,30\n120.01,30\n120,30.01');
    expect(lsHex(b),'D00347868C0011E1A300478812A011E1A30047868C0011E329A0');
    expect(livestockPolygon(polygonText(b.sublist(1))),b);
    for(final text in ['120,30\n120,30.01\n120.01,30','0,0\n1,1\n0,1\n1,0','0,0\n1,1\n2,2','0,0\n0,0\n1,1','181,0\n0,0\n1,1'])expect(()=>livestockPolygon(text),throwsFormatException);
  });
  test('Asset rule validates report blocks, filter lengths and overlap',(){
    validateAssetRule(lsBytes('1203000502001E'));
    validateAssetRule(lsBytes('12010918F2A52D43E0AB489CB64C4A830014672002191C'));
    for(final s in ['10020001','11010001FF','11030006','12020002020104','11010000FF'])expect(()=>validateAssetRule(lsBytes(s)),throwsFormatException);
  });
  test('Transport sends ASCII and times out without manufacturing an acknowledgement',()async{
    final c=LivestockGatt();
    final reply=await livestockExchange(c,[0xa0,6,20],accepts:(b)=>b.length==2&&b[0]==0x6a&&b[1]==6);
    expect(reply,[0x6a,6]);expect(c.sent.single,'A00614');
    c.silent=true;
    await expectLater(livestockExchange(c,[0xb0,6],accepts:(b)=>b.length==3&&b[0]==0x6b,timeout:const Duration(milliseconds:10)),throwsA(isA<TimeoutException>()));
    await c.stream.close();
  });
  testWidgets('Livestock automatically queries settings and applies only one edited value with readback',(tester)async{
    await tester.binding.setSurfaceSize(const Size(600,1000));addTearDown(()=>tester.binding.setSurfaceSize(null));
    final d=FakeDevice(),c=LivestockGatt();c.stored[6]=[120];
    await tester.pumpWidget(MaterialApp(home:LivestockSetupPage(device:d,services:[FakeService([c])])));
    await tester.pumpAndSettle();
    expect(c.sent.every((s)=>s.startsWith('B0')),isTrue);
    expect(c.sent,contains('B006'));expect(c.sent,contains('B030'));
    await tester.scrollUntilVisible(find.text('Heartbeat interval'),200,scrollable:find.byType(Scrollable).first);
    await tester.tap(find.text('Heartbeat interval'));await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField),'600');
    await tester.tap(find.text('Apply'));await tester.pumpAndSettle();
    expect(c.sent.where((s)=>s.startsWith('A0')),['A00614']);
    expect(c.sent.last,'B006');expect(find.text('600 s'),findsOneWidget);
    await tester.pumpWidget(const SizedBox());await tester.pump(const Duration(seconds:1));await d.changes.close();await c.stream.close();
  });
  test('Additional model layouts and downlinks use their own formats',(){
    for(final m in [LoRaModel.asset,LoRaModel.flex,LoRaModel.label]){
      final p={for(final p in loRaParameters(m))p.key:p.preset};expect(loRaSettings(m,p),'9B003C016878020504');
    }
    expect(loRaSettings(LoRaModel.helmet,{for(final p in loRaParameters(LoRaModel.helmet))p.key:p.preset}),'9B3832003C016878020504');
    expect(extraCommand('PT100 Sensor','Report interval',{'value':'600'},1),'90003C');
    expect(extraCommand('UWB Anchor','Heartbeat',{'value':'3600'},1),'A00100780001');
    expect(extraCommand('UWB Anchor','Advertising interval',{'value':'8000'},2),'A05E00001F400002');
    expect(extraCommand('Rotary Valve Sensor','Restart',{},1),'A300');
    expect(extraOperations('Rotary Valve Sensor'),isNot(contains('Heartbeat')));
    expect(extraOperations('UWB Tracker'),isNot(contains('Position interval')));
  });
}
