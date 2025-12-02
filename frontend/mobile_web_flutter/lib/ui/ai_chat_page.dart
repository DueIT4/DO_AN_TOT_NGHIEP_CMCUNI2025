import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/chatbot_service.dart';

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final _messages = <_ChatMessage>[];
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _sending = false;
  bool _loading = true;
  String? _error;
  int? _currentSessionId;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Chỉ load lịch sử nếu đã có session với tin nhắn
      // Không tạo session mới cho đến khi user gửi tin nhắn đầu tiên
      final history = await ChatbotService.getChatHistory();
      
      setState(() {
        _messages.clear();
        for (var item in history) {
          _messages.add(_ChatMessage(text: item['question']!, isUser: true));
          _messages.add(_ChatMessage(text: item['answer']!, isUser: false));
        }
        _loading = false;
      });
      
      if (_messages.isNotEmpty) {
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        // Không hiển thị lỗi nếu chỉ là không có session (bình thường)
        _loading = false;
      });
    }
  }

  Future<void> _loadSession(int chatbotId) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final history = await ChatbotService.loadSession(chatbotId);
      
      setState(() {
        _currentSessionId = chatbotId;
        _messages.clear();
        for (var item in history) {
          _messages.add(_ChatMessage(text: item['question']!, isUser: true));
          _messages.add(_ChatMessage(text: item['answer']!, isUser: false));
        }
        _loading = false;
      });
      
      if (_messages.isNotEmpty) {
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        _error = 'Không thể tải lịch sử chat. Vui lòng thử lại.';
        _loading = false;
      });
    }
  }

  Future<void> _showHistoryDialog() async {
    setState(() => _loading = true);
    
    try {
      final sessions = await ChatbotService.listSessions();
      setState(() => _loading = false);
      
      if (!mounted) return;
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => _HistoryBottomSheet(
          sessions: sessions,
          currentSessionId: _currentSessionId,
          onSessionSelected: (chatbotId) {
            Navigator.pop(context);
            _loadSession(chatbotId);
          },
        ),
      );
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _sending = true;
      _error = null;
    });
    _inputCtrl.clear();
    _scrollToBottom();

    try {
      final reply = await ChatbotService.sendMessage(text);
      setState(() {
        _messages.add(_ChatMessage(text: reply, isUser: false));
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _error = 'Lỗi: ${e.toString()}';
        // Xóa tin nhắn user nếu lỗi
        if (_messages.isNotEmpty && _messages.last.isUser) {
          _messages.removeLast();
        }
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('ai_chat_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Lịch sử chat',
            onPressed: _showHistoryDialog,
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF2F9E9),
      body: Column(
        children: [
          if (_error != null)
            _InfoBanner(
              text: _error!,
              icon: Icons.error_outline,
              color: Colors.red.shade100,
            ),
          if (_loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Chào bạn! Tôi là trợ lý nông nghiệp.\nHãy hỏi tôi bất cứ điều gì về cây trồng.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final alignment =
                            msg.isUser ? Alignment.centerRight : Alignment.centerLeft;
                        final bubbleColor = msg.isUser
                            ? const Color(0xFF7CCD2B)
                            : Colors.white;
                        final textColor = msg.isUser ? Colors.white : Colors.black87;

                        return Align(
                          alignment: alignment,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            constraints: const BoxConstraints(maxWidth: 280),
                            decoration: BoxDecoration(
                              color: bubbleColor,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: msg.isUser
                                    ? const Radius.circular(18)
                                    : Radius.zero,
                                bottomRight: msg.isUser
                                    ? Radius.zero
                                    : const Radius.circular(18),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              msg.text,
                              style: TextStyle(
                                  color: textColor, height: 1.3, fontSize: 15),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          SafeArea(
            minimum: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    minLines: 1,
                    maxLines: 4,
                    enabled: !_loading && !_sending,
                    decoration: InputDecoration(
                      hintText: l10n.translate('ai_input_hint'),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: (_loading || _sending) ? null : () => _sendMessage(),
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : Text(l10n.translate('ai_send')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryBottomSheet extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  final int? currentSessionId;
  final Function(int) onSessionSelected;

  const _HistoryBottomSheet({
    required this.sessions,
    required this.currentSessionId,
    required this.onSessionSelected,
  });

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inDays == 0) {
        if (diff.inHours == 0) {
          if (diff.inMinutes == 0) {
            return 'Vừa xong';
          }
          return '${diff.inMinutes} phút trước';
        }
        return '${diff.inHours} giờ trước';
      } else if (diff.inDays == 1) {
        return 'Hôm qua';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} ngày trước';
      } else {
        return DateFormat('dd/MM/yyyy').format(date);
      }
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Lịch sử chat',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Chưa có lịch sử chat',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final chatbotId = session['chatbot_id'] as int?;
                        final count = session['details_count'] as int? ?? 0;
                        final createdAt = session['created_at']?.toString() ?? '';
                        final status = session['status']?.toString() ?? '';
                        final isActive = status == 'active';
                        final isCurrent = chatbotId == currentSessionId;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: isCurrent
                              ? const Color(0xFF7CCD2B).withOpacity(0.1)
                              : null,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isActive
                                  ? const Color(0xFF7CCD2B)
                                  : Colors.grey,
                              child: Icon(
                                isActive ? Icons.chat : Icons.chat_bubble_outline,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              isCurrent ? 'Cuộc trò chuyện hiện tại' : 'Cuộc trò chuyện',
                              style: TextStyle(
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                color: isCurrent ? const Color(0xFF7CCD2B) : null,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  '$count tin nhắn • ${_formatDate(createdAt)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                if (isActive)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7CCD2B).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Đang hoạt động',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF7CCD2B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: isCurrent
                                ? const Icon(Icons.check_circle, color: Color(0xFF7CCD2B))
                                : const Icon(Icons.chevron_right),
                            onTap: chatbotId != null
                                ? () => onSessionSelected(chatbotId)
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  const _InfoBanner({
    required this.text,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;

  _ChatMessage({required this.text, required this.isUser});
}
