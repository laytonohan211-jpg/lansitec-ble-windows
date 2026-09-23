import 'package:flutter_blue/config/routes/go_router.dart';
import 'package:flutter_blue/constants/app_constants.dart';
import 'package:flutter_blue/utils/dio/dio_client.dart';
import 'package:flutter_blue/utils/services/overlay_service/i_overlay_service.dart';
import 'package:flutter_blue/utils/services/overlay_service/overlay_service.dart';
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

/// 初始化根依赖项
Future<void> setUpRootDependencies() async {
  final appRouter = AppRouter();

  getIt
    ..registerSingleton<AppRouter>(appRouter)
    ..registerLazySingleton<IOverlayService>(() => OverlayService())
    ..registerLazySingleton<DioClient>(
      () => DioClient(
        baseUrl: '${AppConstants.apiEndpoint}/prod-api',
        headers: {'Content-Type': 'application/json'},
        debug: false,
        onLoad: (isLoading) => {},
        onError: (err) => {},
      ),
    );
  ;
}
