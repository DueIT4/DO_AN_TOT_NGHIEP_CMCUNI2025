import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'ai_chat_page.dart';
import 'user_settings_page.dart';

class HomeUserPage extends StatefulWidget {
  const HomeUserPage({super.key});

  @override
  State<HomeUserPage> createState() => _HomeUserPageState();
}

class _HomeUserPageState extends State<HomeUserPage> {
  int _currentIndex = 0; // bottom nav

  String? _droicamUrl; // lưu địa chỉ Droicam đã nhập
  final TextEditingController _droicamCtrl = TextEditingController();

  @override
  void dispose() {
    _droicamCtrl.dispose();
    super.dispose();
  }

  Future<void> _showDroicamDialog() async {
    // gợi ý lại url cũ nếu đã có
    _droicamCtrl.text = _droicamUrl ?? '';

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Kết nối Droicam'),
          content: TextField(
            controller: _droicamCtrl,
            decoration: const InputDecoration(
              labelText: 'Địa chỉ Droicam / URL stream',
              hintText: 'vd: http://192.168.1.11:4747/video',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final url = _droicamCtrl.text.trim();
                if (url.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập địa chỉ Droicam'),
                    ),
                  );
                  return;
                }
                setState(() {
                  _droicamUrl = url;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Kết nối'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF2F9E9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= HEADER =================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDFF0C8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.spa_rounded,
                      color: Color(0xFF7CCD2B),
                      size: 28,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UserSettingsPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_outline),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                l10n.translate('greeting'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                l10n.translate('monitoring'),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // ========== 2 CARD ĐỘ ẨM / NHIỆT ĐỘ ==========
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: l10n.translate('humidity'),
                      value: '70%',
                      icon: Icons.water_drop_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      title: l10n.translate('temperature'),
                      value: '27 °C',
                      icon: Icons.thermostat_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ========== CAMERA ==========
              GestureDetector(
                onTap: _showDroicamDialog, // chạm để nhập địa chỉ Droicam
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: Colors.black,
                      child: (_droicamUrl == null || _droicamUrl!.isEmpty)
                          ? Center(
                              child: Text(
                                l10n.translate('camera_hint'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            )
                          : DroicamView(url: _droicamUrl!),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.translate('camera_title'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  const Icon(Icons.circle, size: 10, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(l10n.translate('camera_hint')),
                ],
              ),
              const SizedBox(height: 16),

              // ========== AI CHATBOT ==========
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF7CCD2B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.smart_toy_outlined,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.translate('ai_chatbot'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.translate('ai_helper'),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF7CCD2B),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AIChatPage(),
                          ),
                        );
                      },
                      child: Text(l10n.translate('ask_now')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ========== 2 Ô BÊN DƯỚI ==========
              Row(
                children: [
                  Expanded(
                    child: _SmallCard(
                      icon: Icons.insert_chart_outlined,
                      title: l10n.translate('report'),
                      subtitle: l10n.translate('view_analytics'),
                      onTap: () {
                        // TODO: điều hướng sang trang báo cáo
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SmallCard(
                      icon: Icons.notifications_active_outlined,
                      title: l10n.translate('alerts'),
                      subtitle: l10n.translate('alerts_count'),
                      onTap: () {
                        // TODO: điều hướng sang trang cảnh báo
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),

      // ========== BOTTOM NAV ==========
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserSettingsPage()),
            );
            return;
          }
          setState(() => _currentIndex = index);
        },
        selectedItemColor: const Color(0xFF7CCD2B),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              label: l10n.translate('home_tab')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.videocam_outlined),
              label: l10n.translate('camera_tab')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.sensors_outlined),
              label: l10n.translate('device_tab')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              label: l10n.translate('personal_tab')),
        ],
      ),
    );
  }
}

// ================= DROICAM VIEW (bản mobile – placeholder) =================

class DroicamView extends StatelessWidget {
  final String url;

  const DroicamView({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // TẠM THỜI: trên Android chỉ hiển thị placeholder,
    // chưa stream được Droicam trực tiếp.
    return Center(
      child: Text(
        '${l10n.translate('droicam_configured')}\n$url\n\n'
        '${l10n.translate('droicam_desc')}',
        style: const TextStyle(color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ======================= WIDGET PHỤ =======================

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4D9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF7CCD2B)),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: 0.7,
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

class _SmallCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SmallCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F4D9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF7CCD2B)),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
