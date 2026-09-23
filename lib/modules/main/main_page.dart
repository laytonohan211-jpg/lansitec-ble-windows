import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainPage extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainPage({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey.shade600,
        showUnselectedLabels: true,
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          navigationShell.goBranch(index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.bluetooth_outlined),
            activeIcon: Icon(Icons.bluetooth),
            label: 'Devices',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.wifi_tethering_outlined),
            activeIcon: Icon(Icons.wifi_tethering_outlined),
            label: 'Batch Config',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Remote',
          ),
        ],
      ),
    );
  }
}
