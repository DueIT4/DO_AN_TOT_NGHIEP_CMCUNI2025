import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';

import '../services/support_service.dart';

XFile? _selectedFile;
final ImagePicker _imagePicker = ImagePicker();

class SupportDetailPage extends StatefulWidget {
  final Map<String, dynamic> ticket;

  const SupportDetailPage({super.key, required this.ticket});

  @override
  State<SupportDetailPage> createState() => _SupportDetailPageState();
}

class _SupportDetailPageState extends State<SupportDetailPage> {
  late Future<List<dynamic>> _messagesFuture;
  final _messageCtrl = TextEditingController();
  bool _isSending = false;

  int? _ticketId;
  int? _ownerUserId;

  XFile? _selectedFile;
  final ImagePicker _imagePicker = ImagePicker();

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  int? _extractTicketId(Map<String, dynamic> ticket) =>
      _asInt(ticket['ticket_id'] ?? ticket['id']);

  @override
  void initState() {
    super.initState();
    _ticketId = _extractTicketId(widget.ticket);
    _ownerUserId = _asInt(widget.ticket['user_id']);
    _loadMessages();
  }

  void _loadMessages() {
    final ticketId = _ticketId;
    setState(() {
      _messagesFuture = ticketId == null
          ? Future.value(<dynamic>[])
          : SupportService.fetchMessages(ticketId);
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageCtrl.text.trim();
    if (message.isEmpty && _selectedFile == null) return;

    final ticketId = _ticketId;
    if (ticketId == null) return;

    setState(() => _isSending = true);
    try {
      await SupportService.createMessage(
        ticketId: ticketId,
        message: message,
        file: _selectedFile, // ✅ XFile
      );

      if (!mounted) return;
      _messageCtrl.clear();
      setState(() => _selectedFile = null);
      _loadMessages();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gửi tin nhắn thành công')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (file != null) {
        setState(() => _selectedFile = file);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi chọn ảnh: $e')),
      );
    }
  }

  Future<void> _pickCamera() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (file != null) {
        setState(() => _selectedFile = file);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi chụp ảnh: $e')),
      );
    }
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.ticket['title'] ?? 'Hỗ trợ';
    final description = widget.ticket['description'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F9E9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _messagesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }

                final messages = snapshot.data ?? [];

                final normalizedMessages = messages.map((m) {
                  final mm = (m as Map).cast<String, dynamic>();
                  return {
                    'content': mm['message'] ?? '',
                    'is_user': _asInt(mm['sender_id']) == _ownerUserId,
                    'created_at': mm['created_at']?.toString() ?? '',
                    // SupportService đã normalize absolute URL rồi
                    'attachment_url': mm['attachment_url']?.toString(),
                  };
                }).toList();

                final allMessages = [
                  {
                    'content': description,
                    'is_user': true,
                    'created_at': widget.ticket['created_at']?.toString() ?? '',
                    'attachment_url': null,
                  },
                  ...normalizedMessages,
                ];

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...allMessages.map((msg) {
                        final isUser = msg['is_user'] ?? false;
                        final content = msg['content'] ?? '';
                        final createdAt = msg['created_at'] ?? '';

                        String formattedTime = '';
                        try {
                          if (createdAt.isNotEmpty) {
                            final date = DateTime.parse(createdAt);
                            formattedTime =
                                DateFormat('HH:mm dd/MM/yyyy').format(date);
                          }
                        } catch (_) {
                          formattedTime = createdAt;
                        }

                        final attachmentUrl = msg['attachment_url']?.toString();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            mainAxisAlignment: isUser
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isUser)
                                const CircleAvatar(
                                  backgroundColor: Color(0xFF7CCD2B),
                                  radius: 18,
                                  child: Icon(
                                    Icons.support_agent,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              if (!isUser) const SizedBox(width: 8),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: isUser
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                                0.7,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isUser
                                            ? const Color(0xFF7CCD2B)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (content.isNotEmpty)
                                            Text(
                                              content,
                                              style: TextStyle(
                                                color: isUser
                                                    ? Colors.white
                                                    : Colors.black87,
                                                fontSize: 15,
                                                height: 1.4,
                                              ),
                                            ),
                                          if (attachmentUrl != null &&
                                              attachmentUrl.isNotEmpty) ...[
                                            if (content.isNotEmpty)
                                              const SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                attachmentUrl,
                                                fit: BoxFit.cover,
                                                loadingBuilder: (context, child,
                                                    loadingProgress) {
                                                  if (loadingProgress == null) {
                                                    return child;
                                                  }
                                                  return Container(
                                                    height: 150,
                                                    alignment: Alignment.center,
                                                    child:
                                                        CircularProgressIndicator(
                                                      value: loadingProgress
                                                                  .expectedTotalBytes !=
                                                              null
                                                          ? loadingProgress
                                                                  .cumulativeBytesLoaded /
                                                              loadingProgress
                                                                  .expectedTotalBytes!
                                                          : null,
                                                    ),
                                                  );
                                                },
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: isUser
                                                          ? Colors.white
                                                              .withOpacity(0.2)
                                                          : Colors.grey[200],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.attach_file,
                                                          size: 16,
                                                          color: isUser
                                                              ? Colors.white
                                                              : Colors.black54,
                                                        ),
                                                        const SizedBox(
                                                            width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            attachmentUrl
                                                                .split('/')
                                                                .last,
                                                            style: TextStyle(
                                                              color: isUser
                                                                  ? Colors.white
                                                                  : Colors
                                                                      .black54,
                                                              fontSize: 12,
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        formattedTime,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isUser) const SizedBox(width: 8),
                              if (isUser)
                                const CircleAvatar(
                                  backgroundColor: Color(0xFF2E7D32),
                                  radius: 18,
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
          ),

          // Preview file selected (giữ UI)
          if (_selectedFile != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7CCD2B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.image,
                        color: Color(0xFF7CCD2B),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedFile!.path.split('/').last,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _selectedFile = null),
                      icon: const Icon(Icons.close, color: Colors.red),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),

          // Composer (giữ UI)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageCtrl,
                        enabled: !_isSending,
                        decoration: const InputDecoration(
                          hintText: 'Nhập tin nhắn...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSending
                        ? null
                        : () {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.photo_library,
                                          color: Color(0xFF7CCD2B)),
                                      title: const Text('Chọn từ thư viện'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _pickImage();
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.camera_alt,
                                          color: Color(0xFF7CCD2B)),
                                      title: const Text('Chụp ảnh'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _pickCamera();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                    icon: Icon(
                      Icons.attach_file,
                      color: _isSending ? Colors.grey : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF7CCD2B),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: IconButton(
                      onPressed: _isSending ? null : _sendMessage,
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
