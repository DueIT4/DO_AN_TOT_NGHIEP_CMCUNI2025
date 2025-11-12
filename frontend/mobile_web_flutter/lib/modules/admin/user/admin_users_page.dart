import 'package:flutter/material.dart';

class AdminUsersPage extends StatelessWidget {
  const AdminUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final users = [
      {'name': 'Nguyễn Văn A', 'role': 'Quản trị viên'},
      {'name': 'Trần Thị B', 'role': 'Nhân viên kỹ thuật'},
    ];

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (_, i) => Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(users[i]['name']!),
          subtitle: Text(users[i]['role']!),
          trailing: const Icon(Icons.more_vert),
        ),
      ),
    );
  }
}
