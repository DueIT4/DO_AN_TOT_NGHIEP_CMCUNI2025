import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/support_service.dart';
import 'support_create_page.dart';
import 'support_detail_page.dart';

class SupportListPage extends StatefulWidget {
  const SupportListPage({super.key});

  @override
  State<SupportListPage> createState() => _SupportListPageState();
}

class _SupportListPageState extends State<SupportListPage> {
  late Future<(bool, List<dynamic>, String)> _ticketsFuture;

  @override
  void initState() {
    super.initState();
    _refreshTickets();
  }

  void _refreshTickets() {
    setState(() {
      _ticketsFuture = SupportService.fetchMyTickets();
    });
  }

  Future<void> _openCreateTicketPage() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SupportCreatePage()),
    );
    if (result == true) {
      _refreshTickets();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F9E9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Hỗ trợ',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<(bool, List<dynamic>, String)>(
        future: _ticketsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return Center(
              child: Text(
                'Không thể tải dữ liệu',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }

          final (success, tickets, error) = snapshot.data!;

          if (!success) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    error,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _refreshTickets,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          if (tickets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.help_outline,
                    size: 64,
                    color: Colors.black26,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có yêu cầu hỗ trợ',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index] as Map<String, dynamic>;
              final title = ticket['title'] ?? 'Không có tiêu đề';
              final description = ticket['description'] ?? '';
              final latestMessage = ticket['latest_message'] ?? '';
              final updatedAt = ticket['updated_at'] ?? '';

              // Parse and format date
              String formattedDate = '';
              try {
                if (updatedAt.isNotEmpty) {
                  final date = DateTime.parse(updatedAt);
                  formattedDate = DateFormat('dd/MM/yyyy').format(date);
                }
              } catch (_) {
                formattedDate = updatedAt;
              }

              // Get snippet (latest message or description)
              final snippet = (latestMessage.isNotEmpty
                      ? latestMessage
                      : description)
                  .replaceAll('\n', ' ')
                  .substring(
                      0,
                      (latestMessage.isNotEmpty ? latestMessage : description)
                                  .length >
                              60
                          ? 60
                          : (latestMessage.isNotEmpty
                                  ? latestMessage
                                  : description)
                              .length);

              final hasReply = ticket['has_reply'] ?? false;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SupportDetailPage(ticket: ticket),
                    ),
                  ).then((_) => _refreshTickets());
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasReply)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$snippet${snippet.length < (latestMessage.isNotEmpty ? latestMessage : description).length ? '...' : ''}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black38,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.black26,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF7CCD2B),
        onPressed: _openCreateTicketPage,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
