import 'package:flutter/material.dart';
import '../../core/api_base.dart';

class DeviceContent extends StatefulWidget {
  const DeviceContent({super.key});
  @override
  State<DeviceContent> createState() => _DeviceContentState();
}

class _DeviceContentState extends State<DeviceContent> {
  Future<List<dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<dynamic>> _fetch() async {
    final res = await ApiBase.getJson(ApiBase.api('/devices/'));
    return (res as List<dynamic>);
  }

  Future<void> _openCreateDialog() async {
    final name = TextEditingController();
    final type = TextEditingController(); // nhập ID tạm thời
    final serial = TextEditingController();
    final location = TextEditingController();
    final form = GlobalKey<FormState>();
    bool loading = false;
    String? error;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateD) {
          Future<void> _submit() async {
            if (!form.currentState!.validate()) return;
            setStateD(() { loading = true; error = null; });
            try {
              await ApiBase.postJson(
                ApiBase.api('/devices/'),
                {
                  "name": name.text.trim(),
                  "device_type_id": int.parse(type.text.trim()),
                  "serial_no": serial.text.trim(),
                  "location": location.text.trim().isEmpty ? null : location.text.trim(),
                },
              );
              if (context.mounted) Navigator.pop(context, true);
            } catch (e) {
              setStateD(() => error = '$e');
            } finally {
              setStateD(() => loading = false);
            }
          }

          return AlertDialog(
            title: const Text('Thêm thiết bị'),
            content: Form(
              key: form,
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Tên thiết bị'),
                      validator: (v) => (v==null||v.isEmpty) ? 'Nhập tên' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: type,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Device type ID'),
                      validator: (v) => (v==null||int.tryParse(v)==null) ? 'Nhập số hợp lệ' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: serial,
                      decoration: const InputDecoration(labelText: 'Serial number'),
                      validator: (v) => (v==null||v.isEmpty) ? 'Nhập serial' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: location,
                      decoration: const InputDecoration(labelText: 'Vị trí (tuỳ chọn)'),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
              FilledButton(
                onPressed: loading ? null : _submit,
                child: loading
                    ? const SizedBox(width:18,height:18,child: CircularProgressIndicator(strokeWidth:2))
                    : const Text('Lưu'),
              ),
            ],
          );
        },
      ),
    );

    if (ok == true && mounted) {
      setState(() => _future = _fetch());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm thiết bị')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;

    return Padding(
      padding: EdgeInsets.all(wide ? 32 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header hàng nút
          Row(
            children: [
              Text('Danh sách thiết bị', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              FilledButton.icon(
                onPressed: _openCreateDialog,
                icon: const Icon(Icons.add),
                label: const Text('Thêm thiết bị'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Nội dung danh sách
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _future,
              builder: (c, s) {
                if (s.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (s.hasError) return Center(child: Text('Lỗi: ${s.error}'));
                final items = s.data ?? [];

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Chưa có thiết bị'),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _openCreateDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Thêm thiết bị đầu tiên'),
                        ),
                      ],
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (_, cons) {
                    if (cons.maxWidth >= 800) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('ID')),
                            DataColumn(label: Text('Tên')),
                            DataColumn(label: Text('Serial')),
                            DataColumn(label: Text('Loại')),
                            DataColumn(label: Text('Trạng thái')),
                          ],
                          rows: items.map((m) {
                            return DataRow(
                              cells: [
                                DataCell(Text('${m['device_id']}')),
                                DataCell(Text(m['name'] ?? '')),
                                DataCell(Text(m['serial_no'] ?? '')),
                                DataCell(Text('${m['device_type_id'] ?? ''}')),
                                DataCell(Text(m['status'] ?? '')),
                              ],
                              onSelectChanged: (_) {
                                final id = m['device_id'];
                                Navigator.pushNamed(context, '/sensors?device_id=$id');
                              },
                            );
                          }).toList(),
                        ),
                      );
                    }

                    // mobile-ish
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final m = items[i] as Map<String, dynamic>;
                        return ListTile(
                          leading: const Icon(Icons.devices),
                          title: Text(m['name'] ?? 'Thiết bị'),
                          subtitle: Text('Serial: ${m['serial_no'] ?? ''}'),
                          trailing: Text('${m['status'] ?? ''}'),
                          onTap: () {
                            final id = m['device_id'];
                            Navigator.pushNamed(context, '/sensors?device_id=$id');
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
