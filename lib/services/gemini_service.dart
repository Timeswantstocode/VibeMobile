import 'package:google_generative_ai/google_generative_ai.dart';
import 'key_manager.dart';

class GeminiService {
  final KeyManager keyManager;

  GeminiService(this.keyManager);

  Future<String> processCodeTransformation(String originalCode, String instruction) async {
    return await _executeWithRetry(originalCode, instruction, retry: true);
  }

  Future<String> _executeWithRetry(String code, String instruction, {required bool retry}) async {
    final apiKey = keyManager.currentGeminiKey;
    if (apiKey == null) throw Exception("No Gemini API Key available.");

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );

    final prompt = [
      Content.text('''
      ACT AS: A Senior Software Engineer.
      TASK: Modify the provided code based on the instructions.
      RULES: Return ONLY the modified code. No markdown. No explanations.
      
      ORIGINAL CODE:
      $code
      
      INSTRUCTION:
      $instruction
      ''')
    ];

    try {
      final response = await model.generateContent(prompt);
      final newCode = response.text;
      if (newCode == null) throw Exception("Empty response");
      
      return newCode.replaceAll('```dart', '').replaceAll('```', '').trim();
    } catch (e) {
      // Handle Rate Limit (429) or Invalid Key
      if (e.toString().contains('429') || e.toString().contains('quota')) {
        if (retry) {
          print("Rate limit hit. Rotating key and retrying...");
          keyManager.rotateKey();
          return await _executeWithRetry(code, instruction, retry: false);
        } else {
          throw Exception("All API keys exhausted or rate-limited.");
        }
      }
      rethrow;
    }
  }
}