import 'package:flutter/material.dart';
import 'detect_content.dart';

class DetectMobilePage extends StatelessWidget {
  const DetectMobilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(                 // ✅ bỏ const
      appBar: AppBar(                // ✅ AppBar không const
        title: const Text('Chẩn đoán PlantGuard'),
      ),
      body: const SafeArea(
        child: DetectContent(),
      ),
    );
  }
}