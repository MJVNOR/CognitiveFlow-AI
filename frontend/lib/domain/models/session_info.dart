import 'parsing.dart';

List<SessionInfo> parseSessions(List<dynamic> raw) =>
    parseModelList(raw, SessionInfo.fromJson);

class SessionInfo {
  final String id;
  final String labTemplateId;
  final String status;
  const SessionInfo(
      {required this.id, required this.labTemplateId, this.status = ''});
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
