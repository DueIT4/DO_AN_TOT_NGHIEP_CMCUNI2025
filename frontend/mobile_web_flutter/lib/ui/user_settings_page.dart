// lib/ui/user_settings_page.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../l10n/language_service.dart';
import '../models/user_profile.dart';
import '../services/api_client.dart';
import '../services/user_service.dart';

import 'login_page.dart';
import 'support_list_page.dart';

class UserSettingsPage extends StatefulWidget {
  const UserSettingsPage({super.key});

  @override
  State<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  late Future<UserProfile> _profileFuture;

  bool _notificationsEnabled = true;
  String _currentLanguageCode = LanguageService.instance.locale.languageCode;

  final ImagePicker _avatarPicker = ImagePicker();
  bool _avatarUploading = false;

  // ✅ Thêm: bootstrap để restore token trước khi gọi API
  Future<UserProfile> _bootstrapAndFetchProfile() async {
    // 1) Restore token nếu ApiClient đang null (hay bị khi reload web)
    if (ApiClient.authToken == null || ApiClient.authToken!.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('auth_token'); // 🔥 key bạn lưu token
      if (saved != null && saved.isNotEmpty) {
        ApiClient.authToken = saved; // restore vào memory
      }
    }

    // 2) Nếu vẫn không có token => về login
    final token = ApiClient.authToken;
    if (token == null || token.isEmpty) {
      // tránh setState sau khi dispose
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        });
      }
      return UserProfile.placeholder();
    }

    // 3) Có token => gọi API lấy profile
    return await UserService.fetchProfile();
  }

  @override
  void initState() {
    super.initState();
    _profileFuture = _bootstrapAndFetchProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentLanguageCode = Localizations.localeOf(context).languageCode;
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _profileFuture = _bootstrapAndFetchProfile();
    });
  }

  // ✅ Logout: clear token cả memory + storage
  Future<void> _handleLogout() async {
    await ApiClient.clearAuth();
    // nếu ApiClient.clearAuth chưa xoá prefs token thì xoá thêm:
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _openEditSheet(UserProfile profile) async {
    final l10n = AppLocalizations.of(context);

    final nameCtrl = TextEditingController(text: profile.name);
    final phoneCtrl = TextEditingController(text: profile.phone);
    final emailCtrl = TextEditingController(text: profile.email);
    final addressCtrl = TextEditingController(text: profile.address);

    bool loading = false;

    await showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> handleSave() async {
              setSheetState(() => loading = true);
              final updated = await UserService.updateProfile(
                username: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                address: addressCtrl.text.trim(),
              );
              if (mounted) {
                Navigator.of(context).pop(updated);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.translate('info_updated'))),
                );
              }
            }

            return Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.translate('edit_info'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.translate('name'),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: l10n.translate('phone'),
                        prefixIcon: const Icon(Icons.call_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: l10n.translate('email'),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.translate('address'),
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: loading ? null : handleSave,
                        child: loading
                            ? const CircularProgressIndicator()
                            : Text(l10n.translate('save_changes')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((value) {
      if (value != null) {
        setState(() => _profileFuture = Future.value(value));
      } else {
        _refreshProfile();
      }
    });
  }

  void _openLanguageSheet() {
    final locales = LanguageService.supportedLocales;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: locales
              .map(
                (locale) => ListTile(
                  title: Text(
                    LanguageService.instance.displayName(locale.languageCode),
                  ),
                  trailing: locale.languageCode == _currentLanguageCode
                      ? const Icon(Icons.check, color: Color(0xFF7CCD2B))
                      : null,
                  onTap: () {
                    LanguageService.instance.setLocale(locale);
                    setState(() => _currentLanguageCode = locale.languageCode);
                    Navigator.pop(ctx);
                  },
                ),
              )
              .toList(),
        );
      },
    );
  }

  void _showAvatarActions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatar(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatar(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAvatar(ImageSource source) async {
  final file = await _avatarPicker.pickImage(
    source: source,
    imageQuality: 85,
    maxWidth: 1024,
  );
  if (file == null) return;

  setState(() => _avatarUploading = true);

  try {
    final updated = await UserService.uploadAvatar(file); // ✅ await ở ngoài

    if (!mounted) return;
    setState(() {
      _profileFuture = Future.value(updated); // ✅ setState sync
    });
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Không thể cập nhật avatar: $e')),
    );
  } finally {
    if (mounted) setState(() => _avatarUploading = false);
  }
}


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F9E9),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.translate('personal'),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: _refreshProfile,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<UserProfile>(
                future: _profileFuture,
                builder: (context, snapshot) {
                  final profile = snapshot.data ?? UserProfile.placeholder();

                  // ✅ Nếu lỗi API (token hết hạn...) => show snack + về login
                  if (snapshot.hasError) {
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(snapshot.error.toString())),
                      );
                    });
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFB8F28B), Color(0xFFF8FFE1)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: _avatarUploading ? null : _showAvatarActions,
                                child: SizedBox(
                                  width: 120,
                                  height: 120,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 56,
                                        backgroundImage: profile.avatarUrl.isNotEmpty
                                            ? NetworkImage(profile.avatarUrl)
                                            : null,
                                        child: profile.avatarUrl.isEmpty
                                            ? const Icon(Icons.person,
                                                size: 48, color: Colors.white)
                                            : null,
                                        backgroundColor: const Color(0xFF7CCD2B),
                                      ),
                                      Positioned(
                                        bottom: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt_outlined,
                                            size: 18,
                                            color: Color(0xFF7CCD2B),
                                          ),
                                        ),
                                      ),
                                      if (_avatarUploading)
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.4),
                                            shape: BoxShape.circle,
                                          ),
                                          width: 112,
                                          height: 112,
                                          child: const Padding(
                                            padding: EdgeInsets.all(20),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 3,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                profile.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profile.phone,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        _SettingTile(
                          icon: Icons.edit_outlined,
                          label: l10n.translate('edit_info'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _openEditSheet(profile),
                        ),
                        const SizedBox(height: 12),

                        _SettingTile(
                          icon: Icons.language_outlined,
                          label: l10n.translate('language'),
                          trailing: Text(
                            LanguageService.instance.displayName(_currentLanguageCode),
                            style: const TextStyle(color: Colors.black54),
                          ),
                          onTap: _openLanguageSheet,
                        ),
                        const SizedBox(height: 12),

                        _SettingTile(
                          icon: Icons.notifications_none,
                          label: l10n.translate('notifications'),
                          trailing: Switch.adaptive(
                            activeColor: const Color(0xFF7CCD2B),
                            value: _notificationsEnabled,
                            onChanged: (value) {
                              setState(() => _notificationsEnabled = value);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    value
                                        ? l10n.translate('notification_on')
                                        : l10n.translate('notification_off'),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

                        _SettingTile(
                          icon: Icons.support_agent_outlined,
                          label: 'Hỗ trợ',
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SupportListPage()),
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        _SettingTile(
                          icon: Icons.logout,
                          label: l10n.translate('logout'),
                          textColor: Colors.red,
                          iconColor: Colors.red,
                          onTap: _handleLogout,
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? textColor;
  final Color? iconColor;

  const _SettingTile({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.textColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F4D9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor ?? const Color(0xFF7CCD2B)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: textColor ?? Colors.black,
                ),
              ),
            ),
            trailing ?? const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
