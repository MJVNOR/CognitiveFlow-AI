// Repository: auth demo (login por user_id, token opaco).
// MVVM: [AuthRepository] inyectable vía providers.
import '../services/api_client.dart';

typedef Credentials = ({String token, String userId, String role});

class AuthRepository {
  final ApiClient api;
  AuthRepository({ApiClient? api}) : api = api ?? defaultApiClient;

  Future<Credentials> login(String id) async {
    Map<String, dynamic> body;
    try {
      body = await api.post('/auth/login', {'user_id': id});
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
}
