import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue/config/routes/go_router.dart';
import 'package:flutter_blue/locator.dart';
import 'package:flutter_blue/modules/config/bloc/device_bloc.dart';
import 'package:toastification/toastification.dart';

class FlutterBlueApp extends StatefulWidget {
  const FlutterBlueApp({super.key});

  @override
  State<FlutterBlueApp> createState() => _BlueAppState();
}

class _BlueAppState extends State<FlutterBlueApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      child: MultiBlocProvider(
        providers: [
          BlocProvider<DeviceBloc>(create: (_) => DeviceBloc()..initHive()),
          // 如果有其他全局 Bloc，可以加在这里
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Ls BLE Guided',
          builder:
              (context, child) =>
                  Platform.isWindows
                      ? Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: child ?? const SizedBox.shrink(),
                        ),
                      )
                      : child ?? const SizedBox.shrink(),
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF176BDA),
            ),
            scaffoldBackgroundColor: const Color(0xFFF5F7FA),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
            ),
            cardTheme: CardTheme(
              color: Colors.white,
              elevation: 0,
              margin: const EdgeInsets.symmetric(vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
            ),
          ),
          routerConfig: getIt<AppRouter>().router,
        ),
      ),
    );
  }
}
