import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import '../data/models.dart';

/// All Claude traffic goes through the `claude` Cloud Function.
///
/// The Anthropic key stays in Secret Manager server-side, so it is never
/// compiled into the app the way a String.fromEnvironment key would be, and
/// the function checks Firebase Auth before spending anything.
class ClaudeService {
  static final _fn = FirebaseFunctions.instance.httpsCallable('claude');

  /// Why the last call failed, in words a field agent can act on. Null after
  /// a success — callers show this instead of failing silently.
  static String? lastError;

  static Future<String?> _call(Map<String, dynamic> payload) async {
    try {
      final res = await _fn.call<Map<String, dynamic>>(payload);
      lastError = null;
      final text = res.data['text'];
      return text is String ? text : null;
    } on FirebaseFunctionsException catch (e) {
      lastError = switch (e.code) {
        'not-found' => 'AI is not set up yet. Deploy the claude function.',
        'unauthenticated' => 'Please sign in again.',
        'resource-exhausted' => e.message ?? 'Hourly AI limit reached.',
        'invalid-argument' => e.message ?? 'That request was rejected.',
        _ => 'AI request failed. Check your connection and try again.',
      };
      // ignore: avoid_print
      print('ClaudeService: ${e.code} — ${e.message}');
      return null;
    } catch (e) {
      lastError = 'AI request failed. Check your connection and try again.';
      // ignore: avoid_print
      print('ClaudeService: $e');
      return null;
    }
  }

  static const _classifyPrompt = '''Carefully examine this image and identify EVERY distinct waste or trash item you can see.

NAMING RULES — item_name field:
- Write the EXACT common name of the specific physical object you see.
- NEVER write "Unclassified", "Unknown", "Item", or any vague placeholder.

CLASSIFICATION RULES:
- Tissue/napkins/toilet paper = NOT recyclable, waste_type: Paper, action: Landfill
- Clean cardboard/newspaper = recyclable: true, waste_type: Paper
- Metal cans/aluminium = recyclable: true, waste_type: Metal
- Plastic bottles/containers = recyclable: true, waste_type: Plastic
- Food scraps = recyclable: false, action: Compost, waste_type: Organic
- Batteries/chemicals/syringes = hazard_level: High or Critical, waste_type: Hazardous
- Electronic devices/cables = waste_type: E-Waste, action: Special Disposal
- Mixed/contaminated = recyclable: false, action: Landfill

Return ONLY a JSON array:
[{"item_name":"...","waste_type":"Plastic|Metal|Organic|E-Waste|Hazardous|Paper|Glass|Construction|Mixed","recyclable":true,"hazard_level":"None|Low|Medium|High|Critical","condition":"Fresh|Decomposing|Compacted|Contaminated","recommended_action":"Recycle|Compost|Landfill|Special Disposal|Urgent Removal","confidence":85}]
No explanation, no markdown, ONLY the JSON array.''';

  static Future<List<ClassificationResult>> classify(File imageFile) async {
    try {
      final bytes   = await imageFile.readAsBytes();
      final b64     = base64Encode(bytes);
      final mime    = imageFile.path.endsWith('.png') ? 'image/png' : 'image/jpeg';

      final text = await _call({
        'mode':            'classify',
        'imageBase64':     b64,
        'imageMediaType':  mime,
        'system':          _classifyPrompt,
        'maxTokens':       1200,
      });
      if (text == null) return [];

      final match = RegExp(r'\[[\s\S]*\]').firstMatch(text);
      if (match == null) return [];
      final arr = jsonDecode(match.group(0)!) as List;
      return arr.map((i) => ClassificationResult.fromMap(i as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<String?> chat({
    required String systemContext,
    required List<Map<String, String>> messages,
  }) async {
    return _call({
      'mode':      'chat',
      'system':    systemContext,
      'messages':  messages,
      'maxTokens': 800,
    });
  }
}
