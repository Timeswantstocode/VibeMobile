import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  final String apiKey;
  late final GenerativeModel model;

  GeminiService(this.apiKey) {
    model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );
  }

  Future<String> processCodeTransformation(String originalCode, String instruction) async {
    final prompt = [
      Content.text('''
      ACT AS: A Senior Software Engineer.
      TASK: Modify the provided code based on the instructions.
      RULES:
      1. Return ONLY the modified code.
      2. Do NOT use markdown code blocks (no ```dart).
      3. Do NOT provide explanations.
      
      ORIGINAL CODE:
      $originalCode
      
      INSTRUCTION:
      $instruction
      ''')
    ];

    final response = await model.generateContent(prompt);
    final newCode = response.text;

    if (newCode == null) throw Exception("Gemini returned empty response");
    
    // Safety cleanup in case model ignores "No Markdown" rule
    return newCode.replaceAll('```dart', '').replaceAll('```', '').trim();
  }
}