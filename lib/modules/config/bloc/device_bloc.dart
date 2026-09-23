import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue/modules/device/domain/failed_device.dart';

import 'package:flutter_blue/modules/device/domain/updated_device.dart';
import 'package:hive/hive.dart';

import 'device_events.dart';
import 'device_states.dart';

class DeviceBloc extends Bloc<DeviceEvent, DeviceState> {
  // Hive box
  late Box _updatedBox;
  late Box _failedBox;

  // 内存列表
  final List<UpdatedDevice> _updatedDevices = [];
  final List<FailedDevice> _failedDevices = [];

  DeviceBloc() : super(const DeviceState()) {
    // 事件处理
    on<LoadUpdatedDevices>(_onLoadUpdatedDevices);
    on<LoadFailedDevices>(_onLoadFailedDevices);
    on<AddUpdatedDevice>(_onAddUpdatedDevice);
    on<AddFailedDevice>(_onAddFailedDevice);
    on<RemoveUpdatedDevice>(_onRemoveUpdatedDevice);
    on<RemoveFailedDevice>(_onRemoveFailedDevice);
    on<ClearUpdatedDevices>(_onClearUpdatedDevices);
    on<ClearFailedDevices>(_onClearFailedDevices);
    on<UpdateScanConfig>(_onUpdateScanConfig);
  }

  /// 初始化 Hive 并触发加载事件
  Future<void> initHive() async {
    _updatedBox = await Hive.openBox('updated_devices');
    _failedBox = await Hive.openBox('failed_devices');

    add(const LoadUpdatedDevices());
    add(const LoadFailedDevices());
  }

  // 加载成功设备
  Future<void> _onLoadUpdatedDevices(
    LoadUpdatedDevices event,
    Emitter<DeviceState> emit,
  ) async {
    final updatedFromHive =
        _updatedBox.values
            .map((e) => UpdatedDevice.fromMap(Map<String, dynamic>.from(e)))
            .toList();
    _updatedDevices
      ..clear()
      ..addAll(updatedFromHive);

    emit(state.copyWith(updatedDevices: List.from(_updatedDevices)));
  }

  // 加载失败设备
  Future<void> _onLoadFailedDevices(
    LoadFailedDevices event,
    Emitter<DeviceState> emit,
  ) async {
    final failedFromHive =
        _failedBox.values
            .map((e) => FailedDevice.fromMap(Map<String, dynamic>.from(e)))
            .toList();
    _failedDevices
      ..clear()
      ..addAll(failedFromHive);

    emit(state.copyWith(failedDevices: List.from(_failedDevices)));
  }

  // 添加成功设备
  Future<void> _onAddUpdatedDevice(
    AddUpdatedDevice event,
    Emitter<DeviceState> emit,
  ) async {
    _updatedDevices.add(event.device);
    await _updatedBox.put(event.device.id, event.device.toMap());
    emit(state.copyWith(updatedDevices: List.from(_updatedDevices)));
  }

  // 添加失败设备
  Future<void> _onAddFailedDevice(
    AddFailedDevice event,
    Emitter<DeviceState> emit,
  ) async {
    _failedDevices.add(event.device);
    await _failedBox.put(event.device.id, event.device.toMap());
    emit(state.copyWith(failedDevices: List.from(_failedDevices)));
  }

  // 删除成功设备
  Future<void> _onRemoveUpdatedDevice(
    RemoveUpdatedDevice event,
    Emitter<DeviceState> emit,
  ) async {
    _updatedDevices.removeWhere((d) => d.id == event.device.id);
    await _updatedBox.delete(event.device.id);
    emit(state.copyWith(updatedDevices: List.from(_updatedDevices)));
  }

  // 删除失败设备
  Future<void> _onRemoveFailedDevice(
    RemoveFailedDevice event,
    Emitter<DeviceState> emit,
  ) async {
    _failedDevices.removeWhere((d) => d.id == event.device.id);
    await _failedBox.delete(event.device.id);
    emit(state.copyWith(failedDevices: List.from(_failedDevices)));
  }

  // 清空成功设备
  Future<void> _onClearUpdatedDevices(
    ClearUpdatedDevices event,
    Emitter<DeviceState> emit,
  ) async {
    _updatedDevices.clear();
    await _updatedBox.clear();
    emit(state.copyWith(updatedDevices: List.from(_updatedDevices)));
  }

  // 清空失败设备
  Future<void> _onClearFailedDevices(
    ClearFailedDevices event,
    Emitter<DeviceState> emit,
  ) async {
    _failedDevices.clear();
    await _failedBox.clear();
    emit(state.copyWith(failedDevices: List.from(_failedDevices)));
  }

  Future<void> _onUpdateScanConfig(
    UpdateScanConfig event,
    Emitter<DeviceState> emit,
  ) async {
    emit(
      state.copyWith(
        selectedHardware: event.selectedHardware ?? state.selectedHardware,
        selectedTxPower: event.selectedTxPower ?? state.selectedTxPower,
        txPowerEnabled: event.txPowerEnabled ?? state.txPowerEnabled,
        intervalEnabled: event.intervalEnabled ?? state.intervalEnabled,
        nameText: event.nameText ?? state.nameText,
        intervalText: event.intervalText ?? state.intervalText,
      ),
    );
  }
}
