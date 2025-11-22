// lib/core/dashboard_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_base.dart';

class DetectionTimePoint {
  final DateTime date;
  final int count;

  DetectionTimePoint({required this.date, required this.count});

  factory DetectionTimePoint.fromJson(Map<String, dynamic> json) {
    return DetectionTimePoint(
      date: DateTime.parse(json['date'] as String),
      count: json['count'] as int? ?? 0,
    );
  }
}

class DiseaseStat {
  final String diseaseName;
  final int count;

  DiseaseStat({required this.diseaseName, required this.count});

  factory DiseaseStat.fromJson(Map<String, dynamic> json) {
    return DiseaseStat(
      diseaseName: json['disease_name'] as String? ?? 'Không rõ',
      count: json['count'] as int? ?? 0,
    );
  }
}

class TicketStatusStat {
  final String status;
  final int count;

  TicketStatusStat({required this.status, required this.count});

  factory TicketStatusStat.fromJson(Map<String, dynamic> json) {
    return TicketStatusStat(
      status: json['status'] as String? ?? 'unknown',
      count: json['count'] as int? ?? 0,
    );
  }
}

class RecentDetectionItem {
  final int detectionId;
  final int? userId;
  final String? username;
  final String? diseaseName;
  final double? confidence;
  final DateTime createdAt;

  RecentDetectionItem({
    required this.detectionId,
    this.userId,
    this.username,
    this.diseaseName,
    this.confidence,
    required this.createdAt,
  });

  factory RecentDetectionItem.fromJson(Map<String, dynamic> json) {
    return RecentDetectionItem(
      detectionId: json['detection_id'] as int,
      userId: json['user_id'] as int?,
      username: json['username'] as String?,
      diseaseName: json['disease_name'] as String?,
      confidence: json['confidence'] == null
          ? null
          : (json['confidence'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class RecentTicketItem {
  final int ticketId;
  final int? userId;
  final String? username;
  final String? status;
  final String? title;
  final DateTime createdAt;

  RecentTicketItem({
    required this.ticketId,
    this.userId,
    this.username,
    this.status,
    this.title,
    required this.createdAt,
  });

  factory RecentTicketItem.fromJson(Map<String, dynamic> json) {
    return RecentTicketItem(
      ticketId: json['ticket_id'] as int,
      userId: json['user_id'] as int?,
      username: json['username'] as String?,
      status: json['status'] as String?,
      title: json['title'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class DashboardSummary {
  final int totalDevices;
  final int activeDevices;
  final int inactiveDevices;
  final int totalUsers;
  final int newUsers;
  final int totalDetections;
  final List<DetectionTimePoint> detectionsOverTime;
  final List<DiseaseStat> topDiseases;
  final int totalTickets;
  final int openTickets;
  final List<TicketStatusStat> ticketsByStatus;
  final List<RecentDetectionItem> recentDetections;
  final List<RecentTicketItem> recentTickets;

  DashboardSummary({
    required this.totalDevices,
    required this.activeDevices,
    required this.inactiveDevices,
    required this.totalUsers,
    required this.newUsers,
    required this.totalDetections,
    required this.detectionsOverTime,
    required this.topDiseases,
    required this.totalTickets,
    required this.openTickets,
    required this.ticketsByStatus,
    required this.recentDetections,
    required this.recentTickets,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalDevices: json['total_devices'] as int? ?? 0,
      activeDevices: json['active_devices'] as int? ?? 0,
      inactiveDevices: json['inactive_devices'] as int? ?? 0,
      totalUsers: json['total_users'] as int? ?? 0,
      newUsers: json['new_users'] as int? ?? 0,
      totalDetections: json['total_detections'] as int? ?? 0,
      detectionsOverTime:
          (json['detections_over_time'] as List<dynamic>? ?? [])
              .map((e) => DetectionTimePoint.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList(),
      topDiseases: (json['top_diseases'] as List<dynamic>? ?? [])
          .map(
              (e) => DiseaseStat.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      totalTickets: json['total_tickets'] as int? ?? 0,
      openTickets: json['open_tickets'] as int? ?? 0,
      ticketsByStatus:
          (json['tickets_by_status'] as List<dynamic>? ?? [])
              .map((e) => TicketStatusStat.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList(),
      recentDetections:
          (json['recent_detections'] as List<dynamic>? ?? [])
              .map((e) => RecentDetectionItem.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList(),
      recentTickets: (json['recent_tickets'] as List<dynamic>? ?? [])
          .map((e) => RecentTicketItem.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class DashboardService {
  /// range: '7d' | '30d' | '90d'
  static Future<DashboardSummary> fetchSummary({String range = '7d'}) async {
    final params = {'range': range};
    final query = Uri(queryParameters: params).query;

    // giống style AdminUserService: ApiBase.api + getJson
    final res = await ApiBase.getJson(
      ApiBase.api('/admin/dashboard?$query'),
    );

    final map = Map<String, dynamic>.from(res as Map);
    return DashboardSummary.fromJson(map);
  }
}
