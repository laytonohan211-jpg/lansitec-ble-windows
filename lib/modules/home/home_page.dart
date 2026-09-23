import '../guided/guided_page.dart';
import '../guided/help_page.dart';
import 'connection_readiness.dart';

import 'package:flutter/material.dart';

import 'package:flutter_blue/modules/peripherals/peripherals_main_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const ConnectionReadiness(child: PeripheralsMainPage()),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'help',
            tooltip: 'User guide',
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpPage()),
                ),
            child: const Icon(Icons.help_outline),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'calculator',
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GuidedPage()),
                ),
            icon: const Icon(Icons.calculate),
            label: const Text('Tools'),
          ),
        ],
      ),
    );
  }
}
