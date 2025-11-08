import 'package:flutter/material.dart';
import '../../../admin/admin_shell.dart';
import '../../../core/api_base.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  List<dynamic> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ApiBase.getJson(ApiBase.api('/notifications/'));
      setState(() {
        _notifications = response is List ? response : [];
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
      title: 'Quản lý thông báo',
      current: AdminMenu.notifications,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Danh sách thông báo',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              FilledButton.icon(
                onPressed: () {
                  // TODO: Mở dialog tạo notification
                },
                icon: const Icon(Icons.add),
                label: const Text('Tạo thông báo'),
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
                              onPressed: _loadNotifications,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      )
                    : _notifications.isEmpty
                        ? const Center(child: Text('Chưa có thông báo nào'))
                        : ListView.builder(
                            itemCount: _notifications.length,
                            itemBuilder: (context, index) {
                              final notif = _notifications[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue.withOpacity(0.1),
                                    child: const Icon(Icons.notifications, color: Colors.blue),
                                  ),
                                  title: Text(notif['title'] ?? 'Không có tiêu đề'),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(notif['description'] ?? ''),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Người nhận: ${notif['user_id'] ?? 'N/A'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: PopupMenuButton(
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'view',
                                        child: Text('Xem chi tiết'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Xóa'),
                                      ),
                                    ],
                                    onSelected: (value) {
                                      // TODO: Handle action
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
