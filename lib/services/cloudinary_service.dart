import 'dart:io';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Uploads images to Cloudinary using unsigned upload presets.
/// No server required — works entirely from the client.
class CloudinaryService {
  CloudinaryService._();
  static final instance = CloudinaryService._();

  static const _cloudName = 'depju5cjl';
  static const _uploadPreset = 'romanticists';
  static const _baseUrl = 'https://api.cloudinary.com/v1_1';

  /// Uploads [file] to Cloudinary under [folder] and returns the secure URL.
  Future<String> uploadImage(File file, {String folder = 'uploads'}) async {
    final uri = Uri.parse('$_baseUrl/$_cloudName/image/upload');

    dev.log('[Cloudinary] Uploading: ${file.path} → folder: $folder', name: 'CloudinaryService');

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = folder
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Upload timed out after 30s'),
    );
    final response = await http.Response.fromStream(streamedResponse);

    dev.log('[Cloudinary] Response ${response.statusCode}: ${response.body}', name: 'CloudinaryService');

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final url = json['secure_url'] as String;
      dev.log('[Cloudinary] ✅ Upload successful: $url', name: 'CloudinaryService');
      return url;
    } else {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = json['error']?['message'] as String? ?? 'Upload failed (${response.statusCode})';
      dev.log('[Cloudinary] ❌ Error: $msg', name: 'CloudinaryService');
      throw Exception('Cloudinary: $msg');
    }
  }

  Future<String> uploadProfilePicture(String uid, File file) =>
      uploadImage(file, folder: 'users/$uid');

  Future<String> uploadSubmissionImage(String uid, File file) =>
      uploadImage(file, folder: 'submissions/$uid');
}
