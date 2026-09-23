import 'package:equatable/equatable.dart';
import 'package:flutter_blue/modules/device/domain/failed_device.dart';
import 'package:flutter_blue/modules/device/domain/updated_device.dart';

class DeviceState extends Equatable {
  final List<UpdatedDevice> updatedDevices;
  final List<FailedDevice> failedDevices;

  // 新增扫描配置
  final String selectedHardware;
  final int? selectedTxPower;
  final bool txPowerEnabled;
  final bool intervalEnabled;
  final String nameText;
  final String intervalText;

  const DeviceState({
    this.updatedDevices = const [],
    this.failedDevices = const [],
    this.selectedHardware = 'V1.0',
    this.selectedTxPower = 6,
    this.txPowerEnabled = true,
    this.intervalEnabled = false,
    this.nameText = '0000-',
    this.intervalText = '5000',
  });

  DeviceState copyWith({
    List<UpdatedDevice>? updatedDevices,
    List<FailedDevice>? failedDevices,
    String? selectedHardware,
    int? selectedTxPower,
    bool? txPowerEnabled,
    bool? intervalEnabled,
    String? nameText,
    String? intervalText,
  }) {
    return DeviceState(
      updatedDevices: updatedDevices ?? this.updatedDevices,
      failedDevices: failedDevices ?? this.failedDevices,
      selectedHardware: selectedHardware ?? this.selectedHardware,
      selectedTxPower: selectedTxPower ?? this.selectedTxPower,
      txPowerEnabled: txPowerEnabled ?? this.txPowerEnabled,
      intervalEnabled: intervalEnabled ?? this.intervalEnabled,
      nameText: nameText ?? this.nameText,
      intervalText: intervalText ?? this.intervalText,
    );
  }

  @override
  List<Object?> get props => [
    updatedDevices,
    failedDevices,
    selectedHardware,
    selectedTxPower,
    txPowerEnabled,
    intervalEnabled,
    nameText,
    intervalText,
  ];

  @override
  String toString() {
    return 'DeviceState(updatedDevices: $updatedDevices, failedDevices: $failedDevices, '
        'selectedHardware: $selectedHardware, selectedTxPower: $selectedTxPower, '
        'txPowerEnabled: $txPowerEnabled, intervalEnabled: $intervalEnabled, '
        'nameText: $nameText, intervalText: $intervalText)';
  }
}
