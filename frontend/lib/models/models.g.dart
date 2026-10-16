// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Module _$ModuleFromJson(Map<String, dynamic> json) => Module(
  id: json['id'] as String,
  title: json['title'] as String,
  orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$ModuleToJson(Module instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'order_index': instance.orderIndex,
};

Lab _$LabFromJson(Map<String, dynamic> json) => Lab(
  id: json['id'] as String,
  title: json['title'] as String,
  labType: json['lab_type'] as String? ?? '',
  description: json['description'] as String? ?? '',
  orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
  moduleId: json['module_id'] as String? ?? '',
);

Map<String, dynamic> _$LabToJson(Lab instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'lab_type': instance.labType,
  'description': instance.description,
  'order_index': instance.orderIndex,
  'module_id': instance.moduleId,
};

Student _$StudentFromJson(Map<String, dynamic> json) => Student(
  id: json['id'] as String,
  displayName: json['display_name'] as String,
);

Map<String, dynamic> _$StudentToJson(Student instance) => <String, dynamic>{
  'id': instance.id,
  'display_name': instance.displayName,
};

SessionInfo _$SessionInfoFromJson(Map<String, dynamic> json) => SessionInfo(
  id: json['id'] as String,
  labTemplateId: json['lab_template_id'] as String,
  status: json['status'] as String? ?? '',
);

Map<String, dynamic> _$SessionInfoToJson(SessionInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'lab_template_id': instance.labTemplateId,
      'status': instance.status,
    };

Attempt _$AttemptFromJson(Map<String, dynamic> json) => Attempt(
  id: json['id'] as String,
  answer: json['answer'] as String? ?? '',
  input: json['input'] as Map<String, dynamic>? ?? {},
);

Map<String, dynamic> _$AttemptToJson(Attempt instance) => <String, dynamic>{
  'id': instance.id,
  'answer': instance.answer,
  'input': instance.input,
};
