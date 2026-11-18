import 'package:flutter_blue/config/routes/go_router.dart';
import 'package:flutter_blue/utils/services/overlay_service/i_overlay_service.dart';
import 'package:flutter_blue/utils/services/overlay_service/overlay_service.dart';
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

Future<void> setUpRootDependencies() async {
  getIt
    ..registerSingleton<AppRouter>(AppRouter())
    ..registerLazySingleton<IOverlayService>(() => OverlayService());
}
