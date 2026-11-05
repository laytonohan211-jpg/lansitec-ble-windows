import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue/utils/ble_scan_coordinator.dart';
void main() {
 TestWidgetsFlutterBinding.ensureInitialized();
 test('Connection holds block both scan owners until the entire session ends', () async {
  final coordinator = BleScanCoordinator.instance;
  await coordinator.holdForConnection();
  await coordinator.holdForConnection();
  try {
   await coordinator.start(BleScanCoordinator.devicesOwner);
   await coordinator.start(BleScanCoordinator.batchConfigOwner);
   expect(coordinator.isOwnerActive(BleScanCoordinator.devicesOwner), false);
   expect(coordinator.isOwnerActive(BleScanCoordinator.batchConfigOwner), false);
   coordinator.releaseConnectionHold();
   await coordinator.start(BleScanCoordinator.devicesOwner);
   expect(coordinator.isOwnerActive(BleScanCoordinator.devicesOwner), false);
  } finally { coordinator.releaseConnectionHold(); }
 });
}
