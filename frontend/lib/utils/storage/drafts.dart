// Borradores por lab (sobreviven a salir del lab; se limpian al cerrar sesión).
// ponytail: SharedPreferences directo, sin provider (I/O puntual, no estado
// reactivo). Techo: una instancia por llamada; cachear si hay >20 campos.
import 'package:shared_preferences/shared_preferences.dart';

String _draftKey(String labId, String field) => 'draft:$labId:$field';

Future<String?> loadDraft(String labId, String field) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_draftKey(labId, field));
}

Future<void> saveDraft(String labId, String field, String value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_draftKey(labId, field), value);
}

Future<void> clearDrafts(String labId, List<String> fields) async {
  final prefs = await SharedPreferences.getInstance();
  for (final f in fields) {
    await prefs.remove(_draftKey(labId, f));
  }
}
