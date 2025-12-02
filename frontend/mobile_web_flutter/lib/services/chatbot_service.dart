// lib/services/chatbot_service.dart
import '../services/api_client.dart';

/// Service để gọi backend API cho chatbot
/// API key được giữ ở backend .env, không expose ra frontend
class ChatbotService {
  ChatbotService._();

  static int? _currentChatbotId;

  /// Tạo hoặc lấy session chatbot hiện tại
  /// Chỉ tạo session mới khi thực sự cần (khi gửi tin nhắn)
  static Future<int?> getOrCreateSession() async {
    if (_currentChatbotId != null) {
      return _currentChatbotId;
    }

    // Không tự động tạo session mới ở đây
    // Session sẽ được tạo tự động khi gửi tin nhắn đầu tiên (qua API)
    return null;
  }

  /// Gửi câu hỏi và nhận câu trả lời
  /// Session sẽ được tạo tự động nếu chưa có (backend xử lý)
  static Future<String> sendMessage(String question) async {
    // Gửi tin nhắn, backend sẽ tự động tạo session nếu chưa có
    // Nếu đã có session, dùng session đó
    final (success, data, error) = await ApiClient.sendChatbotMessage(
      question: question,
      chatbotId: _currentChatbotId, // Có thể null, backend sẽ tạo mới
    );

    if (success && data != null) {
      // Cập nhật chatbot_id từ response (backend trả về)
      if (data['chatbot_id'] != null) {
        _currentChatbotId = data['chatbot_id'] as int?;
      }
      return data['answer'] as String? ?? '';
    }

    throw Exception(error.isNotEmpty ? error : 'Lỗi gửi tin nhắn');
  }

  /// Lấy lịch sử chat của session hiện tại
  static Future<List<Map<String, String>>> getChatHistory() async {
    // Nếu chưa có session, trả về rỗng (không tạo session mới)
    if (_currentChatbotId == null) {
      return [];
    }

    final (success, data, _) = await ApiClient.getChatbotMessages(_currentChatbotId!);
    if (success && data is List) {
      return data.map((item) {
        return {
          'question': (item['question'] ?? '').toString(),
          'answer': (item['answer'] ?? '').toString(),
        };
      }).toList();
    }
    return [];
  }

  /// Reset session hiện tại
  static void resetSession() {
    _currentChatbotId = null;
  }

  /// Lấy danh sách tất cả sessions (chỉ những session có tin nhắn)
  static Future<List<Map<String, dynamic>>> listSessions() async {
    final (success, data, _) = await ApiClient.listChatbotSessions();
    if (success && data is List) {
      return data
          .where((item) {
            // Chỉ lấy sessions có ít nhất 1 tin nhắn
            final count = item['details_count'] as int? ?? 0;
            return count > 0;
          })
          .map((item) {
            return {
              'chatbot_id': item['chatbot_id'] as int?,
              'created_at': item['created_at']?.toString() ?? '',
              'status': item['status']?.toString() ?? '',
              'details_count': item['details_count'] as int? ?? 0,
            };
          })
          .toList();
    }
    return [];
  }

  /// Load session cụ thể và lấy lịch sử chat
  static Future<List<Map<String, String>>> loadSession(int chatbotId) async {
    final (success, data, _) = await ApiClient.getChatbotSession(chatbotId);
    if (success && data != null) {
      _currentChatbotId = chatbotId;
      
      // Lấy messages từ response
      final messages = data['messages'] as List?;
      if (messages != null) {
        return messages.map((item) {
          return {
            'question': (item['question'] ?? '').toString(),
            'answer': (item['answer'] ?? '').toString(),
          };
        }).toList();
      }
    }
    return [];
  }
}

