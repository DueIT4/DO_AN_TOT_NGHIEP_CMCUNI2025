import 'package:flutter/material.dart';
import 'package:mobile_web_flutter/services/admin/device_service.dart';
import 'package:mobile_web_flutter/services/admin/user_service.dart';
import 'package:mobile_web_flutter/services/admin/device_type_service.dart';
import 'package:mobile_web_flutter/core/toast.dart';
import 'package:mobile_web_flutter/core/role_ui.dart';

class AdminDevicesPage extends StatefulWidget {
  const AdminDevicesPage({super.key});

  @override
  State<AdminDevicesPage> createState() => _AdminDevicesPageState();
}

class _AdminDevicesPageState extends State<AdminDevicesPage> {
  late Future<List<Map<String, dynamic>>> _usersFuture;
  Map<String, dynamic>? _selectedUser;

  Future<List<Map<String, dynamic>>>? _devicesFuture;
  late Future<List<Map<String, dynamic>>> _deviceTypesFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = UserService.listUsers();
    _deviceTypesFuture = DeviceTypeService.listDeviceTypes();
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
      AppToast.show(
        context,
        message: 'Vui lòng chọn một người dùng trước.',
        type: ToastType.warning,
      );
      return;
    }

    final deviceTypes = await _deviceTypesFuture;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DeviceDialog(
        key: UniqueKey(),
        ownerUserId: _selectedUser!['user_id'] as int,
        deviceTypes: deviceTypes,
      ),
    );
    if (ok == true) _reloadDevicesForSelectedUser();
  }

  Future<void> _openEditDialog(Map<String, dynamic> device) async {
    final deviceTypes = await _deviceTypesFuture;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DeviceDialog(
        key: UniqueKey(),
        device: device,
        deviceTypes: deviceTypes,
      ),
    );
    if (ok == true) _reloadDevicesForSelectedUser();
  }

  Future<void> _deleteDevice(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Xóa thiết bị"),
        content: const Text("Bạn chắc chắn muốn xóa thiết bị này khỏi hệ thống?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("Hủy"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text("Xóa"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await DeviceService.deleteDevice(id);
      if (!mounted) return;

      AppToast.show(context, message: 'Đã xóa thiết bị', type: ToastType.success);
      _reloadDevicesForSelectedUser();
    } catch (e) {
      if (!mounted) return;

      final msg = e.toString();
      // nếu backend từng trả 404 sai, giữ workaround an toàn
      if (msg.contains('404')) {
        AppToast.show(context, message: 'Thiết bị đã được xóa.', type: ToastType.warning);
        _reloadDevicesForSelectedUser();
        return;
      }

      AppToast.show(context, message: 'Lỗi xóa thiết bị: $e', type: ToastType.error);
    }
  }

  Widget _buildDeviceStatusChip(String? status) {
    final s = (status ?? '').toLowerCase();
    final scheme = Theme.of(context).colorScheme;

    Color bg;
    Color fg;

    switch (s) {
      case 'active':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'inactive':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        break;
      case 'maintain':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        break;
      default:
        bg = scheme.surfaceContainerHighest;
        fg = scheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Text(
        status ?? '-',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }



  Widget _buildHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final userName = _selectedUser?['username'] ?? _selectedUser?['email'];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withOpacity(0.10),
            scheme.tertiary.withOpacity(0.10),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.devices_other_rounded, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thiết bị theo người dùng',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  userName == null ? 'Chọn người dùng để xem danh sách thiết bị.' : 'Đang xem: $userName',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _openCreateDialogForSelectedUser,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Thêm thiết bị'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserListCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Icon(Icons.people_alt_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Người dùng',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _usersFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'Lỗi tải người dùng: ${snap.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final users = snap.data ?? [];
                if (users.isEmpty) {
                  return const Center(child: Text('Chưa có người dùng nào.'));
                }

                return Scrollbar(
                  thumbVisibility: true,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                     final u = users[index];
                      final bool selected =
                          _selectedUser != null && _selectedUser!['user_id'] == u['user_id'];

                      final name = u['username'] ?? 'User #${u['user_id']}';
                      final email = (u['email'] ?? '').toString().trim();
                      final phone = (u['phone'] ?? '').toString().trim();
                      final status = (u['status'] ?? '').toString();
                      final roleType = (u['role_type'] ?? '').toString();

                      // ✅ chỉ hiển thị 1 cái: ưu tiên email, không có thì sđt
                      final contact = email.isNotEmpty ? email : (phone.isNotEmpty ? phone : '-');

                      return ListTile(
                        selected: selected,
                        selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.06),
                        onTap: () => _selectUser(u),

                        // 👇 Dòng 1: Tên + Vai trò cố định bên phải
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildRoleChip(roleType), // ✅ chip vai trò cố định
                          ],
                        ),

                        // 👇 Dòng 2: Email/SĐT + Trạng thái cố định bên phải
                        subtitle: Row(
                          children: [
                            Expanded(
                              child: Text(
                                contact,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
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
        ],
      ),
    );
  }
Widget _buildRoleChip(String? roleType) {
  final bg = roleBgColor(roleType);
  final fg = roleFgColor(roleType);

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      roleLabelVi(roleType), // ✅ đổi label
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: fg,
      ),
    ),
  );
}



  Widget _buildDevicesCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_selectedUser == null) {
      return Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_rounded, size: 34, color: scheme.primary),
                const SizedBox(height: 10),
                const Text(
                  'Vui lòng chọn một người dùng bên trái\nto xem danh sách thiết bị.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final userLabel =
        _selectedUser!['username'] ?? _selectedUser!['email'] ?? 'User #${_selectedUser!['user_id']}';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Icon(Icons.devices_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Thiết bị của: $userLabel',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Tải lại thiết bị',
                  onPressed: _reloadDevicesForSelectedUser,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _devicesFuture == null
                ? const Center(child: Text('Chọn người dùng để tải danh sách thiết bị.'))
                : FutureBuilder<List<Map<String, dynamic>>>(
                    future: _devicesFuture,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            'Lỗi tải thiết bị: ${snap.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      final devices = snap.data ?? [];
                      if (devices.isEmpty) {
                        return const Center(child: Text('Người dùng này chưa có thiết bị nào.'));
                      }

                      // ✅ UI mới: DataTable vẫn giữ, nhưng bọc card + padding đẹp hơn
                      return Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          scrollDirection: Axis.horizontal,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: DataTable(
                              columnSpacing: 28,
                              headingRowHeight: 44,
                              dataRowHeight: 52,
                              headingTextStyle: const TextStyle(fontWeight: FontWeight.w800),
                              columns: const [
                                DataColumn(label: Text('ID')),
                                DataColumn(label: Text('Tên')),
                                DataColumn(label: Text('Serial')),
                                DataColumn(label: Text('Loại')),
                                DataColumn(label: Text('Trạng thái')),
                                DataColumn(label: Text('Vị trí')),
                                DataColumn(label: Text('Hành động')),
                              ],
                              rows: devices.map((d) {
                                final id = d['device_id'] as int;
                                final name = (d['name'] ?? '').toString();
                                final serial = (d['serial_no'] ?? '').toString();
                                final typeName = (d['device_type_name'] ??
                                        d['device_type_id']?.toString() ??
                                        '')
                                    .toString();
                                final status = (d['status'] ?? '').toString();
                                final location = (d['location'] ?? '').toString();

                                return DataRow(
                                  cells: [
                                    DataCell(Text('$id')),
                                    DataCell(SizedBox(width: 180, child: Text(name, overflow: TextOverflow.ellipsis))),
                                    DataCell(SizedBox(width: 160, child: Text(serial, overflow: TextOverflow.ellipsis))),
                                    DataCell(SizedBox(width: 150, child: Text(typeName, overflow: TextOverflow.ellipsis))),
                                    DataCell(_buildDeviceStatusChip(status)),
                                    DataCell(SizedBox(width: 160, child: Text(location, overflow: TextOverflow.ellipsis))),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Sửa',
                                            icon: const Icon(Icons.edit_rounded, size: 18),
                                            color: Colors.blue,
                                            onPressed: () => _openEditDialog(d),
                                          ),
                                          IconButton(
                                            tooltip: 'Xóa',
                                            icon: const Icon(Icons.delete_rounded, size: 18),
                                            color: Colors.red,
                                            onPressed: () => _deleteDevice(id),
                                          ),

                                          // ❌ BỎ NÚT LOG TẠM THỜI THEO YÊU CẦU
                                          // IconButton(
                                          //   tooltip: 'Xem log thiết bị',
                                          //   icon: const Icon(Icons.list_alt, size: 18, color: Colors.grey),
                                          //   onPressed: () { ... },
                                          // ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: Column(
                  children: [
                    _buildHeader(context),
                    const Divider(height: 1),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: _buildUserListCard(context)),
                            const SizedBox(width: 14),
                            Expanded(flex: 3, child: _buildDevicesCard(context)),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLowest,
                        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.06))),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 18, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Text(
                            'Tip: chọn user → thêm/sửa/xóa thiết bị. Log thiết bị đang tắt tạm thời.',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===================== DIALOG THÊM / SỬA THIẾT BỊ =====================

// ===================== DIALOG THÊM / SỬA THIẾT BỊ (UI IMPROVED) =====================

class _DeviceDialog extends StatefulWidget {
  final Map<String, dynamic>? device;
  final int? ownerUserId;
  final List<Map<String, dynamic>> deviceTypes;

  const _DeviceDialog({
    super.key,
    this.device,
    this.ownerUserId,
    required this.deviceTypes,
  });

  @override
  State<_DeviceDialog> createState() => _DeviceDialogState();
}

class _DeviceDialogState extends State<_DeviceDialog> {
  final _form = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _serial;
  late final TextEditingController _location;

  bool _saving = false;
  late String _statusValue;
  int? _selectedDeviceTypeId;

  static const List<Map<String, String>> _statusOptions = [
    {'value': 'active', 'label': 'Đang hoạt động'},
    {'value': 'inactive', 'label': 'Ngưng hoạt động'},
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.device;

    _name = TextEditingController(text: (d?['name'] ?? '').toString());
    _serial = TextEditingController(text: (d?['serial_no'] ?? '').toString());
    _location = TextEditingController(text: (d?['location'] ?? '').toString());

    if (d != null && d['device_type_id'] != null) {
      _selectedDeviceTypeId = d['device_type_id'] as int;
    }

    final rawStatus = (d?['status'] ?? 'active').toString().toLowerCase();
    _statusValue = _statusOptions.any((o) => o['value'] == rawStatus) ? rawStatus : 'active';
  }

  @override
  void dispose() {
    _name.dispose();
    _serial.dispose();
    _location.dispose();
    super.dispose();
  }

  InputDecoration _decoration(
    BuildContext context, {
    required String label,
    String? hint,
    IconData? icon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 18, color: scheme.onSurfaceVariant),
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withOpacity(0.35),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary.withOpacity(0.55), width: 1.3),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            height: 8,
            width: 8,
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.8),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);

    // ✅ giữ nguyên keys/logic, chỉ UI
    final body = <String, dynamic>{
      "name": _name.text.trim(),
      "serial_no": _serial.text.trim(),
      "location": _location.text.trim(),
      "device_type_id": _selectedDeviceTypeId ?? 0,
      "status": _statusValue,
    };

    if (widget.device == null && widget.ownerUserId != null) {
      body["user_id"] = widget.ownerUserId!;
    }

    try {
      if (widget.device == null) {
        await DeviceService.createDevice(body);
      } else {
        await DeviceService.updateDevice(widget.device!['device_id'] as int, body);
      }

      if (!mounted) return;

      AppToast.show(
        context,
        message: widget.device == null ? 'Tạo thiết bị thành công' : 'Cập nhật thiết bị thành công',
        type: ToastType.success,
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: 'Lỗi lưu thiết bị: $e', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.device != null;
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
      actionsPadding: const EdgeInsets.fromLTRB(18, 10, 18, 16),

      // ✅ Header đẹp + đồng bộ style trang
      title: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withOpacity(0.10),
              scheme.tertiary.withOpacity(0.10),
            ],
          ),
          border: Border(
            bottom: BorderSide(color: Colors.black.withOpacity(0.06)),
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isEdit ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit ? 'Sửa thiết bị' : 'Thêm thiết bị',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isEdit
                        ? 'Cập nhật thông tin thiết bị'
                        : 'Nhập thông tin để tạo thiết bị mới',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Đóng',
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),

      content: Form(
        key: _form,
        child: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sectionTitle(context, 'Thông tin cơ bản'),
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(
                    context,
                    label: 'Tên thiết bị',
                    hint: 'VD: Camera cổng A',
                    icon: Icons.devices_other_rounded,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Không được để trống' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _serial,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(
                    context,
                    label: 'Serial',
                    hint: 'VD: SN-001-ABC',
                    icon: Icons.confirmation_number_rounded,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Không được để trống' : null,
                ),

                const SizedBox(height: 16),
                _sectionTitle(context, 'Phân loại & trạng thái'),

                // ✅ 2 cột gọn gàng (desktop/web), nhỏ quá thì vẫn ổn nhờ layout co giãn
                LayoutBuilder(
                  builder: (context, c) {
                    final isNarrow = c.maxWidth < 460;
                    final children = <Widget>[
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _selectedDeviceTypeId,
                          isExpanded: true,
                          items: widget.deviceTypes.map((dt) {
                            final id = dt['device_type_id'] as int;
                            final name = (dt['device_type_name'] ?? 'Loại #$id').toString();
                            return DropdownMenuItem<int>(
                              value: id,
                              child: Text(name, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedDeviceTypeId = val),
                          decoration: _decoration(
                            context,
                            label: 'Loại thiết bị',
                            icon: Icons.category_rounded,
                          ),
                          validator: (val) => (val == null || val == 0) ? 'Vui lòng chọn loại thiết bị' : null,
                        ),
                      ),
                      SizedBox(width: isNarrow ? 0 : 12, height: isNarrow ? 12 : 0),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _statusValue,
                          isExpanded: true,
                          items: _statusOptions
                              .map((opt) => DropdownMenuItem<String>(
                                    value: opt['value'],
                                    child: Text(opt['label']!),
                                  ))
                              .toList(),
                          onChanged: (val) => setState(() => _statusValue = val ?? 'active'),
                          decoration: _decoration(
                            context,
                            label: 'Trạng thái',
                            icon: Icons.toggle_on_rounded,
                          ),
                        ),
                      ),
                    ];

                    return isNarrow
                        ? Column(children: children.map((w) => w).toList())
                        : Row(children: children);
                  },
                ),

                const SizedBox(height: 16),
                _sectionTitle(context, 'Vị trí'),

                TextFormField(
                  controller: _location,
                  textInputAction: TextInputAction.done,
                  decoration: _decoration(
                    context,
                    label: 'Vị trí lắp đặt',
                    hint: 'VD: Tầng 1 - Khu vực lễ tân',
                    icon: Icons.place_rounded,
                  ),
                ),

                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Mẹo: Điền Serial dễ nhận diện để quản lý nhanh hơn.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(isEdit ? Icons.save_rounded : Icons.add_rounded, size: 18),
          label: Text(isEdit ? 'Lưu thay đổi' : 'Tạo mới'),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}



