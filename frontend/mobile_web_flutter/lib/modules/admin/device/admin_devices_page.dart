import 'package:flutter/material.dart';
import '../../../admin/admin_shell.dart';
import '../../../core/api_base.dart';

class AdminDevicesPage extends StatefulWidget {
  const AdminDevicesPage({super.key});

  @override
  State<AdminDevicesPage> createState() => _AdminDevicesPageState();
}

class _AdminDevicesPageState extends State<AdminDevicesPage> {
  List<dynamic> _devices = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ApiBase.getJson(
        ApiBase.api('/devices/?page=$_page&size=20'),
      );
      setState(() {
        if (response is Map && response['items'] != null) {
          _devices = response['items'] as List;
          _total = response['total'] ?? 0;
        } else if (response is List) {
          _devices = response;
          _total = response.length;
        } else {
          _devices = [];
          _total = 0;
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      title: 'Quản lý thiết bị',
      current: AdminMenu.devices,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Danh sách thiết bị',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              FilledButton.icon(
                onPressed: () {
                  // TODO: Mở dialog tạo device
                },
                icon: const Icon(Icons.add),
                label: const Text('Thêm thiết bị'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Lỗi: $_error'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadDevices,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      )
                    : _devices.isEmpty
                        ? const Center(child: Text('Chưa có thiết bị nào'))
                        : Column(
                            children: [
                              Expanded(
                                child: Card(
                                  child: SingleChildScrollView(
                                    child: DataTable(
                                      columns: const [
                                        DataColumn(label: Text('ID')),
                                        DataColumn(label: Text('Tên thiết bị')),
                                        DataColumn(label: Text('Serial')),
                                        DataColumn(label: Text('Loại')),
                                        DataColumn(label: Text('Vị trí')),
                                        DataColumn(label: Text('Trạng thái')),
                                        DataColumn(label: Text('Thao tác')),
                                      ],
                                      rows: _devices.map((device) {
                                        final deviceType = device['device_type'];
                                        return DataRow(
                                          cells: [
                                            DataCell(Text('${device['device_id'] ?? ''}')),
                                            DataCell(Text(device['name'] ?? '')),
                                            DataCell(Text(device['serial_no'] ?? '-')),
                                            DataCell(Text(
                                              deviceType?['device_type_name'] ?? '-',
                                            )),
                                            DataCell(Text(device['location'] ?? '-')),
                                            DataCell(
                                              Chip(
                                                label: Text(
                                                  device['status'] ?? 'active',
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                                backgroundColor: _getStatusColor(
                                                  device['status'] ?? 'active',
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, size: 20),
                                                    onPressed: () {
                                                      // TODO: Edit device
                                                    },
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, size: 20),
                                                    color: Colors.red,
                                                    onPressed: () {
                                                      // TODO: Delete device
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                              // Pagination
                              if (_total > 20)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.chevron_left),
                                        onPressed: _page > 1
                                            ? () {
                                                setState(() => _page--);
                                                _loadDevices();
                                              }
                                            : null,
                                      ),
                                      Text('Trang $_page / ${(_total / 20).ceil()}'),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right),
                                        onPressed: _page < (_total / 20).ceil()
                                            ? () {
                                                setState(() => _page++);
                                                _loadDevices();
                                              }
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green.withOpacity(0.2);
      case 'maintain':
        return Colors.orange.withOpacity(0.2);
      case 'inactive':
        return Colors.grey.withOpacity(0.2);
      default:
        return Colors.grey.withOpacity(0.2);
    }
  }
}
