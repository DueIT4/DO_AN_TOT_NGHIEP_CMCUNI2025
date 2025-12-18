import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_web_flutter/core/toast.dart';
import 'package:mobile_web_flutter/core/notification_service.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = NotificationService.listSent();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = NotificationService.listSent();
    });
  }

  Future<void> _openCreateDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _NotificationCreateDialog(
        key: UniqueKey(),
      ),
    );
    if (ok == true) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'Đã gửi thông báo',
        type: ToastType.success,
      );
      _reload();
    }
  }

  void _showDetail(Map<String, dynamic> n) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(n['title'] ?? ''),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (n['username'] != null || n['email'] != null) ...[
              Text(
                'Người nhận: '
                '${n['username'] ?? ''}'
                '${n['email'] != null ? " (${n['email']})" : ""}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
            ],
            Text(n['description'] ?? ''),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      String two(int v) => v.toString().padLeft(2, '0');
      return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return iso;
    }
  }

  Widget _buildReadStatus(String? readAt) {
    final isRead = readAt != null;
    return Row(
      children: [
        Icon(
          isRead ? Icons.mark_email_read : Icons.mark_email_unread,
          size: 18,
          color: isRead ? Colors.green.shade700 : Colors.orange.shade700,
        ),
        const SizedBox(width: 4),
        Text(
          isRead ? 'Đã đọc' : 'Chưa đọc',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isRead ? Colors.green.shade800 : Colors.orange.shade800,
          ),
        ),
      ],
    );
  }

  Future<void> _openResendDialog(Map<String, dynamic> n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _NotificationResendDialog(
        key: UniqueKey(),
        notificationId: n['notification_id'] as int,
        title: n['title'] ?? '',
        description: n['description'] ?? '',
      ),
    );

    if (ok == true) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'Đã gửi lại thông báo',
        type: ToastType.success,
      );
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.8),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Text(
                        'Quản lý thông báo',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 360,
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Tìm theo ID, tiêu đề, nội dung, user, email...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Xoá tìm kiếm',
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _query = '');
                                    },
                                  ),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        tooltip: 'Tạo thông báo',
                        onPressed: _openCreateDialog,
                        icon: const Icon(Icons.add),
                      ),
                      IconButton(
                        tooltip: 'Tải lại',
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _future,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Lỗi tải danh sách thông báo: ${snap.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      final items = snap.data ?? [];

                      final q = _query.trim().toLowerCase();
                      final filtered = q.isEmpty
                          ? items
                          : items.where((n) {
                              final id = '${n['notification_id'] ?? ''}'.toLowerCase();
                              final title = '${n['title'] ?? ''}'.toLowerCase();
                              final desc = '${n['description'] ?? ''}'.toLowerCase();
                              final username = '${n['username'] ?? ''}'.toLowerCase();
                              final email = '${n['email'] ?? ''}'.toLowerCase();
                              return id.contains(q) ||
                                  title.contains(q) ||
                                  desc.contains(q) ||
                                  username.contains(q) ||
                                  email.contains(q);
                            }).toList();

                      if (filtered.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Không tìm thấy thông báo phù hợp.'),
                        );
                      }

                      return Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 28,
                            headingRowHeight: 40,
                            dataRowHeight: 52,
                            columns: const [
                              DataColumn(label: Text('ID')),
                              DataColumn(label: Text('Tiêu đề')),
                              DataColumn(label: Text('Người nhận')),
                              DataColumn(label: Text('Thời gian gửi')),
                              DataColumn(label: Text('Trạng thái')),
                              DataColumn(label: Text('Hành động')),
                            ],
                            rows: filtered.map((n) {
                              final id = (n['notification_id'] as num).toInt();
                              final title = n['title'] ?? '';
                              final username = n['username'] ?? '';
                              final email = n['email'] ?? '';
                              final createdAt = _formatDate(n['created_at'] as String?);
                              final readAt = n['read_at'] as String?;

                              final receiver = (email is String && email.isNotEmpty)
                                  ? '$username ($email)'
                                  : username;

                              return DataRow(
                                cells: [
                                  DataCell(Text('$id')),
                                  DataCell(
                                    SizedBox(
                                      width: 240,
                                      child: Text(
                                        title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 220,
                                      child: Text(
                                        receiver,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(createdAt)),
                                  DataCell(_buildReadStatus(readAt)),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Xem nội dung',
                                          icon: const Icon(
                                            Icons.visibility,
                                            size: 18,
                                            color: Colors.blue,
                                          ),
                                          onPressed: () => _showDetail(n),
                                        ),
                                        IconButton(
                                          tooltip: 'Gửi lại (tạo thông báo mới)',
                                          icon: const Icon(
                                            Icons.send,
                                            size: 18,
                                            color: Colors.teal,
                                          ),
                                          onPressed: () => _openResendDialog(n),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationCreateDialog extends StatefulWidget {
  const _NotificationCreateDialog({super.key});

  @override
  State<_NotificationCreateDialog> createState() =>
      _NotificationCreateDialogState();
}

class _NotificationCreateDialogState extends State<_NotificationCreateDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _userIdsText = TextEditingController();

  bool _sendAll = true;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _userIdsText.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    if (!_sendAll && _userIdsText.text.trim().isEmpty) {
      AppToast.show(
        context,
        message: 'Nhập danh sách user_id hoặc chọn gửi toàn bộ.',
        type: ToastType.warning,
      );
      return;
    }

    List<int>? userIds;
    if (!_sendAll) {
      userIds = _userIdsText.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map((s) => int.tryParse(s))
          .whereType<int>()
          .toList();

      if (userIds.isEmpty) {
        AppToast.show(
          context,
          message: 'Danh sách user_id không hợp lệ.',
          type: ToastType.error,
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await NotificationService.create(
        title: _title.text.trim(),
        description: _description.text.trim(),
        sendAll: _sendAll,
        userIds: userIds,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'Lỗi tạo thông báo: $e',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tạo thông báo mới'),
      content: Form(
        key: _form,
        child: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Tiêu đề'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nhập tiêu đề' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Nội dung'),
                  maxLines: 4,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nhập nội dung' : null,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Gửi tới tất cả người dùng'),
                  value: _sendAll,
                  onChanged: (v) => setState(() => _sendAll = v),
                ),
                if (!_sendAll) ...[
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _userIdsText,
                    decoration: const InputDecoration(
                      labelText: 'Danh sách user_id (vd: 1,2,3)',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Gửi'),
        ),
      ],
    );
  }
}

class _NotificationResendDialog extends StatefulWidget {
  final int notificationId;
  final String title;
  final String description;

  const _NotificationResendDialog({
    super.key,
    required this.notificationId,
    required this.title,
    required this.description,
  });

  @override
  State<_NotificationResendDialog> createState() =>
      _NotificationResendDialogState();
}

class _NotificationResendDialogState
    extends State<_NotificationResendDialog> {
  final _userIdsText = TextEditingController();
  bool _sendAll = true;
  bool _saving = false;

  @override
  void dispose() {
    _userIdsText.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    List<int>? userIds;
    if (!_sendAll) {
      userIds = _userIdsText.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map((s) => int.tryParse(s))
          .whereType<int>()
          .toList();

      if (userIds.isEmpty) {
        AppToast.show(
          context,
          message: 'Danh sách user_id không hợp lệ.',
          type: ToastType.error,
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await NotificationService.resend(
        notificationId: widget.notificationId,
        sendAll: _sendAll,
        userIds: userIds,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'Lỗi gửi lại: $e',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gửi lại thông báo'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tiêu đề:', style: Theme.of(context).textTheme.labelMedium),
              Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text('Nội dung:', style: Theme.of(context).textTheme.labelMedium),
              Text(widget.description),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Gửi tới tất cả người dùng'),
                value: _sendAll,
                onChanged: (v) => setState(() => _sendAll = v),
              ),
              if (!_sendAll) ...[
                const SizedBox(height: 6),
                TextField(
                  controller: _userIdsText,
                  decoration: const InputDecoration(
                    labelText: 'Danh sách user_id (vd: 1,2,3)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: const Text('Gửi lại'),
        ),
      ],
    );
  }
}
