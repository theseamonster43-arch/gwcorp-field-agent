import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../data/models.dart';

class ClaudeService {
  static const _apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
  static const _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const _model  = 'claude-opus-4-8';

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

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'x-api-key':         _apiKey,
          'anthropic-version': '2023-06-01',
          'content-type':      'application/json',
        },
        body: jsonEncode({
          'model':      _model,
          'max_tokens': 1200,
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'image', 'source': {'type': 'base64', 'media_type': mime, 'data': b64}},
                {'type': 'text',  'text': _classifyPrompt},
              ],
            }
          ],
        }),
      );

      final text = (jsonDecode(response.body)['content'] as List)[0]['text'] as String;
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
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'x-api-key':         _apiKey,
          'anthropic-version': '2023-06-01',
          'content-type':      'application/json',
        },
        body: jsonEncode({
          'model':      _model,
          'max_tokens': 800,
          'system':     systemContext,
          'messages':   messages,
        }),
      );
      return (jsonDecode(response.body)['content'] as List)[0]['text'] as String;
    } catch (_) {
      return null;
    }
  }
}
