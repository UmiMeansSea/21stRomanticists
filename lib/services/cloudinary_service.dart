import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Uploads images to Cloudinary using unsigned upload presets.
/// No server required — works entirely from the client.
///
/// Setup:
///   1. Create a free account at cloudinary.com
///   2. Copy your Cloud Name from the dashboard
///   3. Settings → Upload → Upload Presets → Add preset (set to Unsigned)
///   4. Replace the values below with your own
class CloudinaryService {
  CloudinaryService._();
  static final instance = CloudinaryService._();

  // ── Cloudinary config ─────────────────────────────────────────────────────
  static const _cloudName = 'depju5cjl';      // ✅
  static const _uploadPreset = 'romanticists'; // ✅ unsigned preset

  static const _baseUrl = 'https://api.cloudinary.com/v1_1';

  /// Uploads [file] to Cloudinary under [folder] and returns the secure URL.
  Future<String> uploadImage(File file, {String folder = 'uploads'}) async {
    final uri = Uri.parse('$_baseUrl/$_cloudName/image/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = folder
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['secure_url'] as String;
    } else {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = json['error']?['message'] as String? ?? 'Upload failed';
      throw Exception('Cloudinary error: $msg');
    }
  }

  /// Uploads a profile picture for [uid].
  Future<String> uploadProfilePicture(String uid, File file) =>
      uploadImage(file, folder: 'users/$uid');

  /// Uploads a submission cover image for [uid].
  Future<String> uploadSubmissionImage(String uid, File file) =>
      uploadImage(file, folder: 'submissions/$uid');
}
