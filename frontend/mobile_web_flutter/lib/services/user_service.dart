import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/api_base.dart';
import '../models/user_profile.dart';
import 'api_client.dart';

class UserService {
  static Future<UserProfile> fetchProfile() async {
    final token = ApiClient.authToken;
    if (token == null || token.isEmpty) {
      return UserProfile.placeholder();
    }

    final uri = Uri.parse(ApiBase.api('/me/get_me'));
    try {
      final resp = await http.get(
        uri,
        headers: ApiClient.authHeaders(),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return UserProfile.fromJson(data);
      }
    } catch (e, s) {
      debugPrint('fetchProfile error: $e\n$s');
    }
    return UserProfile.placeholder();
  }

  static Future<UserProfile> updateProfile({
    String? username,
    String? phone,
    String? email,
    String? address,
  }) async {
    final token = ApiClient.authToken;
    if (token == null || token.isEmpty) {
      return UserProfile.placeholder();
    }

    final uri = Uri.parse(ApiBase.api('/me/update_me'));
    final body = <String, String>{};
    if (username != null) body['username'] = username;
    if (phone != null) body['phone'] = phone;
    if (email != null) body['email'] = email;
    if (address != null) body['address'] = address;

    try {
      final resp = await http.put(
        uri,
        headers: ApiClient.authHeaders(json: false, extra: {
          'Content-Type': 'application/x-www-form-urlencoded',
        }),
        body: body,
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return UserProfile.fromJson(data);
      } else {
        debugPrint('updateProfile failed: ${resp.statusCode} ${resp.body}');
      }
    } catch (e, s) {
      debugPrint('updateProfile error: $e\n$s');
    }
    return UserProfile.placeholder();
  }
}

