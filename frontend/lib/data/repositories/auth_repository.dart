// Repository: auth demo (login por user_id, token opaco).
// Extraído de features/login_page.dart sin cambios de lógica.
import '../services/api_client.dart';

Future<({String token, String userId, String role})> login(String id) async {
  Map<String, dynamic> body;
  try {
    body = await postJson('/auth/login', {'user_id': id});
  } catch (e) {
    // login_page distingue 'usuario desconocido' en el mensaje (igual que antes).
    if ('$e'.startsWith('404') || '$e'.startsWith('401')) {
      throw Exception('401 usuario desconocido');
    }
    rethrow;
  }
  return (
    token: body['token'] as String,
    userId: (body['user_id'] ?? id) as String,
    role: (body['role'] ?? 'student') as String,
  );
}
