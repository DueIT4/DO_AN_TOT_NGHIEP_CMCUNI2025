// lib/ui/detection_detail_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/detection_record.dart';
import '../services/detection_service.dart';

class DetectionDetailPage extends StatelessWidget {
  final DetectionRecord record;

  const DetectionDetailPage({super.key, required this.record});

  int? get _detId => int.tryParse(record.id);

  Future<void> _confirmDelete(BuildContext context) async {
    final detId = _detId;
    if (detId == null || detId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không xoá được: detection_id không hợp lệ (${record.id})')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá lịch sử?'),
        content: const Text('Bạn có chắc muốn xoá bản ghi lịch sử này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xoá')),
        ],
      ),
    );

    if (ok != true) return;

    await DetectionService.deleteHistory(detId);
    if (!context.mounted) return;
    Navigator.pop(context, true); // ✅ báo về trang list để reload
  }

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('dd/MM/yyyy HH:mm').format(record.detectedAt);
    final percent = (record.accuracy * 100).toStringAsFixed(0);
    final sourceLabel =
        record.source == DetectionSource.camera ? 'Camera' : 'Thư viện';

    return Scaffold(
      appBar: AppBar(
        title: Text(record.diseaseName),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RecordImage(record: record),
              const SizedBox(height: 16),

              Text(
                record.diseaseName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Chip(text: '$percent% tin cậy'),
                  const SizedBox(width: 8),
                  _Chip(text: sourceLabel),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                dateText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
              ),

              const SizedBox(height: 16),

              _InfoCard(title: 'Tóm tắt tình trạng', body: record.cause),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'Khuyến nghị xử lý / chăm sóc',
                body: record.solution,
                asBullets: true,
              ),
              const SizedBox(height: 12),

              if ((record.explanation ?? '').trim().isNotEmpty) ...[
                _InfoCard(
                  title: 'Giải thích từ hệ thống',
                  body: record.explanation!.trim(),
                ),
                const SizedBox(height: 12),
              ],

              if (record.detections.isNotEmpty) ...[
                _DetectionsCard(items: record.detections),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4D9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4B8D1F),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String body;
  final bool asBullets;

  const _InfoCard({
    required this.title,
    required this.body,
    this.asBullets = false,
  });

  List<String> _splitBullets(String text) {
    final t = text.trim();
    if (t.isEmpty) return const [];
    final lines = t
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.length >= 2) return lines;

    final parts = t
        .split('. ')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.length >= 2 ? parts : [t];
  }

  @override
  Widget build(BuildContext context) {
    final bulletItems = asBullets ? _splitBullets(body) : const <String>[];

    return Container(
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
          const SizedBox(height: 10),
          if (!asBullets)
            Text(body, style: const TextStyle(height: 1.45))
          else
            ...bulletItems.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(height: 1.45)),
                    Expanded(child: Text(e, style: const TextStyle(height: 1.45))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetectionsCard extends StatelessWidget {
  final List<DetectionItem> items;
  const _DetectionsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            'Chi tiết phát hiện',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          ...items.map((it) {
            final pct = (it.confidence * 100).toStringAsFixed(0);
            final bbox = it.bbox;
            final bboxText = (bbox == null || bbox.isEmpty)
                ? null
                : 'bbox: ${bbox.map((e) => e.toStringAsFixed(1)).join(', ')}';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6FAF0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8F4D9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          it.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text('$pct%'),
                    ],
                  ),
                  if (bboxText != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      bboxText,
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ],
              ),
            );
          }),
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
