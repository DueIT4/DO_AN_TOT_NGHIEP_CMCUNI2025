import 'package:flutter/material.dart';
import 'package:mobile_web_flutter/core/admin_user_service.dart';

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
      // Nếu ô tìm trống → quay lại danh sách gốc
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tìm kiếm: $e')),
        );
      }
    }
  }

  Future<void> _deleteUser(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá người dùng'),
        content: const Text(
            'Bạn chắc chắn muốn xoá người dùng này khỏi hệ thống?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AdminUserService.deleteUser(id);
      _reload();
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
              Text('Email: ${u['email']}', style: const TextStyle(fontSize: 13)),
            if (u['phone'] != null)
              Text('SĐT: ${u['phone']}', style: const TextStyle(fontSize: 13)),
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
      title: 'Tạo người dùng mới',
      onSubmit: (data) async {
        await AdminUserService.createUser(
          username: data['username'] as String,
          phone: data['phone'] as String,
          password: data['password'] as String,
          email: data['email'] as String?,
          address: data['address'] as String?,
          roleId: data['roleId'] as int?,   // 👈 thêm roleId
        );
      },
    ),
  );

  if (ok == true) {
    _reload();
  }
}

Future<void> _openEditUserDialog(Map<String, dynamic> user) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _UserFormDialog(
      title: 'Cập nhật người dùng',
      initialUser: user,
      onSubmit: (data) async {
        await AdminUserService.updateUser(
          userId: user['user_id'] as int,
          username: data['username'] as String?,
          phone: data['phone'] as String?,
          password: data['password'] as String?,  // có thể null
          email: data['email'] as String?,
          address: data['address'] as String?,
          roleId: data['roleId'] as int?,         // 👈 thêm roleId
        );
      },
    ),
  );

  if (ok == true) {
    _reload();
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
    final r = (roleType ?? '').toLowerCase();
    Color bg;
    Color fg;

    switch (r) {
      case 'admin':
        bg = Colors.deepPurple.shade50;
        fg = Colors.deepPurple.shade700;
        break;
      case 'support_admin':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        break;
      case 'viewer':
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade900;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        roleType ?? '-',
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
    // Không dùng Scaffold, AdminShell sẽ bao bên ngoài
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
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 12),
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
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
                      horizontal: 16, vertical: 12),
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
                          child:
                              Text('Chưa có người dùng nào trong hệ thống.'),
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
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Xem chi tiết',
                                          icon: const Icon(
                                            Icons.info_outline,
                                            size: 18,
                                            color: Colors.blue,
                                          ),
                                          onPressed: () => _showInfo(u),
                                        ),
                                        IconButton(
                                          tooltip: 'Sửa',
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 18,
                                            color: Colors.orange,
                                          ),
                                          onPressed: () =>
                                              _openEditUserDialog(u),
                                        ),
                                        IconButton(
                                          tooltip: 'Xoá',
                                          icon: const Icon(
                                            Icons.delete,
                                            size: 18,
                                            color: Colors.red,
                                          ),
                                          onPressed: () => _deleteUser(id),
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
class _UserFormDialog extends StatefulWidget {
  final String title;
  final Map<String, dynamic>? initialUser;
  final Future<void> Function(Map<String, dynamic> data) onSubmit;

  const _UserFormDialog({
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

  // 👉 giá trị role đang chọn: 'viewer' | 'support_admin' | 'admin'
  late String _roleValue;

  // ⚠️ MAP ROLE → ID: bạn sửa số này cho đúng với DB của bạn
  static const Map<String, int> _roleIdMap = {
    'support_admin': 3,
    'support': 2,
    'admin': 1,
      'viewwer': 4,

  };

  // Danh sách option hiển thị trong dropdown
  static const List<Map<String, String>> _roleOptions = [
    {'value': 'viewer', 'label': 'Viewer'},
    {'value': 'support_admin', 'label': 'Support Admin'},
    {'value': 'admin', 'label': 'Admin'},
  ];

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(
        text: widget.initialUser != null ? widget.initialUser!['username'] : '');
    _phoneCtrl = TextEditingController(
        text: widget.initialUser != null ? widget.initialUser!['phone'] : '');
    _emailCtrl = TextEditingController(
        text: widget.initialUser != null ? widget.initialUser!['email'] ?? '' : '');
    _addressCtrl = TextEditingController(
        text: widget.initialUser != null ? widget.initialUser!['address'] ?? '' : '');
    _passwordCtrl = TextEditingController();

    // set role mặc định
    if (widget.initialUser != null &&
        widget.initialUser!['role_type'] != null) {
      _roleValue = (widget.initialUser!['role_type'] as String).toLowerCase();
    } else {
      _roleValue = 'viewer'; // default
    }

    if (!_roleIdMap.containsKey(_roleValue)) {
      _roleValue = 'viewer';
    }
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

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final String username = _usernameCtrl.text.trim();
    final String phone = _phoneCtrl.text.trim();
    final String? email = _emailCtrl.text.trim().isEmpty
        ? null
        : _emailCtrl.text.trim();
    final String? address = _addressCtrl.text.trim().isEmpty
        ? null
        : _addressCtrl.text.trim();
    final String? password =
        _passwordCtrl.text.isEmpty ? null : _passwordCtrl.text;

    // map role string → role_id
    final int? roleId = _roleIdMap[_roleValue];

    final data = <String, dynamic>{
      'username': username,
      'phone': phone,
      'email': email,
      'address': address,
      'password': password,
      'roleId': roleId,
    };

    try {
      await widget.onSubmit(data);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên đăng nhập',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Bắt buộc';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Bắt buộc';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email (tuỳ chọn)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ (tuỳ chọn)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),

                // 🔽 Dropdown chọn vai trò
                DropdownButtonFormField<String>(
                  value: _roleValue,
                  items: _roleOptions
                      .map(
                        (opt) => DropdownMenuItem<String>(
                          value: opt['value'],
                          child: Text(opt['label']!),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _roleValue = val;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Vai trò',
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _passwordCtrl,
                  decoration: InputDecoration(
                    labelText: _isEdit
                        ? 'Mật khẩu mới (để trống nếu không đổi)'
                        : 'Mật khẩu',
                  ),
                  obscureText: true,
                  validator: (v) {
                    if (!_isEdit) {
                      if (v == null || v.isEmpty) {
                        return 'Bắt buộc';
                      }
                    }
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
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
        FilledButton(
          onPressed: _loading ? null : _handleSubmit,
          child: _loading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Lưu'),
        ),
      ],
    );
  }
}

