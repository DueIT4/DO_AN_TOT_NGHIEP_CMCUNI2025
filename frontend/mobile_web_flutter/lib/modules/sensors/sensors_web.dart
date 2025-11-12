import 'package:flutter/material.dart';
import '../../layout/shell_web.dart';
import 'sensors_content.dart';

class SensorsWebPage extends StatelessWidget {
  const SensorsWebPage({super.key});

  int _extractDeviceId(BuildContext context) {
    // Lấy từ ModalRoute (ví dụ '/sensors?device_id=12')
    final uri = Uri.parse(ModalRoute.of(context)!.settings.name ?? '/sensors');
    final q = uri.queryParameters['device_id'];
    return int.tryParse(q ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final id = _extractDeviceId(context);
    return ShellWeb(
      body: id > 0
          ? SensorsContent(deviceId: id)
          : const Center(child: Text('Thiếu device_id')),
    );
  }
}
