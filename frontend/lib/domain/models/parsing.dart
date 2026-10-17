// Helpers de parseo para los modelos del API (backend/app/main.py).
Map<String, dynamic> asModelMap(dynamic e) =>
    (e as Map).cast<String, dynamic>();

List<T> parseModelList<T>(
        List<dynamic> raw, T Function(Map<String, dynamic>) fromJson) =>
    [for (final e in raw) fromJson(asModelMap(e))];
