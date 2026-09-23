import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_blue/locator.dart';
import 'package:flutter_blue/utils/dio/dio_client.dart';

class RemotePage extends StatefulWidget {
  const RemotePage({super.key});

  @override
  State<RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends State<RemotePage> {
  // final Dio dio = Dio();
  final DioClient dioClient = getIt<DioClient>();

  final TextEditingController nameController = TextEditingController();

  /// 用 ValueNotifier 管理结果文本
  final ValueNotifier<String> responseText = ValueNotifier<String>(
    'Please enter name and request',
  );

  /// 用 ValueNotifier 管理 loading 状态
  final ValueNotifier<bool> loading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> configuring = ValueNotifier(false); // 开启/停止配置
  final ValueNotifier<bool?> upgradeSuccess = ValueNotifier(null); // 配置成功/失败
  /// 新增，用于显示配置状态
  final ValueNotifier<String> configStatusText = ValueNotifier<String>('');

  Future<void> fetchConfig(String name) async {
    if (name.isEmpty) {
      responseText.value = 'Name cannot be empty';
      return;
    }

    loading.value = true;

    try {
      final response = await dioClient.get(
        '/captchaImage',
        queryParameters: {'name': name},
      );

      final code = response.data['code'];
      if (code == 200) {
        responseText.value = 'Request success: ${response.data['msg'] ?? ''}';
      } else {
        responseText.value = 'Request failed, code=$code';
      }
    } on DioException catch (e) {
      responseText.value = 'Request error: ${e.message}';
    } catch (e) {
      responseText.value = 'Unknown error: $e';
    } finally {
      loading.value = false;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    responseText.dispose();
    loading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Remote Config')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 输入框
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            /// 请求按钮
            ValueListenableBuilder<bool>(
              valueListenable: loading,
              builder: (context, isLoading, _) {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        isLoading
                            ? null
                            : () => fetchConfig(nameController.text.trim()),
                    child:
                        isLoading
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Fetch Config'),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            /// 响应结果
            ValueListenableBuilder<String>(
              valueListenable: responseText,
              builder: (context, text, _) {
                return Text(text, style: const TextStyle(fontSize: 14));
              },
            ),
            const SizedBox(height: 16),

            /// 开启/停止配置按钮
            ValueListenableBuilder<bool>(
              valueListenable: configuring,
              builder: (context, isConfiguring, _) {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (responseText.value ==
                              'Please enter name and request' ||
                          responseText.value == 'Name cannot be empty' ||
                          responseText.value.trim().isEmpty) {
                        configStatusText.value =
                            'Response text cannot be empty';
                        return;
                      }

                      configuring.value = !isConfiguring;

                      // 只更新配置状态，不动 responseText
                      configStatusText.value =
                          isConfiguring
                              ? 'Configuration stopped'
                              : 'Configuration started...';

                      // TODO: 调用 BLE 批量写入或停止任务
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConfiguring ? Colors.red : Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(
                      isConfiguring ? Icons.stop : Icons.play_arrow,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(isConfiguring ? 'Stop Config' : 'Start Config'),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            /// 配置状态显示
            ValueListenableBuilder<String>(
              valueListenable: configStatusText,
              builder: (context, status, _) {
                return Text(
                  status,
                  style: const TextStyle(fontSize: 14, color: Colors.blue),
                );
              },
            ),

            const SizedBox(height: 12),

            /// 升级/配置结果显示
            ValueListenableBuilder<bool?>(
              valueListenable: upgradeSuccess,
              builder: (context, success, _) {
                if (success == null) return const SizedBox();
                return Text(
                  success
                      ? 'Configuration success ✅'
                      : 'Configuration failed ❌',
                  style: TextStyle(
                    fontSize: 16,
                    color: success ? Colors.green : Colors.red,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
