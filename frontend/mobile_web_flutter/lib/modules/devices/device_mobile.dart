import 'package:flutter/material.dart';
import 'device_content.dart';

class DeviceMobilePage extends StatelessWidget {
  const DeviceMobilePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thiết bị của tôi')),
      body: const SafeArea(child: DeviceContent()),
    );
  }
}
