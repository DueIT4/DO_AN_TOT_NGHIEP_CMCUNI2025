import 'package:flutter/material.dart';
import '../../layout/shell_web.dart';
import 'device_content.dart';

class DeviceWebPage extends StatelessWidget {
  const DeviceWebPage({super.key});
  @override
  Widget build(BuildContext context) => const ShellWeb(body: DeviceContent());
}
