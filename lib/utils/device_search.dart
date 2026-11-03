bool matchesDeviceNumber(String query, Iterable<String> identifiers) {
  String normalized(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final q = normalized(query);
  return q.isEmpty || identifiers.any((s) => normalized(s).contains(q));
}
