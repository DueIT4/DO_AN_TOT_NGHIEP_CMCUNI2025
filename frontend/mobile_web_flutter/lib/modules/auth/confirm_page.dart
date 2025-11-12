import 'package:flutter/material.dart';
import 'dart:html' as html; // chỉ web
import '../../core/api_base.dart';


class ConfirmPage extends StatefulWidget {
const ConfirmPage({super.key});
@override
State<ConfirmPage> createState() => _ConfirmPageState();
}


class _ConfirmPageState extends State<ConfirmPage> {
String? _message;
@override
void initState() {
super.initState();
_confirm();
}


Future<void> _confirm() async {
final url = html.window.location.href;
final uri = Uri.parse(url);
final token = uri.queryParameters['token'];
if (token == null) {
setState(() => _message = 'Thiếu token xác nhận');
return;
}
try {
final res = await ApiBase.getJson(ApiBase.api('/auth/confirm?token=$token'));
setState(() => _message = res['message']?.toString() ?? 'Xác nhận thành công');
} catch (e) {
setState(() => _message = 'Xác nhận thất bại: $e');
}
}


@override
Widget build(BuildContext context) {
return Center( child: Padding(
padding: const EdgeInsets.all(24.0),
child: Text(_message ?? 'Đang xác nhận...', style: Theme.of(context).textTheme.titleMedium),
));
}
}