import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue/modules/guided/mqtt_address.dart';
void main() {
  test('accepts explicit TLS and separate-port addresses', () {
    for(final address in ['mqtts://broker.example.com','broker.example.com','192.168.1.2','mqtts://[::1]']) {
      expect(()=>validateMqttAddress(address),returnsNormally);
    }
  });
  test('rejects web URLs, paths, embedded credentials and ports', () {
    for(final address in ['mqtts://','https://broker.example.com','mqtts://host/path','mqtts://user:secret@host','host:8883','host name','host?x=1']) {
      expect(()=>validateMqttAddress(address),throwsFormatException);
    }
  });
}
