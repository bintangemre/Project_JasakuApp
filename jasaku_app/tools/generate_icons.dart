import 'dart:io';
import 'package:image/image.dart' as img;

void main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart tools/generate_icons.dart <source_png> <flavor_name>');
    print('Example: dart tools/generate_icons.dart assets/logo_customer.png customer');
    exit(1);
  }

  final sourcePath = args[0];
  final flavor = args[1];

  final sourceFile = File(sourcePath);
  if (!await sourceFile.exists()) {
    print('Error: Source file not found: $sourcePath');
    exit(1);
  }

  final image = img.decodeImage(await sourceFile.readAsBytes());
  if (image == null) {
    print('Error: Could not decode image: $sourcePath');
    exit(1);
  }

  // Android mipmap sizes
  final sizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };

  final baseDir = 'android/app/src/$flavor/res';

  for (final entry in sizes.entries) {
    final dir = Directory('$baseDir/mipmap-${entry.key}');
    await dir.create(recursive: true);

    final resized = img.copyResize(image, width: entry.value, height: entry.value);
    final file = File('${dir.path}/ic_launcher.png');
    await file.writeAsBytes(img.encodePng(resized));
    print('  ✅ ${entry.key} (${entry.value}x${entry.value})');
  }

  print('✅ Icons generated for flavor "$flavor"');
}
