import 'parsing.dart';

List<Lab> parseLabs(List<dynamic> raw) => parseModelList(raw, Lab.fromJson);

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
