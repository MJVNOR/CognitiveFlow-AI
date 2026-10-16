// Modelos tipados del API (backend/app/main.py) vía json_serializable.
// Eval/intervenciones siguen como Map: sus formas varían por lab y mock/jev.
import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

Map<String, dynamic> _asMap(dynamic e) => (e as Map).cast<String, dynamic>();

List<T> _parseList<T>(List<dynamic> raw, T Function(Map<String, dynamic>) fromJson) =>
    [for (final e in raw) fromJson(_asMap(e))];

List<Module> parseModules(List<dynamic> raw) => _parseList(raw, Module.fromJson);
List<Lab> parseLabs(List<dynamic> raw) => _parseList(raw, Lab.fromJson);
List<Student> parseStudents(List<dynamic> raw) => _parseList(raw, Student.fromJson);
List<SessionInfo> parseSessions(List<dynamic> raw) => _parseList(raw, SessionInfo.fromJson);
List<Attempt> parseAttempts(List<dynamic> raw) => _parseList(raw, Attempt.fromJson);

@JsonSerializable()
class Module {
  final String id;
  final String title;
  @JsonKey(name: 'order_index', defaultValue: 0)
  final int orderIndex;
  const Module({required this.id, required this.title, this.orderIndex = 0});
  factory Module.fromJson(Map<String, dynamic> json) => _$ModuleFromJson(json);
  Map<String, dynamic> toJson() => _$ModuleToJson(this);
}

@JsonSerializable()
class Lab {
  final String id;
  final String title;
  @JsonKey(name: 'lab_type', defaultValue: '')
  final String labType;
  @JsonKey(defaultValue: '')
  final String description;
  @JsonKey(name: 'order_index', defaultValue: 0)
  final int orderIndex;
  @JsonKey(name: 'module_id', defaultValue: '')
  final String moduleId;
  const Lab({
    required this.id,
    required this.title,
    this.labType = '',
    this.description = '',
    this.orderIndex = 0,
    this.moduleId = '',
  });
  factory Lab.fromJson(Map<String, dynamic> json) => _$LabFromJson(json);
  Map<String, dynamic> toJson() => _$LabToJson(this);
}

@JsonSerializable()
class Student {
  final String id;
  @JsonKey(name: 'display_name')
  final String displayName;
  const Student({required this.id, required this.displayName});
  factory Student.fromJson(Map<String, dynamic> json) => _$StudentFromJson(json);
  Map<String, dynamic> toJson() => _$StudentToJson(this);
}

@JsonSerializable()
class SessionInfo {
  final String id;
  @JsonKey(name: 'lab_template_id')
  final String labTemplateId;
  @JsonKey(defaultValue: '')
  final String status;
  const SessionInfo({required this.id, required this.labTemplateId, this.status = ''});
  factory SessionInfo.fromJson(Map<String, dynamic> json) => _$SessionInfoFromJson(json);
  Map<String, dynamic> toJson() => _$SessionInfoToJson(this);
}

@JsonSerializable()
class Attempt {
  final String id;
  @JsonKey(defaultValue: '')
  final String answer;
  @JsonKey(defaultValue: {})
  final Map<String, dynamic> input;
  const Attempt({required this.id, this.answer = '', this.input = const {}});
  factory Attempt.fromJson(Map<String, dynamic> json) => _$AttemptFromJson(json);
  Map<String, dynamic> toJson() => _$AttemptToJson(this);
}
