// Service sin estado: un wrapper por datasource HTTP (docs.flutter.dev/app-architecture/guide).
// Extraído de session/lab_session.dart sin cambios de lógica.
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/auth/auth_state.dart';

const apiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

Map<String, String> _headers([bool json = false]) => {
      if (apiToken != null) 'Authorization': 'Bearer $apiToken',
      if (json) 'Content-Type': 'application/json',
    };

Future<List<dynamic>> fetchJson(String path) async {
  final r = await http.get(Uri.parse('$apiBase$path'), headers: _headers());
  if (r.statusCode != 200) throw Exception('${r.statusCode} $path');
  return jsonDecode(r.body) as List;
}

Future<Map<String, dynamic>> fetchMap(String path) async {
  final r = await http.get(Uri.parse('$apiBase$path'), headers: _headers());
  if (r.statusCode != 200) throw Exception('${r.statusCode} $path');
  return jsonDecode(r.body) as Map<String, dynamic>;
}

Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
  final r = await http.post(
    Uri.parse('$apiBase$path'),
    headers: _headers(true),
    body: jsonEncode(body),
  );
  if (r.statusCode != 200) throw Exception('${r.statusCode} $path');
  return jsonDecode(r.body) as Map<String, dynamic>;
}

// P1.5: id único por evento (reintento seguro vía dedup en backend).
int _eventSeq = 0;
String newEventId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${_eventSeq++}';
