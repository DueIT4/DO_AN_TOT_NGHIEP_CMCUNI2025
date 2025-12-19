// lib/modules/admin/dashboard/admin_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html;

import '../../../services/admin/dashboard_service.dart';
import 'package:mobile_web_flutter/models/admin/dashboard_models.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  String _range = '7d';
  late Future<DashboardSummary> _future;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _future = DashboardService.fetchSummary(range: _range);
  }

  void _reload() {
    setState(() {
      _future = DashboardService.fetchSummary(range: _range);
    });
  }

  Future<void> _exportPdf() async {
    try {
      setState(() {
        _exporting = true;
      });

      // Gọi API lấy PDF bytes
      final bytes =
          await DashboardService.exportSummaryPdf(range: _range);

      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);

      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'report_summary_$_range.pdf')
        ..click();

      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xuất báo cáo PDF')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xuất PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<DashboardSummary>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Lỗi tải dashboard:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final data = snapshot.data!;
          return _buildContent(context, data);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, DashboardSummary data) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + filter
          Row(
            children: [
              Text(
                'Tổng quan hệ thống',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _exporting ? null : _exportPdf,
                icon: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: const Text('Xuất báo cáo (PDF)'),
              ),
              const SizedBox(width: 16),
              const Text('Khoảng thời gian:'),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _range,
                items: const [
                  DropdownMenuItem(
                    value: '7d',
                    child: Text('7 ngày'),
                  ),
                  DropdownMenuItem(
                    value: '30d',
                    child: Text('30 ngày'),
                  ),
                  DropdownMenuItem(
                    value: '90d',
                    child: Text('90 ngày'),
                  ),
                ],
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _range = val;
                  });
                  _reload();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stat cards
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatCard(
                title: 'Tổng thiết bị',
                value: data.totalDevices.toString(),
                subtitle:
                    'Đang hoạt động: ${data.activeDevices}/${data.totalDevices}',
                color: Colors.green.shade700,
              ),
              _StatCard(
                title: 'Thiết bị offline',
                value: data.inactiveDevices.toString(),
                subtitle: 'Thiết bị không hoạt động',
                color: Colors.red.shade600,
              ),
              _StatCard(
                title: 'Người dùng',
                value: data.totalUsers.toString(),
                subtitle: 'Mới trong kỳ: ${data.newUsers}',
                color: Colors.blue.shade700,
              ),
              _StatCard(
                title: 'Lượt dự đoán',
                value: data.totalDetections.toString(),
                subtitle: 'Trong khoảng đã chọn',
                color: Colors.orange.shade700,
              ),
              _StatCard(
                title: 'Ticket hỗ trợ',
                value: data.totalTickets.toString(),
                subtitle: 'Đang mở: ${data.openTickets}',
                color: Colors.purple.shade700,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Charts row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _CardSection(
                  title: 'Lượt dự đoán theo ngày',
                  child: _DetectionsChart(data.detectionsOverTime),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _CardSection(
                  title: 'Bệnh phát hiện nhiều nhất',
                  child: _TopDiseasesList(data.topDiseases),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: _CardSection(
                  title: 'Ticket theo trạng thái',
                  child: _TicketsByStatus(data.ticketsByStatus),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _CardSection(
                  title: 'Dự đoán gần đây',
                  child: _RecentDetectionsTable(data.recentDetections),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _CardSection(
            title: 'Ticket mới nhất',
            child: _RecentTicketsTable(data.recentTickets),
          ),
        ],
      ),
    );
  }
}

// ====== Widgets phụ (giữ nguyên như cũ) ======

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return SizedBox(
      width: 220,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: t.labelMedium?.copyWith(color: Colors.grey[700])),
              const SizedBox(height: 8),
              Text(
                value,
                style: t.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: t.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _CardSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _DetectionsChart extends StatelessWidget {
  final List<DetectionTimePoint> points;

  const _DetectionsChart(this.points);

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Text('Chưa có dữ liệu trong khoảng này.');
    }

    final maxCount =
        points.map((e) => e.count).fold<int>(0, (a, b) => b > a ? b : a);
    final dateFmt = DateFormat('dd/MM');

    return SizedBox(
      height: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final p in points)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: maxCount == 0
                            ? 0
                            : (150 * (p.count / maxCount)).clamp(4, 150),
                        width: 12,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.green.shade600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFmt.format(p.date),
                    style: const TextStyle(fontSize: 10),
                  ),
                  Text(
                    '${p.count}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TopDiseasesList extends StatelessWidget {
  final List<DiseaseStat> diseases;

  const _TopDiseasesList(this.diseases);

  @override
  Widget build(BuildContext context) {
    if (diseases.isEmpty) {
      return const Text('Chưa có lượt phát hiện bệnh trong khoảng này.');
    }

    final maxCount =
        diseases.map((e) => e.count).fold<int>(0, (a, b) => b > a ? b : a);

    return Column(
      children: [
        for (final d in diseases)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    d.diseaseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    value: maxCount == 0 ? 0 : d.count / maxCount,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${d.count}'),
              ],
            ),
          ),
      ],
    );
  }
}

class _TicketsByStatus extends StatelessWidget {
  final List<TicketStatusStat> stats;

  const _TicketsByStatus(this.stats);

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const Text('Chưa có ticket trong khoảng này.');
    }

    final total = stats.map((e) => e.count).fold<int>(0, (a, b) => a + b);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in stats)
          Chip(
            label: Text(
              '${s.status} (${s.count}${total > 0 ? ' • ${(s.count * 100 / total).toStringAsFixed(0)}%' : ''})',
            ),
          ),
      ],
    );
  }
}

class _RecentDetectionsTable extends StatelessWidget {
  final List<RecentDetectionItem> items;

  const _RecentDetectionsTable(this.items);

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('Chưa có dự đoán nào gần đây.');
    }

    final fmt = DateFormat('dd/MM HH:mm');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        columns: const [
          DataColumn(label: Text('Thời gian')),
          DataColumn(label: Text('Người dùng')),
          DataColumn(label: Text('Bệnh')),
          DataColumn(label: Text('Độ tin cậy')),
        ],
        rows: items.map((e) {
          return DataRow(
            cells: [
              DataCell(Text(fmt.format(e.createdAt))),
              DataCell(Text(e.username ?? '-')),
              DataCell(Text(e.diseaseName ?? 'Không phát hiện')),
              DataCell(Text(
                e.confidence != null
                    ? '${(e.confidence! * 100).toStringAsFixed(1)}%'
                    : '-',
              )),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _RecentTicketsTable extends StatelessWidget {
  final List<RecentTicketItem> items;

  const _RecentTicketsTable(this.items);

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('Chưa có ticket nào.');
    }

    final fmt = DateFormat('dd/MM HH:mm');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        columns: const [
          DataColumn(label: Text('Thời gian')),
          DataColumn(label: Text('Người dùng')),
          DataColumn(label: Text('Tiêu đề')),
          DataColumn(label: Text('Trạng thái')),
        ],
        rows: items.map((e) {
          return DataRow(
            cells: [
              DataCell(Text(fmt.format(e.createdAt))),
              DataCell(Text(e.username ?? '-')),
              DataCell(Text(e.title ?? '-')),
              DataCell(Text(e.status ?? '-')),
            ],
          );
        }).toList(),
      ),
    );
  }
}
