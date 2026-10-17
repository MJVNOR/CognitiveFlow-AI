import 'parsing.dart';

List<Module> parseModules(List<dynamic> raw) =>
    parseModelList(raw, Module.fromJson);

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
