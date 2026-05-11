import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageService {
  /// Compresses [file] and returns a new [File] that is much smaller.
  /// Standardizes resolution and quality for fast uploads.
  static Future<File> compressImage(File file, {int quality = 70, int maxWidth = 1080}) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = p.join(
      tempDir.path, 
      'comp_${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}'
    );

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: quality,
      minWidth: maxWidth,
      minHeight: maxWidth, // Aspect ratio is preserved by the library
    );

    if (result == null) return file; // Fallback to original if compression fails
    
    return File(result.path);
  }
}
