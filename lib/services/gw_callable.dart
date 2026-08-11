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

    final String? token;
    try {
      token = await user.getIdToken();
    } catch (e) {
      // firebase_auth's Windows support is thinner than the mobile SDKs, so
      // this is a real possibility rather than a theoretical one.
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Could not get a sign-in token: $e',
      );
    }
    if (token == null || token.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Sign-in token was empty.',
      );
    }

    final http.Response res;
    try {
      res = await http.post(
        Uri.https('$_region-$_project.cloudfunctions.net', '/$name'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'data': data ?? const {}}),
      );
    } catch (e) {
      throw FirebaseFunctionsException(
        code: 'unavailable',
        message: 'Network error calling $name: $e',
      );
    }

    // ignore: avoid_print
    print('GwCallable[$name]: HTTP ${res.statusCode}');

    final Object? decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      // A gateway error page rather than the callable protocol.
      throw FirebaseFunctionsException(
        code: 'internal',
        message: '$name returned ${res.statusCode}: '
            '${res.body.substring(0, res.body.length.clamp(0, 200))}',
      );
    }
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
