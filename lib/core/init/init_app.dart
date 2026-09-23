import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class InitApp extends StatefulWidget {
  const InitApp({super.key});

  @override
  State<InitApp> createState() => _InitAppState();
}

class _InitAppState extends State<InitApp> {
  final List<ScanResult> scanResults = [];
  bool isScanning = false;

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  void startScan() {
    scanResults.clear();
    setState(() {
      isScanning = true;
    });

    // 调用静态方法
    FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 5),
      androidUsesFineLocation: true,
    );

    // 监听扫描结果
    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        for (var r in results) {
          if (!scanResults.any((e) => e.device.id == r.device.id)) {
            scanResults.add(r);
          }
        }
      });
    });

    Future.delayed(const Duration(seconds: 5), () {
      setState(() {
        isScanning = false;
      });
    });
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    setState(() {
      isScanning = false;
    });
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(license: License.free, mtu: null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("${device.name} 已连接")));
      await device.disconnect();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("连接失败: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("蓝牙扫描示例"),
        actions: [
          isScanning
              ? IconButton(icon: const Icon(Icons.stop), onPressed: stopScan)
              : IconButton(
                icon: const Icon(Icons.search),
                onPressed: startScan,
              ),
        ],
      ),
      body:
          scanResults.isEmpty
              ? Center(
                child:
                    isScanning
                        ? const CircularProgressIndicator()
                        : const Text("点击右上角开始扫描"),
              )
              : ListView.builder(
                itemCount: scanResults.length,
                itemBuilder: (context, index) {
                  final result = scanResults[index];
                  return ListTile(
                    title: Text(
                      result.device.name.isNotEmpty
                          ? result.device.name
                          : "未知设备",
                    ),
                    subtitle: Text(result.device.id.id),
                    trailing: Text("RSSI: ${result.rssi}"),
                    onTap: () => connectToDevice(result.device),
                  );
                },
              ),
    );
  }
}
