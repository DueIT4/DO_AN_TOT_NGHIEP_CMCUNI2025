import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mobile_web_flutter/core/admin_me_service.dart';
import 'package:mobile_web_flutter/core/api_base.dart';
import 'package:mobile_web_flutter/core/toast.dart';

class AdminProfileDialog extends StatefulWidget {
  const AdminProfileDialog({super.key, required this.service});
  final AdminMeService service;

  @override
  State<AdminProfileDialog> createState() => _AdminProfileDialogState();
}

class _AdminProfileDialogState extends State<AdminProfileDialog> {
  AdminUserMe? _user;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  late final TextEditingController _usernameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;

  // đổi mật khẩu
  bool _showChangePassword = false;
  final _pwFormKey = GlobalKey<FormState>();
  late final TextEditingController _oldPwCtrl;
  late final TextEditingController _newPwCtrl;
  late final TextEditingController _confirmPwCtrl;
  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;

  final _picker = ImagePicker();

  void _toast(String msg, ToastType type) {
    if (!mounted) return;
    AppToast.show(context, message: msg, type: type);
  }

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _addressCtrl = TextEditingController();

    _oldPwCtrl = TextEditingController();
    _newPwCtrl = TextEditingController();
    _confirmPwCtrl = TextEditingController();

    _loadMe();
  }

  Future<void> _loadMe() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final me = await widget.service.getMe();
      if (!mounted) return;
      setState(() {
        _user = me;
        _usernameCtrl.text = me.username ?? '';
        _phoneCtrl.text = me.phone ?? '';
        _emailCtrl.text = me.email ?? '';
        _addressCtrl.text = me.address ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      _toast('Lỗi tải thông tin: $e', ToastType.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await widget.service.updateMe(
        username: _usernameCtrl.text.trim().isEmpty ? null : _usernameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _user = updated);
      _toast('Cập nhật thành công', ToastType.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      _toast('Lỗi cập nhật: $e', ToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;

      setState(() {
        _saving = true;
        _error = null;
      });

      final Uint8List bytes = await file.readAsBytes();
      final updated = await widget.service.updateAvatar(
        bytes: bytes,
        filename: (file.name.isNotEmpty) ? file.name : 'avatar.jpg',
      );

      if (!mounted) return;
      setState(() => _user = updated);

      _toast('Cập nhật avatar thành công', ToastType.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      _toast('Lỗi cập nhật avatar: $e', ToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    if (!(_pwFormKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.service.changePassword(
        oldPassword: _oldPwCtrl.text,
        newPassword: _newPwCtrl.text,
      );

      if (!mounted) return;
      _oldPwCtrl.clear();
      _newPwCtrl.clear();
      _confirmPwCtrl.clear();

      setState(() => _showChangePassword = false);

      _toast('Đổi mật khẩu thành công', ToastType.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      _toast('Lỗi đổi mật khẩu: $e', ToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _oldPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avt = _user?.avtUrl;
    final fullAvtUrl = (avt != null && avt.isNotEmpty) ? '${ApiBase.baseURL}$avt' : null;
    final avatarProvider = fullAvtUrl != null ? NetworkImage(fullAvtUrl) : null;

    return AlertDialog(
      title: const Text('Thông tin cá nhân'),
      content: SizedBox(
        width: 520,
        child: _loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.green.shade700,
                          backgroundImage: avatarProvider,
                          child: avatarProvider == null
                              ? const Icon(Icons.person, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _user?.username ?? 'Admin',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _saving ? null : _pickAndUploadAvatar,
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Đổi avatar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(),
                    TextField(
                      controller: _usernameCtrl,
                      decoration: const InputDecoration(labelText: 'Tên đăng nhập'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Số điện thoại'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(labelText: 'Địa chỉ'),
                    ),
                    const SizedBox(height: 10),
                    if (_user?.roleType != null)
                      Text(
                        'Vai trò: ${_user!.roleType}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    if (_user?.status != null)
                      Text(
                        'Trạng thái: ${_user!.status}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    const SizedBox(height: 18),
                    const Divider(),
                    Row(
                      children: [
                        Text(
                          'Bảo mật',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _saving
                              ? null
                              : () => setState(() => _showChangePassword = !_showChangePassword),
                          icon: Icon(
                            _showChangePassword ? Icons.expand_less : Icons.lock_reset,
                          ),
                          label: Text(_showChangePassword ? 'Ẩn' : 'Đổi mật khẩu'),
                        ),
                      ],
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 200),
                      crossFadeState: _showChangePassword
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      firstChild: Form(
                        key: _pwFormKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _oldPwCtrl,
                              obscureText: !_showOld,
                              decoration: InputDecoration(
                                labelText: 'Mật khẩu hiện tại',
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() => _showOld = !_showOld),
                                  icon: Icon(_showOld ? Icons.visibility_off : Icons.visibility),
                                ),
                              ),
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Nhập mật khẩu hiện tại' : null,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _newPwCtrl,
                              obscureText: !_showNew,
                              decoration: InputDecoration(
                                labelText: 'Mật khẩu mới',
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() => _showNew = !_showNew),
                                  icon: Icon(_showNew ? Icons.visibility_off : Icons.visibility),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Nhập mật khẩu mới';
                                if (v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _confirmPwCtrl,
                              obscureText: !_showConfirm,
                              decoration: InputDecoration(
                                labelText: 'Nhập lại mật khẩu mới',
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() => _showConfirm = !_showConfirm),
                                  icon:
                                      Icon(_showConfirm ? Icons.visibility_off : Icons.visibility),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Nhập lại mật khẩu mới';
                                }
                                if (v != _newPwCtrl.text) {
                                  return 'Mật khẩu xác nhận không khớp';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FilledButton.icon(
                                onPressed: _saving ? null : _changePassword,
                                icon: const Icon(Icons.lock_reset),
                                label: const Text('Xác nhận đổi mật khẩu'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      secondChild: const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Lưu'),
        ),
      ],
    );
  }
}
