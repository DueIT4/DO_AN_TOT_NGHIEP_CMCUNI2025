import 'package:flutter/material.dart';
import '../../layout/shell_mobile.dart';
import 'weather_content.dart';

class WeatherMobilePage extends StatelessWidget {
  const WeatherMobilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShellMobile(body: WeatherContent());
  }
}

