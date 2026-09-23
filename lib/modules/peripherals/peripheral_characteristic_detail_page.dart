import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue/locator.dart';
import 'package:flutter_blue/modules/peripherals/bloc_characteristic/characteristic_bloc.dart';
import 'package:flutter_blue/modules/peripherals/bloc_characteristic/characteristic_events.dart';
import 'package:flutter_blue/modules/peripherals/bloc_characteristic/characteristic_states.dart';
import 'package:flutter_blue/modules/peripherals/widgets/log_list.dart';
import 'package:flutter_blue/utils/services/overlay_service/i_overlay_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter_blue/utils/export_directory.dart';
import '/utils/data_entry.dart';

/// 特征详情页面
class CharacteristicDetailPage extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothCharacteristic characteristic;
  final String? description;
  final Map<String, String?>? descCache;

  const CharacteristicDetailPage({
    super.key,
    required this.device,
    required this.characteristic,
    this.description,
    this.descCache,
  });

  @override
  State<CharacteristicDetailPage> createState() =>
      _CharacteristicDetailPageState();
}

enum EncodingType { utf8, hex }

class _CharacteristicDetailPageState extends State<CharacteristicDetailPage> {
  late EncodingType _selectedEncoding;
  final List<String> utf8Keys = [
    'HostName(Url/IP)',
    'HostPort',
    'SSL',
    'MQTT ClientID',
    'MQTT UserName',
    'MQTT UserPsw',
    'MQTT SubTopic',
    'MQTT PubTopic',
    'APN',
    'APN UserName',
    'APN UserPsw',
    'APN AuthMethod',
    'Configuration',
    'Device IMEI',
    'Device IMSI',
    'Device CCID',
    'Reboot',
    'Log and debug',
    'NetState',
    'DeviceRunMode',
    'ModuleSwitch',
  ];

  @override
  void initState() {
    super.initState();
    _selectedEncoding = EncodingType.hex;

    if (widget.descCache != null &&
        widget.descCache!.values.any(
          (v) => v != null && utf8Keys.contains(v),
        )) {
      _selectedEncoding = EncodingType.utf8;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.platformName),
        actions: [
          PopupMenuButton<EncodingType>(
            onSelected: (value) {
              setState(() {
                _selectedEncoding = value;
              });
            },
            itemBuilder:
                (_) => [
                  PopupMenuItem(
                    value: EncodingType.utf8,
                    child: Row(
                      children: [
                        Icon(
                          _selectedEncoding == EncodingType.utf8
                              ? Icons.check
                              : Icons.circle_outlined,
                          size: 18,
                          color:
                              _selectedEncoding == EncodingType.utf8
                                  ? Colors.blue
                                  : Colors.transparent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "UTF-8 String",
                          style: TextStyle(
                            color:
                                _selectedEncoding == EncodingType.utf8
                                    ? Colors.blue
                                    : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: EncodingType.hex,
                    child: Row(
                      children: [
                        Icon(
                          _selectedEncoding == EncodingType.hex
                              ? Icons.check
                              : Icons.circle_outlined,
                          size: 18,
                          color:
                              _selectedEncoding == EncodingType.hex
                                  ? Colors.blue
                                  : Colors.transparent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Hex",
                          style: TextStyle(
                            color:
                                _selectedEncoding == EncodingType.hex
                                    ? Colors.blue
                                    : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    _selectedEncoding == EncodingType.utf8
                        ? "UTF-8 String"
                        : "Hex",
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: CharacteristicTile(
          device: widget.device,
          characteristic: widget.characteristic,
          description: widget.description,
          selectedEncoding: _selectedEncoding,
        ),
      ),
    );
  }
}

/// 特征值条目（含 UUID、Value 显示和操作按钮）
class CharacteristicTile extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothCharacteristic characteristic;
  final String? description;
  final EncodingType selectedEncoding;

  const CharacteristicTile({
    super.key,
    required this.device,
    required this.characteristic,
    this.description,
    required this.selectedEncoding,
  });

  @override
  State<CharacteristicTile> createState() => _CharacteristicTileState();
}

class _CharacteristicTileState extends State<CharacteristicTile> {
  final overlayService = getIt<IOverlayService>();
  List<int> _value = [];
  BluetoothConnectionState _deviceState = BluetoothConnectionState.disconnected;
  late final StreamSubscription _valueSub;
  late final StreamSubscription _deviceStateSub;

  bool get canRead => widget.characteristic.properties.read;

  bool get canWrite =>
      widget.characteristic.properties.write ||
      widget.characteristic.properties.writeWithoutResponse;

  bool get canNotify =>
      widget.characteristic.properties.notify ||
      widget.characteristic.properties.indicate;

  @override
  void initState() {
    super.initState();

    // 监听特征值
    _valueSub = widget.characteristic.lastValueStream.listen((v) {
      if (!mounted) return;
      setState(() => _value = v);

      if (widget.characteristic.isNotifying) {
        final timeString = getCurrentTimeString();
        // 检查 mounted 再用 context
        if (!mounted) return;
        context.read<CharacteristicBloc>().add(
          AddNotifyValue(
            uuid: widget.characteristic.uuid.str,
            value: "$timeString  $readableValue",
          ),
        );
      }
    });

    // 监听设备连接状态
    _deviceStateSub = widget.device.connectionState.listen((state) {
      if (!mounted) return;
      setState(() => _deviceState = state);
    });
  }

  @override
  void dispose() {
    _valueSub.cancel(); // 取消特征值订阅
    _deviceStateSub.cancel(); // 取消设备状态订阅
    super.dispose();
  }

  String get readableValue {
    return _formatDisplayValue(_value);
  }

  String _formatDisplayValue(List<int> valueBytes) {
    if (valueBytes.isEmpty) return '';

    if (widget.selectedEncoding == EncodingType.hex) {
      final hexStr =
          valueBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      return '0x${hexStr.toUpperCase()}';
    }

    return _decodeUtf8ForDisplay(valueBytes);
  }

  String _decodeUtf8ForDisplay(List<int> bytes) {
    final decoded = utf8.decode(bytes, allowMalformed: true);
    // BLE payloads often append trailing 0x00 or control chars as terminators.
    // Only trim from the end to avoid altering valid in-string spacing/content.
    return decoded.replaceFirst(RegExp(r'[\u0000-\u001F\uFFFD]+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _buildDescriptionTile(),
        const Divider(height: 2, thickness: 0.5, indent: 1, color: Colors.grey),

        if (canWrite) ...[
          const SizedBox(height: 8),
          _buildWriteSection(context),
        ],

        if (canRead) ...[const SizedBox(height: 16), _buildReadSection()],

        if (canNotify) ...[
          const SizedBox(height: 16),
          _buildSubscribeSection(),
        ],
      ],
    );
  }

  Widget _buildDescriptionTile() {
    // 获取当前设备状态
    final isConnected = _deviceState == BluetoothConnectionState.connected;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        widget.description ?? "N/A",
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        "UUID: ${widget.characteristic.uuid.str.toUpperCase()}",
        style: const TextStyle(fontSize: 16, color: Colors.grey),
      ),
      trailing: Padding(
        padding: const EdgeInsets.only(right: 30), // 右侧留 16 像素空间
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              color: isConnected ? Colors.blue : Colors.red,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              isConnected ? "Connected" : "Disconnected",
              style: TextStyle(
                fontSize: 14,
                color: isConnected ? Colors.blue : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWriteSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Write",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () async {
            List<int>? bytes = await DataEntry.enterData(
              context,
              isHexDefault: widget.selectedEncoding == EncodingType.hex,
            );
            if (bytes != null && bytes.isNotEmpty) {
              try {
                await widget.characteristic.write(bytes);
                if (mounted) {
                  final writeTimeString = getCurrentTimeString();
                  final value = _formatDisplayValue(bytes);

                  // **发事件到 Bloc**
                  context.read<CharacteristicBloc>().add(
                    AddWrittenValue(
                      uuid: widget.characteristic.uuid.str,
                      value: "$writeTimeString  $value",
                    ),
                  );

                  final isLogAndDebug =
                      (widget.description ?? '').trim() == 'Log and debug';
                  if (canRead && !isLogAndDebug) {
                    try {
                      final latestValueBytes =
                          await widget.characteristic.read();
                      if (!mounted) return;
                      setState(() => _value = latestValueBytes);

                      final readTimeString = getCurrentTimeString();
                      final latestValue = _formatDisplayValue(latestValueBytes);
                      context.read<CharacteristicBloc>().add(
                        AddReadValue(
                          uuid: widget.characteristic.uuid.str,
                          value: "$readTimeString  $latestValue",
                        ),
                      );
                    } catch (e) {
                      if (mounted) {
                        overlayService.showWarnNotification(
                          (context) =>
                              "Write success, but failed to read latest value: $e",
                          duration: const Duration(milliseconds: 2200),
                        );
                      }
                    }
                  }

                  overlayService.showSuccessNotification(
                    (context) => "Write success",
                    duration: const Duration(milliseconds: 2000),
                  );
                }
              } catch (e) {
                if (mounted) {
                  overlayService.showErrorNotification(
                    (context) => "Write failed: $e",
                    duration: const Duration(milliseconds: 2000),
                  );
                }
              }
            }
          },
          child: const Text(
            "Write new value",
            style: TextStyle(color: Colors.blue),
          ),
        ),
        const SizedBox(height: 16),
        const Divider(height: 2, thickness: 0.5, indent: 1, color: Colors.grey),
        _buildWrittenValuesList(),
      ],
    );
  }

  Widget _buildWrittenValuesList() {
    final uuid = widget.characteristic.uuid.str;
    return BlocBuilder<CharacteristicBloc, CharacteristicState>(
      builder: (context, state) {
        final writtenValues = state.writtenLogs[uuid] ?? [];
        return LogList(logs: writtenValues);
      },
    );
  }

  Widget _buildReadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Read values",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () async {
            final readValue = await widget.characteristic.read();
            if (mounted) {
              setState(() => _value = readValue);
              final timeString = getCurrentTimeString();
              context.read<CharacteristicBloc>().add(
                AddReadValue(
                  uuid: widget.characteristic.uuid.str,
                  value: "$timeString  ${_formatDisplayValue(readValue)}",
                ),
              );
            }
          },
          child: const Text("Read", style: TextStyle(color: Colors.blue)),
        ),

        const SizedBox(height: 16),
        const Divider(height: 2, thickness: 0.5, indent: 1, color: Colors.grey),
        _buildReadValuesList(),
      ],
    );
  }

  Widget _buildReadValuesList() {
    final uuid = widget.characteristic.uuid.str;
    return BlocBuilder<CharacteristicBloc, CharacteristicState>(
      builder: (context, state) {
        final readValues = state.readLogs[uuid] ?? [];
        return LogList(logs: readValues);
      },
    );
  }

  Widget _buildSubscribeSection() {
    final uuid = widget.characteristic.uuid.str;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Notification",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            Row(
              children: [
                _buildClearButton(uuid),
                const SizedBox(width: 8),
                _buildExportButton(uuid),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () async {
            bool enable = !widget.characteristic.isNotifying;
            await widget.characteristic.setNotifyValue(enable);
            setState(() {}); // 刷新按钮文字
          },
          child: Text(
            widget.characteristic.isNotifying ? "Unsubscribe" : "Subscribe",
            style: const TextStyle(color: Colors.blue),
          ),
        ),
        const SizedBox(height: 16),
        const Divider(height: 2, thickness: 0.5, indent: 1, color: Colors.grey),
        _buildNotifyValuesList(),
      ],
    );
  }

  /// 清空按钮方法
  Widget _buildClearButton(String uuid) {
    return ElevatedButton.icon(
      onPressed: () async {
        final logs =
            context.read<CharacteristicBloc>().state.notifyLogs[uuid] ?? [];
        if (logs.isEmpty) {
          overlayService.showErrorNotification(
            (context) => "No data to clear",
            duration: const Duration(milliseconds: 2000),
          );
          return;
        }

        final confirm = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text("Confirm Clear"),
                content: Text("Do you want to clear ${logs.length} records?"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      "Clear",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
        );

        if (confirm == true) {
          context.read<CharacteristicBloc>().add(ClearNotifyValues(uuid: uuid));
          overlayService.showSuccessNotification(
            (context) => "Cleared successfully",
            duration: const Duration(milliseconds: 2000),
          );
        }
      },
      icon: const Icon(Icons.delete_outline, color: Colors.white),
      label: const Text("Clear", style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
    );
  }

  /// 导出按钮方法
  Widget _buildExportButton(String uuid) {
    return ElevatedButton.icon(
      onPressed: () async {
        final logs =
            context.read<CharacteristicBloc>().state.notifyLogs[uuid] ?? [];
        if (logs.isEmpty) {
          overlayService.showErrorNotification(
            (context) => "No data to export",
            duration: const Duration(milliseconds: 2000),
          );
          return;
        }

        final confirm = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text("Confirm Export"),
                content: Text("Do you want to export ${logs.length} records?"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      "Export",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
        );

        if (confirm == true) {
          await exportNotifyLogsCsv(logs, uuid, overlayService);
        }
      },
      icon: const Icon(Icons.file_download, color: Colors.white),
      label: const Text("Export", style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
    );
  }

  /// 导出方法：生成 CSV 文件
  Future<void> exportNotifyLogsCsv(
    List<String> logs,
    String uuid,
    IOverlayService overlayService,
  ) async {
    if (logs.isEmpty) {
      overlayService.showErrorNotification(
        (context) => "No data to export",
        duration: const Duration(milliseconds: 2000),
      );
      return;
    }

    // 生成 CSV 内容
    String csv = "Time,Value\n";
    for (var log in logs) {
      // log 格式: "HH:mm:ss.SSS  value"
      final splitIndex = log.indexOf('  ');
      final time = splitIndex != -1 ? log.substring(0, splitIndex) : '';
      final value = splitIndex != -1 ? log.substring(splitIndex + 2) : log;

      // 如果 value 里有逗号，包裹双引号
      final safeValue = value.contains(',') ? '"$value"' : value;

      csv += '="$time",$safeValue\n';
    }

    try {
      final downloadsDir = await exportDirectory();

      String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      File file = File("${downloadsDir.path}/notify_${uuid}_$timestamp.csv");

      await file.writeAsString(csv);

      // 成功提示
      overlayService.showSuccessNotification(
        (context) => "Export successful: ${file.path}",
        duration: const Duration(milliseconds: 5000),
      );
    } catch (e) {
      overlayService.showErrorNotification(
        (context) => "Export failed: $e",
        duration: const Duration(milliseconds: 2000),
      );
    }
  }

  Widget _buildNotifyValuesList() {
    final uuid = widget.characteristic.uuid.str;
    return BlocBuilder<CharacteristicBloc, CharacteristicState>(
      builder: (context, state) {
        final notifyValues = state.notifyLogs[uuid] ?? [];
        return LogList(logs: notifyValues);
      },
    );
  }

  /// 获取当前时间的 HH:mm:ss.SSS 格式字符串，SSS 为毫秒
  String getCurrentTimeString() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    final millisecond = now.millisecond.toString().padLeft(3, '0');
    return "$hour:$minute:$second.$millisecond";
  }
}
