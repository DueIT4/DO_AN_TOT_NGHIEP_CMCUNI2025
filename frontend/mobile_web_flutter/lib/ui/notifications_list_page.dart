import 'package:flutter/material.dart';
import '../models/notification.dart' as models;
import '../services/api_client.dart';
import 'notification_detail_page.dart';
import 'package:intl/intl.dart';

class NotificationsListPage extends StatefulWidget {
  const NotificationsListPage({super.key});

  @override
  State<NotificationsListPage> createState() => _NotificationsListPageState();
}

class _NotificationsListPageState extends State<NotificationsListPage> {
  List<models.AppNotification> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final (success, data, message) = await ApiClient.getMyNotifications();

    if (success) {
      try {
        final notifications = (data as List)
            .map((json) => models.AppNotification.fromJson(json as Map<String, dynamic>))
            .toList();
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Lỗi phân tích dữ liệu: $e';
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Vừa xong';
        }
        return '${difference.inMinutes} phút trước';
      }
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays == 1) {
      return 'Hôm qua';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  String _truncateDescription(String description, {int maxLength = 80}) {
    if (description.length <= maxLength) {
      return description;
    }
    return '${description.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F9E9),
      appBar: AppBar(
        title: const Text('Thông báo'),
        backgroundColor: const Color(0xFF7CCD2B),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadNotifications,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : _notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Chưa có thông báo nào',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          return _NotificationItem(
                            notification: notification,
                            onTap: () async {
                              // Đánh dấu đã đọc nếu chưa đọc
                              if (!notification.isRead) {
                                await ApiClient.markNotificationAsRead(
                                    notification.notificationId);
                                // Reload để cập nhật trạng thái
                                _loadNotifications();
                              }
                              // Điều hướng đến trang chi tiết
                              if (mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => NotificationDetailPage(
                                      notification: notification,
                                    ),
                                  ),
                                ).then((_) {
                                  // Reload khi quay lại để cập nhật trạng thái
                                  _loadNotifications();
                                });
                              }
                            },
                            formatDate: _formatDate,
                            truncateDescription: _truncateDescription,
                          );
                        },
                      ),
                    ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final models.AppNotification notification;
  final VoidCallback onTap;
  final String Function(DateTime) formatDate;
  final String Function(String) truncateDescription;

  const _NotificationItem({
    required this.notification,
    required this.onTap,
    required this.formatDate,
    required this.truncateDescription,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              // Chấm đỏ cho thông báo chưa đọc
              if (!notification.isRead)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tiêu đề
                  Padding(
                    padding: EdgeInsets.only(
                      left: notification.isRead ? 0 : 16,
                    ),
                    child: Text(
                      notification.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Nội dung (căn trái)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      truncateDescription(notification.description),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Ngày nhận (căn phải)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatDate(notification.createdAt),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

