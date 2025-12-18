import 'package:flutter/material.dart';
import '../../layout/web_shell.dart';
import 'weather_content.dart';

class WeatherPage extends StatelessWidget {
  const WeatherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const WebShell(child: WeatherContent());
  }
}
