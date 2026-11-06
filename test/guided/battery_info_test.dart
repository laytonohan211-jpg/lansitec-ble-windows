import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_blue/modules/guided/battery_info.dart';

class BatteryField extends BluetoothCharacteristic {
  BatteryField(String id, this.bytes, {this.writable = false, this.label}) : super(
    remoteId: const DeviceIdentifier('battery-test'), serviceUuid: Guid('fff0'), characteristicUuid: Guid(id));
  final List<int> bytes;
  final bool writable;
  final String? label;
  int reads = 0;
  @override CharacteristicProperties get properties => CharacteristicProperties(read:true,write:writable);
  @override List<BluetoothDescriptor> get descriptors => label == null ? [] : [BatteryDescription(label!)];
  @override Future<List<int>> read({int timeout=15}) async { reads++; return bytes; }
}
class BatteryDescription implements BluetoothDescriptor {
  BatteryDescription(this.label);
  final String label;
  @override Guid get uuid => Guid('2901');
  @override Future<List<int>> read({int timeout=15}) async => utf8.encode(label);
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class BatteryService implements BluetoothService {
  BatteryService(String id, this.characteristics):uuid=Guid(id);
  @override final Guid uuid;
  @override final List<BluetoothCharacteristic> characteristics;
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
void main() {
  test('standard byte vs proprietary UTF-8 percentage are distinct', () {
    expect(batteryPercent([85],standard:true),'85%');
    expect(batteryPercent(utf8.encode('85%\u0000')),'85%');
    expect(batteryPercent([85]),isNull);
    expect(batteryPercent(utf8.encode('101%')),isNull);
    expect(batteryPercent([255],standard:true),isNull);
    expect(batteryPercent(utf8.encode('3.57V')),isNull);
    expect(batteryPercent([0],standard:true),'0%');
  });
  test('Livestock capture reads FFF0 FF8C, other profiles do not assume its meaning', () async {
    final c=BatteryField('ff8c',utf8.encode('85%'));
    final services=[BatteryService('fff0',[c])];
    expect(await readBattery(services,livestock:true,active:()=>true),'85%');
    expect(c.reads,1);
    expect(await readBattery(services,active:()=>true),isNull);
    expect(c.reads,1);
  });
  test('standard Battery Service works for any model and validates service', () async {
    final c=BatteryField('2a19',[42]);
    expect(await readBattery([BatteryService('180f',[c])],active:()=>true),'42%');
    expect(await readBattery([BatteryService('fff0',[c])],active:()=>true),isNull);
  });
  test('self-described battery field can be discovered without model map', () async {
    final c=BatteryField('ff99',utf8.encode('67%'),label:'Battery Level');
    expect(await readBattery([BatteryService('fff0',[c])],active:()=>true),'67%');
  });
  test('no guess for legacy writable interval, duplicate field, or inactive session', () async {
    final c=BatteryField('ff8c',utf8.encode('85%'),writable:true);
    expect(await readBattery([BatteryService('fff0',[c])],livestock:true,active:()=>true),isNull);
    expect(c.reads,0);
    final b=BatteryField('ff8c',utf8.encode('85%'));
    expect(await readBattery([BatteryService('fff0',[b,b])],livestock:true,active:()=>true),isNull);
    expect(await readBattery([BatteryService('fff0',[b])],livestock:true,active:()=>false),isNull);
    expect(b.reads,0);
  });
}
