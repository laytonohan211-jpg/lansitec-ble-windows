import 'package:equatable/equatable.dart';
import 'package:flutter_blue/modules/device/domain/failed_device.dart';
import 'package:flutter_blue/modules/device/domain/updated_device.dart';

abstract class DeviceEvent extends Equatable {
  const DeviceEvent();

  @override
  List<Object?> get props => [];
}

/// 从 Hive 加载成功设备列表
class LoadUpdatedDevices extends DeviceEvent {
  const LoadUpdatedDevices();
}

/// 从 Hive 加载失败设备列表
class LoadFailedDevices extends DeviceEvent {
  const LoadFailedDevices();
}

/// 添加成功设备
class AddUpdatedDevice extends DeviceEvent {
  final UpdatedDevice device;
  const AddUpdatedDevice(this.device);

  @override
  List<Object?> get props => [device];
}

/// 添加失败设备
class AddFailedDevice extends DeviceEvent {
  final FailedDevice device;
  const AddFailedDevice(this.device);

  @override
  List<Object?> get props => [device];
}

/// 从成功设备列表删除某个设备
class RemoveUpdatedDevice extends DeviceEvent {
  final UpdatedDevice device;
  const RemoveUpdatedDevice(this.device);

  @override
  List<Object?> get props => [device];
}

/// 从失败设备列表删除某个设备
class RemoveFailedDevice extends DeviceEvent {
  final FailedDevice device;
  const RemoveFailedDevice(this.device);

  @override
  List<Object?> get props => [device];
}

/// 清空成功设备
class ClearUpdatedDevices extends DeviceEvent {}

/// 清空失败设备
class ClearFailedDevices extends DeviceEvent {}

/// 新增事件：更新扫描页面配置
class UpdateScanConfig extends DeviceEvent {
  final String? selectedHardware;
  final int? selectedTxPower;
  final bool? txPowerEnabled;
  final bool? intervalEnabled;
  final String? nameText;
  final String? intervalText;

  const UpdateScanConfig({
    this.selectedHardware,
    this.selectedTxPower,
    this.txPowerEnabled,
    this.intervalEnabled,
    this.nameText,
    this.intervalText,
  });

  @override
  List<Object?> get props => [
    selectedHardware,
    selectedTxPower,
    txPowerEnabled,
    intervalEnabled,
    nameText,
    intervalText,
  ];
}
