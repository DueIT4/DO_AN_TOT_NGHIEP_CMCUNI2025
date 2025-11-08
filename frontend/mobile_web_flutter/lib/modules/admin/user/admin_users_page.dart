import 'package:flutter/material.dart';
import '../../../admin/admin_shell.dart';
import '../../../core/api_base.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<dynamic> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ApiBase.getJson(ApiBase.api('/users/'));
      setState(() {
        _users = response is List ? response : [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      title: 'Quản lý người dùng',
      current: AdminMenu.users,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header với nút thêm
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Danh sách người dùng',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              FilledButton.icon(
                onPressed: () {
                  // TODO: Mở dialog tạo user
                },
                icon: const Icon(Icons.add),
                label: const Text('Thêm người dùng'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Lỗi: $_error'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadUsers,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      )
                    : _users.isEmpty
                        ? const Center(child: Text('Chưa có người dùng nào'))
                        : Card(
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('ID')),
                                DataColumn(label: Text('Tên đăng nhập')),
                                DataColumn(label: Text('Email')),
                                DataColumn(label: Text('Số điện thoại')),
                                DataColumn(label: Text('Vai trò')),
                                DataColumn(label: Text('Trạng thái')),
                                DataColumn(label: Text('Thao tác')),
                              ],
                              rows: _users.map((user) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text('${user['user_id'] ?? ''}')),
                                    DataCell(Text(user['username'] ?? '')),
                                    DataCell(Text(user['email'] ?? '-')),
                                    DataCell(Text(user['phone'] ?? '-')),
                                    DataCell(Text(user['role']?['role_type'] ?? '-')),
                                    DataCell(
                                      Chip(
                                        label: Text(
                                          user['status'] ?? 'active',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        backgroundColor: (user['status'] == 'active')
                                            ? Colors.green.withOpacity(0.2)
                                            : Colors.grey.withOpacity(0.2),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, size: 20),
                                            onPressed: () {
                                              // TODO: Edit user
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, size: 20),
                                            color: Colors.red,
                                            onPressed: () {
                                              // TODO: Delete user
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
