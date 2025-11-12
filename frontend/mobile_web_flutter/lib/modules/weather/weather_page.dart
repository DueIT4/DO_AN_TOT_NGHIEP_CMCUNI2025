import 'package:flutter/material.dart';
import '../../layout/shell_web.dart';
import 'weather_content.dart';

class WeatherPage extends StatelessWidget {
  const WeatherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShellWeb(body: WeatherContent());
  }
}
