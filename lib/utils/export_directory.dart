import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<Directory> exportDirectory() async {
  final Directory directory;
  if (Platform.isAndroid) {
    final external = await getExternalStorageDirectory();
    if (external == null) throw StateError('Storage is unavailable');
    directory = Directory('${external.path.split('Android')[0]}Download');
  } else {
    directory =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
  }
  await directory.create(recursive: true);
  return directory;
}
