/// Treat device-originated data as text, never as spreadsheet formulas.
String csvCell(Object? value) {
  var text = '${value ?? ''}';
  if (RegExp(r'^[\s\x00-\x1f]*[=+@-]').hasMatch(text)) text = "'$text";
  return '"${text.replaceAll('"', '""')}"';
}
String csvRow(List<Object?> values) => '${values.map(csvCell).join(',')}\n';

/// This removes known credential fields, not all possible personal information.
Map<String, String> supportNetwork(Map<String, String> source) => {
  for (final e in source.entries)
    e.key: RegExp(r'password|passwd|psw|username|passkey|appkey|nwkskey|appskey|secret|token',
      caseSensitive: false).hasMatch(e.key) ? '[omitted]' : e.value,
};
