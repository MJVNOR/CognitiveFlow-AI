// Modelos tipados del API (backend/app/main.py), fromJson/toJson a mano.
// Eval/intervenciones siguen como Map: sus formas varían por lab y mock/jev.
Map<String, dynamic> _asMap(dynamic e) => (e as Map).cast<String, dynamic>();

List<T> _parseList<T>(List<dynamic> raw, T Function(Map<String, dynamic>) fromJson) =>
    [for (final e in raw) fromJson(_asMap(e))];

List<Module> parseModules(List<dynamic> raw) => _parseList(raw, Module.fromJson);
List<Lab> parseLabs(List<dynamic> raw) => _parseList(raw, Lab.fromJson);
List<Student> parseStudents(List<dynamic> raw) => _parseList(raw, Student.fromJson);
List<SessionInfo> parseSessions(List<dynamic> raw) => _parseList(raw, SessionInfo.fromJson);
List<Attempt> parseAttempts(List<dynamic> raw) => _parseList(raw, Attempt.fromJson);

class Module {
  final String id;
  final String title;
  final int orderIndex;
  const Module({required this.id, required this.title, this.orderIndex = 0});
  factory Module.fromJson(Map<String, dynamic> json) => Module(
        id: json['id'] as String,
        title: json['title'] as String,
        orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
      );
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'order_index': orderIndex,
      };
}

class Lab {
  final String id;
  final String title;
  final String labType;
  final String description;
  final int orderIndex;
  final String moduleId;
  const Lab({
    required this.id,
    required this.title,
    this.labType = '',
    this.description = '',
    this.orderIndex = 0,
    this.moduleId = '',
  });
  factory Lab.fromJson(Map<String, dynamic> json) => Lab(
        id: json['id'] as String,
        title: json['title'] as String,
        labType: json['lab_type'] as String? ?? '',
        description: json['description'] as String? ?? '',
        orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
        moduleId: json['module_id'] as String? ?? '',
      );
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'lab_type': labType,
        'description': description,
        'order_index': orderIndex,
        'module_id': moduleId,
      };
}

class Student {
  final String id;
  final String displayName;
  const Student({required this.id, required this.displayName});
  factory Student.fromJson(Map<String, dynamic> json) => Student(
        id: json['id'] as String,
        displayName: json['display_name'] as String,
      );
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'display_name': displayName,
      };
}

class SessionInfo {
  final String id;
  final String labTemplateId;
  final String status;
  const SessionInfo({required this.id, required this.labTemplateId, this.status = ''});
  factory SessionInfo.fromJson(Map<String, dynamic> json) => SessionInfo(
        id: json['id'] as String,
        labTemplateId: json['lab_template_id'] as String,
        status: json['status'] as String? ?? '',
      );
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'lab_template_id': labTemplateId,
        'status': status,
      };
}

class Attempt {
  final String id;
  final String answer;
  final Map<String, dynamic> input;
  const Attempt({required this.id, this.answer = '', this.input = const {}});
  factory Attempt.fromJson(Map<String, dynamic> json) => Attempt(
        id: json['id'] as String,
        answer: json['answer'] as String? ?? '',
        input: json['input'] as Map<String, dynamic>? ?? {},
      );
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'answer': answer,
        'input': input,
      };
}
