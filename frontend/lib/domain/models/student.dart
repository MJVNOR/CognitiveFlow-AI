import 'parsing.dart';

List<Student> parseStudents(List<dynamic> raw) =>
    parseModelList(raw, Student.fromJson);

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
