// lib/core/role_ui.dart
import 'package:flutter/material.dart';

String roleLabelVi(String? role) {
  switch ((role ?? '').trim().toLowerCase()) {
    case 'admin':
      return 'Quản trị viên';
    case 'support_admin':
      return 'Quản trị hỗ trợ';
    case 'support':
      return 'Nhân viên';
    case 'viewer':
      return 'Khách hàng';
    default:
      return role == null || role.trim().isEmpty ? '-' : role;
  }
}

Color roleBgColor(String? role) {
  switch ((role ?? '').trim().toLowerCase()) {
    case 'admin':
      return Colors.deepPurple.shade50;
    case 'support_admin':
      return Colors.blue.shade50;
    case 'support':
      return Colors.teal.shade50;
    case 'viewer':
    default:
      return Colors.grey.shade100;
  }
}

Color roleFgColor(String? role) {
  switch ((role ?? '').trim().toLowerCase()) {
    case 'admin':
      return Colors.deepPurple.shade700;
    case 'support_admin':
      return Colors.blue.shade700;
    case 'support':
      return Colors.teal.shade700;
    case 'viewer':
    default:
      return Colors.grey.shade900;
  }
}
