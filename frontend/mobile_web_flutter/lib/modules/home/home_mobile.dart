import 'package:flutter/material.dart';
import '../detect/detect_mobile.dart';

class HomeMobilePage extends StatelessWidget {
  const HomeMobilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PlantGuard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Chẩn đoán bằng ảnh'),
              subtitle: const Text('Tải/chụp ảnh lá – AI nhận diện bệnh'),
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DetectMobilePage())),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.sensors),
              title: const Text('Theo dõi cảm biến'),
              subtitle: const Text('Nhiệt độ, độ ẩm, đất...'),
              onTap: () => Navigator.pushNamed(context, '/sensors'), // TODO
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book),
              title: const Text('Thư viện tri thức'),
              subtitle: const Text('Hướng dẫn xử lý bệnh & canh tác'),
              onTap: () => Navigator.pushNamed(context, '/library'),
            ),
          ),
        ],
      ),
    );
  }
}
