// Source: LoRaWAN test workbook, BLE-02/BLE-08 and instructions B52.
// Livestock only. Legacy Badge FF89/FF8A/FF8B have different meanings.
const livestockInfoLabels = {
  'ff89': 'LoRaWAN region', 'ff8a': 'LoRaWAN sub-band',
  'ff8b': 'Firmware version', 'ff87': 'Network status', 'battery': 'Battery',
};
int livestockBandMaximum(String region) {
  final name = region.trim().toUpperCase();
  if (name.contains('CN470')) return 12;
  if (['US915', 'AU915', 'LA915'].any(name.contains)) return 8;
  return 0;
}
String livestockBandInput(String input, int maximum) {
  final value = input.trim().toUpperCase();
  final number = int.tryParse(value);
  if (maximum == 0 || (value != 'AUTO' &&
      (number == null || number < 1 || number > maximum))) {
    throw FormatException('Enter AUTO or 1–$maximum');
  }
  return value == 'AUTO' ? value : '$number';
}
