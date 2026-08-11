import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Calls a Cloud Function callable from any platform.
///
/// cloud_functions ships no Windows implementation — it is absent from
/// generated_plugins.cmake, so httpsCallable throws MissingPluginException on
/// desktop and every AI and Maps call failed there with a generic network
/// error. Callables are only an HTTPS POST with a Firebase ID token though,
/// and firebase_auth *does* support Windows, so desktop takes that path.
///
/// Both paths throw [FirebaseFunctionsException], so callers handle one shape.
class GwCallable {
  static const _region  = 'us-central1';
  static const _project = 'gwcorp-ihs';

  /// The plugin exists on phones; everywhere else, speak the protocol directly.
  static bool get _viaHttp => !(Platform.isAndroid || Platform.isIOS);

  static Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic>? data,
  ]) async {
    if (!_viaHttp) {
      final res = await FirebaseFunctions.instance
          .httpsCallable(name)
          .call<Map<String, dynamic>>(data ?? const {});
      return Map<String, dynamic>.from(res.data);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Sign in required.',
      );
    }

    final token = await user.getIdToken();
    final res = await http.post(
      Uri.https('$_region-$_project.cloudfunctions.net', '/$name'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'data': data ?? const {}}),
    );

    final decoded = jsonDecode(res.body);
    final body = decoded is Map ? Map<String, dynamic>.from(decoded) : const {};

    if (res.statusCode != 200) {
      final err = body['error'];
      // The wire format uses UPPER_SNAKE; the plugin reports lower-kebab, and
      // callers switch on the plugin's spelling.
      final status = err is Map ? err['status'] : null;
      throw FirebaseFunctionsException(
        code: status is String
            ? status.toLowerCase().replaceAll('_', '-')
            : 'internal',
        message: (err is Map ? err['message'] as String? : null) ??
            'Request failed (${res.statusCode}).',
      );
    }

    final result = body['result'];
    return result is Map ? Map<String, dynamic>.from(result) : <String, dynamic>{};
  }
}
