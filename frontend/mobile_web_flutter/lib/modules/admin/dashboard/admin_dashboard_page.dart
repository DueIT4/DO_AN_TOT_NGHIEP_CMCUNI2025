import 'package:flutter/material.dart';
import '../../../admin/admin_shell.dart';
import '../../../core/api_base.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      // Load stats từ API
      final users = await ApiBase.getJson(ApiBase.api('/users/'));
      final devices = await ApiBase.getJson(ApiBase.api('/devices/'));
      
      setState(() {
        _stats = {
          'totalUsers': (users as List).length,
          'totalDevices': (devices['total'] ?? (devices['items'] as List?)?.length ?? 0),
          'activeDevices': 0, // TODO: tính từ devices
        };
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _stats = {
          'totalUsers': 0,
          'totalDevices': 0,
          'activeDevices': 0,
        };
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      title: 'Dashboard',
      current: AdminMenu.dashboard,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats cards
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2.5,
                    children: [
                      _StatCard(
                        icon: Icons.people,
                        label: 'Tổng người dùng',
                        value: '${_stats?['totalUsers'] ?? 0}',
                        color: Colors.blue,
                      ),
                      _StatCard(
                        icon: Icons.devices,
                        label: 'Tổng thiết bị',
                        value: '${_stats?['totalDevices'] ?? 0}',
                        color: Colors.green,
                      ),
                      _StatCard(
                        icon: Icons.check_circle,
                        label: 'Thiết bị hoạt động',
                        value: '${_stats?['activeDevices'] ?? 0}',
                        color: Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Recent activity hoặc charts có thể thêm sau
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hoạt động gần đây',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Chức năng này sẽ được bổ sung sau',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

