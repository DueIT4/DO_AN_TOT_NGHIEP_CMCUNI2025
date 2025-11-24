import 'package:google_generative_ai/google_generative_ai.dart';

/// Wrapper for Google Gemini chat.
///
/// Provide your API key via `--dart-define=GEMINI_API_KEY=xxxx`
/// when running `flutter run` or `flutter build`.
class GeminiService {
  GeminiService._();

  static const _apiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  static bool get hasApiKey => _apiKey.isNotEmpty;

  static ChatSession startChat() {
    if (!hasApiKey) {
      throw StateError('MISSING_GEMINI_API_KEY');
    }

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
      ],
    );

    return model.startChat(history: [
      Content.text(
        'Bạn là trợ lý nông nghiệp thân thiện. Hãy trả lời ngắn gọn, '
        'dễ hiểu và ưu tiên tiếng Việt nếu người dùng dùng tiếng Việt.',
      ),
    ]);
  }

  static Future<String> sendMessage(ChatSession session, String prompt) async {
    final response = await session.sendMessage(Content.text(prompt));
    final text = response.text?.trim();
    if (text == null || text.isEmpty) {
      throw StateError('EMPTY_RESPONSE');
    }
    return text;
  }
}

