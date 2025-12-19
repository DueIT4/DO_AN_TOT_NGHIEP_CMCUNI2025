class AdminUserMe {
  final int userId;
  final String? username;
  final String? phone;
  final String? email;
  final String? address;
  final String? roleType;
  final String? status;

  // ✅ avatar
  final String? avtUrl;

  AdminUserMe({
    required this.userId,
    this.username,
    this.phone,
    this.email,
    this.address,
    this.roleType,
    this.status,
    this.avtUrl,
  });

  factory AdminUserMe.fromJson(Map<String, dynamic> json) {
    return AdminUserMe(
      userId: (json['user_id'] as num).toInt(),
      username: json['username'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      roleType: json['role_type'] as String?,
      status: json['status'] as String?,
      avtUrl: json['avt_url'] as String?, // ✅ parse đúng key backend
    );
  }
}
