import 'package:flutter/material.dart';
import 'package:mobile_web_flutter/core/device_service.dart';
import 'package:mobile_web_flutter/core/user_service.dart';

class AdminDevicesPage extends StatefulWidget {
  const AdminDevicesPage({super.key});

  @override
  State<AdminDevicesPage> createState() => _AdminDevicesPageState();
}

class _AdminDevicesPageState extends State<AdminDevicesPage> {
  late Future<List<Map<String, dynamic>>> _usersFuture;
  Map<String, dynamic>? _selectedUser;

  Future<List<Map<String, dynamic>>>? _devicesFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = UserService.listUsers();
  }

  void _reloadUsers() {
    setState(() {
      _usersFuture = UserService.listUsers();
      _selectedUser = null;
      _devicesFuture = null;
    });
  }

  void _reloadDevicesForSelectedUser() {
    final u = _selectedUser;
    if (u == null) return;
    final userId = u['user_id'] as int;
    setState(() {
      _devicesFuture = DeviceService.listDevicesByUser(userId);
    });
  }

  void _selectUser(Map<String, dynamic> user) {
    setState(() {
      _selectedUser = user;
      _devicesFuture = DeviceService.listDevicesByUser(user['user_id'] as int);
    });
  }

  Future<void> _openCreateDialogForSelectedUser() async {
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn một người dùng trước.')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DeviceDialog(
        ownerUserId: _selectedUser!['user_id'] as int,
      ),
    );
    if (ok == true) _reloadDevicesForSelectedUser();
  }

  Future<void> _openEditDialog(Map<String, dynamic> device) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DeviceDialog(device: device),
    );
    if (ok == true) _reloadDevicesForSelectedUser();
  }

  Future<void> _deleteDevice(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Xóa thiết bị"),
        content:
            const Text("Bạn chắc chắn muốn xóa thiết bị này khỏi hệ thống?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hủy"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Xóa"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DeviceService.deleteDevice(id);
      _reloadDevicesForSelectedUser();
    }
  }

  // Chip trạng thái thiết bị
  Widget _buildDeviceStatusChip(String? status) {
    final s = (status ?? '').toLowerCase();
    Color bg;
    Color fg;

    if (s == 'active') {
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
    } else if (s == 'inactive') {
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
    } else if (s == 'maintain') {
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade800;
    } else {
      bg = Colors.grey.shade100;
      fg = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status ?? '-',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }

  // Chip trạng thái user
  Widget _buildUserStatusChip(String? status) {
    final s = (status ?? '').toLowerCase();
    Color bg;
    Color fg;

    if (s == 'active') {
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
    } else if (s == 'inactive') {
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
    } else {
      bg = Colors.grey.shade100;
      fg = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status ?? '-',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(0.8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Thống kê thiết bị theo người dùng',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Thêm thiết bị cho người dùng đang chọn',
                            onPressed: _openCreateDialogForSelectedUser,
                            icon: const Icon(Icons.add),
                          ),
                          IconButton(
                            tooltip: 'Tải lại danh sách người dùng',
                            onPressed: _reloadUsers,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SizedBox(
                    height: 600, // để 2 bảng cùng cao
                    child: Row(
                      children: [
                        // ================= CỘT TRÁI: DANH SÁCH USER =================
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Người dùng',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: FutureBuilder<
                                    List<Map<String, dynamic>>>(
                                  future: _usersFuture,
                                  builder: (context, snap) {
                                    if (snap.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                    if (snap.hasError) {
                                      return Text(
                                        'Lỗi tải người dùng: ${snap.error}',
                                        style: const TextStyle(
                                            color: Colors.red),
                                      );
                                    }
                                    final users = snap.data ?? [];
                                    if (users.isEmpty) {
                                      return const Center(
                                        child:
                                            Text('Chưa có người dùng nào.'),
                                      );
                                    }

                                    return Scrollbar(
                                      thumbVisibility: true,
                                      child: ListView.separated(
                                        itemCount: users.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          final u = users[index];
                                          final bool selected =
                                              _selectedUser != null &&
                                                  _selectedUser!['user_id'] ==
                                                      u['user_id'];
                                          final name = u['username'] ??
                                              u['email'] ??
                                              'User #${u['user_id']}';
                                          final email = u['email'] ?? '';
                                          final phone = u['phone'] ?? '';
                                          final status = u['status'] ?? '';
                                          final roleType =
                                              u['role_type'] ?? '';

                                          return ListTile(
                                            selected: selected,
                                            selectedTileColor:
                                                Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withOpacity(0.06),
                                            onTap: () => _selectUser(u),
                                            title: Row(
                                              children: [
                                                Expanded(child: Text(name)),
                                                if (roleType.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 8),
                                                    child: Text(
                                                      roleType,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            subtitle: Row(
                                              children: [
                                                if (email.isNotEmpty)
                                                  Expanded(
                                                    child: Text(
                                                      email,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                if (phone.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 8),
                                                    child: Text(
                                                      phone,
                                                      style: const TextStyle(
                                                          fontSize: 12),
                                                    ),
                                                  ),
                                                const SizedBox(width: 8),
                                                _buildUserStatusChip(status),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        const VerticalDivider(width: 24),

                        // ================= CỘT PHẢI: THIẾT BỊ CỦA USER =================
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_selectedUser == null) ...[
                                Text(
                                  'Thiết bị',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 16),
                                const Expanded(
                                  child: Center(
                                    child: Text(
                                      'Vui lòng chọn một người dùng ở bên trái để xem danh sách thiết bị.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ] else ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Thiết bị của: ${_selectedUser!['username'] ?? _selectedUser!['email'] ?? 'User #${_selectedUser!['user_id']}'}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: _devicesFuture == null
                                      ? const Center(
                                          child: Text(
                                              'Chọn người dùng để tải danh sách thiết bị.'),
                                        )
                                      : FutureBuilder<
                                          List<Map<String, dynamic>>>(
                                          future: _devicesFuture,
                                          builder: (context, snap) {
                                            if (snap.connectionState ==
                                                ConnectionState.waiting) {
                                              return const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              );
                                            }
                                            if (snap.hasError) {
                                              return Text(
                                                'Lỗi tải thiết bị: ${snap.error}',
                                                style: const TextStyle(
                                                    color: Colors.red),
                                              );
                                            }
                                            final devices = snap.data ?? [];
                                            if (devices.isEmpty) {
                                              return const Center(
                                                child: Text(
                                                    'Người dùng này chưa có thiết bị nào.'),
                                              );
                                            }

                                            return Scrollbar(
                                              thumbVisibility: true,
                                              child: SingleChildScrollView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: DataTable(
                                                  columnSpacing: 32,
                                                  headingRowHeight: 40,
                                                  dataRowHeight: 44,
                                                  columns: const [
                                                    DataColumn(
                                                        label: Text('ID')),
                                                    DataColumn(
                                                        label: Text('Tên')),
                                                    DataColumn(
                                                        label: Text('Serial')),
                                                    DataColumn(
                                                        label: Text('Loại')),
                                                    DataColumn(
                                                        label:
                                                            Text('Trạng thái')),
                                                    DataColumn(
                                                        label: Text('Vị trí')),
                                                    DataColumn(
                                                        label:
                                                            Text('Hành động')),
                                                  ],
                                                  rows: devices.map((d) {
                                                    final id = d['device_id'];
                                                    final name =
                                                        d['name'] ?? '';
                                                    final serial =
                                                        d['serial_no'] ?? '';
                                                    final typeName =
                                                        d['device_type_name'] ??
                                                            d['device_type_id']
                                                                ?.toString() ??
                                                            '';
                                                    final status =
                                                        d['status'] ?? '';
                                                    final location =
                                                        d['location'] ?? '';

                                                    return DataRow(
                                                      cells: [
                                                        DataCell(
                                                            Text('$id')),
                                                        DataCell(
                                                            Text(name)),
                                                        DataCell(
                                                            Text(serial)),
                                                        DataCell(
                                                            Text(typeName)),
                                                        DataCell(
                                                          _buildDeviceStatusChip(
                                                              status),
                                                        ),
                                                        DataCell(
                                                            Text(location)),
                                                        DataCell(
                                                          Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              IconButton(
                                                                tooltip: 'Sửa',
                                                                icon:
                                                                    const Icon(
                                                                  Icons.edit,
                                                                  size: 18,
                                                                  color: Colors
                                                                      .blue,
                                                                ),
                                                                onPressed: () =>
                                                                    _openEditDialog(
                                                                        d),
                                                              ),
                                                              IconButton(
                                                                tooltip: 'Xóa',
                                                                icon:
                                                                    const Icon(
                                                                  Icons.delete,
                                                                  size: 18,
                                                                  color: Colors
                                                                      .red,
                                                                ),
                                                                onPressed: () =>
                                                                    _deleteDevice(
                                                                        id
                                                                            as int),
                                                              ),
                                                              IconButton(
                                                                tooltip:
                                                                    'Xem log thiết bị',
                                                                icon:
                                                                    const Icon(
                                                                  Icons.list_alt,
                                                                  size: 18,
                                                                  color: Colors
                                                                      .grey,
                                                                ),
                                                                onPressed: () {
                                                                  showDialog(
                                                                    context:
                                                                        context,
                                                                    builder:
                                                                        (_) =>
                                                                            _DeviceLogsDialog(
                                                                      deviceId:
                                                                          id as int,
                                                                      deviceName:
                                                                          name,
                                                                    ),
                                                                  );
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
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===================== DIALOG LOG THIẾT BỊ =====================

class _DeviceLogsDialog extends StatefulWidget {
  final int deviceId;
  final String deviceName;

  const _DeviceLogsDialog({
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<_DeviceLogsDialog> createState() => _DeviceLogsDialogState();
}

class _DeviceLogsDialogState extends State<_DeviceLogsDialog> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = DeviceService.getDeviceLogs(widget.deviceId);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Log thiết bị: ${widget.deviceName} (#${widget.deviceId})'),
      content: SizedBox(
        width: 520,
        height: 400,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Text(
                'Lỗi tải log: ${snap.error}',
                style: const TextStyle(color: Colors.red),
              );
            }
            final logs = snap.data ?? [];
            if (logs.isEmpty) {
              return const Center(
                child: Text('Chưa có log nào cho thiết bị này.'),
              );
            }

            return Scrollbar(
              thumbVisibility: true,
              child: ListView.separated(
                itemCount: logs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final eventType = (log['event_type'] ?? '').toString();
                  final description =
                      (log['description'] ?? '').toString();
                  final createdAt =
                      (log['created_at'] ?? '').toString(); // ISO string

                  IconData icon;
                  Color color;
                  switch (eventType) {
                    case 'online':
                      icon = Icons.check_circle;
                      color = Colors.green;
                      break;
                    case 'offline':
                      icon = Icons.wifi_off;
                      color = Colors.red;
                      break;
                    case 'error':
                      icon = Icons.error;
                      color = Colors.orange;
                      break;
                    case 'maintenance':
                      icon = Icons.build;
                      color = Colors.blueGrey;
                      break;
                    default:
                      icon = Icons.info;
                      color = Colors.grey;
                  }

                  return ListTile(
                    leading: Icon(icon, color: color),
                    title: Text(eventType),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (description.isNotEmpty)
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          createdAt,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}

// ===================== DIALOG THÊM / SỬA THIẾT BỊ =====================

class _DeviceDialog extends StatefulWidget {
  final Map<String, dynamic>? device;
  final int? ownerUserId; // user_id của chủ thiết bị (khi tạo mới)

  const _DeviceDialog({
    this.device,
    this.ownerUserId,
  });

  @override
  State<_DeviceDialog> createState() => _DeviceDialogState();
}

class _DeviceDialogState extends State<_DeviceDialog> {
  final _form = GlobalKey<FormState>();

  late TextEditingController _name;
  late TextEditingController _serial;
  late TextEditingController _location;
  late TextEditingController _type;

  bool _saving = false;
  late String _statusValue;

  static const List<Map<String, String>> _statusOptions = [
    {'value': 'active', 'label': 'Đang hoạt động'},
    {'value': 'inactive', 'label': 'Ngưng hoạt động'},
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.device;
    _name = TextEditingController(text: d?['name'] ?? '');
    _serial = TextEditingController(text: d?['serial_no'] ?? '');
    _location = TextEditingController(text: d?['location'] ?? '');
    _type =
        TextEditingController(text: d?['device_type_id']?.toString() ?? '');

    final rawStatus = (d?['status'] ?? 'active').toString().toLowerCase();
    if (_statusOptions.any((o) => o['value'] == rawStatus)) {
      _statusValue = rawStatus;
    } else {
      _statusValue = 'active';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _serial.dispose();
    _location.dispose();
    _type.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);

    final body = {
      "name": _name.text.trim(),
      "serial_no": _serial.text.trim(),
      "location": _location.text.trim(),
      "device_type_id": int.tryParse(_type.text) ?? 0,
      "status": _statusValue,
    };

    // gán user_id khi tạo mới
    if (widget.device == null && widget.ownerUserId != null) {
      body["user_id"] = widget.ownerUserId!;
    }

    try {
      if (widget.device == null) {
        await DeviceService.createDevice(body);
      } else {
        await DeviceService.updateDevice(
          widget.device!['device_id'] as int,
          body,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi lưu thiết bị: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.device != null;

    return AlertDialog(
      title: Text(isEdit ? 'Sửa thiết bị' : 'Thêm thiết bị cho người dùng'),
      content: Form(
        key: _form,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Tên thiết bị'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'Không được để trống'
                        : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _serial,
                decoration: const InputDecoration(labelText: 'Serial'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'Không được để trống'
                        : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _type,
                decoration:
                    const InputDecoration(labelText: 'Loại thiết bị (ID)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _statusValue,
                items: _statusOptions
                    .map(
                      (opt) => DropdownMenuItem<String>(
                        value: opt['value'],
                        child: Text(opt['label']!),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _statusValue = val);
                },
                decoration: const InputDecoration(labelText: 'Trạng thái'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _location,
                decoration:
                    const InputDecoration(labelText: 'Vị trí lắp đặt'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEdit ? 'Lưu thay đổi' : 'Tạo mới'),
        ),
      ],
    );
  }
}
