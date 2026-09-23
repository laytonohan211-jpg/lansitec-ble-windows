import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_js/flutter_js.dart';

/// Uses the same bundled Lansitec decoders on Android and Windows.
Future<String> decodeUplink(String family, String payload) async {
  if (!{'container', 'badge', 'gateway'}.contains(family) ||
      payload.isEmpty ||
      payload.length > 8192 ||
      payload.length.isOdd ||
      !RegExp(r'^[0-9A-Fa-f]+$').hasMatch(payload)) {
    throw const FormatException('Invalid model or hexadecimal payload');
  }
  if (!Platform.isWindows) {
    return await const MethodChannel('lansitec/decoder').invokeMethod<String>(
          'decode',
          {'family': family, 'payload': payload},
        ) ??
        '{}';
  }
  final script = await rootBundle.loadString('assets/decoders/$family.js');
  final runtime = getJavascriptRuntime(xhr: false);
  try {
    final result = runtime.evaluate(
      '(function(){try{\n$script\nreturn JSON.stringify(decodeChecked(${jsonEncode(payload)}));'
      '}catch(e){return JSON.stringify({error:String(e.message||e)});}})()',
    );
    if (result.isError) throw FormatException(result.stringResult);
    return result.stringResult;
  } finally {
    runtime.dispose();
  }
}
