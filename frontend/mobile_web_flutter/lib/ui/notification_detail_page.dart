import 'package:flutter/material.dart';
import '../models/notification.dart' as models;
import 'package:intl/intl.dart';

class NotificationDetailPage extends StatelessWidget {
  final models.AppNotification notification;

  const NotificationDetailPage({
    super.key,
    required this.notification,
  });

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F9E9),
      appBar: AppBar(
        title: const Text('Chi tiết thông báo'),
        backgroundColor: const Color(0xFF7CCD2B),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tiêu đề (in đậm, căn giữa, font lớn hơn)
                Center(
                  child: Text(
                    notification.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                // Chi tiết (mô tả) thông báo
                Text(
                  notification.description,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 32),
                // Ngày gửi (căn trái, ở cuối)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Ngày gửi: ${_formatDate(notification.createdAt)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
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

