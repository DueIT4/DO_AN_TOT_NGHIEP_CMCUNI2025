import 'package:flutter/material.dart';
import 'sensors_content.dart';

class SensorsMobilePage extends StatelessWidget {
  final int? deviceId; // nếu mở từ tab chung thì có thể null
  const SensorsMobilePage({super.key, this.deviceId});

  @override
  Widget build(BuildContext context) {
    final id = deviceId ?? ModalRoute.of(context)?.settings.arguments as int? ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Dữ liệu cảm biến')),
      body: id > 0
          ? SensorsContent(deviceId: id)
          : const Center(child: Text('Chọn thiết bị để xem dữ liệu')),
    );
  }
}
