import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/detection_record.dart';

class DetectionDetailPage extends StatelessWidget {
  final DetectionRecord record;

  const DetectionDetailPage({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('dd/MM/yyyy HH:mm').format(record.detectedAt);

    return Scaffold(
      appBar: AppBar(
        title: Text(record.diseaseName),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _RecordImage(record: record),
              const SizedBox(height: 20),
              Text(
                '${record.diseaseName} · ${(record.accuracy * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _InfoCard(
                title: 'Nguyên nhân',
                body: record.cause,
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'Giải pháp',
                body: record.solution,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  dateText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String body;

  const _InfoCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _RecordImage extends StatelessWidget {
  final DetectionRecord record;

  const _RecordImage({required this.record});

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (record.imageBytes != null) {
      child = Image.memory(record.imageBytes!, fit: BoxFit.cover);
    } else if (record.imageUrl != null && record.imageUrl!.isNotEmpty) {
      child = Image.network(record.imageUrl!, fit: BoxFit.cover);
    } else {
      child = Container(
        color: const Color(0xFFE8F4D9),
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined, size: 48),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(aspectRatio: 4 / 3, child: child),
    );
  }
}

