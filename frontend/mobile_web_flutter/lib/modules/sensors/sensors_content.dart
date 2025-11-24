import 'package:flutter/material.dart';
import '../../core/api_base.dart';

class SensorsContent extends StatefulWidget {
  final int deviceId;
  const SensorsContent({super.key, required this.deviceId});

  @override
  State<SensorsContent> createState() => _SensorsContentState();
}

class _SensorsContentState extends State<SensorsContent> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<dynamic>> _fetch() async {
    final res = await ApiBase.getJson(ApiBase.api('/sensors/${widget.deviceId}'));
    return (res as List<dynamic>);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;

    return Padding(
      padding: EdgeInsets.all(wide ? 32 : 16),
      child: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) return Center(child: Text('Lỗi: ${s.error}'));
          final data = s.data ?? [];
          if (data.isEmpty) {
            return const Center(child: Text('Chưa có dữ liệu cảm biến'));
          }

          // List các bản ghi (50 gần nhất từ backend)
          return ListView.separated(
            itemCount: data.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final m = data[i] as Map<String, dynamic>;
              final metric = (m['metric'] ?? '').toString();
              final value  = (m['value_num'] ?? '').toString();
              final unit   = (m['unit'] ?? '').toString();
              final ts     = (m['recorded_at'] ?? '').toString();
              return ListTile(
                leading: const Icon(Icons.sensors),
                title: Text('$metric = $value $unit'),
                subtitle: Text(ts),
              );
            },
          );
        },
      ),
    );
  }
}
