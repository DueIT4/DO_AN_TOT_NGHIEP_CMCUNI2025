import 'package:flutter/material.dart';
import '../../../layout/admin_shell_web.dart';

class AdminDevicesPage extends StatelessWidget {
  const AdminDevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminShellWeb(
      title: 'Quản lý thiết bị',
      current: AdminMenu.devices,
      body: _DeviceTable(),
    );
  }
}

class _DeviceTable extends StatelessWidget {
  const _DeviceTable();

  @override
  Widget build(BuildContext context) {
    final devices = [
      {'name': 'Gateway Vườn Bưởi A', 'status': 'Hoạt động', 'serial': 'GW-001'},
      {'name': 'Camera Lá Bưởi', 'status': 'Đang truyền', 'serial': 'CAM-021'},
      {'name': 'Cảm biến độ ẩm đất', 'status': 'Tạm ngưng', 'serial': 'SM-007'},
    ];

    return DataTable(
      columns: const [
        DataColumn(label: Text('Tên thiết bị')),
        DataColumn(label: Text('Serial')),
        DataColumn(label: Text('Trạng thái')),
      ],
      rows: devices
          .map(
            (d) => DataRow(
              cells: [
                DataCell(Text(d['name']!)),
                DataCell(Text(d['serial']!)),
                DataCell(Text(d['status']!)),
              ],
            ),
          )
          .toList(),
    );
  }
}
