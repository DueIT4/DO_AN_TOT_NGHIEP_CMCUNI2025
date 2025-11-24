// lib/modules/admin/support/admin_support_page.dart
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:mobile_web_flutter/core/admin_ticket_service.dart';
import 'package:mobile_web_flutter/src/routes/web_routes.dart';

class AdminSupportPage extends StatefulWidget {
  const AdminSupportPage({super.key});

  @override
  State<AdminSupportPage> createState() => _AdminSupportPageState();
}

class _AdminSupportPageState extends State<AdminSupportPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _replyCtrl = TextEditingController();

  String? _statusFilter; // null, 'processing', 'processed'
  int _page = 1;
  final int _pageSize = 20;

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

  Future<void> _loadTickets({bool resetPage = false}) async {
    if (resetPage) _page = 1;

    setState(() {
      _loadingList = true;
    });

    try {
      final result = await AdminTicketService.listTickets(
        status: _statusFilter,
        search:
            _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        page: _page,
        size: _pageSize,
      );

      if (!mounted) return;

      setState(() {
        _tickets = result.items;
        _total = result.total;

        if (_selectedTicket == null && _tickets.isNotEmpty) {
          _selectTicket(_tickets.first);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải ticket: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingList = false;
        });
      }
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
      final detail =
          await AdminTicketService.getTicketDetail(ticket.ticketId);
      if (!mounted) return;

      setState(() {
        _ticketDetail = detail;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải chi tiết ticket: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingDetail = false;
        });
      }
    }
  }

  Future<void> _sendReply() async {
    final detail = _ticketDetail;
    if (detail == null) return;

    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _sending = true;
    });

    try {
      final msg = await AdminTicketService.sendAdminMessage(
        ticketId: detail.ticketId,
        message: text,
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gửi tin nhắn thất bại: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _changeStatus(String status) async {
    final detail = _ticketDetail;
    if (detail == null) return;

    setState(() {
      _loadingDetail = true;
    });

    try {
      final updated = await AdminTicketService.updateTicketStatus(
        ticketId: detail.ticketId,
        status: status,
      );
      if (!mounted) return;

      setState(() {
        _ticketDetail = updated;
      });

      _loadTickets();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đổi trạng thái thất bại: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingDetail = false;
        });
      }
    }
  }

  int get _totalPages {
    if (_total == 0) return 1;
    return (_total / _pageSize).ceil();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmtDate = DateFormat('dd/MM HH:mm');

    return Column(
      children: [
        // ===== HEADER HỖ TRỢ + NÚT TẠO THÔNG BÁO =====
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              Text(
                'Hỗ trợ người dùng',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.campaign),
                label: const Text('Tạo thông báo'),
                onPressed: () {
                  // 👉 sang trang thông báo hệ thống
                  Navigator.pushNamed(context, WebRoutes.adminNoti);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        Expanded(
          child: Row(
            children: [
              // ===== Cột trái: danh sách ticket =====
              SizedBox(
                width: 320,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: const InputDecoration(
                                isDense: true,
                                prefixIcon: Icon(Icons.search),
                                hintText:
                                    'Tìm theo tiêu đề, người dùng...',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) =>
                                  _loadTickets(resetPage: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _statusFilter,
                            hint: const Text('Trạng thái'),
                            onChanged: (value) {
                              setState(() {
                                _statusFilter = value;
                              });
                              _loadTickets(resetPage: true);
                            },
                            items: const [
                              DropdownMenuItem(
                                value: null,
                                child: Text('Tất cả'),
                              ),
                              DropdownMenuItem(
                                value: 'processing',
                                child: Text('Đang xử lý'),
                              ),
                              DropdownMenuItem(
                                value: 'processed',
                                child: Text('Đã xử lý'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_loadingList)
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: _tickets.isEmpty
                          ? const Center(child: Text('Không có ticket'))
                          : ListView.separated(
                              itemCount: _tickets.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final t = _tickets[index];
                                final isActive =
                                    _selectedTicket?.ticketId ==
                                        t.ticketId;
                                final statusColor =
                                    t.status == 'processed'
                                        ? Colors.green
                                        : Colors.orange;

                                return Material(
                                  color: isActive
                                      ? Colors.green.withOpacity(0.05)
                                      : Colors.transparent,
                                  child: ListTile(
                                    dense: true,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8),
                                    title: Text(
                                      t.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.username ?? 'Không rõ user',
                                          style: const TextStyle(
                                              fontSize: 12),
                                        ),
                                        Text(
                                          fmtDate.format(t.createdAt),
                                          style: const TextStyle(
                                              fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    trailing: Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        color: statusColor
                                            .withOpacity(0.1),
                                      ),
                                      child: Text(
                                        t.status == 'processed'
                                            ? 'Đã xử lý'
                                            : 'Đang xử lý',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                    onTap: () => _selectTicket(t),
                                  ),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed:
                                _page > 1 && !_loadingList
                                    ? () {
                                        setState(() {
                                          _page--;
                                        });
                                        _loadTickets();
                                      }
                                    : null,
                            child: const Text('< Trước'),
                          ),
                          Text('$_page/$_totalPages'),
                          TextButton(
                            onPressed:
                                _page < _totalPages && !_loadingList
                                    ? () {
                                        setState(() {
                                          _page++;
                                        });
                                        _loadTickets();
                                      }
                                    : null,
                            child: const Text('Sau >'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const VerticalDivider(width: 1),

              // ===== Cột phải: chi tiết + chat =====
              Expanded(
                child: _buildDetailPane(fmtDate),
              ),
            ],
          ),
        ),
      ],
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
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.black12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail?.title ?? _selectedTicket!.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (detail != null && detail.username != null)
                      Text(
                        'Người gửi: ${detail.username}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ),
              if (detail != null)
                DropdownButton<String>(
                  value: detail.status,
                  onChanged: (value) {
                    if (value == null || value == detail.status) return;
                    _changeStatus(value);
                  },
                  items: const [
                    DropdownMenuItem(
                      value: 'processing',
                      child: Text('Đang xử lý'),
                    ),
                    DropdownMenuItem(
                      value: 'processed',
                      child: Text('Đã xử lý'),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (_loadingDetail)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: detail == null
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: detail.messages.length,
                  itemBuilder: (context, index) {
                    final m = detail.messages[index];
                    final isAdmin = m.senderName == null ||
                        (m.senderName ?? '')
                            .toLowerCase()
                            .contains('admin');

                    final align = isAdmin
                        ? Alignment.centerRight
                        : Alignment.centerLeft;
                    final bgColor =
                        isAdmin ? Colors.green[50] : Colors.grey[200];

                    return Container(
                      alignment: align,
                      margin:
                          const EdgeInsets.symmetric(vertical: 4),
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxWidth: 500),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: isAdmin
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.senderName ??
                                      (isAdmin
                                          ? 'Admin'
                                          : 'Người dùng'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(m.message),
                                const SizedBox(height: 4),
                                Text(
                                  fmtDate.format(m.createdAt),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
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
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyCtrl,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Nhập nội dung trả lời...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) {
                    if (!_sending) _sendReply();
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _sending ? null : _sendReply,
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('Gửi'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
