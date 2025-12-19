/// 1 item trong lịch sử dự đoán (admin thấy được cả thông tin user)
class DetectionHistoryItem {
  final int detectionId;
  final int imgId;
  final String fileUrl;
  final String? diseaseName;
  final double? confidence;
  final DateTime createdAt;

  // Thông tin user – chỉ có trong API admin
  final int? userId;
  final String? username;
  final String? email;
  final String? phone;

  DetectionHistoryItem({
    required this.detectionId,
    required this.imgId,
    required this.fileUrl,
    this.diseaseName,
    this.confidence,
    required this.createdAt,
    this.userId,
    this.username,
    this.email,
    this.phone,
  });

  factory DetectionHistoryItem.fromJson(Map<String, dynamic> json) {
    return DetectionHistoryItem(
      detectionId: json['detection_id'] as int,
      imgId: json['img_id'] as int,
      fileUrl: (json['file_url'] ?? '') as String,
      diseaseName: json['disease_name'] as String?,
      confidence: json['confidence'] == null
          ? null
          : (json['confidence'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      userId: json['user_id'] as int?,
      username: json['username'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }
}

class DetectionHistoryList {
  final List<DetectionHistoryItem> items;
  final int total;

  DetectionHistoryList({
    required this.items,
    required this.total,
  });

  factory DetectionHistoryList.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List<dynamic>)
        .map((e) => DetectionHistoryItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();

    return DetectionHistoryList(
      items: list,
      total: json['total'] as int? ?? 0,
    );
  }
}
