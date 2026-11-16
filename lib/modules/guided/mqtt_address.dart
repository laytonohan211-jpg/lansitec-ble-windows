void validateMqttAddress(String value) {
  final host = value.startsWith('mqtts://') ? value.substring(8) : value;
  if (host.isEmpty || RegExp(r'[\s/@?#]').hasMatch(host) || host.contains('://')) {
    throw const FormatException('Enter a hostname or IP, optionally prefixed with mqtts://. Enter the port separately; no path or credentials.');
  }
  if (host.contains(':') && !(host.startsWith('[') && host.endsWith(']'))) {
    throw const FormatException('Enter the port separately. Enclose an IPv6 address in brackets.');
  }
}
