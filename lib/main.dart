import 'package:flutter/material.dart';
import 'package:flutter_blue/blue_app.dart';
import 'package:flutter_blue/locator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  await setUpRootDependencies();

  await FlutterBluePlus.setLogLevel(LogLevel.none);

  runApp(const FlutterBlueApp());
}
