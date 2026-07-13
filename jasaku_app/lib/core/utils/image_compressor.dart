import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

Future<File> compressImage(File file, {int quality = 85, int minWidth = 1024, int minHeight = 1024}) async {
  final dir = await getTemporaryDirectory();
  final targetPath = p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');

  final result = await FlutterImageCompress.compressWithFile(
    file.absolute.path,
    quality: quality,
    minWidth: minWidth,
    minHeight: minHeight,
    format: CompressFormat.jpeg,
  );

  if (result == null) return file;
  return File(targetPath)..writeAsBytesSync(result);
}
