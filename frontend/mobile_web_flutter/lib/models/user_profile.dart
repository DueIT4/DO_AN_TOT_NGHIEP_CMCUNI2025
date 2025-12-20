class UserProfile {
  final int? id;
  final String name;
  final String phone;
  final String email;
  final String avatarUrl;
  final String address;

  const UserProfile({
    this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.avatarUrl,
    required this.address,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['user_id'] as int?,
      name: (json['username'] ?? 'Người dùng').toString(),
      phone: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      avatarUrl: (json['avt_url'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
    );
  }

  UserProfile copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? avatarUrl,
    String? address,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      address: address ?? this.address,
    );
  }

  static UserProfile placeholder() {
    return const UserProfile(
      id: null,
      name: 'Nguyễn Văn An',
      phone: '0128831129',
      email: 'user@example.com',
      avatarUrl: '',
      address: 'Chưa cập nhật',
    );
  }
}