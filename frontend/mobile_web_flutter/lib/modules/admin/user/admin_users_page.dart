import 'package:flutter/material.dart';
import 'package:mobile_web_flutter/services/admin/admin_user_service.dart';
import 'package:mobile_web_flutter/core/toast.dart';
import 'package:mobile_web_flutter/core/role_ui.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  late Future<List<Map<String, dynamic>>> _future;

  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResult = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _future = AdminUserService.listUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _isSearching = false;
      _searchResult = [];
      _future = AdminUserService.listUsers();
    });
  }

  Future<void> _search() async {
    final keyword = _searchCtrl.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResult = [];
        _future = AdminUserService.listUsers();
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final res = await AdminUserService.searchUsers(keyword: keyword);
      setState(() {
        _searchResult = res.items;
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'Lỗi tìm kiếm: $e',
        type: ToastType.error,
      );
    }
  }

  void _showInfo(Map<String, dynamic> u) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(u['username'] ?? ''),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (u['email'] != null)
              Text(
                'Email: ${u['email']}',
                style: const TextStyle(fontSize: 13),
              ),
            if (u['phone'] != null)
              Text(
                'SĐT: ${u['phone']}',
                style: const TextStyle(fontSize: 13),
              ),
            if (u['address'] != null &&
                (u['address'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Địa chỉ:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(u['address'], style: const TextStyle(fontSize: 13)),
            ],
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

  Future<void> _openCreateUserDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _UserFormDialog(
        key: UniqueKey(),
        title: 'Tạo người dùng mới',
        onSubmit: (data) async {
          await AdminUserService.createUser(
            username: data['username'] as String,
            phone: data['phone'] as String,
            password: data['password'] as String,
            email: data['email'] as String?,
            address: data['address'] as String?,
            roleId: data['roleId'] as int?,
            status: data['status'] as String?,
          );
        },
      ),
    );

    if (ok == true) {
      if (mounted) {
        AppToast.show(
          context,
          message: 'Tạo người dùng thành công',
          type: ToastType.success,
        );
      }
      _reload();
    }
  }

  Future<void> _openEditUserDialog(Map<String, dynamic> user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _UserFormDialog(
        key: UniqueKey(),
        title: 'Cập nhật người dùng',
        initialUser: user,
        onSubmit: (data) async {
          await AdminUserService.updateUser(
            userId: user['user_id'] as int,
            username: data['username'] as String?,
            phone: data['phone'] as String?,
            password: data['password'] as String?,
            email: data['email'] as String?,
            address: data['address'] as String?,
            roleId: data['roleId'] as int?,
            status: data['status'] as String?,
          );
        },
      ),
    );

    if (ok == true) {
      if (mounted) {
        AppToast.show(
          context,
          message: 'Cập nhật người dùng thành công',
          type: ToastType.success,
        );
      }
      _reload();
    }
  }

  Future<void> _setStatus(int userId, String status) async {
    try {
      await AdminUserService.updateUser(
        userId: userId,
        status: status,
      );
      if (!mounted) return;
      AppToast.show(
        context,
        message: status == 'active'
            ? 'Đã kích hoạt người dùng'
            : 'Đã ngưng hoạt động người dùng',
        type: ToastType.success,
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'Lỗi cập nhật trạng thái: $e',
        type: ToastType.error,
      );
    }
  }

  Widget _buildStatusChip(String? status) {
    final s = (status ?? '').toLowerCase();
    Color bg;
    Color fg;

    if (s == 'active') {
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
    } else if (s == 'inactive') {
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
    } else {
      bg = Colors.grey.shade100;
      fg = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status ?? '-',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }

    Widget _buildRoleChip(String? roleType) {
    final bg = roleBgColor(roleType);
    final fg = roleFgColor(roleType);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        roleLabelVi(roleType), // ✅ đổi label
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header card
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(0.8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quản lý người dùng',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Row(
                        children: [
                          SizedBox(
                            width: 260,
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                hintText: 'Tìm theo tên, email, SĐT...',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onSubmitted: (_) => _search(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _search,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            child: const Icon(Icons.search, size: 20),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Tạo người dùng',
                            onPressed: _openCreateUserDialog,
                            icon: const Icon(Icons.person_add),
                          ),
                          IconButton(
                            tooltip: 'Tải lại',
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Nội dung
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _future,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting &&
                          !_isSearching) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Lỗi tải danh sách người dùng: ${snap.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      final users =
                          _isSearching ? _searchResult : (snap.data ?? []);
                      if (users.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Chưa có người dùng nào trong hệ thống.'),
                        );
                      }

                      return Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 28,
                            headingRowHeight: 40,
                            dataRowHeight: 48,
                            columns: const [
                              DataColumn(label: Text('ID')),
                              DataColumn(label: Text('Tên đăng nhập')),
                              DataColumn(label: Text('SĐT')),
                              DataColumn(label: Text('Email')),
                              DataColumn(label: Text('Vai trò')),
                              DataColumn(label: Text('Trạng thái')),
                              DataColumn(label: Text('Hành động')),
                            ],
                            rows: users.map((u) {
                              final id = u['user_id'] as int;
                              final username = u['username'] ?? '';
                              final phone = u['phone'] ?? '';
                              final email = u['email'] ?? '';
                              final role = u['role_type'] ?? '';
                              final status = u['status'] ?? '';

                              return DataRow(
                                cells: [
                                  DataCell(Text('$id')),
                                  DataCell(
                                    Row(
                                      children: [
                                        const CircleAvatar(
                                          radius: 14,
                                          child: Icon(Icons.person, size: 16),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(username),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text(phone)),
                                  DataCell(
                                    SizedBox(
                                      width: 200,
                                      child: Text(
                                        email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(_buildRoleChip(role)),
                                  DataCell(_buildStatusChip(status)),
                                  DataCell(
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'view') {
                                          _showInfo(u);
                                        } else if (value == 'edit') {
                                          _openEditUserDialog(u);
                                        } else if (value == 'active') {
                                          _setStatus(id, 'active');
                                        } else if (value == 'inactive') {
                                          _setStatus(id, 'inactive');
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'view',
                                          child: ListTile(
                                            leading: Icon(Icons.info_outline),
                                            title: Text('Xem chi tiết'),
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: ListTile(
                                            leading: Icon(Icons.edit),
                                            title: Text('Sửa'),
                                          ),
                                        ),
                                        PopupMenuDivider(),
                                        PopupMenuItem(
                                          value: 'active',
                                          child: ListTile(
                                            leading: Icon(
                                                Icons.check_circle_outline),
                                            title: Text('Kích hoạt'),
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'inactive',
                                          child: ListTile(
                                            leading: Icon(Icons.block),
                                            title: Text('Ngưng hoạt động'),
                                          ),
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

/// Dialog form thêm / sửa user
/// Dialog form thêm / sửa user (UI IMPROVED - giữ nguyên logic)
class _UserFormDialog extends StatefulWidget {
  final String title;
  final Map<String, dynamic>? initialUser;
  final Future<void> Function(Map<String, dynamic> data) onSubmit;

  const _UserFormDialog({
    super.key,
    required this.title,
    this.initialUser,
    required this.onSubmit,
  });

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _usernameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _passwordCtrl;

  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.initialUser != null;

  // role (khớp DB)
  late String _roleValue;

  static const Map<String, int> _roleIdMap = {
    'admin': 1,
    'support': 2,
    'support_admin': 3,
    'viewer': 4,
  };

  static const List<Map<String, String>> _roleOptions = [
    {'value': 'viewer', 'label': 'Khách hàng'},
    {'value': 'support', 'label': 'Nhân viên'},
    {'value': 'support_admin', 'label': 'Quản trị hỗ trợ'},
    {'value': 'admin', 'label': 'Quản trị viên'},
  ];

  // status
  late String _statusValue;
  static const List<Map<String, String>> _statusOptions = [
    {'value': 'active', 'label': 'Hoạt động'},
    {'value': 'inactive', 'label': 'Không hoạt động'},
  ];

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(
      text: widget.initialUser != null ? widget.initialUser!['username'] : '',
    );
    _phoneCtrl = TextEditingController(
      text: widget.initialUser != null ? widget.initialUser!['phone'] : '',
    );
    _emailCtrl = TextEditingController(
      text: widget.initialUser != null ? widget.initialUser!['email'] ?? '' : '',
    );
    _addressCtrl = TextEditingController(
      text: widget.initialUser != null ? widget.initialUser!['address'] ?? '' : '',
    );
    _passwordCtrl = TextEditingController();

    if (widget.initialUser != null && widget.initialUser!['role_type'] != null) {
      _roleValue = (widget.initialUser!['role_type'] as String).toLowerCase();
    } else {
      _roleValue = 'viewer';
    }
    if (!_roleIdMap.containsKey(_roleValue)) _roleValue = 'viewer';

    if (widget.initialUser != null && widget.initialUser!['status'] != null) {
      _statusValue = (widget.initialUser!['status'] as String).toLowerCase();
    } else {
      _statusValue = 'active';
    }
    if (!_statusOptions.any((o) => o['value'] == _statusValue)) _statusValue = 'active';
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  InputDecoration _decoration(
    BuildContext context, {
    required String label,
    String? hint,
    IconData? icon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 18, color: scheme.onSurfaceVariant),
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withOpacity(0.35),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
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

  Widget _sectionTitle(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            height: 8,
            width: 8,
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.8),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    // ✅ giữ nguyên logic/keys
    final String username = _usernameCtrl.text.trim();
    final String phone = _phoneCtrl.text.trim();
    final String? email = _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim();
    final String? address = _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim();
    final String? password = _passwordCtrl.text.isEmpty ? null : _passwordCtrl.text;
    final int? roleId = _roleIdMap[_roleValue];

    final data = <String, dynamic>{
      'username': username,
      'phone': phone,
      'email': email,
      'address': address,
      'password': password,
      'roleId': roleId,
      'status': _statusValue,
    };

    try {
      await widget.onSubmit(data);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
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

      // ✅ Header gradient + icon + subtitle
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
          border: Border(
            bottom: BorderSide(color: Colors.black.withOpacity(0.06)),
          ),
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
              child: Icon(
                _isEdit ? Icons.manage_accounts_rounded : Icons.person_add_alt_1_rounded,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isEdit ? 'Cập nhật thông tin & phân quyền' : 'Tạo tài khoản và phân quyền',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Đóng',
              onPressed: _loading ? null : () => Navigator.pop(context, false),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),

      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sectionTitle(context, 'Thông tin tài khoản'),

                TextFormField(
                  controller: _usernameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(
                    context,
                    label: 'Tên đăng nhập',
                    hint: 'VD: nguyenvana',
                    icon: Icons.person_rounded,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _phoneCtrl,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.phone,
                  decoration: _decoration(
                    context,
                    label: 'Số điện thoại (tuỳ chọn)',
                    hint: 'VD: 09xxxxxxxx',
                    icon: Icons.phone_rounded,
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return null; // ✅ cho phép null/empty

                    // ✅ chỉ cho số, dài 9-11 (tuỳ bạn chỉnh)
                    final ok = RegExp(r'^\d{9,11}$').hasMatch(value);
                    if (!ok) return 'SĐT không hợp lệ (chỉ gồm số, 9–11 ký tự)';
                    return null;
                  },
                ),

                const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                decoration: _decoration(
                  context,
                  label: 'Email (tuỳ chọn)',
                  hint: 'VD: user@email.com',
                  icon: Icons.email_rounded,
                ),
                validator: (v) {
                  final value = (v ?? '').trim();

                  final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
                  if (!ok) return 'Email không đúng định dạng';
                  return null;
                },
              ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _addressCtrl,
                  textInputAction: TextInputAction.next,
                  maxLines: 2,
                  decoration: _decoration(
                    context,
                    label: 'Địa chỉ (tuỳ chọn)',
                    hint: 'VD: 12 Nguyễn Trãi, Q.1',
                    icon: Icons.location_on_rounded,
                  ),
                ),

                const SizedBox(height: 16),
                _sectionTitle(context, 'Phân quyền & trạng thái'),

                LayoutBuilder(
                  builder: (context, c) {
                    final isNarrow = c.maxWidth < 460;

                    final role = Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _roleValue,
                        isExpanded: true,
                        items: _roleOptions
                            .map((opt) => DropdownMenuItem<String>(
                                  value: opt['value'],
                                  child: Text(opt['label']!, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => _roleValue = val);
                        },
                        decoration: _decoration(
                          context,
                          label: 'Vai trò',
                          icon: Icons.badge_rounded,
                        ),
                      ),
                    );

                    final status = Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _statusValue,
                        isExpanded: true,
                        items: _statusOptions
                            .map((opt) => DropdownMenuItem<String>(
                                  value: opt['value'],
                                  child: Text(opt['label']!),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => _statusValue = val);
                        },
                        decoration: _decoration(
                          context,
                          label: 'Trạng thái',
                          icon: Icons.toggle_on_rounded,
                        ),
                      ),
                    );

                    return isNarrow
                        ? Column(
                            children: [
                              role,
                              const SizedBox(height: 12),
                              status,
                            ],
                          )
                        : Row(
                            children: [
                              role,
                              const SizedBox(width: 12),
                              status,
                            ],
                          );
                  },
                ),

                const SizedBox(height: 16),
                _sectionTitle(context, 'Bảo mật'),

                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  decoration: _decoration(
                    context,
                    label: _isEdit ? 'Mật khẩu mới (để trống nếu không đổi)' : 'Mật khẩu',
                    icon: Icons.lock_rounded,
                  ),
                  validator: (v) {
                    if (!_isEdit && (v == null || v.isEmpty)) return 'Bắt buộc';
                    return null;
                  },
                ),

                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.18)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          onPressed: _loading ? null : _handleSubmit,
          icon: _loading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_rounded, size: 18),
          label: Text(_isEdit ? 'Lưu thay đổi' : 'Tạo mới'),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}
