// lib/modules/admin/notifications/admin_notifications_page.dart
import 'package:flutter/material.dart';
import 'package:mobile_web_flutter/core/toast.dart';
import 'package:mobile_web_flutter/services/admin/notification_service.dart';
import 'package:mobile_web_flutter/models/admin/notification_models.dart';
import 'dart:async';
import 'package:mobile_web_flutter/services/admin/admin_user_service.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  late Future<List<NotificationItem>> _future;

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

  void _showDetail(NotificationItem n) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(n.title ?? ''),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((n.username != null && n.username!.isNotEmpty) ||
                (n.email != null && n.email!.isNotEmpty)) ...[
              Text(
                'Người nhận: '
                '${n.username ?? ''}'
                '${(n.email != null && n.email!.isNotEmpty) ? " (${n.email})" : ""}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
            ],
            Text(n.description ?? ''),
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

  // Hỗ trợ cả DateTime? và String? (phòng khi model bạn parse theo kiểu nào)
  String _formatDate(Object? value) {
    if (value == null) return '-';

    DateTime? dt;
    if (value is DateTime) {
      dt = value;
    } else if (value is String && value.isNotEmpty) {
      try {
        dt = DateTime.parse(value);
      } catch (_) {
        return value;
      }
    } else {
      return '$value';
    }

    dt = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Widget _buildReadStatus(Object? readAt) {
    final isRead = readAt != null &&
        (!(readAt is String) || (readAt as String).isNotEmpty);
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

  Future<void> _openResendDialog(NotificationItem n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _NotificationResendDialog(
        key: UniqueKey(),
        notificationId: n.notificationId ?? 0,
        title: n.title ?? '',
        description: n.description ?? '',
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
                  child: FutureBuilder<List<NotificationItem>>(
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
                              final id = '${n.notificationId ?? ''}'.toLowerCase();
                              final title = '${n.title ?? ''}'.toLowerCase();
                              final desc = '${n.description ?? ''}'.toLowerCase();
                              final username = '${n.username ?? ''}'.toLowerCase();
                              final email = '${n.email ?? ''}'.toLowerCase();
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
                              final id = (n.notificationId ?? 0);
                              final title = n.title ?? '';
                              final username = n.username ?? '';
                              final email = n.email ?? '';

                              final createdAt = _formatDate(n.createdAt);
                              final readAt = n.readAt;

                              final receiver = (email.isNotEmpty)
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

class _UserRecipientPicker extends StatefulWidget {
  final bool enabled;
  final void Function(List<int> userIds) onChanged;
  final List<int> initialSelectedIds;

  const _UserRecipientPicker({
    super.key,
    required this.enabled,
    required this.onChanged,
    this.initialSelectedIds = const [],
  });

  @override
  State<_UserRecipientPicker> createState() => _UserRecipientPickerState();
}

class _UserRecipientPickerState extends State<_UserRecipientPicker> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _results = [];
  final Map<int, Map<String, dynamic>> _selected = {};

  @override
  void initState() {
    super.initState();
    // init selected from ids only (không có info thì chip sẽ hiện #id)
    for (final id in widget.initialSelectedIds) {
      _selected[id] = {'user_id': id, 'username': 'User #$id'};
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onChanged(_selected.keys.toList());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged(_selected.keys.toList());

  Future<void> _doSearch(String q) async {
    final keyword = q.trim();
    if (!widget.enabled) return;

    if (keyword.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // ✅ dùng đúng service bạn đã có ở AdminUsersPage
      final res = await AdminUserService.searchUsers(keyword: keyword);
      final items = (res.items).map((e) => Map<String, dynamic>.from(e)).toList();

      if (!mounted) return;
      setState(() {
        _results = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () => _doSearch(v));
  }

  void _toggleUser(Map<String, dynamic> u) {
    final id = (u['user_id'] as int?) ?? 0;
    if (id == 0) return;

    setState(() {
      if (_selected.containsKey(id)) {
        _selected.remove(id);
      } else {
        _selected[id] = u;
      }
    });
    _emit();
  }

  String _displayName(Map<String, dynamic> u) {
    final username = (u['username'] ?? '').toString().trim();
    final email = (u['email'] ?? '').toString().trim();
    final phone = (u['phone'] ?? '').toString().trim();

    final main = username.isNotEmpty ? username : 'User #${u['user_id']}';
    final sub = email.isNotEmpty ? email : (phone.isNotEmpty ? phone : '');
    return sub.isNotEmpty ? '$main ($sub)' : main;
  }

  InputDecoration _decoration(BuildContext context, {required String label, String? hint, IconData? icon}) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 18, color: scheme.onSurfaceVariant),
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withOpacity(0.35),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary.withOpacity(0.55), width: 1.3),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: widget.enabled ? 1 : 0.55,
      child: IgnorePointer(
        ignoring: !widget.enabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: _decoration(
                context,
                label: 'Tìm người nhận',
                hint: 'Nhập username / email / SĐT...',
                icon: Icons.search_rounded,
              ),
            ),
            const SizedBox(height: 10),

            // Selected chips
            if (_selected.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selected.entries.map((e) {
                  final u = e.value;
                  final text = (u['username'] ?? 'User #${e.key}').toString();
                  return Chip(
                    label: Text(text, overflow: TextOverflow.ellipsis),
                    onDeleted: () {
                      setState(() => _selected.remove(e.key));
                      _emit();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],

            // Results
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
              ),
              child: SizedBox(
                height: 220,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Lỗi tìm kiếm: $_error',
                              style: const TextStyle(color: Colors.red),
                            ),
                          )
                        : _results.isEmpty
                            ? const Center(child: Text('Nhập từ khóa để tìm người dùng.'))
                            : ListView.separated(
                                itemCount: _results.length,
                                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.black.withOpacity(0.06)),
                                itemBuilder: (context, i) {
                                  final u = _results[i];
                                  final id = (u['user_id'] as int?) ?? 0;
                                  final selected = _selected.containsKey(id);

                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      _displayName(u),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    subtitle: Text('user_id: $id', style: TextStyle(color: scheme.onSurfaceVariant)),
                                    trailing: Icon(
                                      selected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                                      color: selected ? scheme.primary : scheme.onSurfaceVariant,
                                    ),
                                    onTap: () => _toggleUser(u),
                                  );
                                },
                              ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Chọn nhiều người nhận được. Danh sách gửi sẽ lấy theo user_id.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
class _NotificationCreateDialog extends StatefulWidget {
  const _NotificationCreateDialog({super.key});

  @override
  State<_NotificationCreateDialog> createState() => _NotificationCreateDialogState();
}

class _NotificationCreateDialogState extends State<_NotificationCreateDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();

  bool _sendAll = true;
  bool _saving = false;

  List<int> _selectedUserIds = [];

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  InputDecoration _decoration(BuildContext context, {required String label, String? hint, IconData? icon}) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 18, color: scheme.onSurfaceVariant),
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withOpacity(0.35),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary.withOpacity(0.55), width: 1.3),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    if (!_sendAll && _selectedUserIds.isEmpty) {
      AppToast.show(
        context,
        message: 'Vui lòng chọn ít nhất 1 người nhận hoặc bật gửi toàn bộ.',
        type: ToastType.warning,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await NotificationService.create(
        title: _title.text.trim(),
        description: _description.text.trim(),
        sendAll: _sendAll,
        userIds: _sendAll ? null : _selectedUserIds,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: 'Lỗi tạo thông báo: $e', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      actionsPadding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
      title: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withOpacity(0.10),
              scheme.tertiary.withOpacity(0.10),
            ],
          ),
          border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.06))),
        ),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.notifications_active_rounded, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tạo thông báo mới',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('Soạn nội dung và chọn người nhận',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Đóng',
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
      content: Form(
        key: _form,
        child: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: _decoration(context, label: 'Tiêu đề', hint: 'VD: Bảo trì hệ thống', icon: Icons.title_rounded),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập tiêu đề' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 4,
                  decoration: _decoration(context, label: 'Nội dung', hint: 'Nhập nội dung thông báo...', icon: Icons.description_rounded),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập nội dung' : null,
                ),
                const SizedBox(height: 12),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Gửi tới tất cả người dùng'),
                  value: _sendAll,
                  onChanged: (v) {
                    setState(() {
                      _sendAll = v;
                      if (v) _selectedUserIds = [];
                    });
                  },
                ),

                if (!_sendAll) ...[
                  const SizedBox(height: 8),
                  _UserRecipientPicker(
                    enabled: !_sendAll && !_saving,
                    onChanged: (ids) => _selectedUserIds = ids,
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
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send_rounded, size: 18),
          label: const Text('Gửi'),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
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
  State<_NotificationResendDialog> createState() => _NotificationResendDialogState();
}

class _NotificationResendDialogState extends State<_NotificationResendDialog> {
  bool _sendAll = true;
  bool _saving = false;
  List<int> _selectedUserIds = [];

  Future<void> _submit() async {
    if (!_sendAll && _selectedUserIds.isEmpty) {
      AppToast.show(
        context,
        message: 'Vui lòng chọn ít nhất 1 người nhận hoặc bật gửi toàn bộ.',
        type: ToastType.warning,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await NotificationService.resend(
        notificationId: widget.notificationId,
        sendAll: _sendAll,
        userIds: _sendAll ? null : _selectedUserIds,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: 'Lỗi gửi lại: $e', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      actionsPadding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
      title: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withOpacity(0.10),
              scheme.tertiary.withOpacity(0.10),
            ],
          ),
          border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.06))),
        ),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.send_rounded, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gửi lại thông báo',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('Tạo thông báo mới từ nội dung cũ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Đóng',
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tiêu đề', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),

              Text('Nội dung', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(widget.description),

              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Gửi tới tất cả người dùng'),
                value: _sendAll,
                onChanged: (v) {
                  setState(() {
                    _sendAll = v;
                    if (v) _selectedUserIds = [];
                  });
                },
              ),

              if (!_sendAll) ...[
                const SizedBox(height: 8),
                _UserRecipientPicker(
                  enabled: !_sendAll && !_saving,
                  onChanged: (ids) => _selectedUserIds = ids,
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
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send, size: 18),
          label: const Text('Gửi lại'),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}



