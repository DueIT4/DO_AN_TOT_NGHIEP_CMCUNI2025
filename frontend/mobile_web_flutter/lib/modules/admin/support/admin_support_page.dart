// lib/modules/admin/support/admin_support_page.dart
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:mobile_web_flutter/services/admin/admin_ticket_service.dart';
import 'package:mobile_web_flutter/core/api_base.dart';
import 'package:mobile_web_flutter/models/admin/detection_history_models.dart';
import 'package:mobile_web_flutter/models/admin/admin_ticket_models.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class AdminSupportPage extends StatefulWidget {
  const AdminSupportPage({super.key});

  @override
  State<AdminSupportPage> createState() => _AdminSupportPageState();
}

class _AdminSupportPageState extends State<AdminSupportPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _replyCtrl = TextEditingController();
  PlatformFile? _pickedFile;
  Uint8List? _pickedBytes;
  bool _uploadingFile = false;
  String? _attachmentUrl;

  String? _statusFilter; // null, 'processing', 'processed'
  int _page = 1;
  final int _pageSize = 20;
 // === helper build URL ảnh ===
  String _buildAttachmentUrl(String raw) {
    // Nếu backend đã trả sẵn http/https thì dùng luôn
    if (raw.startsWith('http')) return raw;

    // Còn nếu chỉ trả "/uploads/..." thì ghép với baseURL của API
    final base = ApiBase.baseURL; // dùng chung với AdminTicketService
    return '$base$raw';
  }

  bool _loadingList = false;
  bool _loadingDetail = false;
  bool _sending = false;

  AdminTicketItem? _selectedTicket;
  List<AdminTicketItem> _tickets = [];
  int _total = 0;
  AdminTicketDetail? _ticketDetail;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _replyCtrl.dispose();
    super.dispose();
  }

  int get _totalPages {
    if (_total == 0) return 1;
    return (_total / _pageSize).ceil();
  }

  // ====== UI helpers (tone xanh + xám) ======
  Color get _green => Colors.green.shade700;

  String _statusLabel(String s) {
    return s == 'processed' ? 'Đã xử lý' : 'Đang xử lý';
  }

  Widget _statusChip(String? status) {
    final s = (status ?? 'processing').toLowerCase();
    final isDone = s == 'processed';
    final bg = isDone ? Colors.green.shade50 : Colors.grey.shade100;
    final fg = isDone ? Colors.green.shade800 : Colors.grey.shade800;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Text(
        _statusLabel(s),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  InputDecoration _pillInput({
    required String hint,
    IconData? icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      prefixIcon: icon == null ? null : Icon(icon, size: 18),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.10)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _green, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
TextStyle get _t12 => const TextStyle(fontSize: 12);
TextStyle get _t12Bold => const TextStyle(fontSize: 12, fontWeight: FontWeight.w700);

Widget _compactDropdown({
  required String? value,
  required List<DropdownMenuItem<String?>> items,
  required ValueChanged<String?> onChanged,
  String? hint,
  IconData? icon,
}) {
  return DropdownButtonHideUnderline(
    child: Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.10)),
        color: Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.black54),
            const SizedBox(width: 6),
          ],
          DropdownButton<String?>(
            value: value,
            hint: hint == null ? null : Text(hint, style: _t12),
            items: items,
            onChanged: onChanged,
            isDense: true,
            style: _t12.copyWith(color: Colors.black87),
          ),
        ],
      ),
    ),
  );
}

  // ===================== DATA =====================

  Future<void> _loadTickets({bool resetPage = false}) async {
    if (resetPage) _page = 1;

    setState(() => _loadingList = true);

    try {
      final result = await AdminTicketService.listTickets(
        status: _statusFilter,
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        page: _page,
        size: _pageSize,
      );

      if (!mounted) return;

      setState(() {
        _tickets = result.items;
        _total = result.total;

        if (_selectedTicket == null && _tickets.isNotEmpty) {
          _selectTicket(_tickets.first);
        } else if (_selectedTicket != null) {
          // nếu ticket cũ không còn trong list (do filter/search), chọn ticket đầu
          final stillExists = _tickets.any((t) => t.ticketId == _selectedTicket!.ticketId);
          if (!stillExists && _tickets.isNotEmpty) {
            _selectTicket(_tickets.first);
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải ticket: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  Future<void> _selectTicket(AdminTicketItem ticket) async {
    setState(() {
      _selectedTicket = ticket;
      _ticketDetail = null;
      _loadingDetail = true;
      _replyCtrl.clear();
    });

    try {
      final detail = await AdminTicketService.getTicketDetail(ticket.ticketId);
      if (!mounted) return;
      setState(() => _ticketDetail = detail);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải chi tiết ticket: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }
Future<void> _pickFile() async {
  final res = await FilePicker.platform.pickFiles(withData: true);
  if (res == null || res.files.isEmpty) return;

  final f = res.files.first;
  if (f.bytes == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Không đọc được file.')),
    );
    return;
  }

  setState(() {
    _pickedFile = f;
    _pickedBytes = f.bytes!;
    _attachmentUrl = null;
  });
}

void _clearFile() {
  setState(() {
    _pickedFile = null;
    _pickedBytes = null;
    _attachmentUrl = null;
  });
}

Future<String?> _ensureUpload() async {
  if (_attachmentUrl != null && _attachmentUrl!.isNotEmpty) return _attachmentUrl;
  if (_pickedBytes == null || _pickedFile == null) return null;

  setState(() => _uploadingFile = true);
  try {
    final url = await AdminTicketService.uploadSupportAttachment(
      bytes: _pickedBytes!,
      filename: _pickedFile!.name,
    );
    if (!mounted) return null;
    setState(() => _attachmentUrl = url);
    return url;
  } finally {
    if (mounted) setState(() => _uploadingFile = false);
  }
}

  Future<void> _sendReply() async {
    final detail = _ticketDetail;
    if (detail == null) return;

    final text = _replyCtrl.text.trim();
    final hasFile = _pickedFile != null && _pickedBytes != null;

    if (text.isEmpty && !hasFile) return;

    setState(() => _sending = true);

        try {
      String? attachmentUrl;
      if (hasFile) {
        attachmentUrl = await _ensureUpload();
      }

      // backend bắt buộc message không rỗng → nếu chỉ gửi file thì gửi placeholder
      final payloadMessage = text.isEmpty ? '(Đính kèm)' : text;

      final msg = await AdminTicketService.sendAdminMessage(
        ticketId: detail.ticketId,
        message: payloadMessage,
        attachmentUrl: attachmentUrl,
      );

      if (!mounted) return;

      setState(() {
        _ticketDetail = AdminTicketDetail(
          ticketId: detail.ticketId,
          userId: detail.userId,
          username: detail.username,
          title: detail.title,
          description: detail.description,
          status: detail.status,
          createdAt: detail.createdAt,
          messages: [...detail.messages, msg],
        );
        _replyCtrl.clear();
      });

      _clearFile();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gửi tin nhắn thất bại: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _changeStatus(String status) async {
    final detail = _ticketDetail;
    if (detail == null) return;

    setState(() => _loadingDetail = true);

    try {
      final updated = await AdminTicketService.updateTicketStatus(
        ticketId: detail.ticketId,
        status: status,
      );
      if (!mounted) return;

      setState(() => _ticketDetail = updated);

      _loadTickets();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đổi trạng thái thất bại: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    final fmtDate = DateFormat('dd/MM HH:mm');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 1.5,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Column(
          children: [
            // ===== HEADER =====
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.7),
              child: Row(
                children: [
                  Icon(Icons.support_agent_rounded, color: _green),
                  const SizedBox(width: 10),
                  Text(
                    'Hỗ trợ người dùng',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Tải lại',
                    onPressed: _loadingList ? null : () => _loadTickets(resetPage: true),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: Row(
                children: [
                  // ===== LEFT: LIST =====
                  SizedBox(
                    width: 360,
                    child: Column(
                      children: [
                        Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                        child: Row(
                          children: [
                            // Search
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                style: _t12,
                                decoration: _pillInput(
                                  hint: 'Tìm tiêu đề, người dùng...',
                                  icon: Icons.search,
                                  suffix: _searchCtrl.text.trim().isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Xoá',
                                          icon: const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            _searchCtrl.clear();
                                            setState(() {});
                                            _loadTickets(resetPage: true);
                                          },
                                        ),
                                ),
                                onChanged: (_) => setState(() {}),
                                onSubmitted: (_) => _loadTickets(resetPage: true),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Dropdown compact (nhỏ)
                            _compactDropdown(
                              value: _statusFilter,
                              hint: 'Tất cả',
                              icon: Icons.filter_alt_outlined,
                              onChanged: (value) {
                                setState(() => _statusFilter = value);
                                _loadTickets(resetPage: true);
                              },
                              items: const [
                                DropdownMenuItem<String?>(value: null, child: Text('Tất cả')),
                                DropdownMenuItem<String?>(value: 'processing', child: Text('Đang xử lý')),
                                DropdownMenuItem<String?>(value: 'processed', child: Text('Đã xử lý')),
                              ],
                            ),

                            const SizedBox(width: 8),

                            // Nút lọc sát bên (icon + tooltip)
                            Tooltip(
                              message: 'Lọc / tải lại danh sách',
                              child: IconButton.filledTonal(
                                onPressed: _loadingList ? null : () => _loadTickets(resetPage: true),
                                icon: const Icon(Icons.tune, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),


                        if (_loadingList) const LinearProgressIndicator(minHeight: 2),

                        Expanded(
                          child: _tickets.isEmpty
                              ? const Center(child: Text('Không có ticket'))
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                                  itemCount: _tickets.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                                  itemBuilder: (context, index) {
                                    final t = _tickets[index];
                                    final isActive = _selectedTicket?.ticketId == t.ticketId;

                                    return InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () => _selectTicket(t),
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isActive ? Colors.green.withOpacity(0.06) : Colors.white,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isActive
                                                ? _green.withOpacity(0.35)
                                                : Colors.black.withOpacity(0.06),
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: Colors.grey.shade100,
                                              child: Icon(Icons.person, size: 18, color: Colors.grey.shade700),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    t.title,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    t.username ?? 'Không rõ user',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    fmtDate.format(t.createdAt),
                                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                             _statusChip(t.status),


                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),

                        // pagination
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: (_page > 1 && !_loadingList)
                                      ? () {
                                          setState(() => _page--);
                                          _loadTickets();
                                        }
                                      : null,
                                  icon: const Icon(Icons.chevron_left),
                                  label: const Text('Trước'),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text('$_page / $_totalPages', style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: (_page < _totalPages && !_loadingList)
                                      ? () {
                                          setState(() => _page++);
                                          _loadTickets();
                                        }
                                      : null,
                                  icon: const Icon(Icons.chevron_right),
                                  label: const Text('Sau'),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const VerticalDivider(width: 1),

                  // ===== RIGHT: DETAIL =====
                  Expanded(child: _buildDetailPane(fmtDate)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailPane(DateFormat fmtDate) {
  final detail = _ticketDetail;

  if (_selectedTicket == null) {
    return const Center(
      child: Text('Chọn một ticket ở bên trái để xem chi tiết'),
    );
  }

  return Column(
    children: [
      // ===== TOP BAR =====
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.black.withOpacity(0.06)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail?.title ?? _selectedTicket!.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Người gửi: ${(detail?.username ?? _selectedTicket?.username) ?? "Không rõ"}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (detail != null)
              _compactDropdown(
                value: detail.status,
                hint: 'Trạng thái',
                icon: Icons.flag_outlined,
                onChanged: (value) {
                  if (value == null || value == detail.status) return;
                  _changeStatus(value);
                },
                items: const [
                  DropdownMenuItem<String?>(
                    value: 'processing',
                    child: Text('Đang xử lý'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'processed',
                    child: Text('Đã xử lý'),
                  ),
                ],
              ),
          ],
        ),
      ),

      if (_loadingDetail) const LinearProgressIndicator(minHeight: 2),

      // ===== BODY =====
      Expanded(
        child: detail == null
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                // +1 để dành index 0 hiển thị mô tả ban đầu
                itemCount: detail.messages.length + 1,
                itemBuilder: (context, index) {
                  // index 0: mô tả initial
                  if (index == 0) {
                    final desc = detail.description;
                    if (desc == null || desc.trim().isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.06),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // const Text(
                          //   'Mô tả ban đầu',
                          //   style: TextStyle(
                          //     fontSize: 12,
                          //     fontWeight: FontWeight.w800,
                          //   ),
                          // ),
                          const SizedBox(height: 6),
                          Text(
                            desc,
                            style: const TextStyle(height: 1.3),
                          ),
                        ],
                      ),
                    );
                  }

                  // các index còn lại là message
 // các index còn lại là message
final m = detail.messages[index - 1];

final senderRaw = (m.senderName ?? '').trim();
final sender = senderRaw.toLowerCase();

// ✅ Chỉ KHÁCH HÀNG nằm bên trái, còn lại (admin/support/support_admin) bên phải
final isCustomer =
    sender.contains('user') ||
    sender.contains('khách') ||
    sender.contains('khach') ||
    sender.contains('người dùng') ||
    sender.contains('nguoi dung') ||
    (detail.username != null &&
        detail.username!.trim().isNotEmpty &&
        senderRaw == detail.username!.trim());

final align = isCustomer ? Alignment.centerLeft : Alignment.centerRight;
final bubble = isCustomer ? Colors.grey.shade100 : Colors.green.shade50;
final cross = isCustomer ? CrossAxisAlignment.start : CrossAxisAlignment.end;

final displayName = m.senderName ?? (isCustomer ? 'Khách hàng' : 'Nhân viên');


                  return Container(
                    alignment: align,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: 560),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: bubble,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.06),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Column(
                          crossAxisAlignment: cross,
                            children: [
                              Text(
                              displayName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // nội dung text
                              if (m.message.trim().isNotEmpty)
                                Text(
                                  m.message,
                                  style: const TextStyle(height: 1.25),
                                ),

                              // ảnh đính kèm (nếu có)
                              if (m.attachmentUrl != null &&
                                  m.attachmentUrl!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  child: Image.network(
                                    _buildAttachmentUrl(
                                      m.attachmentUrl!,
                                    ),
                                    height: 180,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error,
                                            stackTrace) =>
                                        Text(
                                      'Không tải được ảnh',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.red.shade400,
                                      ),
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 6),
                              Text(
                                fmtDate.format(m.createdAt),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),

      // ===== COMPOSER =====
      Container(
        padding:
            const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Colors.black.withOpacity(0.06),
            ),
          ),
        ),
        child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: 'Đính kèm file',
            onPressed: (_sending || _uploadingFile) ? null : _pickFile,
            icon: _uploadingFile
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.attach_file_rounded),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_pickedFile != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      label: Text(_pickedFile!.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onDeleted: (_sending || _uploadingFile) ? null : _clearFile,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                TextField(
                  controller: _replyCtrl,
                  minLines: 1,
                  maxLines: 4,
                  decoration: _pillInput(
                    hint: 'Nhập nội dung trả lời...',
                    icon: Icons.chat_bubble_outline,
                  ),
                  onSubmitted: (_) {
                    if (!_sending && !_uploadingFile) _sendReply();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: (_sending || _uploadingFile) ? null : _sendReply,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send, size: 18),
            label: const Text('Gửi'),
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      )

      ),
    ],
  );
}

}
