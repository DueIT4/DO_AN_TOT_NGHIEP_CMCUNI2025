import 'package:flutter/material.dart';
import '../../core/api_base.dart';

class DeviceDetailPage extends StatefulWidget {
  final int deviceId;
  final Map<String, dynamic>? deviceLite;

  const DeviceDetailPage({super.key, required this.deviceId, this.deviceLite});

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchDetail();
  }

  Future<Map<String, dynamic>> _fetchDetail() async {
    final dev = await ApiBase.getJson(ApiBase.api('/devices/${widget.deviceId}'));
    final rds = await ApiBase.getJson(ApiBase.api('/devices/${widget.deviceId}/readings?limit=20'));
    return {"device": dev, "readings": rds};
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;

    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) return Center(child: Text('Lỗi: ${s.error}'));

        final data = s.data!;
        final d = (data['device'] ?? {}) as Map<String, dynamic>;
        final readings = (data["readings"] as List).cast<Map<String, dynamic>>();

        return ListView(
          children: [
            // Thông tin tổng quan
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 28,
                  runSpacing: 14,
                  children: [
                    _kv('Tên thiết bị', d['name']),
                    _kv('Serial', d['serial_no']),
                    _kv('Loại', d['device_type_name'] ?? d['device_type_id']),
                    _kv('Trạng thái', d['status'], chip: true),
                    _kv('Vị trí', d['location']),
                    _kv('FW Version', d['fw_version']),
                    _kv('IP', d['ip_addr']),
                    _kv('Lần cuối online', d['last_seen']),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            if ((d['notes'] ?? '').toString().isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ghi chú', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(d['notes']),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 14),

            // readings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('Thông số gần đây', style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Làm mới',
                          onPressed: () => setState(() => _future = _fetchDetail()),
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (readings.isEmpty) const Text('Chưa có dữ liệu cảm biến.'),
                    if (readings.isNotEmpty) _ReadingsTable(readings: readings),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _kv(String k, dynamic v, {bool chip = false}) {
    final text = (v == null || v.toString().isEmpty) ? '—' : v.toString();
    if (chip) {
      final s = text.toLowerCase();
      Color bg;
      switch (s) {
        case 'active': bg = Colors.green; break;
        case 'inactive': bg = Colors.red; break;
        case 'maintain':
        case 'maintenance': bg = Colors.orange; break;
        default: bg = Colors.grey;
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$k: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Chip(label: Text(text), backgroundColor: bg.withOpacity(.12), side: BorderSide.none),
        ],
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
          const SizedBox(height: 2),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ReadingsTable extends StatelessWidget {
  final List<Map<String, dynamic>> readings;
  const _ReadingsTable({required this.readings});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Thời gian')),
          DataColumn(label: Text('Chỉ số')),
          DataColumn(label: Text('Giá trị')),
        ],
        rows: readings.map((r) {
          final v = r['value'];
          final unit = (r['unit'] ?? '').toString();
          final valueText = unit.isEmpty ? '$v' : '$v $unit';
          return DataRow(cells: [
            DataCell(Text(r['ts'] ?? '—')),
            DataCell(Text(r['metric'] ?? '—')),
            DataCell(Text(valueText)),
          ]);
        }).toList(),
      ),
    );
  }
}
