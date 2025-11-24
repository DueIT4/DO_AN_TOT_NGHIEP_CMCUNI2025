import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../l10n/app_localizations.dart';
import '../services/gemini_service.dart';

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final _messages = <_ChatMessage>[];
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  ChatSession? _chatSession;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  void _initChat() {
    try {
      _chatSession = GeminiService.startChat();
      _error = null;
    } catch (_) {
      _error = 'MISSING_GEMINI_API_KEY';
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _chatSession == null || _sending) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _sending = true;
      _error = null;
    });
    _inputCtrl.clear();
    _scrollToBottom();

    try {
      final reply = await GeminiService.sendMessage(_chatSession!, text);
      setState(() {
        _messages.add(_ChatMessage(text: reply, isUser: false));
      });
      _scrollToBottom();
    } catch (_) {
      setState(() => _error = 'AI_ERROR');
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
    final missingKey = _error == 'MISSING_GEMINI_API_KEY' || !GeminiService.hasApiKey;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('ai_chat_title')),
      ),
      backgroundColor: const Color(0xFFF2F9E9),
      body: Column(
        children: [
          if (missingKey)
            _InfoBanner(
              text: l10n.translate('ai_missing_key'),
              icon: Icons.warning_amber_rounded,
              color: Colors.orange.shade100,
            )
          else if (_error == 'AI_ERROR')
            _InfoBanner(
              text: l10n.translate('ai_error'),
              icon: Icons.error_outline,
              color: Colors.red.shade100,
            ),
          Expanded(
            child: ListView.builder(
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft:
                            msg.isUser ? const Radius.circular(18) : Radius.zero,
                        bottomRight:
                            msg.isUser ? Radius.zero : const Radius.circular(18),
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
                      style:
                          TextStyle(color: textColor, height: 1.3, fontSize: 15),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            minimum:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    minLines: 1,
                    maxLines: 4,
                    enabled: !missingKey,
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
                    onPressed:
                        missingKey || _sending ? null : () => _sendMessage(),
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

