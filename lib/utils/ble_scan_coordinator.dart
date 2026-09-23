import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleScanCoordinator {
  BleScanCoordinator._() {
    FlutterBluePlus.isScanning.listen((isScanning) {
      if (!isScanning && _owners.isNotEmpty) {
        _owners.clear();
        _emitOwners();
      }
    });
  }

  static final BleScanCoordinator instance = BleScanCoordinator._();

  static const String devicesOwner = 'devices_page';
  static const String batchConfigOwner = 'batch_config_page';

  final Set<String> _owners = <String>{};
  final StreamController<Set<String>> _ownersController =
      StreamController<Set<String>>.broadcast();

  Stream<Set<String>> get ownersStream => _ownersController.stream;

  bool isOwnerActive(String owner) => _owners.contains(owner);

  Future<void> start(
    String owner, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final added = _owners.add(owner);
    if (added) {
      _emitOwners();
    }

    if (FlutterBluePlus.isScanningNow) {
      return;
    }

    try {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: true,
      );
    } catch (_) {
      if (added) {
        _owners.remove(owner);
        _emitOwners();
      }
      rethrow;
    }
  }

  Future<void> stop(String owner) async {
    final removed = _owners.remove(owner);
    if (removed) {
      _emitOwners();
    }

    if (_owners.isEmpty && FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
  }

  void _emitOwners() {
    _ownersController.add(Set<String>.unmodifiable(_owners));
  }
}
