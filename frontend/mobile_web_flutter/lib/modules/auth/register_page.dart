import 'package:flutter/material.dart';
validator: (v) => (v==null||v.isEmpty)?'Nhập username':null,
),
const SizedBox(height: 12),
TextFormField(
controller: _phone, decoration: const InputDecoration(labelText: 'Số điện thoại'),
validator: (v) => (v==null||v.isEmpty)?'Nhập số điện thoại':null,
),
const SizedBox(height: 12),
TextFormField(
controller: _password, decoration: const InputDecoration(labelText: 'Mật khẩu'), obscureText: true,
validator: (v) => (v==null||v.length<6)?'Tối thiểu 6 ký tự':null,
),
const SizedBox(height: 12),
if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
const SizedBox(height: 12),
FilledButton(
onPressed: _loading?null:_registerPhone,
child: _loading? const SizedBox(height:18,width:18,child: CircularProgressIndicator(strokeWidth:2)) : const Text('Đăng ký bằng SĐT'),
),
const SizedBox(height: 12),
Row( mainAxisAlignment: MainAxisAlignment.center, children: [
OutlinedButton.icon(onPressed: _loading?null:_registerGoogle, icon: const Icon(Icons.g_mobiledata, size: 28), label: const Text('Google')),
const SizedBox(width: 10),
OutlinedButton.icon(onPressed: _loading?null:_registerFacebook, icon: const Icon(Icons.facebook, size: 24), label: const Text('Facebook')),
]),
const SizedBox(height: 8),
TextButton( onPressed: () => Navigator.pushReplacementNamed(context, WebRoutes.login), child: const Text('Đã có tài khoản? Đăng nhập')),
],
),
),
),
),
),
);
}
}