import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ImageUploadService {
  // ── Fill these in from your Cloudinary dashboard ─────────────────────────
  static const _cloudName    = 'oqbwkrkp';
  static const _uploadPreset = 'ml_default';
  // ─────────────────────────────────────────────────────────────────────────

  static Future<String?> upload(String localPath) async {
    try {
      final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
      final req = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset;

      if (kIsWeb) {
        final bytes = await XFile(localPath).readAsBytes();
        req.files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: 'scan.jpg'));
      } else {
        req.files.add(await http.MultipartFile.fromPath('file', localPath));
      }

      final streamed = await req.send();
      final body     = await streamed.stream.bytesToString();
      if (streamed.statusCode == 200) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        return json['secure_url'] as String?;
      }
      debugPrint('Cloudinary upload failed ${streamed.statusCode}: $body');
    } catch (e) {
      debugPrint('Image upload error: $e');
    }
    return null;
  }
}
