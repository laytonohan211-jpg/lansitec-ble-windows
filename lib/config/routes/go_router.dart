import 'package:flutter/material.dart';
import 'package:flutter_blue/modules/config/config_device_page.dart';
import 'package:flutter_blue/modules/home/home_page.dart';
import 'package:flutter_blue/modules/main/main_page.dart';
import 'package:flutter_blue/modules/peripherals/peripheral_characteristics_page.dart';
import 'package:flutter_blue/modules/peripherals/peripheral_filter_page.dart';
import 'package:flutter_blue/modules/remote/remote_page.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  late final GoRouter router;

  AppRouter() {
    router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/home',
      debugLogDiagnostics: true,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainPage(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => HomePage(),
                  routes: [
                    GoRoute(
                      path: 'peripheral_filter',
                      builder: (context, state) => PeripheralFilterPage(),
                    ),
                    GoRoute(
                      path: 'peripheral_characteristics',
                      builder: (context, state) {
                        final extra = state.extra;
                        if (extra is! Map) {
                          return const _RouteArgsErrorPage();
                        }

                        final device = extra['device'];
                        final services = extra['services'];
                        final descCache = extra['descCache'];
                        if (device is! BluetoothDevice ||
                            services is! List<BluetoothService> ||
                            descCache is! Map<String, String?>) {
                          return const _RouteArgsErrorPage();
                        }

                        return PeripheralCharacteristicsPage(
                          device: device,
                          services: services,
                          descCache: descCache,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/config',
                  builder: (context, state) => ConfigDevicePage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/remote',
                  builder: (context, state) => RemotePage(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _RouteArgsErrorPage extends StatelessWidget {
  const _RouteArgsErrorPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Route arguments are missing or invalid')),
    );
  }
}
