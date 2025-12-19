class AdminUserSearchResult {
  final int total;
  final List<Map<String, dynamic>> items;

  AdminUserSearchResult({
    required this.total,
    required this.items,
  });

  factory AdminUserSearchResult.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return AdminUserSearchResult(
      total: json['total'] as int? ?? 0,
      items: list,
    );
  }
}
