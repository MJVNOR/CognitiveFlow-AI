// Service sin estado: un wrapper por datasource HTTP (docs.flutter.dev/app-architecture/guide).
// MVVM: ApiClient es la fuente injectable; las funciones sueltas quedan como
// compat para callers viejos y delegan a [defaultApiClient].
import 'dart:convert';

import 'package:http/http.dart' as http;

const apiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

/// Cliente HTTP inyectable (Model/Data). El token lo pone [AuthNotifier]
/// (login/logout/bootstrap); los ViewModels lo reciben por provider.
class ApiClient {
  final String baseUrl;
  String? _token;
  ApiClient({this.baseUrl = apiBase});

  void setToken(String? token) => _token = token;

  Map<String, String> _headers([bool json = false]) => {
        if (_token != null) 'Authorization': 'Bearer $_token',
        if (json) 'Content-Type': 'application/json',
      };

  Future<List<dynamic>> getList(String path) async {
    final r = await http.get(Uri.parse('$baseUrl$path'), headers: _headers());
    if (r.statusCode != 200) throw Exception('${r.statusCode} $path');
    return jsonDecode(r.body) as List;
  }

  Future<Map<String, dynamic>> getMap(String path) async {
    final r = await http.get(Uri.parse('$baseUrl$path'), headers: _headers());
    if (r.statusCode != 200) throw Exception('${r.statusCode} $path');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final r = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(true),
      body: jsonEncode(body),
    );
    if (r.statusCode != 200) throw Exception('${r.statusCode} $path');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}

final defaultApiClient = ApiClient();

// P1.5: id único por evento (reintento seguro vía dedup en backend).
int _eventSeq = 0;
String newEventId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${_eventSeq++}';
